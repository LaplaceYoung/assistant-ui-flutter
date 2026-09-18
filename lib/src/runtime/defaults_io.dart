import 'dart:io';
import 'dart:typed_data';

/// Writes the bytes under the temporary directory and returns the path.
Future<String?> writeFileBytes(
  String filename,
  Uint8List bytes, {
  String? directory,
}) async {
  final Directory dir = directory == null
      ? await Directory.systemTemp.createTemp('assistant_ui')
      : Directory(directory);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final File file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
/// Removes a file this adapter wrote.
Future<void> deleteFile(String path) async {
  final File file = File(path);
  if (file.existsSync()) await file.delete();
}
