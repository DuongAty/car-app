import 'dart:async';

import 'package:remote_protocol/remote_protocol.dart';
import 'package:viet_ktv/features/remote/data/remote_channel.dart';

/// In-memory stand-in for the Supabase realtime link.
///
/// [emit] plays the part of the phone sending something; [sent] records what
/// the head unit broadcast back, which is what the publisher tests assert on.
class FakeRemoteChannel implements RemoteChannel {
  final StreamController<RemoteEnvelope> _messages =
      StreamController<RemoteEnvelope>.broadcast();
  final StreamController<bool> _phoneOnline =
      StreamController<bool>.broadcast();
  final StreamController<RemoteChannelStatus> _status =
      StreamController<RemoteChannelStatus>.broadcast();
  final StreamController<bool> _protocolMismatch =
      StreamController<bool>.broadcast();

  final List<RemoteEnvelope> sent = [];
  final List<String> connectedTo = [];
  int disconnectCount = 0;

  List<RemoteState> get sentStates => [
    for (final envelope in sent)
      if (envelope.isState) envelope.asState(),
  ];

  List<SearchResultsPayload> get sentSearchResults => [
    for (final envelope in sent)
      if (envelope.isSearchResults) envelope.asSearchResults(),
  ];

  /// Delivers a message as if it had arrived from the phone.
  void emit(RemoteEnvelope envelope) => _messages.add(envelope);

  void emitCommand(RemoteCommand command, {String? id}) =>
      emit(RemoteEnvelope.command(command, id: id));

  void emitPhoneOnline(bool online) => _phoneOnline.add(online);

  @override
  Stream<RemoteEnvelope> get messages => _messages.stream;

  @override
  Stream<bool> get phoneOnline => _phoneOnline.stream;

  @override
  Stream<RemoteChannelStatus> get status => _status.stream;

  @override
  Stream<bool> get protocolMismatch => _protocolMismatch.stream;

  @override
  Future<void> connect(String pairingId) async => connectedTo.add(pairingId);

  @override
  Future<void> send(RemoteEnvelope envelope) async => sent.add(envelope);

  @override
  Future<void> disconnect() async => disconnectCount++;

  @override
  Future<void> dispose() async {
    await _messages.close();
    await _phoneOnline.close();
    await _status.close();
    await _protocolMismatch.close();
  }
}
