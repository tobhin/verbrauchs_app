// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz; // HINZUGEFÜGT für den Zugriff auf getLocation
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'services/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('de_DE', null);

  // Zeitzonen-Datenbank initialisieren
  tz.initializeTimeZones();
  // MODIFIZIERT: Lokale Zeitzone für Deutschland setzen. Dies ist entscheidend für geplante Benachrichtigungen.
  tz.setLocalLocation(tz.getLocation('Europe/Berlin'));

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  FlutterError.onError = (details) {
    Logger.log('Flutter error: ${details.exceptionAsString()}');
  };

  runApp(const VerbrauchsApp());
}

class VerbrauchsApp extends StatefulWidget {
  const VerbrauchsApp({super.key});

  @override
  State<VerbrauchsApp> createState() => _VerbrauchsAppState();
}

class _VerbrauchsAppState extends State<VerbrauchsApp> {
  final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.system);

  void _changeTheme(ThemeMode themeMode) {
    _themeMode.value = themeMode;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Verbrauchswerte',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorSchemeSeed: Colors.blue,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: Colors.blue,
          ),
          themeMode: themeMode,
          home: AppScreen(
            onChangeTheme: _changeTheme,
            themeModeListenable: _themeMode,
          ),
        );
      },
    );
  }
}