// Базичен smoke test: апликацијата стартува на Login екран и навигира
// кон HomeShell преку "Продолжи со демо профил".

import 'package:flutter_test/flutter_test.dart';

import 'package:timski/main.dart';

void main() {
  testWidgets('Login screen прикажува наслов и демо копче', (WidgetTester tester) async {
    await tester.pumpWidget(const TimskiApp());

    expect(find.text('Тимски'), findsOneWidget);
    expect(find.text('Продолжи со демо профил'), findsOneWidget);
  });

  testWidgets('Демо најава отвора Feed со bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const TimskiApp());

    await tester.tap(find.text('Продолжи со демо профил'));
    await tester.pumpAndSettle();

    expect(find.text('Почетна'), findsOneWidget);
    expect(find.text('Профил'), findsOneWidget);
  });
}
