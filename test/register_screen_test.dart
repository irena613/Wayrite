import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timski/screens/auth/register_screen.dart';

// Проверува клиентска валидација и провeрata за совпаѓање на лозинки, кои
// мора да се извршат ПРЕД appStore.register() (кое бара вистинска Firebase
// сесија) — затоа тестовите никогаш не пополнуваат валидна комбинација која
// би поминала целосно.
void main() {
  Future<void> pumpRegister(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
  }

  testWidgets('прикажува грешки за сите празни полиња', (tester) async {
    await pumpRegister(tester);

    await tester.tap(find.text('Регистрирај се'));
    await tester.pump();

    expect(find.text('Внеси име'), findsOneWidget);
    expect(find.text('Внеси корисничко име'), findsOneWidget);
    expect(find.text('Внеси е-маил'), findsOneWidget);
    expect(find.text('Најмалку 6 карактери'), findsOneWidget);
    // "Потврди лозинка" е и лабелата на полето и текстот на грешката, па
    // кога полето е празно се прикажани и двете — 2 совпаѓања, не 1.
    expect(find.text('Потврди лозинка'), findsNWidgets(2));
  });

  testWidgets('лозинка пократка од 6 карактери е одбиена', (tester) async {
    await pumpRegister(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(3), '123'); // Лозинка

    await tester.tap(find.text('Регистрирај се'));
    await tester.pump();

    expect(find.text('Најмалку 6 карактери'), findsOneWidget);
  });

  testWidgets('прикажува грешка кога лозинките не се совпаѓаат', (tester) async {
    await pumpRegister(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Марија Стојановска'); // Име
    await tester.enterText(fields.at(1), 'marija'); // Корисничко име
    await tester.enterText(fields.at(2), 'marija@test.mk'); // Е-маил
    await tester.enterText(fields.at(3), 'lozinka1'); // Лозинка
    await tester.enterText(fields.at(4), 'lozinka2'); // Потврди лозинка (различна)

    await tester.tap(find.text('Регистрирај се'));
    await tester.pump();

    expect(find.text('Лозинките не се совпаѓаат.'), findsOneWidget);
  });
}
