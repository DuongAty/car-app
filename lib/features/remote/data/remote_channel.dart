import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:remote_protocol/remote_protocol.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_bootstrap.dart';

/// Where the realtime link currently stands, for the pairing screen.
enum RemoteChannelStatus {
  /// No pairing id yet — nothing is open and nothing costs anything.
  idle,
  connecting,
  connected,

  /// Dropped; a backoff timer is counting down to the next attempt. Normal on
  /// a moving car, not an error state.
  reconnecting,
}

/// Realtime transport between this head unit and the paired phone.
///
/// An interface rather than the Supabase channel directly so the session,
/// command handler, and publisher can all be driven by `FakeRemoteChannel` in
/// tests without a socket.
abstract interface class RemoteChannel {
  /// Envelopes received from the phone. Messages that fail to decode never
  /// reach here — see [protocolMismatch].
  Stream<RemoteEnvelope> get messages;

  /// True while at least one phone is present on the channel.
  Stream<bool> get phoneOnline;

  Stream<RemoteChannelStatus> get status;

  /// Emits once per message dropped because the sender runs a different
  /// [protocolVersion]. The UI turns this into "hai app lệch phiên bản".
  Stream<bool> get protocolMismatch;

  Future<void> connect(String pairingId);

  Future<void> send(RemoteEnvelope envelope);

  Future<void> disconnect();

  /// Closes the streams. The channel is unusable afterwards.
  Future<void> dispose();
}

/// Outcome of decoding one broadcast payload.
sealed class RemoteBroadcastDecoding {
  const RemoteBroadcastDecoding();
}

class RemoteBroadcastDecoded extends RemoteBroadcastDecoding {
  const RemoteBroadcastDecoded(this.envelope);

  final RemoteEnvelope envelope;
}

/// The sender runs a different protocol version. Guessing at the contents is
/// the worst possible failure mode for two independently released apps, so the
/// message is dropped and the mismatch surfaced instead.
class RemoteBroadcastVersionMismatch extends RemoteBroadcastDecoding {
  const RemoteBroadcastVersionMismatch(this.received, this.expected);

  final int received;
  final int expected;
}

class RemoteBroadcastMalformed extends RemoteBroadcastDecoding {
  const RemoteBroadcastMalformed(this.reason);

  final String reason;
}

/// Decodes what `onBroadcast` hands over.
///
/// The envelope travels wrapped under a single key — `RealtimeChannel.send`
/// overwrites `type`/`event` directly on the map it is handed, and the
/// envelope has a `type` field of its own. See [wrapEnvelopeForTransport].
/// Split out as a pure function so the drop-on-mismatch rule is testable
/// without a socket.
RemoteBroadcastDecoding decodeRemoteBroadcast(Map<String, dynamic> broadcast) {
  try {
    return RemoteBroadcastDecoded(unwrapEnvelopeFromTransport(broadcast));
  } on ProtocolVersionMismatch catch (error) {
    return RemoteBroadcastVersionMismatch(error.received, error.expected);
  } on ProtocolException catch (error) {
    return RemoteBroadcastMalformed(error.message);
  } catch (error) {
    return RemoteBroadcastMalformed('$error');
  }
}

/// Exponential backoff with jitter: 1s, 2s, 4s, 8s, 16s, then capped at 30s.
///
/// The link is assumed to be unreliable by default — a head unit in a moving
/// car loses signal constantly. Jitter keeps a fleet of boxes coming back from
/// the same tunnel from reconnecting in lockstep.
Duration remoteReconnectDelay(int attempt, {math.Random? random}) {
  const maxSeconds = 30;
  final exponent = attempt.clamp(0, 5);
  final base = math.min(maxSeconds, 1 << exponent);
  final jitter = (random ?? _defaultRandom).nextDouble() * 0.4 - 0.2;
  final millis = (base * 1000 * (1 + jitter)).round();
  return Duration(milliseconds: millis.clamp(250, maxSeconds * 1000));
}

final math.Random _defaultRandom = math.Random();

/// Supabase Realtime Broadcast + Presence implementation.
///
/// Broadcast (not Postgres changes): a remote button press is ephemeral
/// pub/sub, and writing a row per tap would be pure waste.
class SupabaseRemoteChannel implements RemoteChannel {
  SupabaseRemoteChannel({math.Random? random})
    : _random = random ?? _defaultRandom;

  static const String _logName = 'viet_ktv.remote';
  static const String _presenceKey = 'car';

  /// Injectable only so the backoff schedule can be made deterministic.
  final math.Random _random;

  final StreamController<RemoteEnvelope> _messages =
      StreamController<RemoteEnvelope>.broadcast();
  final StreamController<bool> _phoneOnline =
      StreamController<bool>.broadcast();
  final StreamController<RemoteChannelStatus> _status =
      StreamController<RemoteChannelStatus>.broadcast();
  final StreamController<bool> _protocolMismatch =
      StreamController<bool>.broadcast();

  RealtimeChannel? _channel;
  String? _pairingId;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _disposed = false;
  bool _lastPhoneOnline = false;
  RemoteChannelStatus _lastStatus = RemoteChannelStatus.idle;

  @override
  Stream<RemoteEnvelope> get messages => _messages.stream;

  @override
  Stream<bool> get phoneOnline => _phoneOnline.stream;

  @override
  Stream<RemoteChannelStatus> get status => _status.stream;

  @override
  Stream<bool> get protocolMismatch => _protocolMismatch.stream;

  @override
  Future<void> connect(String pairingId) async {
    if (_disposed) {
      return;
    }
    if (_pairingId == pairingId && _channel != null) {
      return;
    }
    await disconnect();
    _pairingId = pairingId;
    _attempt = 0;
    await _open();
  }

  Future<void> _open() async {
    final pairingId = _pairingId;
    if (_disposed || pairingId == null) {
      return;
    }
    _emitStatus(
      _attempt == 0
          ? RemoteChannelStatus.connecting
          : RemoteChannelStatus.reconnecting,
    );

    await ensureSupabaseInitialized();
    if (_disposed || _pairingId != pairingId) {
      return;
    }

    final client = Supabase.instance.client;
    // A RealtimeChannel can only be subscribed once, so every reconnect
    // attempt builds a fresh one rather than re-subscribing this instance.
    final channel = client.channel(
      'remote:$pairingId',
      opts: const RealtimeChannelConfig(key: _presenceKey, enabled: true),
    );
    _channel = channel;

    for (final event in const [
      RemoteMessageType.command,
      RemoteMessageType.state,
      RemoteMessageType.searchResults,
    ]) {
      channel.onBroadcast(event: event, callback: _handleBroadcast);
    }

    channel
        .onPresenceSync((_) => _emitPresence(channel))
        .onPresenceJoin((_) => _emitPresence(channel))
        .onPresenceLeave((_) => _emitPresence(channel));

    channel.subscribe((status, error) {
      if (_disposed || !identical(_channel, channel)) {
        return;
      }
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _attempt = 0;
          _emitStatus(RemoteChannelStatus.connected);
          unawaited(
            channel
                .track({'role': _presenceKey})
                .catchError((Object _) => ChannelResponse.error),
          );
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          developer.log(
            'Kênh remote rớt: $status',
            name: _logName,
            error: error,
          );
          _scheduleRetry();
      }
    });
  }

  void _scheduleRetry() {
    if (_disposed || _pairingId == null || _retryTimer != null) {
      return;
    }
    _emitPhoneOnline(false);
    _emitStatus(RemoteChannelStatus.reconnecting);
    final delay = remoteReconnectDelay(_attempt, random: _random);
    _attempt++;
    _retryTimer = Timer(delay, () async {
      _retryTimer = null;
      await _closeChannel();
      await _open();
    });
  }

  void _handleBroadcast(Map<String, dynamic> broadcast) {
    final decoded = decodeRemoteBroadcast(broadcast);
    switch (decoded) {
      case RemoteBroadcastDecoded(:final envelope):
        if (!_messages.isClosed) {
          _messages.add(envelope);
        }
      case RemoteBroadcastVersionMismatch(:final received, :final expected):
        developer.log(
          'Bỏ message lệch phiên bản giao thức: nhận $received, cần $expected',
          name: _logName,
        );
        if (!_protocolMismatch.isClosed) {
          _protocolMismatch.add(true);
        }
      case RemoteBroadcastMalformed(:final reason):
        developer.log('Bỏ message sai định dạng: $reason', name: _logName);
    }
  }

  void _emitPresence(RealtimeChannel channel) {
    final hasPhone = channel.presenceState().any(
      (entry) => entry.key != _presenceKey,
    );
    _emitPhoneOnline(hasPhone);
  }

  void _emitPhoneOnline(bool value) {
    if (_lastPhoneOnline == value || _phoneOnline.isClosed) {
      return;
    }
    _lastPhoneOnline = value;
    _phoneOnline.add(value);
  }

  void _emitStatus(RemoteChannelStatus value) {
    if (_lastStatus == value || _status.isClosed) {
      return;
    }
    _lastStatus = value;
    _status.add(value);
  }

  @override
  Future<void> send(RemoteEnvelope envelope) async {
    final channel = _channel;
    if (channel == null || _lastStatus != RemoteChannelStatus.connected) {
      // Fire-and-forget by design: a command pressed while the box is off the
      // network is stale by the time it reconnects, so queueing it would
      // replay the past rather than obey the user.
      return;
    }
    try {
      await channel.sendBroadcastMessage(
        event: envelope.type,
        // Wrapped: `sendBroadcastMessage` overwrites `type`/`event` on the map
        // it is given, and the envelope carries a `type` of its own.
        payload: wrapEnvelopeForTransport(envelope),
      );
    } catch (error) {
      developer.log(
        'Gửi message remote thất bại',
        name: _logName,
        error: error,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _pairingId = null;
    _attempt = 0;
    await _closeChannel();
    _emitPhoneOnline(false);
    _emitStatus(RemoteChannelStatus.idle);
  }

  Future<void> _closeChannel() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) {
      return;
    }
    try {
      await Supabase.instance.client.removeChannel(channel);
    } catch (error) {
      developer.log('Đóng kênh remote thất bại', name: _logName, error: error);
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _messages.close();
    await _phoneOnline.close();
    await _status.close();
    await _protocolMismatch.close();
  }
}
