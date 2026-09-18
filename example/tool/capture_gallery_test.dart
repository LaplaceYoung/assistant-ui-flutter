// Captures the showcase pages as PNGs, one per page, so the gallery's look is
// archived rather than only asserted.
//
//   flutter test tool/capture_gallery_test.dart --update-goldens
//
// Kept out of `test/` on purpose: goldens are font-sensitive, and the CI machine
// is not the machine these were captured on, so they are evidence, not a gate.
import 'dart:io';

import 'package:assistant_ui_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pages the picker offers, under the names they carry there, with the
/// height each one lays out at. `messages` carries pieces that want a normal
/// viewport, so it is captured at the height the app gives it.
const Map<String, (Widget, double)> _pages = <String, (Widget, double)>{
  'states': (StatesDemo(), 1800),
  'pieces': (PiecesDemo(), 1800),
  'messages': (MessagesDemo(), 1000),
  'navigation': (NavigationDemo(), 1800),
  // The rendering page carries six diagrams; it needs the room.
  'rendering': (RenderingDemo(), 3400),
  'surfaces': (SurfacesDemo(), 1800),
};

/// The test binding draws text as boxes unless a real font is loaded; the
/// landing bundles the one the port is designed against, so the captures read.
Future<void> _loadFonts() async {
  // The icons come from the Material font the SDK caches, so the captures show
  // glyphs rather than boxes.
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      _flutterRootFromTool();
  final List<(String, String)> fonts = <(String, String)>[
    ('Public Sans', '../landing/assets/fonts/PublicSans[wght].ttf'),
    // The theme asks for the generic `monospace` family, so register the file
    // under that name as well as its own.
    ('JetBrains Mono', '../landing/assets/fonts/JetBrainsMono[wght].ttf'),
    ('monospace', '../landing/assets/fonts/JetBrainsMono[wght].ttf'),
    if (flutterRoot != null)
      (
        'MaterialIcons',
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
  ];
  for (final (String family, String path) in fonts) {
    final File file = File(path);
    if (!file.existsSync()) continue;
    final Uint8List bytes = file.readAsBytesSync();
    final FontLoader loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

/// `flutter test` puts the SDK's `flutter` on PATH; its parent is the root.
String? _flutterRootFromTool() {
  for (final String dir in (Platform.environment['PATH'] ?? '').split(':')) {
    final File tool = File('$dir/flutter');
    if (tool.existsSync()) return Directory(dir).parent.path;
  }
  return null;
}

void main() {
  setUpAll(_loadFonts);

  for (final MapEntry<String, (Widget, double)> entry in _pages.entries) {
    testWidgets('capture ${entry.key}', (WidgetTester tester) async {
      tester.view.physicalSize = Size(1200, entry.value.$2);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Public Sans',
          ),
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: entry.value.$1),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${entry.key}.png'),
      );
    });
  }
}
