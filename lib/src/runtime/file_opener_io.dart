import 'dart:io';

/// Hands a path to the desktop's own opener: `open` on macOS, `xdg-open` on
/// Linux, `start` on Windows. No plugin, and nothing happens on a mobile build.
Future<bool> openWithSystem(String path) async {
  final File file = File(path);
  if (!file.existsSync()) return false;
  final List<String> command;
  if (Platform.isMacOS) {
    command = <String>['open', path];
  } else if (Platform.isLinux) {
    command = <String>['xdg-open', path];
  } else if (Platform.isWindows) {
    command = <String>['cmd', '/c', 'start', '', path];
  } else {
    // iOS and Android have no such command line; the host opens the file.
    return false;
  }
  try {
    final Process process = await Process.start(
      command.first,
      command.sublist(1),
      mode: ProcessStartMode.detached,
    );
    return process.pid > 0;
  } on Object {
    return false;
  }
}
