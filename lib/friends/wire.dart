import 'dart:convert';
import 'dart:typed_data';

/// What actually travels: a version, optionally the sender's public key (only on
/// the very first hello, so the receiver knows which key to open it with), and the
/// sealed bytes. No names, no words, nothing readable.
class Frame {
  const Frame({this.from, required this.sealed});
  final String? from;
  final Uint8List sealed;
}

Uint8List encodeFrame({String? from, required Uint8List sealed}) => Uint8List.fromList(utf8.encode(jsonEncode({
      'v': 1,
      'f': ?from,
      'b': base64.encode(sealed),
    })));

Frame? decodeFrame(List<int> bytes) {
  try {
    final j = jsonDecode(utf8.decode(bytes));
    if (j is! Map || j['v'] != 1) return null;
    final b = j['b'];
    if (b is! String) return null;
    final f = j['f'];
    if (f != null && f is! String) return null;
    return Frame(from: f as String?, sealed: base64.decode(b));
  } on FormatException {
    return null;
  }
}
