import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plural_app/friends/qr_reader.dart';
import 'package:qr/qr.dart';
import '../helpers/friends_harness.dart';

/// Draws [data] as a QR code picture, the way a friend's screen would show it.
Uint8List qrPicture(String data, {int scale = 6, bool jpeg = false, int quiet = 4}) {
  final qr = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
  final image = QrImage(qr);
  final n = image.moduleCount + quiet * 2;
  final out = img.Image(width: n * scale, height: n * scale);
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  for (var r = 0; r < image.moduleCount; r++) {
    for (var c = 0; c < image.moduleCount; c++) {
      if (!image.isDark(r, c)) continue;
      img.fillRect(out,
          x1: (c + quiet) * scale,
          y1: (r + quiet) * scale,
          x2: (c + quiet + 1) * scale - 1,
          y2: (r + quiet + 1) * scale - 1,
          color: img.ColorRgb8(0, 0, 0));
    }
  }
  return jpeg ? Uint8List.fromList(img.encodeJpg(out, quality: 60)) : Uint8List.fromList(img.encodePng(out));
}

void main() {
  final reader = ZxingQrReader();

  test('reads a real friend code back out of a picture of its QR', () async {
    final hub = MemoryHub();
    final p = await Phone.on(hub, username: 'alpha');
    final code = await p.c.myCode();
    expect(code, startsWith('WL1-'));
    expect(await reader.decode(qrPicture(code)), code);
  });

  test('still reads it from a small, compressed photo-like picture', () async {
    final hub = MemoryHub();
    final p = await Phone.on(hub, username: 'alpha');
    final code = await p.c.myCode();
    expect(await reader.decode(qrPicture(code, scale: 4, jpeg: true)), code);
  });

  test('a picture with no QR code in it gives null, not an error', () async {
    final blank = img.Image(width: 200, height: 200);
    img.fill(blank, color: img.ColorRgb8(240, 240, 240));
    expect(await reader.decode(Uint8List.fromList(img.encodePng(blank))), isNull);
  });

  test('REVIEW FOCUS: something that is not a picture, or is empty, gives null, not an error', () async {
    expect(await reader.decode(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    expect(await reader.decode(Uint8List(0)), isNull);
  });

  test('REVIEW FOCUS: a huge picture is handled without trouble', () async {
    final big = img.Image(width: 4000, height: 3000);
    img.fill(big, color: img.ColorRgb8(255, 255, 255));
    expect(await reader.decode(Uint8List.fromList(img.encodeJpg(big, quality: 50))), isNull);
  });
}
