import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/meter.dart';
import '../models/meter_type.dart';
import '../models/reading.dart';
import '../models/reading_with_consumption.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';
import '../widgets/verbrauchs_diagramm.dart';

class WerteScreen extends StatefulWidget {
  const WerteScreen({super.key});

  @override
  State<WerteScreen> createState() => _WerteScreenState();
}

class _WerteScreenState extends State<WerteScreen> {
  List<Meter> _meters = [];
  Meter? _selected;
  MeterType? _selectedMeterType;
  List<ReadingWithConsumption> _readingsWithConsumption = [];
  List<int> _availableYears = [];
  int? _selectedYear;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _loadMeters();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMeters() async {
    setState(() => _isLoading = true);
    try {
      final ms = await AppDb.instance.fetchMeters();

      if (ms.isEmpty) {
        if (mounted) {
          setState(() {
            _meters = [];
            _selected = null;
            _readingsWithConsumption = [];
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _meters = ms;
          _selected = ms.first;
        });
      }
      await _reloadReadings();
      if (mounted) setState(() => _isLoading = false);
    } catch (e, st) {
      await Logger.log('[WerteScreen] ERROR: Failed to load meters: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reloadReadings() async {
    if (_selected == null) {
      if (mounted) {
        setState(() {
          _readingsWithConsumption = [];
          _availableYears = [];
        });
      }
      return;
    }

    try {
      final meterType = await AppDb.instance.fetchMeterTypeById(_selected!.meterTypeId);
      final readings = await AppDb.instance.fetchReadingsForMeter(_selected!.id!);
      final readingsWithConsumption = <ReadingWithConsumption>[];
      for (var i = 0; i < readings.length; i++) {
        final consumption = i < readings.length - 1 ? readings[i].value! - readings[i + 1].value! : null;
        readingsWithConsumption.add(ReadingWithConsumption(
          reading: readings[i],
          consumption: consumption,
        ));
      }

      final years = readings.map((r) => r.date.year).toSet().toList()..sort((a, b) => b.compareTo(a));
      if (mounted) {
        setState(() {
          _selectedMeterType = meterType;
          _readingsWithConsumption = readingsWithConsumption;
          _availableYears = years;
        });
      }
    } catch (e, st) {
      await Logger.log('[WerteScreen] ERROR: Failed to reload readings: $e\n$st');
    }
  }

  Future<void> _showManageEntryDialog(ReadingWithConsumption item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag verwalten'),
        content: const Text('Möchten Sie diesen Eintrag löschen?'),
        actions: [
          TextButton(
            child: const Text('Abbrechen'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            child: const Text('Löschen'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AppDb.instance.deleteReading(item.reading.id!);
      await _reloadReadings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eintrag gelöscht')),
      );
    }
  }

  Future<void> _exportReadings() async {
    try {
      final readings = _readingsWithConsumption
          .where((r) => _selectedYear == null || r.reading.date.year == _selectedYear)
          .toList();
      final csvData = [
        ['Datum', 'Zählerstand', 'Verbrauch', 'Einheit'],
        ...readings.map((r) => [
              DateFormat('dd.MM.yyyy').format(r.reading.date),
              r.reading.value?.toStringAsFixed(2) ?? 'HT: ${r.reading.ht} / NT: ${r.reading.nt}',
              r.consumption?.toStringAsFixed(2) ?? '',
              _selectedMeterType?.name == 'Strom (HT/NT)' ? 'kWh' : 'm³',
            ]),
      ];
      final csvString = const ListToCsvConverter().convert(csvData);
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/readings_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      await File(path).writeAsString(csvString);
      await Share.shareXFiles([XFile(path)], text: 'Zählerstände Export');
      await Logger.log('[WerteScreen] Exported readings to $path');
    } catch (e, st) {
      await Logger.log('[WerteScreen] ERROR: Failed to export readings: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export fehlgeschlagen')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final unit = _selectedMeterType?.name == 'Strom (HT/NT)' ? 'kWh' : 'm³';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Werte'),
        actions: [
          DropdownButton<int>(
            value: _selectedYear,
            items: [
              const DropdownMenuItem(value: null, child: Text('Alle Jahre')),
              ..._availableYears.map((year) => DropdownMenuItem(value: year, child: Text('$year'))),
            ],
            onChanged: (year) {
              setState(() => _selectedYear = year);
              _reloadReadings();
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReadings,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<Meter>(
              value: _selected,
              isExpanded: true,
              items: _meters
                  .map((meter) => DropdownMenuItem(
                        value: meter,
                        child: Text(meter.name),
                      ))
                  .toList(),
              onChanged: (meter) {
                setState(() => _selected = meter);
                _reloadReadings();
              },
            ),
          ),
          VerbrauchsDiagramm(
            monatsVerbrauch: {},
            balkenFarbe: Theme.of(context).colorScheme.primary,
            einheit: unit,
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _readingsWithConsumption.length,
              itemBuilder: (ctx, i) {
                final item = _readingsWithConsumption[i];
                final reading = item.reading;
                if (_selectedYear != null && reading.date.year != _selectedYear) return const SizedBox.shrink();

                String title;
                if (reading.value != null) {
                  title = '${reading.value!.toStringAsFixed(2)} $unit';
                } else {
                  title = 'HT: ${reading.ht?.toStringAsFixed(2)} / NT: ${reading.nt?.toStringAsFixed(2)} $unit';
                }

                String consumptionText = '';
                if (item.consumption != null && item.consumption! >= 0) {
                  consumptionText = '+${item.consumption!.toStringAsFixed(2)} $unit';
                }

                return ListTile(
                  onLongPress: () => _showManageEntryDialog(item),
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(title),
                  subtitle: Text(
                    '${DateFormat('dd.MM.yyyy', 'de_DE').format(reading.date)}\n'
                    '${DateFormat('HH:mm', 'de_DE').format(reading.date)} Uhr',
                  ),
                  trailing: Text(
                    consumptionText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}