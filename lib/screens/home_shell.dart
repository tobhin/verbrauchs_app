import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'erfassen_screen.dart';
import 'werte_screen.dart';
import 'menu_screen.dart';

class HomeShell extends StatefulWidget {
  final void Function(ThemeMode) onChangeTheme;
  final ValueNotifier<ThemeMode> themeModeListenable;
  
  const HomeShell({super.key, required this.onChangeTheme, required this.themeModeListenable});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ErfassenScreen(),
      const WerteScreen(),
      MenuScreen(onChangeTheme: widget.onChangeTheme, themeModeListenable: widget.themeModeListenable),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch (_index) {
            0 => 'Verbrauchswert erfassen',
            1 => 'Auswertung',
            _ => 'Menü', // --- UPDATE (FEATURE-004) ---
          },
        ),
        centerTitle: true,
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Erfassen'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Werte'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Menü'),
        ],
      ),
    );
  }
}