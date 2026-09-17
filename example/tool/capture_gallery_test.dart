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

/// The pages the picker offers, under the names they carry there, with the
/// height each one lays out at. `messages` carries pieces that want a normal
/// viewport, so it is captured at the height the app gives it.
const Map<String, (Widget, double)> _pages = <String, (Widget, double)>{
  'states': (StatesDemo(), 1800),
  'pieces': (PiecesDemo(), 1800),
  'messages': (MessagesDemo(), 1000),
  'navigation': (NavigationDemo(), 1800),
  'rendering': (RenderingDemo(), 1800),
  'surfaces': (SurfacesDemo(), 1800),
};

void main() {
  for (final MapEntry<String, (Widget, double)> entry in _pages.entries) {
    testWidgets('capture ${entry.key}', (WidgetTester tester) async {
      tester.view.physicalSize = Size(1200, entry.value.$2);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
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
