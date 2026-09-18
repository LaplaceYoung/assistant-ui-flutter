import 'dart:typed_data';

/// The web has no file system: the host decides what a download means there.
Future<String?> writeFileBytes(
  String filename,
  Uint8List bytes, {
  String? directory,
}) async =>
    null;
