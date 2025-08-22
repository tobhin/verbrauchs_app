import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart'; // KORRIGIERT: Importiert jetzt die korrekte app.dart
// import 'services/database_service.dart'; // Nicht mehr nötig, da wir init() nicht aufrufen

void main() async {
  // Diese Initialisierungen sind sicher und können hier bleiben.
  WidgetsFlutterBinding.ensureInitialized();

  // ENTFERNT: Deine Datenbank initialisiert sich selbst, dieser Aufruf war falsch.
  // await AppDb.instance.init(); 

  // Zeitzonen initialisieren
  tz.initializeTimeZones();

  // App nur im Hochformat erlauben
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const VerbrauchsApp());
}

// Dein ursprünglicher App-Code
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
          home: AppScreen( // KORRIGIERT: Dieser Name passt jetzt zum Widget aus deiner app.dart
            onChangeTheme: _changeTheme,
            themeModeListenable: _themeMode,
          ),
        );
      },
    );
  }
}