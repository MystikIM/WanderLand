import 'dart:typed_data';

/// One sealed message addressed to a mailbox. The transport never sees words.
class Envelope {
  const Envelope(this.mailbox, this.bytes);
  final String mailbox;
  final Uint8List bytes;
}

/// How sealed mail travels. Pieces 2 and 3 provide real ones (relay, same Wi-Fi).
abstract class FriendTransport {
  /// Everything that arrives for any mailbox this phone listens on.
  Stream<Envelope> get incoming;

  /// True when the mail was handed over; false when it could not be (offline, relay busy).
  Future<bool> send(Envelope e);

  Future<void> listenOn(String mailbox);
  Future<void> forget(String mailbox);
}

/// What the app uses until a real transport exists: nothing leaves the phone.
class OfflineTransport implements FriendTransport {
  @override
  Stream<Envelope> get incoming => const Stream<Envelope>.empty();
  @override
  Future<bool> send(Envelope e) async => false;
  @override
  Future<void> listenOn(String mailbox) async {}
  @override
  Future<void> forget(String mailbox) async {}
}
