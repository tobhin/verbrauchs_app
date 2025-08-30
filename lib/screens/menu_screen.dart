// lib/screens/menu_screen.dart

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
import '../services/logger_service.dart';
import '../utils/icon_mapper.dart';

class MenuScreen extends StatefulWidget {
  final void Function(ThemeMode) onChangeTheme;
  final ValueNotifier<ThemeMode> themeModeListenable;

  const MenuScreen({super.key, required this.onChangeTheme, required this.themeModeListenable});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<Meter> _meters = [];
  Map<int, Tariff?> _tariffs = {};
  Map<int, Reading?> _startwerte = {};
  List<MeterType> _meterTypes = [];
  Map<int, List<Reminder>> _reminders = {};
  
  final Map<int, ExpansionTileController> _tileControllers = {};
  int _openPanelIndex = -1;

  @override
  void initState() {
    super.initState();
    _tileControllers[100] = ExpansionTileController(); // Design
    _tileControllers[0] = ExpansionTileController();   // Favoriten
    _tileControllers[1] = ExpansionTileController();   // Zähler & Tarife
    _tileControllers[2] = ExpansionTileController();   // Benachrichtigungen
    _tileControllers[3] = ExpansionTileController();   // Datensicherung
    _tileControllers[4] = ExpansionTileController();   // Impressum
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _meterTypes = await AppDb.instance.fetchMeterTypes();
      final ms = await AppDb.instance.fetchMeters();
      final Map<int, Tariff?> ts = {};
      final Map<int, Reading?> starts = {};
      final Map<int, List<Reminder>> rems = {};

      for (var meter in ms) {
        ts[meter.id!] = await AppDb.instance.getTariff(meter.id!);
        starts[meter.id!] = await AppDb.instance.fetchStartwertForMeter(meter.id!);
        rems[meter.id!] = await AppDb.instance.fetchReminders(meter.id!);
      }

      if (mounted) {
        setState(() {
          _meters = ms;
          _tariffs = ts;
          _startwerte = starts;
          _reminders = rems;
        });
      }
    } catch (e, st) {
      await Logger.log('[MenuScreen] ERROR: Failed to load data: $e\n$st');
    }
  }

  void _handleExpansion(int index, bool isExpanded) {
    if (isExpanded) {
      if (_openPanelIndex != -1 && _openPanelIndex != index) {
        _tileControllers[_openPanelIndex]?.collapse();
      }
      _openPanelIndex = index;
    } else {
      if (_openPanelIndex == index) {
        _openPanelIndex = -1;
      }
    }
    setState(() {});
  }

  Future<void> _toggleFavorite(Meter meter, bool? isFav) async {
    await AppDb.instance.updateMeter(meter.copyWith(isFavorite: isFav ?? false));
    await _loadData();
  }

  double? _parseNum(String? s) {
    if (s == null || s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.').trim());
  }

  Future<void> _showStartwertDialog(Meter meter) async {
    final meterType = _meterTypes.firstWhere((t) => t.id == meter.meterTypeId);
    final isStromZaehler = meterType.name == 'Strom (HT/NT)';
    final alreadyStartwert = _startwerte[meter.id];

    if (alreadyStartwert != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Startwert verwalten'),
          content: const Text('Ein Startwert existiert bereits. Möchtest du ihn ändern oder komplett entfernen?'),
          actions: [
            TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(ctx, "abbrechen")),
            TextButton(child: const Text('Löschen'), onPressed: () => Navigator.pop(ctx, "löschen")),
            FilledButton(child: const Text('Ändern'), onPressed: () => Navigator.pop(ctx, "ändern")),
          ],
        ),
      );

      if (choice == 'abbrechen' || choice == null) return;
      if (choice == 'löschen') {
        await AppDb.instance.deleteStartwert(meter.id!);
        await _loadData();
        return;
      }
    }

    final dateCtrl = TextEditingController(text: DateFormat('dd.MM.yyyy').format(DateTime.now()));
    final htCtrl = TextEditingController();
    final ntCtrl = TextEditingController();
    final valueCtrl = TextEditingController();

    final regularReadings = await AppDb.instance.fetchReadingsForMeter(meter.id!);
    regularReadings.sort((a, b) => a.date.compareTo(b.date));
    final firstRegularReading = regularReadings.isNotEmpty ? regularReadings.first : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(alreadyStartwert != null ? 'Startwert ändern' : 'Startwert festlegen'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (isStromZaehler) ...[
            TextFormField(controller: htCtrl, decoration: const InputDecoration(labelText: 'HT-Startwert'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            TextFormField(controller: ntCtrl, decoration: const InputDecoration(labelText: 'NT-Startwert (optional)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ] else ...[
            TextFormField(controller: valueCtrl, decoration: const InputDecoration(labelText: 'Anfangszählerstand'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: dateCtrl,
            decoration: const InputDecoration(labelText: 'Datum des Startwerts'),
            readOnly: true,
            onTap: () async {
              final pickedDate = await showDatePicker(context: context, initialDate: DateFormat('dd.MM.yyyy').parseLoose(dateCtrl.text), firstDate: DateTime(2000), lastDate: DateTime.now());
              if (pickedDate != null) dateCtrl.text = DateFormat('dd.MM.yyyy').format(pickedDate);
            },
          ),
        ]),
        actions: [
          TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(child: const Text('Speichern'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (ok == true) {
      final newHt = isStromZaehler ? _parseNum(htCtrl.text) : null;
      final newNt = isStromZaehler ? _parseNum(ntCtrl.text) : null;
      final newValue = !isStromZaehler ? _parseNum(valueCtrl.text) : null;

      if (firstRegularReading != null) {
        bool validationFailed = false;
        if (isStromZaehler) {
          if (newHt != null && firstRegularReading.ht != null && newHt >= firstRegularReading.ht!) validationFailed = true;
          if (newNt != null && firstRegularReading.nt != null && newNt >= firstRegularReading.nt!) validationFailed = true;
        } else {
          if (newValue != null && firstRegularReading.value != null && newValue >= firstRegularReading.value!) validationFailed = true;
        }
        if (validationFailed) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fehler: Startwert muss kleiner sein als der erste erfasste Wert.')));
          return;
        }
      }
      
      if (alreadyStartwert != null) await AppDb.instance.deleteStartwert(meter.id!);
      
      final newReading = Reading(meterId: meter.id!, date: DateFormat('dd.MM.yyyy').parseLoose(dateCtrl.text), value: newValue, ht: newHt, nt: newNt, tariffId: AppDb.startwertTariffId);
      await AppDb.instance.insertReading(newReading);
      await _loadData();
    }
    dateCtrl.dispose();
    htCtrl.dispose();
    ntCtrl.dispose();
    valueCtrl.dispose();
  }

  Future<void> _showTarifDialog(Meter meter) async {
    final allTariffs = await AppDb.instance.fetchAllTariffsForMeter(meter.id!);

    if (allTariffs.isEmpty) {
      final newTariffCreated = await _showAddTariffDialog(meter);
      if (newTariffCreated) {
        await _loadData();
      }
    } else {
      await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setStateInDialog) {
              return AlertDialog(
                title: const Text('Tarifhistorie'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: allTariffs.length,
                          itemBuilder: (context, index) {
                            final tariff = allTariffs[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text('ab ${DateFormat('dd.MM.yyyy').format(tariff.gueltigAb)}'),
                                subtitle: Text('${tariff.costPerUnit.toStringAsFixed(2)} €/Einheit, ${tariff.baseFee.toStringAsFixed(2)} € Grundgebühr\nGrund: ${tariff.grund ?? 'N/A'}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await AppDb.instance.deleteTariff(tariff.id!);
                                    final updatedTariffs = await AppDb.instance.fetchAllTariffsForMeter(meter.id!);
                                    setStateInDialog(() {
                                      allTariffs.clear();
                                      allTariffs.addAll(updatedTariffs);
                                    });
                                    await _loadData();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(child: const Text('Schließen'), onPressed: () => Navigator.pop(ctx)),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Neuer Tarif'),
                    onPressed: () async {
                      final newTariffCreated = await _showAddTariffDialog(meter);
                      if (newTariffCreated) {
                        final updatedTariffs = await AppDb.instance.fetchAllTariffsForMeter(meter.id!);
                         setStateInDialog(() {
                           allTariffs.clear();
                           allTariffs.addAll(updatedTariffs);
                         });
                         await _loadData();
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  Future<bool> _showAddTariffDialog(Meter meter) async {
    final costCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    final grundCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateFormat('dd.MM.yyyy').format(DateTime.now()));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neuen Tarif anlegen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ein neuer Tarif wird für alle Ablesungen ab dem gewählten Datum angewendet.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextFormField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Kosten pro Einheit (€)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),
              TextFormField(controller: feeCtrl, decoration: const InputDecoration(labelText: 'Grundgebühr (€)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),
              TextFormField(controller: grundCtrl, decoration: const InputDecoration(labelText: 'Grund der Änderung (z.B. Preisanpassung)')),
              const SizedBox(height: 12),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Gültig ab Datum'),
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (pickedDate != null) dateCtrl.text = DateFormat('dd.MM.yyyy').format(pickedDate);
                },
              ),
            ],
          ),
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
        costPerUnit: _parseNum(costCtrl.text) ?? 0.0,
        baseFee: _parseNum(feeCtrl.text) ?? 0.0,
        gueltigAb: DateFormat('dd.MM.yyyy').parseLoose(dateCtrl.text),
        grund: grundCtrl.text,
      ));
      return true;
    }
    return false;
  }
  
  Future<void> _showEditMeterDialog(Meter meter) async {
    final nameCtrl = TextEditingController(text: meter.name);
    final nrCtrl = TextEditingController(text: meter.number);
    int selectedTypeId = meter.meterTypeId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zähler bearbeiten'),
        content: StatefulBuilder(
          builder: (context, setStateInDialog) {
            return SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 16),
                TextField(controller: nrCtrl, decoration: const InputDecoration(labelText: 'Zählernummer')),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedTypeId,
                  items: _meterTypes.map((type) {
                    return DropdownMenuItem<int>(
                      value: type.id,
                      child: Row(children: [Icon(IconMapper.getIcon(type.iconName)), const SizedBox(width: 8), Text(type.name)]),
                    );
                  }).toList(),
                  onChanged: (v) { if (v != null) setStateInDialog(() => selectedTypeId = v); },
                  decoration: const InputDecoration(labelText: 'Typ/Icon', border: OutlineInputBorder()),
                ),
              ]),
            );
          },
        ),
        actions: [
          TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(child: const Text('Speichern'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (ok == true) {
      final updatedMeter = meter.copyWith(name: nameCtrl.text.trim(), number: nrCtrl.text.trim(), meterTypeId: selectedTypeId);
      await AppDb.instance.updateMeter(updatedMeter);
      await _loadData();
    }
    nameCtrl.dispose();
    nrCtrl.dispose();
  }

  Future<void> _showDeleteDialog(Meter meter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zähler löschen'),
        content: Text('Möchtest du "${meter.name}" wirklich löschen?\nAlle Ablesungen und Tarife für diesen Zähler werden ebenfalls gelöscht.'),
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
    int? typeId = _meterTypes.isNotEmpty ? _meterTypes.first.id : null;

    if (_meterTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine Zählertypen verfügbar.')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zähler hinzufügen'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: typeId,
            items: _meterTypes.map((type) => DropdownMenuItem<int>(
                  value: type.id,
                  child: Row(children: [Icon(IconMapper.getIcon(type.iconName)), const SizedBox(width: 8), Text(type.name)]),
                )).toList(),
            onChanged: (v) { if (v != null) typeId = v; },
            decoration: const InputDecoration(labelText: 'Typ/Icon', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(controller: nrCtrl, decoration: const InputDecoration(labelText: 'Zählernummer')),
        ])),
        actions: [
          TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(child: const Text('Hinzufügen'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true && typeId != null) {
      await AppDb.instance.insertMeter(Meter(name: nameCtrl.text.trim(), meterTypeId: typeId!, number: nrCtrl.text.trim(), active: true, isFavorite: false));
      await _loadData();
    }
    nameCtrl.dispose();
    nrCtrl.dispose();
  }
  
  // MODIFIZIERT: Die gesamte Logik zum Planen von Benachrichtigungen wurde hier implementiert.
  Future<void> _scheduleNotificationWorkflow({required Meter forMeter, Reminder? edit}) async {
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    RepeatPlan selectedRepeat = edit?.repeat ?? RepeatPlan.none;

    // Wenn ein Reminder bearbeitet wird, fülle die Felder mit den existierenden Daten.
    if (edit != null) {
      final existingDate = DateTime.parse(edit.baseDate);
      selectedDate = existingDate;
      selectedTime = TimeOfDay.fromDateTime(existingDate);
      dateCtrl.text = DateFormat('dd.MM.yyyy').format(selectedDate!);
      timeCtrl.text = selectedTime!.format(context);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateInDialog) {
          return AlertDialog(
            title: Text(edit == null ? 'Neue Erinnerung' : 'Erinnerung bearbeiten'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(labelText: 'Datum', border: OutlineInputBorder()),
                    readOnly: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setStateInDialog(() {
                          selectedDate = picked;
                          dateCtrl.text = DateFormat('dd.MM.yyyy').format(picked);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(labelText: 'Uhrzeit', border: OutlineInputBorder()),
                    readOnly: true,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setStateInDialog(() {
                          selectedTime = picked;
                          timeCtrl.text = picked.format(context);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<RepeatPlan>(
                    value: selectedRepeat,
                    decoration: const InputDecoration(labelText: 'Wiederholung', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: RepeatPlan.none, child: Text('Keine')),
                      DropdownMenuItem(value: RepeatPlan.weekly, child: Text('Wöchentlich')),
                      DropdownMenuItem(value: RepeatPlan.monthly, child: Text('Monatlich')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setStateInDialog(() => selectedRepeat = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(ctx, false)),
              FilledButton(child: const Text('Speichern'), onPressed: () {
                if (selectedDate == null || selectedTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bitte wähle ein Datum und eine Uhrzeit aus.'))
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              }),
            ],
          );
        },
      ),
    );

    if (ok == true && selectedDate != null && selectedTime != null) {
      final finalDateTime = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
      final notifId = edit?.notificationId ?? DateTime.now().millisecondsSinceEpoch % 100000;
      
      // Wenn es ein Edit ist, lösche zuerst die alte Benachrichtigung
      if (edit != null && edit.notificationId != null) {
        await NotificationService().cancel(edit.notificationId!);
      }
      
      DateTimeComponents? matchComponents;
      if (selectedRepeat == RepeatPlan.weekly) {
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
      } else if (selectedRepeat == RepeatPlan.monthly) {
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
      }

      await NotificationService().scheduleFlexible(
        id: notifId,
        title: 'Erinnerung für ${forMeter.name}',
        body: 'Zeit zum Ablesen des Zählerstandes!',
        whenLocal: finalDateTime,
        matchComponents: matchComponents,
      );
      
      if (edit != null) {
        await AppDb.instance.updateReminder(edit.copyWith(
          baseDate: finalDateTime.toIso8601String(),
          repeat: selectedRepeat,
        ));
      } else {
        final newReminder = Reminder(
          meterId: forMeter.id!,
          baseDate: finalDateTime.toIso8601String(),
          repeat: selectedRepeat,
          notificationId: notifId,
        );
        await AppDb.instance.insertReminder(newReminder);
      }
      
      await _loadData();
    }

    dateCtrl.dispose();
    timeCtrl.dispose();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup erstellt: $backupPath')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup wiederhergestellt')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tileControllers.values.forEach((controller) {
      controller.dispose();
    });
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    Color _flagColor(Meter meter) => _startwerte[meter.id ?? -1] != null ? Colors.green : Colors.grey;
    Color _euroColor(Meter meter) => _tariffs[meter.id ?? -1] != null ? Colors.amber[700]! : Colors.grey;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // MODIFIZIERT: Das Scaffold-Widget und die AppBar wurden entfernt.
    // Das Widget gibt jetzt nur noch den Inhalt für den Body zurück.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      children: [
        // Design Panel (ganz oben!)
        Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>('panel_design'),
              controller: _tileControllers[100],
              onExpansionChanged: (isExpanded) => _handleExpansion(100, isExpanded),
              title: const Text('Design', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.tune, color: Colors.grey),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ToggleButtons(
                        isSelected: [
                          widget.themeModeListenable.value == ThemeMode.light,
                          widget.themeModeListenable.value == ThemeMode.dark,
                        ],
                        borderRadius: BorderRadius.circular(30),
                        fillColor: isDark ? Colors.grey[700] : Colors.blue[100],
                        selectedColor: isDark ? Colors.white : Colors.black87,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                        constraints: const BoxConstraints(minWidth: 80, minHeight: 36),
                        onPressed: (index) {
                          if (index == 0) widget.onChangeTheme(ThemeMode.light);
                          if (index == 1) widget.onChangeTheme(ThemeMode.dark);
                        },
                        children: const [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 20),
                              SizedBox(width: 6),
                              Text('Hell'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.nightlight_round, size: 20),
                              SizedBox(width: 6),
                              Text('Dunkel'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Favoriten Panel ohne Linien oben/unten!
        Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>('panel_0'),
              controller: _tileControllers[0],
              onExpansionChanged: (isExpanded) => _handleExpansion(0, isExpanded),
              title: const Text('Favoriten', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.star, color: Colors.grey),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: _meters.map((meter) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Material(
                    color: Theme.of(context).cardColor,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(12),
                    child: SwitchListTile(
                      value: meter.isFavorite,
                      title: Text(meter.name),
                      subtitle: Text('Nr: ${meter.number ?? 'N/A'}'),
                      onChanged: (val) => _toggleFavorite(meter, val),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Zähler & Tarife Panel mit credit_card Icon
        Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>('panel_1'),
              controller: _tileControllers[1],
              onExpansionChanged: (isExpanded) => _handleExpansion(1, isExpanded),
              title: const Text('Zähler & Tarife', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.credit_card, color: Colors.grey),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                ..._meters.map((meter) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Material(
                        color: Theme.of(context).cardColor,
                        elevation: 1,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(meter.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text('Nr: ${meter.number ?? 'N/A'}', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Zähler bearbeiten', padding: const EdgeInsets.all(8), visualDensity: VisualDensity.compact, onPressed: () => _showEditMeterDialog(meter)),
                                IconButton(icon: Icon(Icons.flag, color: _flagColor(meter)), tooltip: 'Startwert bearbeiten', padding: const EdgeInsets.all(8), visualDensity: VisualDensity.compact, onPressed: () => _showStartwertDialog(meter)),
                                IconButton(icon: Icon(Icons.euro, color: _euroColor(meter)), tooltip: 'Tarif bearbeiten', padding: const EdgeInsets.all(8), visualDensity: VisualDensity.compact, onPressed: () => _showTarifDialog(meter)),
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), tooltip: 'Zähler löschen', padding: const EdgeInsets.all(8), visualDensity: VisualDensity.compact, onPressed: () => _showDeleteDialog(meter)),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: isDark ? Colors.grey[700] : null,
                      foregroundColor: isDark ? Colors.white : null,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Zähler hinzufügen'),
                    onPressed: _addMeter,
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>('panel_2'),
              controller: _tileControllers[2],
              onExpansionChanged: (isExpanded) => _handleExpansion(2, isExpanded),
              title: const Text('Benachrichtigungen', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.notifications, color: Colors.grey),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: _meters.map((meter) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Material(
                    color: Theme.of(context).cardColor,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(meter.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Erinnerungen: ${_reminders[meter.id ?? -1]?.length ?? 0}'),
                        ),
                        if ((_reminders[meter.id ?? -1] ?? []).isNotEmpty) ...[
                          ...(_reminders[meter.id ?? -1] ?? []).map((reminder) => ListTile(
                                dense: true,
                                title: Text(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(reminder.baseDate))),
                                subtitle: Text('Wiederholung: ${reminder.repeat.toString().split('.').last}'),
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
                              ))
                        ],
                        ListTile(
                          leading: const Icon(Icons.add_alert_outlined),
                          title: const Text('Neue Erinnerung planen...'),
                          onTap: () => _scheduleNotificationWorkflow(forMeter: meter),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>('panel_3'),
              controller: _tileControllers[3],
              onExpansionChanged: (isExpanded) => _handleExpansion(3, isExpanded),
              title: const Text('Datensicherung', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.backup_outlined, color: Colors.grey),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Material(
                    color: Theme.of(context).cardColor,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: const Icon(Icons.upload_file_outlined),
                      title: const Text('Backup erstellen'),
                      onTap: _createBackup,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Material(
                    color: Theme.of(context).cardColor,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: const Icon(Icons.download_for_offline_outlined),
                      title: const Text('Backup wiederherstellen'),
                      onTap: _restoreBackup,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>('panel_4'),
              controller: _tileControllers[4],
              onExpansionChanged: (isExpanded) => _handleExpansion(4, isExpanded),
              title: const Text('Impressum', style: TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.info_outline, color: Colors.grey),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Material(
                    color: Theme.of(context).cardColor,
                    elevation: 1,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}