import '../core/message_part.dart';
import 'defaults.dart' show TempFileSaver;
import 'file_opener_stub.dart'
    if (dart.library.io) 'file_opener_io.dart' as platform;

/// The port's default answer to "open this file the reader just made".
///
/// [TempFileSaver] writes the payload somewhere real; this hands the path to the
/// desktop's own opener, so a file chip does something a reader can see without
/// the app adding a plugin. It reports whether a handler was launched, and says
/// no rather than pretending on the platforms that have none — the web and the
/// mobile targets, where opening is the host's to define.
class SystemFileOpener {
  const SystemFileOpener();

  Future<bool> open(String path) => platform.openWithSystem(path);

  /// Saves the payload and opens what was written; false when either step had
  /// nothing to work with.
  Future<bool> saveAndOpen(
    FilePart part, {
    TempFileSaver saver = const TempFileSaver(),
    String? name,
  }) async {
    final String? path = await saver.save(part, name: name);
    if (path == null) return false;
    return open(path);
  }
}
