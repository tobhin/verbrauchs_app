import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/meter.dart';
import '../models/meter_type.dart';
import '../models/reading.dart';
import '../models/reading_with_consumption.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart'; // HINZUGEFÜGT für Logging
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
  final bool _isChartVisible = false;
  bool _isLoading = true;
  String _totalCostString = '';
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
      final meterType = await AppDb.instance.fetchMeterTypeById(_selected!.meterTypeId); // Behoben: fetchMeterTypeById
      final readings = await AppDb.instance.fetchReadingsForMeter(_selected!.id!);
      final readingsWithConsumption = <ReadingWithConsumption>[];
      for (var i = 0; i < readings.length; i++) {
        final consumption = i < readings.length - 1 ? readings[i].value! - readings[i + 1].value! : null;
        readingsWithConsumption.add(ReadingWithConsumption(readings[i], consumption));
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

  // Weitere Methoden für Export, _showManageEntryDialog usw. aus deinem truncated Code

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final unit = _selectedMeterType?.name == 'Strom (HT/NT)' ? 'kWh' : 'm³';

    return Scaffold(
      body: Column(
        children: [
          DropdownButton<Meter>(
            value: _selected,
            items: _meters.map((meter) => DropdownMenuItem(
              value: meter,
              child: Text(meter.name),
            )).toList(),
            onChanged: (meter) {
              setState(() => _selected = meter);
              _reloadReadings();
            },
          ),
          // Chart und Liste aus truncated Code
          VerbrauchsDiagramm(monatsVerbrauch: {}, balkenFarbe: Colors.blue, einheit: unit),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _readingsWithConsumption.length,
              itemBuilder: (ctx, i) {
                final item = _readingsWithConsumption[i];
                final reading = item.reading;
                final consumption = item.consumption;

                String title;
                if (reading.value != null) {
                  title = '${reading.value} $unit';
                } else {
                  title = 'HT: ${reading.ht} / NT: ${reading.nt} $unit';
                }

                String consumptionText = '';
                if (consumption != null && consumption >= 0) {
                  consumptionText = '+${consumption.toStringAsFixed(2)} $unit';
                }

                return ListTile(
                  onLongPress: () => _showManageEntryDialog(item),
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(title),
                  subtitle: Text(
                    '${DateFormat('dd.MM.yyyy', 'de_DE').format(reading.date)}\n'
                    '${DateFormat('HH:mm', 'de_DE').format(reading.date)} Uhr'
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