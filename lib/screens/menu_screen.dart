// Datei: lib/screens/menu_screen.dart

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/excel_helper.dart'; // KORRIGIERT
import '../utils/pdf_helper.dart';   // KORRIGIERT

class MenuScreen extends StatefulWidget {
  final void Function(ThemeMode) onChangeTheme;
  final ValueNotifier<ThemeMode> themeModeListenable;
  
  const MenuScreen({
    super.key,
    required this.onChangeTheme,
    required this.themeModeListenable,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // JETZT WIEDER AKTIVIERT
        ListTile(
          leading: const Icon(Icons.import_export),
          title: const Text('Daten exportieren'),
          onTap: () => _showExportDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever),
          title: const Text('Daten zurücksetzen'),
          onTap: () => _showResetDialog(context),
        ),
        ValueListenableBuilder<ThemeMode>(
            valueListenable: widget.themeModeListenable,
            builder: (context, mode, child) {
              return ExpansionTile(
                leading: const Icon(Icons.color_lens),
                title: const Text('Darstellung'),
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Systemstandard'),
                    value: ThemeMode.system,
                    groupValue: mode,
                    onChanged: (val) => widget.onChangeTheme(val!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Hell'),
                    value: ThemeMode.light,
                    groupValue: mode,
                    onChanged: (val) => widget.onChangeTheme(val!),
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dunkel'),
                    value: ThemeMode.dark,
                    groupValue: mode,
                    onChanged: (val) => widget.onChangeTheme(val!),
                  ),
                ],
              );
            }),
      ],
    );
  }

  // JETZT WIEDER AKTIVIERT
  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daten exportieren'),
        content: const Text('In welchem Format möchtest du exportieren?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportAsExcel(context);
            },
            child: const Text('Excel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportAsPdf(context);
            },
            child: const Text('PDF'),
          ),
        ],
      ),
    );
  }

  // JETZT WIEDER AKTIVIERT
  Future<void> _exportAsExcel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await exportToExcel();
      messenger.showSnackBar(const SnackBar(content: Text('Daten erfolgreich als Excel exportiert und geteilt.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler beim Excel-Export: $e')));
    }
  }

  // JETZT WIEDER AKTIVIERT
  Future<void> _exportAsPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await exportToPdf();
      messenger.showSnackBar(const SnackBar(content: Text('Daten erfolgreich als PDF exportiert und geteilt.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler beim PDF-Export: $e')));
    }
  }
  
  void _showResetDialog(BuildContext context) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ACHTUNG'),
        content: const Text('Möchtest du wirklich alle Zählerstände unwiderruflich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () async {
              await AppDb.instance.deleteDatabaseFile();
              // ignore: use_build_context_synchronously
              Navigator.pop(ctx);
              if (mounted) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alle Daten wurden gelöscht.')));
              }
            },
            child: const Text('Ja, alles löschen'),
          ),
        ],
      ),
    );
  }
}