import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Reads the text out of a picture of a QR code. Null when there is no readable code.
abstract class QrReader {
  Future<String?> decode(Uint8List pictureBytes);
}

/// Open-source ZXing port in plain Dart: nothing leaves the phone and no camera permission
/// is needed, because the picture comes from the camera app or the gallery.
class ZxingQrReader implements QrReader {
  @override
  Future<String?> decode(Uint8List pictureBytes) => compute(_decodeSync, pictureBytes);
}

String? _decodeSync(Uint8List bytes) {
  try {
    if (bytes.isEmpty) return null;
    var image = img.decodeImage(bytes);
    if (image == null) return null;
    // Big photos are slow and no better to read: shrink the long side to 1600.
    const longest = 1600;
    if (image.width > longest || image.height > longest) {
      image = image.width >= image.height
          ? img.copyResize(image, width: longest)
          : img.copyResize(image, height: longest);
    }
    final rgba = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List();
    final source = RGBLuminanceSource(image.width, image.height, rgba);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final hints = DecodeHints()..put(DecodeHintType.tryHarder);
    return QRCodeReader().decode(bitmap, hints: hints).text;
  } catch (_) {
    // Not a picture, no code in it, or too blurry: all just "nothing found".
    return null;
  }
}
