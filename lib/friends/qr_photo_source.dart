import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Where a picture of a friend's QR code comes from. Null means the person backed out.
abstract class QrPhotoSource {
  /// Opens the phone's own camera app for one picture. The app itself never gets camera access.
  Future<Uint8List?> takePhoto();

  /// Lets the person choose a picture or screenshot they already have.
  Future<Uint8List?> pickPicture();
}

class DevicePhotoSource implements QrPhotoSource {
  final ImagePicker _picker = ImagePicker();

  Future<Uint8List?> _get(ImageSource source) async {
    final x = await _picker.pickImage(source: source, maxWidth: 2000);
    return x?.readAsBytes();
  }

  @override
  Future<Uint8List?> takePhoto() => _get(ImageSource.camera);

  @override
  Future<Uint8List?> pickPicture() => _get(ImageSource.gallery);
}
