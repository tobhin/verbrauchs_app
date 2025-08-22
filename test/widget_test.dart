import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verbrauchs_app/main.dart'; // Importiert deine main.dart

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Baue die App und löse einen Frame aus.
    await tester.pumpWidget(const VerbrauchsApp());

    // Überprüfe, ob der erste Bildschirm (Erfassen) angezeigt wird.
    // Wir suchen nach dem Titel im AppBar.
    expect(find.text('Erfassen'), findsOneWidget);

    // Wir überprüfen, ob die anderen Titel NICHT sichtbar sind.
    expect(find.text('Werte'), findsNothing);
    expect(find.text('Menü'), findsNothing);
  });
}