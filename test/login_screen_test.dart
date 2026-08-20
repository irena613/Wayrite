import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timski/screens/auth/login_screen.dart';

// Проверува само клиентска валидација на формата — не смее да стигне до
// appStore.login() (кое бара вистинска Firebase сесија), затоа полињата
// секогаш прво се празнат пред tap на копчето.
void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  }

  testWidgets('прикажува грешки кога е-маил и лозинка се празни', (tester) async {
    await pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '');
    await tester.enterText(fields.at(1), '');

    await tester.tap(find.text('Најави се'));
    await tester.pump();

    expect(find.text('Внеси е-маил'), findsOneWidget);
    expect(find.text('Внеси лозинка'), findsOneWidget);
  });

  testWidgets('не прикажува грешка за е-маил кога полето е пополнето', (tester) async {
    await pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'test@test.mk');
    await tester.enterText(fields.at(1), '');

    await tester.tap(find.text('Најави се'));
    await tester.pump();

    expect(find.text('Внеси е-маил'), findsNothing);
    expect(find.text('Внеси лозинка'), findsOneWidget);
  });

  testWidgets('копчето за демо профил е видливо и достапно', (tester) async {
    await pumpLogin(tester);
    expect(find.text('Продолжи со демо профил'), findsOneWidget);
  });
}
