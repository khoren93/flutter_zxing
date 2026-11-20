// The showcase launcher.
//
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing_example/showcase.dart';

void main() {
  testWidgets('a template it does not have opens the list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ShowcaseTemplate('kiosk')));
    expect(tester.takeException(), isNull);
    expect(find.byType(ShowcasePage), findsOneWidget);
  });
}
