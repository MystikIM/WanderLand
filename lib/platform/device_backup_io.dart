import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract class BackupIo {
  Future<Directory> exportDirectory();
  Future<void> shareFile(File f);
  Future<Uint8List?> pickBackup();
}

class DeviceBackupIo implements BackupIo {
  @override
  Future<Directory> exportDirectory() => getTemporaryDirectory();

  @override
  Future<void> shareFile(File f) async {
    // share_plus changed its entry point across versions; use the one the
    // installed version provides (current: SharePlus.instance.share(ShareParams(...))).
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
  }

  @override
  Future<Uint8List?> pickBackup() async {
    // file_picker 13: static API; read the chosen file ourselves.
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.path;
    if (path == null) return null;
    return File(path).readAsBytes();
  }
}
