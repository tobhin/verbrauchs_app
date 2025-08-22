import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
// Die NotificationService Zeile wird hier nicht mehr importiert
import 'screens/app_screen.dart';
import 'services/database_service.dart';

void main() async {
  // Die meisten Initialisierungen sind sicher und können hier bleiben.
  WidgetsFlutterBinding.ensureInitialized();

  // Datenbank initialisieren
  await AppDb.instance.init();

  // Zeitzonen initialisieren
  tz.initializeTimeZones();

  // ENTFERNT: Diese Zeile war der wahrscheinliche Verursacher des Absturzes.
  // await NotificationService().init();

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
          home: AppScreen(
            onChangeTheme: _changeTheme,
            themeModeListenable: _themeMode,
          ),
        );
      },
    );
  }
}