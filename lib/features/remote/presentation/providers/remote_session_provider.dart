import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_protocol/remote_protocol.dart';

import '../../../../core/providers/device_identity_provider.dart';
import '../../../../core/providers/local_storage_provider.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../data/pairing_repository.dart';
import '../../data/remote_channel.dart';
import 'remote_command_handler.dart';
import 'remote_state_publisher.dart';

/// Where the channel secret is kept between runs. Only the id is persisted —
/// the six-digit code is single-use and worthless afterwards.
const String remotePairingIdStorageKey = 'remote_pairing_id_v1';

/// Override in tests to avoid a socket.
final remoteChannelProvider = Provider<RemoteChannel>((ref) {
  final channel = SupabaseRemoteChannel();
  ref.onDispose(() => unawaited(channel.dispose()));
  return channel;
});

final pairingRepositoryProvider = Provider<PairingRepository>(
  (ref) => const SupabasePairingRepository(),
);

/// The saved `pairing_id`, or null while this box has never been paired.
///
/// Null is the zero-cost path the design mandates: no socket, no publisher,
/// nothing scheduled.
final remotePairingIdProvider =
    StateNotifierProvider<RemotePairingIdController, String?>(
      (ref) =>
          RemotePairingIdController(ref.watch(localStorageServiceProvider)),
    );

class RemotePairingIdController extends StateNotifier<String?> {
  RemotePairingIdController(this._storage) : super(null) {
    _loaded = _load();
  }

  final LocalStorageService _storage;
  late final Future<void> _loaded;

  /// Completes once the persisted id (if any) has been restored. Tests await
  /// it instead of pumping arbitrary delays.
  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    final saved = await _storage.read(remotePairingIdStorageKey);
    if (!mounted || saved == null || saved.isEmpty) {
      return;
    }
    state = saved;
  }

  Future<void> save(String pairingId) async {
    await _storage.write(remotePairingIdStorageKey, pairingId);
    if (mounted) {
      state = pairingId;
    }
  }
}

/// Owns the remote feature's lifetime: opens the channel when a pairing id
/// exists, routes incoming commands, and runs the state publisher.
///
/// Kept alive from `app.dart` so remote control keeps working while the head
/// unit sits on any screen — or none, with the app in the background.
final remoteSessionProvider = Provider<RemoteSession>((ref) {
  final session = RemoteSession(ref);
  ref.onDispose(session.dispose);
  session.watchPairing();
  return session;
});

class RemoteSession {
  RemoteSession(this._ref);

  static const String _logName = 'viet_ktv.remote.session';

  final Ref _ref;

  String? _activePairingId;
  StreamSubscription<RemoteEnvelope>? _messages;
  StreamSubscription<bool>? _mismatch;
  StreamSubscription<bool>? _presence;
  bool _disposed = false;

  // Held directly rather than re-read on teardown: `dispose` runs while the
  // container is being torn down, and reading a provider at that point throws.
  RemoteChannel? _channel;
  RemoteCommandHandler? _handler;
  RemoteStatePublisher? _publisher;

  /// Starts following the saved pairing id. Does nothing else until one
  /// exists — an unpaired box must not pay for this feature at all.
  void watchPairing() {
    _ref.listen<String?>(remotePairingIdProvider, (_, pairingId) {
      unawaited(_apply(pairingId));
    }, fireImmediately: true);
  }

  Future<void> _apply(String? pairingId) async {
    if (_disposed || pairingId == _activePairingId) {
      return;
    }
    await _stop();
    if (pairingId == null || pairingId.isEmpty) {
      return;
    }
    _activePairingId = pairingId;

    final channel = _ref.read(remoteChannelProvider);
    final handler = _ref.read(remoteCommandHandlerProvider);
    final publisher = _ref.read(remoteStatePublisherProvider);
    _channel = channel;
    _handler = handler;
    _publisher = publisher;

    Future<void> send(RemoteEnvelope envelope) => channel.send(envelope);

    handler.bind(send: send, onStateRequested: publisher.publishNow);
    publisher.bind(send: send, carLabel: await _carLabel());

    _messages = channel.messages.listen((envelope) {
      unawaited(handler.handle(envelope));
    });
    // A phone on the channel means typing moved to the phone keyboard, so the
    // on-screen search column stops earning the space it takes from the video.
    // `read`, never `watch`: making `nowPlayingProvider` depend on remote
    // presence would dispose and rebuild the live decoder every time the phone
    // comes and goes.
    _presence = channel.phoneOnline.listen((online) {
      if (_disposed) {
        return;
      }
      _ref.read(nowPlayingProvider.notifier).setRemoteBrowsingActive(online);
    });

    _mismatch = channel.protocolMismatch.listen((_) {
      developer.log(
        'Điện thoại đang chạy phiên bản giao thức khác — message bị bỏ',
        name: _logName,
      );
    });

    await channel.connect(pairingId);
    publisher.start();
  }

  Future<String?> _carLabel() async {
    try {
      final info = await _ref
          .read(deviceIdentityServiceProvider)
          .getDeviceInfo();
      return info.label;
    } catch (_) {
      return null;
    }
  }

  Future<void> _stop() async {
    if (_activePairingId == null) {
      return;
    }
    _activePairingId = null;
    _publisher?.stop();
    _publisher = null;
    _handler?.unbind();
    _handler = null;
    final channel = _channel;
    _channel = null;
    await _messages?.cancel();
    _messages = null;
    await _mismatch?.cancel();
    _mismatch = null;
    await _presence?.cancel();
    _presence = null;
    // Unpairing must give the search column back, not leave the box stuck in a
    // collapsed layout with no phone to drive it. Skipped while disposing:
    // `_stop` also runs during container teardown, and reading a provider at
    // that point throws — the same reason the channel/handler/publisher above
    // are held directly instead of re-read here.
    if (!_disposed) {
      _ref.read(nowPlayingProvider.notifier).setRemoteBrowsingActive(false);
    }
    await channel?.disconnect();
  }

  void dispose() {
    _disposed = true;
    unawaited(_stop());
  }
}
