import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_protocol/remote_protocol.dart';
import 'package:viet_ktv/features/remote/data/remote_channel.dart';

/// Wraps an envelope the way it actually arrives at `onBroadcast`.
///
/// The two extra top-level keys are not decoration: `RealtimeChannel.send`
/// assigns `type`/`event` straight onto the map it is handed. Before the
/// envelope was nested under its own key, that assignment overwrote the
/// envelope's own `type` and every message was silently ignored by both apps.
Map<String, dynamic> _broadcast(Map<String, dynamic> envelope) =>
    wrapEnvelopeForTransport(
        RemoteEnvelope(
          v: envelope['v'] as int,
          type: envelope['type'] as String,
          id: envelope['id'] as String,
          ts: envelope['ts'] as int,
          payload: Map<String, dynamic>.from(envelope['payload'] as Map),
        ),
      )
      ..['type'] = 'broadcast'
      ..['event'] = envelope['type'];

void main() {
  group('decoding what arrives on the channel', () {
    test('a well-formed command decodes', () {
      final envelope = RemoteEnvelope.command(const NextCommand());

      final decoded = decodeRemoteBroadcast(_broadcast(envelope.toJson()));

      expect(decoded, isA<RemoteBroadcastDecoded>());
      expect(
        (decoded as RemoteBroadcastDecoded).envelope.asCommand(),
        isA<NextCommand>(),
      );
    });

    test('a message from another protocol version is dropped, not guessed', () {
      final envelope = RemoteEnvelope.command(const NextCommand()).toJson()
        ..['v'] = protocolVersion + 1;

      final decoded = decodeRemoteBroadcast(_broadcast(envelope));

      expect(decoded, isA<RemoteBroadcastVersionMismatch>());
      final mismatch = decoded as RemoteBroadcastVersionMismatch;
      expect(mismatch.received, protocolVersion + 1);
      expect(mismatch.expected, protocolVersion);
    });

    test('a malformed message is dropped without throwing', () {
      expect(
        decodeRemoteBroadcast({
          'type': 'broadcast',
          'event': 'cmd',
          envelopeTransportKey: {'v': protocolVersion, 'type': 'cmd'},
        }),
        isA<RemoteBroadcastMalformed>(),
      );
      expect(
        decodeRemoteBroadcast({
          'type': 'broadcast',
          'payload': 'not-an-object',
        }),
        isA<RemoteBroadcastMalformed>(),
      );
      expect(
        decodeRemoteBroadcast(const {'type': 'broadcast'}),
        isA<RemoteBroadcastMalformed>(),
      );
    });

    test('an unrecognized command kind is malformed, not a crash', () {
      final envelope = RemoteEnvelope(
        type: RemoteMessageType.command,
        id: 'x',
        ts: 0,
        payload: const {'kind': 'selfDestruct'},
      );

      final decoded = decodeRemoteBroadcast(_broadcast(envelope.toJson()));

      // The envelope itself is valid; the failure surfaces when the payload is
      // read, which is where the handler swallows it.
      expect(decoded, isA<RemoteBroadcastDecoded>());
      expect(
        () => (decoded as RemoteBroadcastDecoded).envelope.asCommand(),
        throwsA(isA<ProtocolFormatException>()),
      );
    });
  });

  group('reconnect backoff', () {
    test('doubles per attempt and caps at 30s', () {
      // Jitterless: a fixed 0.5 draw cancels the ±20% window exactly.
      final random = _FixedRandom(0.5);
      final delays = [
        for (var attempt = 0; attempt < 8; attempt++)
          remoteReconnectDelay(attempt, random: random).inMilliseconds,
      ];

      expect(delays.take(6), [1000, 2000, 4000, 8000, 16000, 30000]);
      expect(delays.every((delay) => delay <= 30000), isTrue);
    });

    test('jitter keeps every delay inside ±20%', () {
      final random = math.Random(7);
      for (var attempt = 0; attempt < 8; attempt++) {
        final delay = remoteReconnectDelay(attempt, random: random);
        final base = math.min(30, 1 << attempt.clamp(0, 5)) * 1000;
        expect(
          delay.inMilliseconds,
          greaterThanOrEqualTo((base * 0.8).round()),
        );
        expect(delay.inMilliseconds, lessThanOrEqualTo((base * 1.2).round()));
      }
    });
  });
}

class _FixedRandom implements math.Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}
