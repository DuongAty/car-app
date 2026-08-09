import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/liquid_glass.dart';
import '../../../../core/shared/widgets/surface_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../queue/presentation/providers/queue_playback_controller.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../../source_selection/presentation/widgets/source_badge.dart';
import 'double_tap_zone.dart';
import 'stage_backdrop.dart';

/// How long the fullscreen controls stay up after the last interaction.
const Duration kControlsAutoHideDelay = Duration(seconds: 3);

/// How long the seek confirmation badge stays up after a double-tap seek.
const Duration kSeekBadgeDuration = Duration(milliseconds: 600);

/// Now-playing preview: real video playback above a transport strip.
///
/// Reads [nowPlayingProvider] rather than owning a [VideoPlayerController]
/// itself. That state (and the controller) is shared app-wide, so the exact
/// same instance of this widget on the browser page and the queue page shows
/// the same video mid-playback instead of restarting it — navigating between
/// them must not interrupt what's already playing, only picking a different
/// song does.
class PreviewPlayer extends ConsumerStatefulWidget {
  const PreviewPlayer({super.key});

  @override
  ConsumerState<PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends ConsumerState<PreviewPlayer> {
  /// Reaches the fullscreen overlay's visibility flag from the key handler.
  ///
  /// Owned per instance, never module-level: the four pages that build a
  /// `PreviewPlayer` are pushed as `maintainState: true` routes, so a player on
  /// a page underneath stays in the element tree while another is on top. A
  /// shared key would then be claimed by two live elements at once and the
  /// framework would throw `Duplicate GlobalKey detected in widget tree`.
  final GlobalKey<_FullscreenControlsOverlayState> _overlayKey = GlobalKey();

  /// Reaches the seek feedback badge from the double-tap handler. Owned per
  /// instance for the same reason as [_overlayKey] above.
  final GlobalKey<_SeekFeedbackBadgeState> _seekBadgeKey = GlobalKey();

  /// Non-focusable marker node wrapped around the play/pause button so the
  /// overlay can hand focus back to it after a reveal. It only exists because
  /// [CircleIconButton] does not expose the focus node it builds; the real
  /// target is the first focusable node underneath this one.
  ///
  /// Deliberately the play/pause button, not the exit-fullscreen button:
  /// `FocusableTile`'s ActivateIntent claims Enter, so if the exit button held
  /// focus after a reveal, the next Enter would exit fullscreen instead of
  /// toggling playback — Enter has always meant play/pause on this player.
  final FocusNode _playPauseFocusAnchor = FocusNode(
    debugLabel: 'playPauseFocusAnchor',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// Captured in onDoubleTapDown because onDoubleTap carries no position.
  Offset? _doubleTapPosition;

  /// Whether the fullscreen controls were on screen when the finger landed.
  ///
  /// Captured here rather than read in onTap because the overlay's own
  /// Listener calls reveal() on pointer-down, ~300ms before the tap is
  /// recognised — by then the controls are always visible and the
  /// tap-only-reveals rule could never fire. Defaults to true so that
  /// normal/wide, which have no overlay at all, simply toggle playback.
  bool _controlsVisibleAtTapDown = true;

  /// The pointer whose tap the capture above is being held for.
  ///
  /// `TapGestureRecognizer` tracks only the primary pointer, so a second
  /// finger landing while the first is still down must not overwrite what
  /// the first finger's eventual tap will read — that would let a stray
  /// second touch (a resting thumb, a second person reaching for the
  /// screen) make a reveal-only tap pause the song instead.
  int? _capturePointer;

  @override
  void dispose() {
    _playPauseFocusAnchor.dispose();
    super.dispose();
  }

  void _revealControls() => _overlayKey.currentState?.reveal();

  void _handleTap(NowPlayingController notifier) {
    if (!_controlsVisibleAtTapDown) {
      // The tap's only job was waking the controls. Toggling playback here
      // would stop the song every time the user glanced at the progress bar.
      return;
    }
    // Safe with nothing playing: togglePlayPause already returns early when
    // there is no player.
    notifier.togglePlayPause();
  }

  void _handleDoubleTap(
    double width,
    NowPlayingController notifier,
    PlayerViewMode mode, {
    required bool playerLive,
  }) {
    final dx = _doubleTapPosition?.dx;
    if (dx == null) {
      return;
    }
    switch (doubleTapZoneFor(dx, width)) {
      case DoubleTapZone.seekBackward:
        // The seek itself is unconditional — the controller no-ops safely when
        // there is no player. The badge is not: with nothing playing the seek
        // does nothing, and a pill claiming a jump would be a lie.
        notifier.seekBackward();
        if (playerLive) {
          _seekBadgeKey.currentState?.show(forward: false);
        }
      case DoubleTapZone.seekForward:
        notifier.seekForward();
        if (playerLive) {
          _seekBadgeKey.currentState?.show(forward: true);
        }
      case DoubleTapZone.toggleFullscreen:
        if (mode == PlayerViewMode.fullscreen) {
          notifier.exitFullscreen();
        } else {
          notifier.enterFullscreen();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Drives the system bars from the mode. Most target head units and TV
    // boxes have no system bars, so this is a no-op there; it matters on
    // phones and emulators used for testing.
    ref.listen<PlayerViewMode>(nowPlayingProvider.select((s) => s.mode), (
      previous,
      next,
    ) {
      if (previous == next) {
        return;
      }
      if (next == PlayerViewMode.fullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });

    final notifier = ref.read(nowPlayingProvider.notifier);
    final queuePlayback = ref.read(queuePlaybackControllerProvider.notifier);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final visualizerEnabled = ref.watch(
      settingsControllerProvider.select((value) => value.visualizerEnabled),
    );
    final repeatOne = ref.watch(
      settingsControllerProvider.select((value) => value.repeatOne),
    );
    final demoVideoEnabled = ref.watch(
      settingsControllerProvider.select((value) => value.demoVideoEnabled),
    );

    // Only coarse, identity-stable slices are watched here: none of these
    // change on the per-second playback tick, so the video surface and the
    // transport buttons are not rebuilt each second. The elapsed/remaining
    // labels, the progress fill and the play/pause icon are the only things
    // that update per second, and each lives in its own leaf Consumer below so
    // the tick's rebuild is contained to a few text widgets.
    final videoController = ref.watch(
      nowPlayingProvider.select((s) => s.videoController),
    );
    final visualizerController = ref.watch(
      nowPlayingProvider.select((s) => s.visualizerController),
    );
    final activeSource = ref.watch(
      nowPlayingProvider.select((s) => s.activeSource),
    );
    final mode = ref.watch(nowPlayingProvider.select((s) => s.mode));
    final playback = ref.watch(nowPlayingProvider.select((s) => s.playback));
    final hasAudioPlayer = ref.watch(
      nowPlayingProvider.select((s) => s.audioPlayer != null),
    );

    final displayController = visualizerEnabled
        ? visualizerController ?? videoController
        : videoController;
    // Controllers only enter the state after they finish initializing, so
    // watching their identity is enough — by the time one is present here it is
    // already initialized.
    final displayReady =
        displayController != null && displayController.value.isInitialized;

    // The picture carries the three double-tap zones (seek back / toggle
    // fullscreen / seek forward — see double_tap_zone.dart). The transport
    // strip below is excluded so double-tapping a control cannot resize the
    // screen or jump the song out from under the user. In fullscreen the
    // reveal of the auto-hidden controls is wired through a Listener around
    // the whole overlay rather than an onTap on this GestureDetector: an
    // onTap next to onDoubleTap does fire, but not until the double-tap
    // window (~300ms) has elapsed and the double-tap recognizer concedes the
    // arena, so the controls would come back a visible beat after the finger
    // lands. Listener sees the raw pointer-down outside the gesture arena, so
    // the reveal is immediate and it neither competes with nor swallows the
    // double-tap.
    final Widget picture = Stack(
      fit: StackFit.expand,
      children: [
        if (displayReady)
          // Letterboxed rather than BoxFit.cover: a cropped video would
          // clip the burned-in karaoke lyrics baked into the source
          // video's own frame.
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: displayController.value.aspectRatio,
                // Kept on its own layer so the picture is never re-laid-out
                // by a sibling rebuild.
                child: RepaintBoundary(child: VideoPlayer(displayController)),
              ),
            ),
          )
        else
          const StageBackdrop(),
        Positioned(
          top: AppSpacing.md,
          right: AppSpacing.md,
          child: SourceBadge(source: activeSource),
        ),
        _PlaybackStatusOverlay(
          playback: playback,
          hasController: displayReady || hasAudioPlayer,
          demoVideoEnabled: demoVideoEnabled,
        ),
        _SeekFeedbackBadge(key: _seekBadgeKey),
      ],
    );

    final Widget video = LayoutBuilder(
      builder: (context, constraints) => Listener(
        // Inner to the overlay's own Listener, and Flutter dispatches pointer
        // events from the innermost hit-test entry outward, so this records
        // the pre-reveal state before reveal() can change it.
        onPointerDown: (event) {
          if (_capturePointer != null) {
            // A later finger must not overwrite what the pending tap will
            // read.
            return;
          }
          _capturePointer = event.pointer;
          _controlsVisibleAtTapDown =
              _overlayKey.currentState?.isControlsVisible ?? true;
        },
        onPointerUp: (event) {
          if (event.pointer == _capturePointer) {
            _capturePointer = null;
          }
        },
        onPointerCancel: (event) {
          if (event.pointer == _capturePointer) {
            _capturePointer = null;
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTap(notifier),
          onDoubleTapDown: (details) =>
              _doubleTapPosition = details.localPosition,
          onDoubleTap: () => _handleDoubleTap(
            constraints.maxWidth,
            notifier,
            mode,
            playerLive: displayReady || hasAudioPlayer,
          ),
          child: picture,
        ),
      ),
    );

    final Widget transportStrip = _TransportStrip(
      onPlayPause: notifier.togglePlayPause,
      onPrevious: queuePlayback.playPrevious,
      onNext: queuePlayback.playNext,
      onRewind: notifier.seekBackward,
      onFastForward: notifier.seekForward,
      onSeek: notifier.seekToFraction,
      repeatOne: repeatOne,
      onToggleRepeatOne: () => settingsController.setRepeatOne(!repeatOne),
      mode: mode,
      onToggleWide: notifier.toggleWide,
      onToggleFullscreen: () => mode == PlayerViewMode.fullscreen
          ? notifier.exitFullscreen()
          : notifier.enterFullscreen(),
      playPauseFocusAnchor: _playPauseFocusAnchor,
    );

    // In fullscreen the panel chrome is dropped entirely — no glass rim, no
    // rounded corners, no clip — so the picture is full-bleed to the display
    // edges. `normal` and `wide` keep the framed panel: they sit inside the
    // shell alongside the rest of the UI, where the rim is what separates the
    // player from the page.
    final Widget framedPlayer = Column(
      children: [
        Expanded(child: video),
        transportStrip,
      ],
    );

    final Widget surface = mode == PlayerViewMode.fullscreen
        ? _FullscreenControlsOverlay(
            key: _overlayKey,
            video: video,
            controls: transportStrip,
            revealFocusAnchor: _playPauseFocusAnchor,
          )
        : SurfaceScope.of(context)
        ? framedPlayer
        : LiquidGlass(
            radius: AppRadius.md,
            opacity: 0.5,
            padding: const EdgeInsets.all(1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md - 1),
              child: framedPlayer,
            ),
          );

    return _PlayerRemoteShortcuts(
      isFullscreen: mode == PlayerViewMode.fullscreen,
      playPauseFocusAnchor: _playPauseFocusAnchor,
      onTogglePlayPause: notifier.togglePlayPause,
      onNext: queuePlayback.playNext,
      onReplay: notifier.replayFromStart,
      onAnyKey: _revealControls,
      child: surface,
    );
  }
}

/// Brief confirmation that a double-tap seek happened, and in which direction.
///
/// A karaoke video runs continuously, so a 10-second jump is not always
/// obvious — and in fullscreen with the controls auto-hidden, the progress bar
/// that would otherwise show it is off screen.
///
/// Its own leaf so showing and hiding it never rebuilds the video subtree.
class _SeekFeedbackBadge extends StatefulWidget {
  const _SeekFeedbackBadge({super.key});

  @override
  State<_SeekFeedbackBadge> createState() => _SeekFeedbackBadgeState();
}

class _SeekFeedbackBadgeState extends State<_SeekFeedbackBadge> {
  bool _visible = false;
  bool _forward = true;
  // Whether the badge content is in the tree at all — false both before the
  // first seek and once the fade-out finishes, so a hidden badge doesn't
  // leave its icon/text sitting invisibly on top of the video.
  bool _inTree = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    // Without this a fired timer calls setState after unmount.
    _hideTimer?.cancel();
    super.dispose();
  }

  void show({required bool forward}) {
    setState(() {
      _visible = true;
      _inTree = true;
      _forward = forward;
    });
    _hideTimer?.cancel();
    _hideTimer = Timer(kSeekBadgeDuration, () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_inTree) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Align(
        alignment: _forward ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          // A one-shot fade on a state change, not a running animation.
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: AppMotion.control,
            onEnd: () {
              if (!_visible && mounted) {
                setState(() => _inTree = false);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _forward ? AppIcons.fastForward : AppIcons.rewind,
                    color: AppColors.textPrimary,
                    size: AppSpacing.lg,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(context.l10n.seekBadgeStep, style: AppTextStyles.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns the fullscreen controls' visibility.
///
/// Deliberately a small leaf: the flag flips every few seconds, and holding it
/// on the page would rebuild the whole tree each time, which the box
/// performance rules forbid.
class _FullscreenControlsOverlay extends StatefulWidget {
  const _FullscreenControlsOverlay({
    required super.key,
    required this.video,
    required this.controls,
    required this.revealFocusAnchor,
  });

  final Widget video;
  final Widget controls;

  /// Marker node wrapped around the play/pause button inside [controls].
  final FocusNode revealFocusAnchor;

  @override
  State<_FullscreenControlsOverlay> createState() =>
      _FullscreenControlsOverlayState();
}

class _FullscreenControlsOverlayState
    extends State<_FullscreenControlsOverlay> {
  bool _visible = true;
  // Kept true through the fade-out so AnimatedOpacity has something to
  // animate; flips to false only once the fade finishes, which is what
  // actually drops the controls from the tree (an opacity of 0 alone still
  // leaves the widget - and its buttons - present and hit-testable).
  bool _controlsInTree = true;
  Timer? _hideTimer;

  /// Read at pointer-down by [_PreviewPlayerState], before [reveal] runs.
  bool get isControlsVisible => _visible;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    // Without this a fired timer calls setState after unmount.
    _hideTimer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(kControlsAutoHideDelay, () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  void reveal() {
    if (!_visible || !_controlsInTree) {
      setState(() {
        _visible = true;
        _controlsInTree = true;
      });
      _restoreFocusAfterReveal();
    }
    _restartTimer();
  }

  /// Dropping the controls from the tree also drops whichever one held focus,
  /// leaving `primaryFocus` on the enclosing modal scope — a remote user would
  /// have to traverse from scratch. Put focus back on the play/pause button
  /// once the rebuilt controls have re-attached their focus nodes: it keeps
  /// Enter meaning play/pause (the exit-fullscreen button also claims Enter
  /// via `FocusableTile`'s ActivateIntent, which would exit fullscreen
  /// instead), and still gives the remote a sensible starting point — the
  /// user can arrow across to the exit button when they want it.
  void _restoreFocusAfterReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusAnchoredButton(widget.revealFocusAnchor);
    });
  }

  /// Hands focus to the enclosing player wrapper once the controls are gone.
  ///
  /// Dropping the strip disposes whichever button held focus, and focus then
  /// falls to the enclosing modal scope — which is *above* the player, so key
  /// events would no longer pass through the player's own handler and a remote
  /// press could not bring the controls back. The wrapper is deliberately
  /// skipped by arrow traversal, so nothing else can put focus there; this is
  /// the one place that does.
  ///
  /// Deferred to after the frame on purpose: the disposal of the outgoing
  /// button's node happens while the tree is being rebuilt and unfocuses last,
  /// so a request made now would be overwritten.
  void _claimFocusAfterHide() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Focus.maybeOf(context)?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // A pointer-down anywhere in the overlay — picture or transport strip —
    // counts as interaction and restarts the hide timer, so tapping a control
    // at t=2.9s does not fade the strip out mid-press. Listener's default
    // deferToChild behaviour keeps this from claiming hits its children do
    // not want, and it observes the pointer without entering the gesture
    // arena, so the buttons' own taps are untouched.
    return Listener(
      onPointerDown: (_) => reveal(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.video,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            // A one-shot fade on a state change, not a running animation.
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              onEnd: () {
                if (!_visible && _controlsInTree) {
                  setState(() => _controlsInTree = false);
                  _claimFocusAfterHide();
                }
              },
              // Hidden controls must not swallow the tap that reveals them,
              // and once fully faded out they are removed from the tree
              // entirely rather than left invisible-but-present.
              child: _controlsInTree
                  ? IgnorePointer(ignoring: !_visible, child: widget.controls)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Moves focus to the button wrapped by [anchor].
///
/// The anchor itself cannot take focus; its subtree also contains a couple of
/// plumbing nodes (FocusableActionDetector's Shortcuts wrapper among them), so
/// the button's real node is the first descendant that can take focus.
///
/// Always call this after the frame the button is built in — a request made
/// while the tree is still being rebuilt is overwritten by the disposal of the
/// outgoing node.
void _focusAnchoredButton(FocusNode anchor) {
  for (final node in anchor.descendants) {
    if (node.canRequestFocus) {
      node.requestFocus();
      return;
    }
  }
}

class _PlayerRemoteShortcuts extends StatefulWidget {
  const _PlayerRemoteShortcuts({
    required this.child,
    required this.isFullscreen,
    required this.playPauseFocusAnchor,
    required this.onTogglePlayPause,
    required this.onNext,
    required this.onReplay,
    required this.onAnyKey,
  });

  final Widget child;

  /// Non-focusable marker wrapped around the play/pause button, used to hand
  /// focus to it on entering fullscreen.
  final FocusNode playPauseFocusAnchor;

  /// Whether the mode is currently fullscreen. Used to reclaim focus after
  /// entering fullscreen (the top nav that may have held it leaves the tree)
  /// and to know, on dispose, whether the system UI needs restoring.
  final bool isFullscreen;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onNext;
  final VoidCallback onReplay;

  /// Reveals the fullscreen controls (no-op outside fullscreen).
  final VoidCallback onAnyKey;

  @override
  State<_PlayerRemoteShortcuts> createState() => _PlayerRemoteShortcutsState();
}

class _PlayerRemoteShortcutsState extends State<_PlayerRemoteShortcuts> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'previewPlayer');
  Timer? _enterHoldTimer;
  bool _enterLongPressHandled = false;

  static const Duration _enterHoldDuration = Duration(milliseconds: 700);

  /// Moves focus into the player when it goes fullscreen, so the remote is
  /// already acting on the player instead of on whatever the vanished chrome
  /// left focused (or on the enclosing route scope, which swallows the press).
  ///
  /// The target is the play/pause button, not this wrapper. Focusing the
  /// wrapper looks right — its key handler owns the shortcuts — but it strands
  /// the D-pad: the wrapper's rect is the whole viewport, and Flutter's
  /// directional traversal only considers candidates whose centre lies beyond
  /// the focused rect's matching edge, so every control (all of them *inside*
  /// that rect) is filtered out in all four directions. Nothing ever
  /// highlights, and since each press also re-reveals the controls the
  /// auto-hide never fires either, so the reveal path cannot rescue the user.
  /// Starting on a real button leaves every other control one arrow away.
  ///
  /// Deferred to after the frame: in fullscreen the strip is rebuilt inside
  /// the overlay in the very frame this runs in, so the button's node does not
  /// exist yet when `didUpdateWidget` is called.
  ///
  /// This used to be dead code: `KaraokeShell` dropped its bars from an
  /// unkeyed `Column`, which shifted the body's slot and threw away the whole
  /// player subtree — so this state was recreated rather than updated and
  /// `didUpdateWidget` never ran at all. The shell's body is keyed now, the
  /// state survives the chrome toggle, and the request takes effect.
  @override
  void didUpdateWidget(_PlayerRemoteShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFullscreen && !oldWidget.isFullscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focusAnchoredButton(widget.playPauseFocusAnchor);
      });
    }
  }

  @override
  void dispose() {
    // Leaving the player while fullscreen must not strand the device in
    // immersive mode.
    if (widget.isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _enterHoldTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Any remote press brings the controls back, so the exit button is
    // always one further press away. This deliberately does not filter to
    // KeyDownEvent: some keys (e.g. arrow keys already claimed by default
    // focus traversal) only reach this handler as a KeyUpEvent, and a
    // press the player does not otherwise act on must still reveal the
    // controls.
    widget.onAnyKey();

    final key = event.logicalKey;
    final isEnter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space;
    final isNext =
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaTrackNext;

    // Remote shortcuts only while this wrapper itself holds focus. Key events
    // from a focused transport button bubble up here too, and claiming them
    // would freeze focus on that button: arrowRight would fire "next song"
    // forever instead of traversing, making every control to the right of
    // play/pause — including exit-fullscreen — unreachable by D-pad. Once
    // focus is inside the strip the buttons own their keys; the reveal above
    // still runs either way.
    if (!node.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent && isNext) {
      widget.onNext();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent && isEnter && _enterHoldTimer == null) {
      _enterLongPressHandled = false;
      _enterHoldTimer = Timer(_enterHoldDuration, () {
        _enterLongPressHandled = true;
        widget.onReplay();
      });
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent && isEnter) {
      _enterHoldTimer?.cancel();
      _enterHoldTimer = null;
      if (!_enterLongPressHandled) {
        widget.onTogglePlayPause();
      }
      _enterLongPressHandled = false;
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      // Skipped by traversal in fullscreen only. Its rect covers the whole
      // player, so directional traversal used to land on it when arrowing
      // across the transport row; it would then claim arrowRight as "next
      // song" and focus could never move on, stranding the user short of the
      // exit-fullscreen button — the one control they need to get out.
      //
      // Outside fullscreen there is no such trap to guard against (the chrome
      // around the player is still there to arrow back to) and skipping would
      // cost real function: the wrapper could then never hold primary focus,
      // and the `hasPrimaryFocus` gate below would leave the remote shortcuts
      // permanently dead in `normal` and `wide`. Hold-Enter-to-replay has no
      // other trigger anywhere in the UI, so it would simply be gone.
      //
      // Traversal only: `_claimFocusAfterHide`'s explicit request still works
      // in fullscreen.
      skipTraversal: widget.isFullscreen,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}

String _formatSeconds(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// Centered status chip shown while a song is loading, failed to resolve, or
/// none has been selected yet. Hidden once a frame is actually on screen.
class _PlaybackStatusOverlay extends StatelessWidget {
  const _PlaybackStatusOverlay({
    required this.playback,
    required this.hasController,
    required this.demoVideoEnabled,
  });

  final PlaybackState playback;
  final bool hasController;
  final bool demoVideoEnabled;

  @override
  Widget build(BuildContext context) {
    if (hasController) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;

    return switch (playback) {
      PlaybackIdle() => _IdleDemoOverlay(demoVideoEnabled: demoVideoEnabled),
      _ => Center(
        child: switch (playback) {
          PlaybackLoading() => _StatusChip(
            spinner: true,
            label: l10n.playbackLoading,
          ),
          PlaybackFailed() => _StatusChip(
            icon: AppIcons.warning,
            label: l10n.playbackFailed,
          ),
          // A ready state with no controller yet means the player is still
          // initializing on the first frame after resolving the link.
          PlaybackReady() => _StatusChip(
            spinner: true,
            label: l10n.playbackLoading,
          ),
          PlaybackIdle() => const SizedBox.shrink(),
        },
      ),
    };
  }
}

class _IdleDemoOverlay extends StatelessWidget {
  const _IdleDemoOverlay({required this.demoVideoEnabled});

  final bool demoVideoEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Stack(
      children: [
        if (demoVideoEnabled)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            child: _StatusChip(
              icon: AppIcons.movie,
              label: l10n.playbackIdleDemo,
            ),
          ),
        Center(
          child: _StatusChip(
            icon: AppIcons.queue,
            label: l10n.playbackIdlePrompt,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({this.icon, required this.label, this.spinner = false});

  final IconData? icon;
  final String label;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: AppRadius.lg,
      opacity: 0.55,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.green,
                ),
              )
            else if (icon != null)
              Icon(icon, color: AppColors.textPrimary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _TransportStrip extends StatelessWidget {
  const _TransportStrip({
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onRewind,
    required this.onFastForward,
    required this.onSeek,
    required this.repeatOne,
    required this.onToggleRepeatOne,
    required this.mode,
    required this.onToggleWide,
    required this.onToggleFullscreen,
    required this.playPauseFocusAnchor,
  });

  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRewind;
  final VoidCallback onFastForward;
  final ValueChanged<double> onSeek;
  final bool repeatOne;
  final VoidCallback onToggleRepeatOne;
  final PlayerViewMode mode;
  final VoidCallback onToggleWide;
  final VoidCallback onToggleFullscreen;

  /// Non-focusable marker the fullscreen overlay uses to find the
  /// play/pause button's own focus node when it restores focus.
  final FocusNode playPauseFocusAnchor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppLayout.browserPreviewControlsHeight,
      child: ColoredBox(
        color: AppColors.background.withValues(alpha: 0.55),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 92;
            final buttonSize = compact ? 34.0 : 46.0;
            final playSize = compact ? 40.0 : 52.0;
            final gap = compact ? AppSpacing.xs : AppSpacing.md;
            final verticalGap = compact ? AppSpacing.xxs : AppSpacing.sm;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? AppSpacing.md : AppSpacing.lg,
                vertical: compact ? 0 : AppSpacing.xs,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Per-second labels + progress fill live here so only this
                  // leaf rebuilds on the playback tick, not the whole row.
                  _ProgressSection(onSeek: onSeek),
                  SizedBox(height: verticalGap),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TransportButton(
                          icon: AppIcons.previous,
                          onPressed: onPrevious,
                          size: buttonSize,
                        ),
                        SizedBox(width: gap),
                        _TransportButton(
                          icon: AppIcons.rewind,
                          onPressed: onRewind,
                          size: buttonSize,
                        ),
                        SizedBox(width: gap),
                        // Only the play/pause icon depends on the playing flag,
                        // so it is its own leaf rather than rebuilding the strip.
                        //
                        // Marker only: it cannot take focus itself and is
                        // skipped by traversal, so the button below still
                        // behaves exactly as the other transport buttons.
                        Focus(
                          focusNode: playPauseFocusAnchor,
                          canRequestFocus: false,
                          skipTraversal: true,
                          child: _PlayPauseButton(
                            onPressed: onPlayPause,
                            size: playSize,
                          ),
                        ),
                        SizedBox(width: gap),
                        // Mirrors the left side: seek sits next to play on both
                        // sides, track-skip outside it. Having rewind inside on
                        // the left but next inside on the right read as lopsided.
                        _TransportButton(
                          icon: AppIcons.fastForward,
                          onPressed: onFastForward,
                          size: buttonSize,
                        ),
                        SizedBox(width: gap),
                        _TransportButton(
                          icon: AppIcons.next,
                          onPressed: onNext,
                          size: buttonSize,
                        ),
                        SizedBox(width: gap),
                        _TransportButton(
                          icon: AppIcons.repeatOne,
                          onPressed: onToggleRepeatOne,
                          tint: repeatOne ? AppColors.green : null,
                          size: buttonSize,
                        ),
                        SizedBox(width: gap),
                        _TransportButton(
                          icon: mode == PlayerViewMode.normal
                              ? AppIcons.panelClose
                              : AppIcons.panelOpen,
                          onPressed: onToggleWide,
                          size: buttonSize,
                        ),
                        SizedBox(width: gap),
                        _TransportButton(
                          icon: mode == PlayerViewMode.fullscreen
                              ? AppIcons.fullscreenExit
                              : AppIcons.fullscreen,
                          onPressed: onToggleFullscreen,
                          size: buttonSize,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Play/pause button isolated from the transport strip: watches only the
/// playing flag so the surrounding buttons are not rebuilt on the tick.
class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton({required this.onPressed, required this.size});

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowPlayingProvider);
    final controller = now.videoController;
    final videoReady = controller != null && controller.value.isInitialized;
    final isPlaying = videoReady
        ? controller.value.isPlaying
        : now.audioIsPlaying;

    return CircleIconButton(
      icon: isPlaying ? AppIcons.pause : AppIcons.play,
      onPressed: onPressed,
      size: size,
      iconSize: size * 0.5,
      tint: AppColors.greenDeep,
    );
  }
}

/// Elapsed/remaining labels + seek track. The only part of the transport strip
/// that legitimately updates once per second while a song plays.
class _ProgressSection extends ConsumerWidget {
  const _ProgressSection({required this.onSeek});

  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowPlayingProvider);
    final controller = now.videoController;
    final videoReady = controller != null && controller.value.isInitialized;
    final hasAudioPlayer = now.audioPlayer != null;
    final audioReady = videoReady || hasAudioPlayer;
    final position = videoReady ? controller.value.position : now.audioPosition;
    final duration = videoReady ? controller.value.duration : now.audioDuration;
    final durationSeconds = duration.inSeconds;
    final elapsedSeconds = position.inSeconds.clamp(0, durationSeconds);
    final remainingSeconds = durationSeconds - elapsedSeconds;
    final progress = audioReady && duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(_formatSeconds(elapsedSeconds), style: textTheme.labelLarge),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _ProgressTrack(progress: progress, onSeek: onSeek),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(_formatSeconds(remainingSeconds), style: textTheme.labelLarge),
      ],
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.onPressed,
    required this.size,
    this.tint,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: icon,
      onPressed: onPressed,
      size: size,
      iconSize: size * 0.52,
      tint: tint,
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress, required this.onSeek});

  final double progress;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final ratio = progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final filled = constraints.maxWidth * ratio;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              onSeek(details.localPosition.dx / constraints.maxWidth),
          onHorizontalDragUpdate: (details) =>
              onSeek(details.localPosition.dx / constraints.maxWidth),
          child: SizedBox(
            height: 20,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.keyFill,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                Container(
                  height: 4,
                  width: filled,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                Positioned(
                  left: (filled - 7).clamp(0.0, constraints.maxWidth - 14),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
