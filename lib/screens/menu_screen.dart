import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/meter.dart';
import '../models/meter_type.dart';
import '../models/reading.dart';
import '../models/reminder.dart';
import '../models/tariff.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';

class MenuScreen extends StatefulWidget {
  final void Function(ThemeMode) onChangeTheme;
  final ValueNotifier<ThemeMode> themeModeListenable;

  const MenuScreen({super.key, required this.onChangeTheme, required this.themeModeListenable});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<Meter> _meters = [];
  List<Meter> _favoriteMeters = [];
  Map<int, Tariff> _tariffs = {};
  Map<int, List<Reminder>> _reminders = {};
  Map<int, int> _readingCounts = {};
  Map<int, Reading?> _startwerte = {};
  int _openPanelIndex = 0;
  List<MeterType> _meterTypes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _meterTypes = await AppDb.instance.fetchMeterTypes();
      final ms = await AppDb.instance.fetchMeters();
      final favs = ms.where((m) => m.isFavorite == true).toList();
      final Map<int, Tariff> ts = {};
      final Map<int, List<Reminder>> rems = {};
      final Map<int, int> counts = {};
      final Map<int, Reading?> starts = {};

      for (var meter in ms) {
        final tariff = await AppDb.instance.getTariff(meter.id!);
        if (tariff != null) {
          ts[meter.id!] = tariff;
        }
        final meterReminders = await AppDb.instance.fetchReminders(meter.id!);
        rems[meter.id!] = meterReminders;

        final readings = await AppDb.instance.fetchReadingsForMeter(meter.id!);
        counts[meter.id!] = readings.length;

        // Startwert ist der Reading mit frühestem Datum
        readings.sort((a, b) => a.date.compareTo(b.date));
        starts[meter.id!] = readings.isNotEmpty ? readings.first : null;
      }

      if (mounted) {
        setState(() {
          _meters = ms;
          _favoriteMeters = favs;
          _tariffs = ts;
          _reminders = rems;
          _readingCounts = counts;
          _startwerte = starts;
        });
      }
    } catch (e, st) {
      await Logger.log('[MenuScreen] ERROR: Failed to load data: $e\n$st');
    }
  }

  void _handlePanelOpen(int index) {
    setState(() {
      _openPanelIndex = _openPanelIndex == index ? -1 : index;
    });
  }

  Future<void> _toggleFavorite(Meter meter, bool? isFav) async {
    await AppDb.instance.updateMeter(meter.copyWith(isFavorite: isFav ?? false));
    await _loadData();
  }

  Future<void> _showStartwertDialog(Meter meter) async {
    final startwertCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateFormat('dd.MM.yyyy').format(DateTime.now()));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Startwert für ${meter.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startwertCtrl,
              decoration: const InputDecoration(labelText: 'Anfangszählerstand'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dateCtrl,
              decoration: const InputDecoration(labelText: 'Datum des Startwerts'),
              keyboardType: TextInputType.datetime,
            ),
          ],
        ),
        actions: [
          TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(child: const Text('Speichern'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) {
      await AppDb.instance.insertReading(Reading(
        meterId: meter.id!,
        date: DateFormat('dd.MM.yyyy').parseLoose(dateCtrl.text),
        value: double.tryParse(startwertCtrl.text.replaceAll(',', '.')),
        ht: null,
        nt: null,
      ));
      await _loadData();
    }
    startwertCtrl.dispose();
    dateCtrl.dispose();
  }

  Future<void> _showTarifDialog(Meter meter) async {
    final costCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tarif für ${meter.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: costCtrl,
              decoration: const InputDecoration(labelText: 'Kosten pro Einheit (€)'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feeCtrl,
              decoration: const InputDecoration(labelText: 'Grundgebühr (€)'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(child: const Text('Speichern'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) {
      await AppDb.instance.insertTariff(Tariff(
        meterId: meter.id!,
        costPerUnit: double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0,
        baseFee: double.tryParse(feeCtrl.text.replaceAll(',', '.')) ?? 0.0,
      ));
      await _loadData();
    }
    costCtrl.dispose();
    feeCtrl.dispose();
  }

  Future<void> _showDeleteDialog(Meter meter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Zähler löschen'),
        content: Text('Möchtest du "${meter.name}" wirklich löschen?\nDie bisherigen Daten bleiben erhalten.'),
        actions: [
          TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(child: const Text('Löschen'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) {
      await AppDb.instance.deleteMeter(meter.id!);
      await _loadData();
    }
  }

  Future<void> _addMeter() async {
    final nameCtrl = TextEditingController();
    final nrCtrl = TextEditingController();
    int typeId = _meterTypes.isNotEmpty ? _meterTypes.first.id! : 2;

    if (_meterTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Zählertypen verfügbar. Verwende Standardtyp (Wasser).')),
      );
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zähler hinzufügen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: typeId,
                items: _meterTypes
                    .map((type) => DropdownMenuItem<int>(
                          value: type.id,
                          child: Text(type.name),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) typeId = v;
                },
                decoration: const InputDecoration(labelText: 'Typ', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nrCtrl,
                decoration: const InputDecoration(labelText: 'Zählernummer'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(child: const Text('Hinzufügen'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) {
      await AppDb.instance.insertMeter(
        Meter(
          name: nameCtrl.text.trim(),
          meterTypeId: typeId,
          number: nrCtrl.text.trim(),
          active: true,
          isFavorite: false,
        ),
      );
      await _loadData();
    }
    nameCtrl.dispose();
    nrCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Helper für Farben von Icons
    Color _flagColor(Meter meter) =>
        _startwerte[meter.id] != null ? Colors.green : Colors.grey;
    Color _euroColor(Meter meter) =>
        _tariffs[meter.id] != null ? Colors.amber[700]! : Colors.grey;
    Color _starColor(Meter meter) => Colors.grey; // immer farblos/neutral

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Favoriten Panel
          Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              key: const PageStorageKey('Favoriten'),
              initiallyExpanded: _openPanelIndex == 0,
              onExpansionChanged: (_) => _handlePanelOpen(0),
              leading: Icon(Icons.star, color: Colors.grey), // farblos
              title: const Text('Favoriten', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                ..._meters.map((meter) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: CheckboxListTile(
                    value: meter.isFavorite,
                    title: Text(meter.name),
                    subtitle: Text('Nr: ${meter.number}'),
                    onChanged: (val) => _toggleFavorite(meter, val),
                  ),
                )),
              ],
            ),
          ),
          // Zähler & Tarife Panel
          Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              key: const PageStorageKey('ZaehlerTarife'),
              initiallyExpanded: _openPanelIndex == 1,
              onExpansionChanged: (_) => _handlePanelOpen(1),
              leading: const Icon(Icons.tune, color: Colors.grey),
              title: const Text('Zähler & Tarife', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                ..._meters.map((meter) => Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    title: Text(meter.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Nr: ${meter.number}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.flag, color: _flagColor(meter)),
                          tooltip: 'Startwert bearbeiten',
                          onPressed: () => _showStartwertDialog(meter),
                        ),
                        IconButton(
                          icon: Icon(Icons.euro, color: _euroColor(meter)),
                          tooltip: 'Tarif bearbeiten',
                          onPressed: () => _showTarifDialog(meter),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          tooltip: 'Zähler löschen',
                          onPressed: () => _showDeleteDialog(meter),
                        ),
                      ],
                    ),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Zähler hinzufügen'),
                    onPressed: _addMeter,
                  ),
                ),
              ],
            ),
          ),
          // Benachrichtigungen Panel
          Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              key: const PageStorageKey('Benachrichtigungen'),
              initiallyExpanded: _openPanelIndex == 2,
              onExpansionChanged: (_) => _handlePanelOpen(2),
              leading: const Icon(Icons.notifications, color: Colors.grey),
              title: const Text('Benachrichtigungen', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                ..._meters.map((meter) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(meter.name),
                        subtitle: Text('Erinnerungen: ${_reminders[meter.id]?.length ?? 0}'),
                      ),
                      ...(_reminders[meter.id] ?? []).map((reminder) => ListTile(
                        title: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(reminder.baseDate))),
                        subtitle: Text('Wiederholung: ${reminder.repeat}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _scheduleNotificationWorkflow(forMeter: meter, edit: reminder),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteReminder(reminder),
                            ),
                          ],
                        ),
                      )),
                      ListTile(
                        leading: const Icon(Icons.add_alert_outlined),
                        title: const Text('Neue Erinnerung planen...'),
                        onTap: () => _scheduleNotificationWorkflow(forMeter: meter),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          // Datensicherung Panel
          Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              key: const PageStorageKey('Datensicherung'),
              initiallyExpanded: _openPanelIndex == 3,
              onExpansionChanged: (_) => _handlePanelOpen(3),
              leading: const Icon(Icons.backup_outlined, color: Colors.grey),
              title: const Text('Datensicherung', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: const Icon(Icons.upload_file_outlined),
                    title: const Text('Backup erstellen'),
                    subtitle: const Text('Sichert die Datenbank in einem Ordner deiner Wahl.'),
                    onTap: _createBackup,
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: const Icon(Icons.download_for_offline_outlined),
                    title: const Text('Backup wiederherstellen'),
                    subtitle: const Text('Überschreibt die aktuellen Daten mit einem Backup.'),
                    onTap: _restoreBackup,
                  ),
                ),
              ],
            ),
          ),
          // Impressum Panel
          Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              key: const PageStorageKey('Impressum'),
              initiallyExpanded: _openPanelIndex == 4,
              onExpansionChanged: (_) => _handlePanelOpen(4),
              leading: const Icon(Icons.info_outline, color: Colors.grey),
              title: const Text('Impressum', style: TextStyle(fontWeight: FontWeight.bold)),
              children: const [
                ListTile(
                  title: Text(
                    'Angaben gemäß § 5 TMG\n\n'
                    'Inhaber: Tobias Hi\n'
                    'Anschrift: Musterstraße 12, 12345 Musterstadt, Deutschland\n'
                    'Kontakt: kontakt@musterfirma.example • Tel.: +49 123 456789\n\n'
                    'USt-IdNr.: DE123456789\n'
                    'Inhaltlich verantwortlich: Tobias Hi\n\n'
                    'Haftungsausschluss: Alle Angaben ohne Gewähr. '
                    'Externe Links wurden bei Verlinkung geprüft; für Inhalte fremder Seiten übernehmen wir keine Haftung.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Notification und Backup Funktionen aus vorherigem Stand übernommen
  Future<void> _scheduleNotificationWorkflow({required Meter forMeter, Reminder? edit}) async {
    final dateCtrl = TextEditingController(
      text: edit != null ? DateFormat('dd.MM.yyyy').format(DateTime.parse(edit.baseDate)) : DateFormat('dd.MM.yyyy').format(DateTime.now()),
    );
    RepeatPlan repeat = edit?.repeat ?? RepeatPlan.none;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(edit == null ? 'Neue Erinnerung für ${forMeter.name}' : 'Erinnerung bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Datum (dd.MM.yyyy)'),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RepeatPlan>(
                value: repeat,
                items: const [
                  DropdownMenuItem(value: RepeatPlan.none, child: Text('Keine Wiederholung')),
                  DropdownMenuItem(value: RepeatPlan.weekly, child: Text('Wöchentlich')),
                  DropdownMenuItem(value: RepeatPlan.monthly, child: Text('Monatlich')),
                ],
                onChanged: (v) => repeat = v ?? RepeatPlan.none,
                decoration: const InputDecoration(labelText: 'Wiederholung'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Abbrechen'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            child: const Text('Speichern'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      final date = DateFormat('dd.MM.yyyy').parseLoose(dateCtrl.text);
      final notificationId = edit?.notificationId ?? Random().nextInt(1000000);
      final reminder = Reminder(
        id: edit?.id,
        meterId: forMeter.id!,
        baseDate: date.toIso8601String(),
        repeat: repeat,
        notificationId: notificationId,
      );

      if (edit != null) {
        await AppDb.instance.updateReminder(reminder);
        if (reminder.notificationId != null) {
          await NotificationService().cancel(reminder.notificationId!);
        }
      } else {
        await AppDb.instance.insertReminder(reminder);
      }

      await NotificationService().scheduleFlexible(
        id: notificationId,
        title: 'Zählerstand erfassen',
        body: 'Erfasse den Zählerstand für ${forMeter.name}',
        whenLocal: date,
        matchComponents: repeat == RepeatPlan.monthly ? DateTimeComponents.dayOfMonthAndTime : null,
      );
      await _loadData();
    }

    dateCtrl.dispose();
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    await AppDb.instance.deleteReminder(reminder.id!);
    if (reminder.notificationId != null) {
      await NotificationService().cancel(reminder.notificationId!);
    }
    await _loadData();
  }

  Future<void> _createBackup() async {
    final dbPath = await AppDb.instance.getDatabasePath();
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      final backupPath = p.join(result, 'verbrauchs_app_backup_${DateTime.now().toIso8601String()}.db');
      await File(dbPath).copy(backupPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup erstellt: $backupPath')),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (result != null && result.files.single.path != null) {
      final dbPath = await AppDb.instance.getDatabasePath();
      await File(result.files.single.path!).copy(dbPath);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup wiederhergestellt')),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}