import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/meter.dart';
import '../models/meter_type.dart';
import '../models/reading.dart';
import '../models/tariff.dart';
import '../models/reading_with_consumption.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';
import '../utils/excel_helper.dart';
import '../utils/pdf_helper.dart';


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

  Reading? _startwert;
  List<Tariff> _tariffHistory = [];

  bool get _isStromZaehler => _selectedMeterType?.name == 'Strom (HT/NT)';

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
            _meters = []; _selected = null; _readingsWithConsumption = []; _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _meters = ms;
          if (_selected == null || !ms.any((m) => m.id == _selected!.id)) {
            _selected = ms.first;
          }
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
      if (mounted) setState(() {
        _readingsWithConsumption = []; _availableYears = []; _selectedYear = null; _startwert = null; _tariffHistory = [];
      });
      return;
    }

    try {
      final meterType = await AppDb.instance.fetchMeterTypeById(_selected!.meterTypeId);
      final startwert = await AppDb.instance.fetchStartwertForMeter(_selected!.id!);
      final tariffHistory = await AppDb.instance.fetchAllTariffsForMeter(_selected!.id!);
      final readings = await AppDb.instance.fetchReadingsForMeter(_selected!.id!);
      
      final allReadingsForConsumption = [if (startwert != null) startwert, ...readings];
      allReadingsForConsumption.sort((a, b) => b.date.compareTo(a.date));

      final readingsWithConsumption = <ReadingWithConsumption>[];
      final bool isCurrentStrom = meterType?.name == 'Strom (HT/NT)';

      for (var i = 0; i < allReadingsForConsumption.length; i++) {
        double? consumption; double? htConsumption; double? ntConsumption;

        if (i < allReadingsForConsumption.length - 1) {
          final current = allReadingsForConsumption[i];
          final previous = allReadingsForConsumption[i + 1];
          if (isCurrentStrom) {
            htConsumption = (current.ht ?? 0.0) - (previous.ht ?? 0.0);
            ntConsumption = (current.nt ?? 0.0) - (previous.nt ?? 0.0);
          } else {
            consumption = (current.value ?? 0.0) - (previous.value ?? 0.0);
          }
        }
        
        if (allReadingsForConsumption[i].tariffId != AppDb.startwertTariffId){
          readingsWithConsumption.add(ReadingWithConsumption(reading: allReadingsForConsumption[i], consumption: consumption, htConsumption: htConsumption, ntConsumption: ntConsumption));
        }
      }

      final years = readings.map((r) => r.date.year).toSet().toList()..sort((a, b) => b.compareTo(a));
      if (mounted) {
        setState(() {
          _selectedMeterType = meterType;
          _startwert = startwert;
          _tariffHistory = tariffHistory;
          _readingsWithConsumption = readingsWithConsumption;
          _availableYears = years;
          
          if (_selectedYear != null && !years.contains(_selectedYear)) {
            _selectedYear = years.isNotEmpty ? years.first : null;
          }
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
          TextButton(child: const Text('Abbrechen'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(child: const Text('Löschen'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (ok == true) {
      await AppDb.instance.deleteReading(item.reading.id!);
      await _reloadReadings();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eintrag gelöscht')));
    }
  }
  
  Future<void> _exportReadingsCSV() async {
    try {
      final readings = _readingsWithConsumption.where((r) => _selectedYear == null || r.reading.date.year == _selectedYear).toList();
      List<List<dynamic>> csvData;
      if (_isStromZaehler) {
        csvData = [['Datum', 'HT-Stand', 'NT-Stand', 'HT-Verbrauch', 'NT-Verbrauch', 'Gesamtverbrauch', 'Einheit'], ...readings.map((r) => [DateFormat('dd.MM.yyyy').format(r.reading.date), r.reading.ht?.toStringAsFixed(2) ?? '', r.reading.nt?.toStringAsFixed(2) ?? '', r.htConsumption?.toStringAsFixed(2) ?? '', r.ntConsumption?.toStringAsFixed(2) ?? '', r.totalConsumption?.toStringAsFixed(2) ?? '', 'kWh'])];
      } else {
        csvData = [['Datum', 'Zählerstand', 'Verbrauch', 'Einheit'], ...readings.map((r) => [DateFormat('dd.MM.yyyy').format(r.reading.date), r.reading.value?.toStringAsFixed(2) ?? '', r.consumption?.toStringAsFixed(2) ?? '', 'm³'])];
      }
      final csvString = const ListToCsvConverter().convert(csvData);
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/readings_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      await File(path).writeAsString(csvString);
      await Share.shareXFiles([XFile(path)], text: 'Zählerstände Export (CSV)');
    } catch (e, st) {
      await Logger.log('[WerteScreen] ERROR: Failed to export readings to CSV: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV Export fehlgeschlagen')));
    }
  }

  Future<void> _exportReadingsExcel() async {
    try {
      await exportToExcel();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Export erfolgreich')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Export fehlgeschlagen')));
    }
  }

  Future<void> _exportReadingsPDF() async {
    try {
      await exportToPdf();
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Export erfolgreich')));
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Export fehlgeschlagen')));
    }
  }

  Widget _buildInfoBox() {
    final filteredReadings = _readingsWithConsumption.where((r) => _selectedYear == null || r.reading.date.year == _selectedYear).toList();
    if (_startwert == null && filteredReadings.isEmpty) return const SizedBox.shrink();
    
    final currentTariff = _tariffHistory.isNotEmpty ? _tariffHistory.first : null;
    double totalCosts = 0;

    if (filteredReadings.isNotEmpty && _tariffHistory.isNotEmpty) {
      double calculatedCosts = 0;
      for (final item in filteredReadings) {
        final tariffForPeriod = _tariffHistory.firstWhere(
          (t) => !t.gueltigAb.isAfter(item.reading.date),
          orElse: () => _tariffHistory.last,
        );
        calculatedCosts += (item.totalConsumption ?? 0.0) * tariffForPeriod.costPerUnit;
      }
      totalCosts = calculatedCosts + (currentTariff?.baseFee ?? 0.0);
    }
    
    final unit = _isStromZaehler ? 'kWh' : 'm³';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_startwert != null) ...[
              Text('Startwert (${DateFormat('dd.MM.yyyy').format(_startwert!.date)}):', style: Theme.of(context).textTheme.titleSmall),
              Text(
                _isStromZaehler
                    ? 'HT: ${_startwert!.ht?.toStringAsFixed(2) ?? '-'} / NT: ${_startwert!.nt?.toStringAsFixed(2) ?? '-'} $unit'
                    : '${_startwert!.value?.toStringAsFixed(2) ?? '-'} $unit',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 16),
            ],
            if (currentTariff != null) ...[
              Text('Aktueller Tarif (gültig ab ${DateFormat('dd.MM.yyyy').format(currentTariff.gueltigAb)}):', style: Theme.of(context).textTheme.titleSmall),
              Text('Grundgebühr: ${currentTariff.baseFee.toStringAsFixed(2)} €', style: Theme.of(context).textTheme.bodyMedium),
              Text('Kosten/Einheit: ${currentTariff.costPerUnit.toStringAsFixed(2)} €', style: Theme.of(context).textTheme.bodyMedium),
              Text('Gesamtkosten: ${totalCosts.toStringAsFixed(2)} €', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            ] else
              Text('Kein Tarif hinterlegt.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final unit = _isStromZaehler ? 'kWh' : 'm³';
    final filteredReadings = _readingsWithConsumption.where((r) => _selectedYear == null || r.reading.date.year == _selectedYear).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Werte'),
        actions: [
          DropdownButton<int>(
            value: _selectedYear,
            items: [const DropdownMenuItem(value: null, child: Text('Alle Jahre')), ..._availableYears.map((year) => DropdownMenuItem(value: year, child: Text('$year')))],
            onChanged: (year) => setState(() => _selectedYear = year),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'csv') _exportReadingsCSV();
              if (value == 'excel') _exportReadingsExcel();
              if (value == 'pdf') _exportReadingsPDF();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.table_chart), SizedBox(width: 8), Text('Als CSV exportieren')])),
              const PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.grid_on), SizedBox(width: 8), Text('Als Excel exportieren')])),
              const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf), SizedBox(width: 8), Text('Als PDF exportieren')])),
            ],
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DropdownButton<Meter>(
              value: _selected,
              isExpanded: true,
              items: _meters.map((meter) => DropdownMenuItem(value: meter, child: Text(meter.name))).toList(),
              onChanged: (meter) {
                if (meter != null) {
                  setState(() => _selected = meter);
                  _reloadReadings();
                }
              },
            ),
          ),
          _buildInfoBox(),
          Expanded(
            child: filteredReadings.isEmpty
                ? const Center(child: Text('Keine Einträge für den gewählten Zeitraum.'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: filteredReadings.length,
                    itemBuilder: (ctx, i) {
                      final item = filteredReadings[i];
                      final reading = item.reading;
                      String title; String consumptionText = '';
                      if (_isStromZaehler) {
                        final htValue = reading.ht?.toStringAsFixed(2) ?? '-';
                        final ntValue = reading.nt?.toStringAsFixed(2) ?? '-';
                        title = 'HT: $htValue / NT: $ntValue $unit';
                        if (item.totalConsumption != null && item.totalConsumption! >= 0) consumptionText = '+${item.totalConsumption!.toStringAsFixed(2)} $unit';
                      } else {
                        title = '${reading.value?.toStringAsFixed(2) ?? '-'} $unit';
                        if (item.consumption != null && item.consumption! >= 0) consumptionText = '+${item.consumption!.toStringAsFixed(2)} $unit';
                      }
                      return ListTile(
                        onLongPress: () => _showManageEntryDialog(item),
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(title),
                        subtitle: Text('${DateFormat('dd.MM.yyyy', 'de_DE').format(reading.date)}\n${DateFormat('HH:mm', 'de_DE').format(reading.date)} Uhr'),
                        trailing: Text(consumptionText, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}