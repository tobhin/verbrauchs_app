import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/date_symbol_data_local.dart'; // HINZUGEFÜGT
import 'app.dart';
// import 'services/database_service.dart'; // Nicht mehr benötigt

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // HINZUGEFÜGT: Initialisiert die Datumsformatierung für die gesamte App
  await initializeDateFormatting('de_DE', null); 

  tz.initializeTimeZones();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const VerbrauchsApp());
}

// Dein App-Code
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