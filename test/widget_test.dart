// Datei: test/widget_test.dart

// import 'package:flutter/material.dart'; // War unbenutzt
import 'package:flutter_test/flutter_test.dart';
import 'package:verbrauchs_app/main.dart';
import 'package:verbrauchs_app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Baue die App und löse einen Frame aus.
    await tester.pumpWidget(const VerbrauchsApp());

    // Überprüfe, ob der erste Bildschirm (AppScreen) angezeigt wird.
    expect(find.byType(AppScreen), findsOneWidget);

    // Überprüfe, ob der Titel "Erfassen" im AppBar vorhanden ist.
    expect(find.text('Erfassen'), findsOneWidget);
  });
}