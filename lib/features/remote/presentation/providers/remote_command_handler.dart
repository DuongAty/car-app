import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remote_protocol/remote_protocol.dart';

import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../queue/presentation/providers/queue_playback_controller.dart';
import '../../../queue/presentation/providers/queue_provider.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../../song_browser/presentation/providers/music_sdk_repository_provider.dart';
import '../../data/remote_mappers.dart';

final remoteCommandHandlerProvider = Provider<RemoteCommandHandler>(
  (ref) => RemoteCommandHandler(ref),
);

/// Turns a [RemoteCommand] from the phone into a call on the controllers that
/// already exist.
///
/// It owns no playback state of its own — every branch delegates. Duplicating
/// any of that logic here would give the head unit and the remote two subtly
/// different notions of "next".
class RemoteCommandHandler {
  RemoteCommandHandler(this._ref);

  static const String _logName = 'viet_ktv.remote.command';

  final Ref _ref;

  Future<void> Function(RemoteEnvelope envelope)? _send;
  void Function()? _onStateRequested;

  /// Wired by [RemoteSession] once a channel is open.
  void bind({
    required Future<void> Function(RemoteEnvelope envelope) send,
    required void Function() onStateRequested,
  }) {
    _send = send;
    _onStateRequested = onStateRequested;
  }

  void unbind() {
    _send = null;
    _onStateRequested = null;
  }

  Future<void> handle(RemoteEnvelope envelope) async {
    if (!envelope.isCommand) {
      // State/search-results are what this side sends, not what it consumes.
      return;
    }
    final RemoteCommand command;
    try {
      command = envelope.asCommand();
    } on ProtocolException catch (error) {
      developer.log('Bỏ lệnh không đọc được', name: _logName, error: error);
      return;
    }
    await apply(command, requestId: envelope.id);
  }

  /// Exposed separately from [handle] so tests can drive a command without
  /// building an envelope.
  Future<void> apply(RemoteCommand command, {required String requestId}) async {
    switch (command) {
      case PlayPauseCommand():
        _nowPlaying.togglePlayPause();
      case NextCommand():
        await _queuePlayback.playNext();
      case PreviousCommand():
        await _queuePlayback.playPrevious();
      case ReplayCommand():
        await _nowPlaying.replayFromStart();
      case StopCommand():
        _nowPlaying.stopPlayback();
      case SeekCommand(:final positionMs):
        _nowPlaying.seekTo(Duration(milliseconds: positionMs));
      case SetVolumeCommand(:final volume):
        // Through Settings, not straight to volumeProvider: that is the path
        // the rail's slider takes, so the level is persisted and Cài đặt →
        // Âm thanh shows the same number.
        _ref
            .read(settingsControllerProvider.notifier)
            .setMasterVolume(volume.clamp(0.0, 1.0));
      case AddToQueueCommand(:final song):
        final queued = RemoteMappers.queuedSong(song);
        _queue.add(queued.song, queued.source);
      case PlayNowCommand(:final song):
        final queued = RemoteMappers.queuedSong(song);
        await _nowPlaying.play(queued.song, queued.source.logoStyle);
      case RemoveFromQueueCommand(:final entryId):
        final index = _indexOfEntry(entryId);
        if (index != -1) {
          _queue.removeAt(index);
        }
      case ReorderQueueCommand(:final entryId, :final toIndex):
        final index = _indexOfEntry(entryId);
        if (index == -1) {
          // The queue changed between the drag and the command landing. Doing
          // nothing is right: acting on a stale index moves the wrong song.
          return;
        }
        _queue.moveToSlot(index, _slotFor(index, toIndex));
      case ClearQueueCommand():
        _queue.clear();
      case SetRepeatModeCommand(:final mode):
        _queue.setQueueRepeatMode(RemoteMappers.queueRepeatModeOf(mode));
      case SetShuffleCommand(:final enabled):
        _queue.setShuffle(enabled);
      case RequestStateCommand():
        _onStateRequested?.call();
      case SearchCommand(:final query, :final source):
        await _search(query: query, source: source, requestId: requestId);
    }
  }

  /// `moveToSlot` works in insertion slots between rows, so a "move to index
  /// N" from the phone has to be shifted by one when the row travels down.
  int _slotFor(int fromIndex, int toIndex) =>
      fromIndex < toIndex ? toIndex + 1 : toIndex;

  int _indexOfEntry(String entryId) {
    final items = _ref.read(queueProvider).items;
    return items.indexWhere((item) => RemoteMappers.entryId(item) == entryId);
  }

  Future<void> _search({
    required String query,
    required RemoteSource source,
    required String requestId,
  }) async {
    // The repository directly, never songBrowserProvider: that one is
    // autoDispose.family, tied to a page, and building it would also kick off
    // a recommendations fetch nobody asked for.
    final repository = _ref.read(musicSdkSongRepositoryProvider);
    final style = RemoteMappers.logoStyleOf(source);
    SearchResultsPayload payload;
    try {
      final results = await repository.search(source: style, query: query);
      payload = SearchResultsPayload(
        requestId: requestId,
        results: [
          for (final song in results) RemoteMappers.songSnapshot(song, style),
        ],
      );
    } catch (error) {
      developer.log(
        'Tìm bài từ điện thoại thất bại',
        name: _logName,
        error: error,
      );
      payload = SearchResultsPayload(requestId: requestId, error: '$error');
    }
    await _send?.call(RemoteEnvelope.searchResults(payload));
  }

  NowPlayingController get _nowPlaying =>
      _ref.read(nowPlayingProvider.notifier);
  QueueController get _queue => _ref.read(queueProvider.notifier);
  QueuePlaybackController get _queuePlayback =>
      _ref.read(queuePlaybackControllerProvider.notifier);
}
