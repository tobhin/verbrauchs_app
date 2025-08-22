import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/meter.dart';
import '../models/meter_type.dart';
import '../models/reading.dart';
import '../models/reminder.dart';
import '../models/tariff.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
  }

  Future<void> _addMeter() async {
    final nameCtrl = TextEditingController();
    final nrCtrl = TextEditingController();
    MeterType type = MeterType.wasser;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zähler hinzufügen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 16),
              DropdownButtonFormField<MeterType>(
                value: type,
                items: const [
                  DropdownMenuItem(value: MeterType.stromDual, child: Text('Strom (HT/NT)')),
                  DropdownMenuItem(value: MeterType.wasser, child: Text('Wasser')),
                  DropdownMenuItem(value: MeterType.schmutzwasser, child: Text('Schmutzwasser')),
                  DropdownMenuItem(value: MeterType.gas, child: Text('Gas')),
                ],
                onChanged: (v) => type = v ?? MeterType.wasser,
                decoration: const InputDecoration(labelText: 'Typ', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(controller: nrCtrl, decoration: const InputDecoration(labelText: 'Zählernummer')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hinzufügen')),
        ],
      ),
    );
    if (ok == true) {
      await AppDb.instance.insertMeter(Meter(name: nameCtrl.text.trim(), type: type, number: nrCtrl.text.trim()));
      await _loadData();
    }
  }

  Future<T?> _showStableInfoDialog<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 0;
        final double bottomPadding = isKeyboardVisible ? keyboardHeight + 16 : 330;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(
            bottom: bottomPadding,
            left: 16,
            right: 16,
          ),
          child: Material(
            elevation: 24.0,
            borderRadius: BorderRadius.circular(28.0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  content,
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showStableInputDialog({
    required BuildContext context,
    required String title,
    required List<Widget> fields,
    required List<Widget> actions,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 0;
        final double bottomPadding = isKeyboardVisible ? keyboardHeight + 16 : 330;
        
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(
            bottom: bottomPadding,
            left: 16,
            right: 16,
          ),
          child: Material(
            elevation: 24.0,
            borderRadius: BorderRadius.circular(28.0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ...fields,
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deactivateMeter(int meterId) async {
    final meter = _meters.firstWhere((m) => m.id == meterId);
    final ok = await _showStableInfoDialog<bool>(
      context: context,
      title: 'Zähler deaktivieren',
      content: Text('Möchtest du "${meter.name}" wirklich deaktivieren? Die bisherigen Daten bleiben erhalten.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
        const SizedBox(width: 8),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deaktivieren')),
      ],
    );

    if (ok == true) {
      await AppDb.instance.deactivateMeter(meterId);
      await _loadData();
    }
  }

  Future<void> _setTariff(Meter meter) async {
    final tariff = await AppDb.instance.getTariff(meter.id!);
    final costCtrl = TextEditingController(text: tariff?.costPerUnit.toString() ?? '');
    final baseFeeCtrl = TextEditingController(text: tariff?.baseFee.toString() ?? '');
    final unit = meter.type == MeterType.stromDual ? 'kWh' : 'm³';

    await _showStableInputDialog(
      context: context,
      title: 'Tarif für ${meter.name}',
      fields: [
        TextField(
          controller: costCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Kosten pro $unit (€)'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: baseFeeCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Grundgebühr pro Monat (€)'),
        ),
      ],
      actions: [
        if (tariff != null)
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AppDb.instance.deleteTariffForMeter(meter.id!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarif gelöscht')));
              }
              await _loadData();
            },
            child: const Text('Löschen'),
          ),
        const Spacer(),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () async {
            if (costCtrl.text.isEmpty) return;
            final cost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final baseFee = double.tryParse(baseFeeCtrl.text.replaceAll(',', '.')) ?? 0.0;
            await AppDb.instance.insertTariff(Tariff(meterId: meter.id!, costPerUnit: cost, baseFee: baseFee));
            Navigator.pop(context);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarif gespeichert')));
            }
            await _loadData();
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }

  Future<void> _manageStartwert(Meter meter) async {
    final readings = await AppDb.instance.fetchReadingsForMeter(meter.id!);
    if (readings.isNotEmpty) {
      final choice = await _showStableInfoDialog<String>(
          context: context,
          title: 'Startwert verwalten',
          content: const Text('Ein Startwert existiert bereits. Möchtest du ihn ändern (alle Daten löschen) oder komplett entfernen?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Abbrechen')),
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              child: Text('Löschen', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => Navigator.pop(context, 'change'), child: const Text('Ändern')),
          ]);

      if (choice == 'delete') {
        await AppDb.instance.deleteReadingsForMeter(meter.id!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Startwert und alle Einträge gelöscht.')));
        await _loadData();
        return;
      } else if (choice != 'change') {
        return;
      }
    }
    _showSetStartwertDialog(meter);
  }

  Future<void> _showSetStartwertDialog(Meter meter) async {
    final valueCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateFormat('dd.MM.yyyy').format(DateTime.now()));
    DateTime selectedDate = DateTime.now();

    await _showStableInputDialog(
      context: context,
      title: 'Startwert festlegen',
      fields: [
        TextField(controller: valueCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Anfangszählerstand')),
        const SizedBox(height: 16),
        TextField(
          controller: dateCtrl,
          readOnly: true,
          decoration: const InputDecoration(labelText: 'Datum des Startwerts'),
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (pickedDate != null) {
              selectedDate = pickedDate;
              dateCtrl.text = DateFormat('dd.MM.yyyy').format(selectedDate);
            }
          },
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () async {
            final value = double.tryParse(valueCtrl.text.replaceAll(',', '.'));
            if (value == null) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ungültiger Wert.')));
              return;
            }
            Navigator.pop(context);
            await AppDb.instance.deleteReadingsForMeter(meter.id!);
            await AppDb.instance.insertReading(Reading(
              meterId: meter.id!,
              date: selectedDate,
              value: meter.type != MeterType.stromDual ? value : null,
              ht: meter.type == MeterType.stromDual ? value : null,
              nt: meter.type == MeterType.stromDual ? 0.0 : null,
            ));
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Startwert wurde gespeichert.')));
            await _loadData();
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }

  String _describeReminder(Reminder r) {
    final dt = DateTime.parse(r.baseDate);
    final time = TimeOfDay.fromDateTime(dt).format(context);
    final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    switch (r.repeat) {
      case RepeatPlan.none:
        return 'Einmalig am ${DateFormat('dd.MM.yy').format(dt)} um $time';
      case RepeatPlan.weekly:
        return 'Jeden ${weekdays[dt.weekday - 1]} um $time';
      case RepeatPlan.monthly:
        return 'Monatlich am ${dt.day}. um $time';
      case RepeatPlan.yearly:
        return 'Jährlich am ${dt.day}.${dt.month}. um $time';
    }
  }

  Future<void> _deleteReminder(Reminder r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erinnerung löschen?'),
        content: const Text('Möchtest du diese Erinnerung wirklich endgültig löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );

    if (confirmed == true) {
      final reminderFromDb = await AppDb.instance.fetchReminderById(r.id!);
      if (reminderFromDb?.notificationId != null) {
        await NotificationService().cancel(reminderFromDb!.notificationId!);
      }
      await AppDb.instance.deleteReminder(r.id!);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erinnerung gelöscht')));
      }
    }
  }

  Future<void> _scheduleNotificationWorkflow({Meter? forMeter, Reminder? edit}) async {
    if (forMeter == null) return;

    final now = DateTime.now();
    DateTime initialDate = edit != null ? DateTime.parse(edit.baseDate) : now;
    if (initialDate.isBefore(now)) initialDate = now;

    final date = await showDatePicker(context: context, initialDate: initialDate, firstDate: now, lastDate: now.add(const Duration(days: 365 * 5)));
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initialDate));
    if (time == null) return;

    final base = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    final rep = await showDialog<RepeatPlan>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Wiederholungstyp'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: const Text('Einmalig'), onTap: () => Navigator.pop(ctx, RepeatPlan.none)),
                ListTile(title: const Text('Wöchentlich'), onTap: () => Navigator.pop(ctx, RepeatPlan.weekly)),
                ListTile(title: const Text('Monatlich'), onTap: () => Navigator.pop(ctx, RepeatPlan.monthly)),
                ListTile(title: const Text('Jährlich'), onTap: () => Navigator.pop(ctx, RepeatPlan.yearly)),
              ],
            ),
          ),
        ) ??
        (edit?.repeat ?? RepeatPlan.none);

    final notificationId = Random().nextInt(90000) + 10000;

    if (edit != null) {
      final updatedReminder = Reminder(id: edit.id!, meterId: forMeter.id!, baseDate: base.toIso8601String(), repeat: rep, notificationId: notificationId);
      await AppDb.instance.updateReminder(updatedReminder);
      if (edit.notificationId != null) {
        await NotificationService().cancel(edit.notificationId!);
      }
    } else {
      final newReminder = Reminder(meterId: forMeter.id!, baseDate: base.toIso8601String(), repeat: rep, notificationId: notificationId);
      await AppDb.instance.insertReminder(newReminder);
    }

    final nextFire = NotificationService().computeNextFire(rep, base);

    DateTimeComponents? match;
    if (rep != RepeatPlan.none) {
      switch (rep) {
        case RepeatPlan.weekly:
          match = DateTimeComponents.dayOfWeekAndTime;
          break;
        case RepeatPlan.monthly:
          match = DateTimeComponents.dayOfMonthAndTime;
          break;
        case RepeatPlan.yearly:
          match = DateTimeComponents.dateAndTime;
          break;
        default:
          break;
      }
    }

    final scheduleOk = await NotificationService().scheduleFlexible(
      id: notificationId,
      title: '${forMeter.name} – Erinnerung',
      body: 'Bitte Zählerstand eintragen (Nr: ${forMeter.number}).',
      whenLocal: nextFire,
      matchComponents: match,
    );

    if (mounted) {
      if (scheduleOk) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Benachrichtigung geplant für ${DateFormat('dd.MM.yy HH:mm').format(nextFire)}')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Planung fehlgeschlagen')));
      }
    }
    await _loadData();
  }

  Future<void> _createBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dbPath = await AppDb.instance.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        messenger.showSnackBar(const SnackBar(content: Text('Fehler: Datenbankdatei nicht gefunden.')));
        return;
      }

      final targetDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Bitte einen Ordner für das Backup auswählen',
      );
      if (targetDir == null) return;

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupPath = p.join(targetDir, 'verbrauchswerte_backup_$timestamp.db');

      await dbFile.copy(backupPath);

      messenger.showSnackBar(
        SnackBar(content: Text('Backup erfolgreich in $targetDir erstellt.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup fehlgeschlagen: $e')));
    }
  }

  Future<void> _restoreBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup wiederherstellen?'),
        content: const Text('ACHTUNG: Alle aktuellen Daten werden unwiderruflich mit den Daten aus der Backup-Datei überschrieben.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Wiederherstellen')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['db']);
      if (result == null || result.files.single.path == null) return;

      final backupFile = File(result.files.single.path!);

      await AppDb.instance.close();

      final dbPath = await AppDb.instance.getDatabasePath();
      await backupFile.copy(dbPath);

      messenger.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Backup erfolgreich wiederhergestellt. Bitte starte die App jetzt neu.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Wiederherstellung fehlgeschlagen: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: ExpansionPanelList(
        elevation: 1,
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _openPanelIndex = _openPanelIndex == index ? -1 : index;
          });
        },
        children: [
          _buildPanel(
            index: 0,
            title: 'Design',
            icon: Icons.tune,
            body: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Hell'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dunkel'), icon: Icon(Icons.dark_mode)),
              ],
              selected: {widget.themeModeListenable.value == ThemeMode.system ? ThemeMode.light : widget.themeModeListenable.value},
              onSelectionChanged: (s) => widget.onChangeTheme(s.first),
            ),
          ),
          _buildPanel(
            index: 1,
            title: 'Zähler & Tarife',
            icon: Icons.speed_outlined,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_meters.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Noch keine Zähler angelegt.'))),
                ..._meters.map((m) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: Theme.of(context).textTheme.titleMedium),
                            Text('Nr: ${m.number}', style: Theme.of(context).textTheme.bodySmall),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Spacer(),
                                IconButton(icon: Icon(Icons.flag_outlined, color: (_readingCounts[m.id] ?? 0) > 0 ? Colors.amber.shade700 : null), tooltip: 'Startwert verwalten', onPressed: () => _manageStartwert(m)),
                                IconButton(icon: Icon(Icons.euro, color: _tariffs.containsKey(m.id) ? Colors.green : null), tooltip: 'Tarif bearbeiten/löschen', onPressed: () => _setTariff(m)),
                                IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Zähler deaktivieren', onPressed: () => _deactivateMeter(m.id!)),
                              ],
                            )
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _addMeter, icon: const Icon(Icons.add), label: const Text('Zähler hinzufügen')),
              ],
            ),
          ),
          _buildPanel(
            index: 2,
            title: 'Benachrichtigungen',
            icon: Icons.notifications_outlined,
            body: _meters.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('Bitte zuerst einen Zähler anlegen.')))
                : Column(
                    children: _meters.map((meter) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          shape: const Border(),
                          title: Text(meter.name),
                          subtitle: Text('${_reminders[meter.id]?.length ?? 0} Erinnerungen'),
                          children: [
                            ...(_reminders[meter.id] ?? []).map((reminder) => ListTile(
                                  title: Text(_describeReminder(reminder)),
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _scheduleNotificationWorkflow(forMeter: meter, edit: reminder)),
                                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteReminder(reminder)),
                                  ]),
                                )),
                            ListTile(
                              leading: const Icon(Icons.add_alert_outlined),
                              title: const Text('Neue Erinnerung planen...'),
                              onTap: () => _scheduleNotificationWorkflow(forMeter: meter),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          _buildPanel(
            index: 3,
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
            index: 4,
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
                'Externe Links wurden bei Verlinkung geprüft; für Inhalte fremder Seiten übernehmen wir keine Haftung.'
              ),
            ),
          )
        ],
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
}