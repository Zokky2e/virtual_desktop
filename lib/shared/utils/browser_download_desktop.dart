import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Desktop counterpart to the web Blob-download trick — opens a native
/// "Save As" dialog (file_picker already ships a desktop implementation)
/// and writes the bytes straight to disk.
Future<void> triggerBrowserDownload(Uint8List bytes, String fileName) async {
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save file',
    fileName: fileName,
  );
  if (savePath == null) return; // user cancelled
  await File(savePath).writeAsBytes(bytes);
}
