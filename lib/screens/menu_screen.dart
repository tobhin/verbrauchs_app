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
import 'favorites_screen.dart';

class MenuScreen extends StatefulWidget {
  final void Function(ThemeMode) onChangeTheme;
  final ValueNotifier<ThemeMode> themeModeListenable;

  const MenuScreen({super.key, required this.onChangeTheme, required this.themeModeListenable});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<Meter> _meters = [];
  Map<int, Tariff> _tariffs = {};
  Map<int, List<Reminder>> _reminders = {};
  Map<int, int> _readingCounts = {};
  int _openPanelIndex = -1;
  List<MeterType> _meterTypes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _meterTypes = await AppDb.instance.fetchMeterTypes();
      if (_meterTypes.isEmpty) {
        await Logger.log('[MenuScreen] WARN: No meter types found in database.');
      }

      final ms = await AppDb.instance.fetchMeters();
      final Map<int, Tariff> ts = {};
      final Map<int, List<Reminder>> rems = {};
      final Map<int, int> counts = {};

      for (var meter in ms) {
        final tariff = await AppDb.instance.getTariff(meter.id!);
        if (tariff != null) {
          ts[meter.id!] = tariff;
        }
        final meterReminders = await AppDb.instance.fetchReminders(meter.id!);
        rems[meter.id!] = meterReminders;

        final readings = await AppDb.instance.fetchReadingsForMeter(meter.id!);
        counts[meter.id!] = readings.length;
      }

      if (mounted) {
        setState(() {
          _meters = ms;
          _tariffs = ts;
          _reminders = rems;
          _readingCounts = counts;
        });
      }
    } catch (e, st) {
      await Logger.log('[MenuScreen] ERROR: Failed to load data: $e\n$st');
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
          TextButton(
            child: const Text('Abbrechen'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            child: const Text('Hinzufügen'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AppDb.instance.insertMeter(
        Meter(
          name: nameCtrl.text.trim(),
          meterTypeId: typeId,
          number: nrCtrl.text.trim(),
          active: true, // BEHOBEN: 1 -> true
          isFavorite: true,
        ),
      );
      await _loadData();
    }

    nameCtrl.dispose();
    nrCtrl.dispose();
  }

  Future<void> _showAddReadingDialog(Meter meter) async {
    final valueCtrl = TextEditingController();
    final htCtrl = TextEditingController();
    final ntCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
      text: DateFormat('dd.MM.yyyy').format(DateTime.now()),
    );
    
    // Get the meter type to determine if it's Strom (HT/NT)
    final meterType = await AppDb.instance.fetchMeterTypeById(meter.meterTypeId);
    final isElectricityMeter = meterType?.name == 'Strom (HT/NT)';
    final unit = isElectricityMeter ? 'kWh' : 'm³';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Neuer Zählerstand für ${meter.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isElectricityMeter) ...[
                TextField(
                  controller: htCtrl,
                  decoration: const InputDecoration(labelText: 'HT (kWh)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ntCtrl,
                  decoration: const InputDecoration(labelText: 'NT (kWh)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ] else ...[
                TextField(
                  controller: valueCtrl,
                  decoration: InputDecoration(labelText: 'Zählerstand ($unit)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Datum (dd.MM.yyyy)'),
                keyboardType: TextInputType.datetime,
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
      
      if (isElectricityMeter) {
        final ht = double.tryParse(htCtrl.text.replaceAll(',', '.'));
        final nt = double.tryParse(ntCtrl.text.replaceAll(',', '.'));
        if (ht != null && nt != null) {
          await AppDb.instance.insertReading(Reading(
            meterId: meter.id!,
            date: date,
            value: null, // No single value for electricity meters
            ht: ht,
            nt: nt,
          ));
          await _loadData();
        }
      } else {
        final value = double.tryParse(valueCtrl.text.replaceAll(',', '.'));
        if (value != null) {
          await AppDb.instance.insertReading(Reading(
            meterId: meter.id!,
            date: date,
            value: value,
            ht: null,
            nt: null,
          ));
          await _loadData();
        }
      }
    }

    valueCtrl.dispose();
    htCtrl.dispose();
    ntCtrl.dispose();
    dateCtrl.dispose();
  }

  Future<void> _saveTariff(Meter meter) async {
    final costCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tarif für ${meter.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: costCtrl,
                decoration: const InputDecoration(labelText: 'Kosten pro Einheit (€)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feeCtrl,
                decoration: const InputDecoration(labelText: 'Grundgebühr (€)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      final cost = double.tryParse(costCtrl.text.replaceAll(',', '.'));
      final fee = double.tryParse(feeCtrl.text.replaceAll(',', '.')) ?? 0.0;
      if (cost != null) {
        await AppDb.instance.insertTariff(Tariff(
          meterId: meter.id!,
          costPerUnit: cost,
          baseFee: fee,
        ));
        await _loadData();
      }
    }

    costCtrl.dispose();
    feeCtrl.dispose();
  }

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
        matchComponents: repeat == RepeatPlan.monthly ? DateTimeComponents.dayOfMonthAndTime : null, // BEHOBEN: flutter_local_notifications. entfernt
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: ExpansionPanelList(
          expansionCallback: (index, isExpanded) {
            setState(() {
              // Accordion behavior: only one panel open at a time
              // If panel is currently expanded, close it; if closed, open it
              if (isExpanded) {
                _openPanelIndex = -1; // Close the currently open panel
              } else {
                _openPanelIndex = index; // Open the clicked panel (closes any other open panel)
              }
            });
          },
          children: [
            _buildPanel(
              index: 0,
              title: 'Zähler hinzufügen',
              icon: Icons.add_circle_outline,
              body: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Neuer Zähler...'),
                    onTap: _addMeter,
                  ),
                ],
              ),
            ),
            _buildPanel(
              index: 1,
              title: 'Zähler verwalten',
              icon: Icons.tune,
              body: Column(
                children: _meters
                    .map((meter) => ListTile(
                          leading: const Icon(Icons.speed),
                          title: Text(meter.name),
                          subtitle: Text('Werte: ${_readingCounts[meter.id] ?? 0}'),
                          onTap: () => _showAddReadingDialog(meter),
                        ))
                    .toList(),
              ),
            ),
            _buildPanel(
              index: 2,
              title: 'Tarife',
              icon: Icons.euro,
              body: Column(
                children: _meters
                    .map((meter) => ListTile(
                          leading: const Icon(Icons.euro),
                          title: Text('Tarif für ${meter.name}'),
                          subtitle: Text(_tariffs[meter.id]?.costPerUnit.toString() ?? 'Kein Tarif'),
                          onTap: () => _saveTariff(meter),
                        ))
                    .toList(),
              ),
            ),
            _buildPanel(
              index: 3,
              title: 'Erinnerungen',
              icon: Icons.notifications_outlined,
              body: Column(
                children: _meters.expand((meter) => [
                      ListTile(
                        title: Text(meter.name),
                        subtitle: Text('Erinnerungen: ${_reminders[meter.id]?.length ?? 0}'),
                      ),
                      ...(_reminders[meter.id] ?? [])
                          .map((reminder) => ListTile(
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
                    ]).toList(),
              ),
            ),
            _buildPanel(
              index: 4,
              title: 'Datensicherung',
              icon: Icons.backup_outlined,
              body: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_file_outlined),
                    title: const Text('Backup erstellen'),
                    subtitle: const Text('Sichert die Datenbank in einem Ordner deiner Wahl.'),
                    onTap: _createBackup,
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_for_offline_outlined),
                    title: const Text('Backup wiederherstellen'),
                    subtitle: const Text('Überschreibt die aktuellen Daten mit einem Backup.'),
                    onTap: _restoreBackup,
                  ),
                ],
              ),
            ),
            _buildPanel(
              index: 5,
              title: 'Impressum',
              icon: Icons.info_outline,
              body: const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
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
            ),
          ],
        ),
      ),
    );
  }

  ExpansionPanel _buildPanel({required int index, required String title, required IconData icon, required Widget body}) {
    return ExpansionPanel(
      canTapOnHeader: true,
      isExpanded: _openPanelIndex == index,
      headerBuilder: (BuildContext context, bool isExpanded) {
        return ListTile(
          leading: Icon(icon),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        );
      },
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: body,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}