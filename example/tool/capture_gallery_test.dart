// Captures the showcase pages as PNGs, one per page, so the gallery's look is
// archived rather than only asserted.
//
//   flutter test tool/capture_gallery_test.dart --update-goldens
//
// Kept out of `test/` on purpose: goldens are font-sensitive, and the CI machine
// is not the machine these were captured on, so they are evidence, not a gate.
import 'package:assistant_ui_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pages the picker offers, under the names they carry there.
const Map<String, Widget> _pages = <String, Widget>{
  'states': StatesDemo(),
  'pieces': PiecesDemo(),
  'messages': MessagesDemo(),
  'navigation': NavigationDemo(),
  'rendering': RenderingDemo(),
  'surfaces': SurfacesDemo(),
};

void main() {
  for (final MapEntry<String, Widget> entry in _pages.entries) {
    testWidgets('capture ${entry.key}', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: entry.value),
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
