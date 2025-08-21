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
  bool _isChartVisible = false;
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
    final ms = await AppDb.instance.fetchMeters();
    
    // KORREKTUR: Lade-Endlosschleife beheben
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

    if(mounted) {
      setState(() {
        _meters = ms;
        _selected = ms.first;
      });
    }
    await _reloadReadings();
    if(mounted) setState(() => _isLoading = false);
  }

  Future<void> _reloadReadings() async {
    if (_selected == null) {
      if(mounted) {
        setState(() {
          _readingsWithConsumption = [];
          _availableYears = [];
          _isLoading = false;
        });
      }
      return;
    }
    if(mounted) setState(() => _isLoading = true);

    final meterType = await AppDb.instance.getMeterTypeById(_selected!.meterTypeId);
    final allReadings = await AppDb.instance.fetchReadingsForMeter(_selected!.id!);

    _availableYears = allReadings.map((r) => r.date.year).toSet().toList();
     if (!_availableYears.contains(DateTime.now().year)) {
      _availableYears.add(DateTime.now().year);
    }
    _availableYears.sort((a, b) => b.compareTo(a));

    final filteredReadings = _selectedYear == null
        ? allReadings
        : allReadings.where((r) => r.date.year == _selectedYear).toList();

    List<ReadingWithConsumption> tempConsumptionList = [];
    for (int i = 0; i < filteredReadings.length; i++) {
      double? consumption;
      if (i + 1 < filteredReadings.length) {
        final current = filteredReadings[i];
        final previous = filteredReadings[i + 1];
        if (current.value != null && previous.value != null) {
          consumption = current.value! - previous.value!;
        } else if (current.ht != null &&
            previous.ht != null &&
            current.nt != null &&
            previous.nt != null) {
          consumption = (current.ht! + current.nt!) - (previous.ht! + previous.nt!);
        }
      }
      tempConsumptionList.add(ReadingWithConsumption(reading: filteredReadings[i], consumption: consumption));
    }
    
    if(mounted) {
      setState(() {
        _selectedMeterType = meterType;
        _readingsWithConsumption = tempConsumptionList;
      });
    }
    await _calculateCosts();
    if(mounted) setState(() => _isLoading = false);
  }
  
  Future<void> _calculateCosts() async {
    if (_selected == null || _readingsWithConsumption.isEmpty) {
      if(mounted) setState(() => _totalCostString = '');
      return;
    }
    final tariff = await AppDb.instance.getTariff(_selected!.id!);
    if (tariff == null) {
      if(mounted) setState(() => _totalCostString = 'Kein Tarif festgelegt');
      return;
    }

    double totalConsumption = 0;
    Set<String> uniqueMonths = {};

    final readingsForCost = _readingsWithConsumption.where((r) => r.consumption != null && r.consumption! >= 0);

    if (readingsForCost.isEmpty) {
      if(mounted) setState(() => _totalCostString = 'Zu wenig Daten für Kostenberechnung');
      return;
    }

    for (var item in readingsForCost) {
      totalConsumption += item.consumption!;
      uniqueMonths.add('${item.reading.date.year}-${item.reading.date.month}');
    }

    final cost = totalConsumption * tariff.costPerUnit;
    final baseFees = uniqueMonths.length * tariff.baseFee;
    final total = cost + baseFees;

    if(mounted) {
      setState(() {
        _totalCostString =
            '${total.toStringAsFixed(2)} € (inkl. ${baseFees.toStringAsFixed(2)} € Grundgebühr)';
      });
    }
  }

  Map<int, double> _getChartData() {
    final Map<int, double> data = {};
    for (final item in _readingsWithConsumption.reversed) {
      if (item.consumption != null && item.consumption! >= 0) {
        final month = item.reading.date.month;
        data[month] = (data[month] ?? 0) + item.consumption!;
      }
    }
    return data;
  }
  
  void _showYearFilter() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nach Jahr filtern'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _availableYears.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    title: const Text('Alle Jahre'),
                    selected: _selectedYear == null,
                    onTap: () {
                      setState(() => _selectedYear = null);
                      _reloadReadings();
                      Navigator.pop(context);
                    },
                  );
                }
                final year = _availableYears[index - 1];
                return ListTile(
                  title: Text(year.toString()),
                  selected: year == _selectedYear,
                  onTap: () {
                    setState(() => _selectedYear = year);
                    _reloadReadings();
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _export() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Als CSV exportieren'),
              onTap: () { Navigator.pop(ctx); _exportCsv(); },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_outlined),
              title: const Text('Als Excel exportieren'),
              onTap: () { Navigator.pop(ctx); _exportExcel(); },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Als PDF exportieren'),
              onTap: () { Navigator.pop(ctx); _exportPdf(); },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<List<dynamic>>> _prepareDataRows() async {
    final List<List<dynamic>> rows = [];
    final unit = _selectedMeterType?.name == 'Strom' ? 'kWh' : 'm³';
    final tariff = await AppDb.instance.getTariff(_selected!.id!);
    
    if (_selectedMeterType?.name == 'Strom') {
      rows.add(['Datum', 'Uhrzeit', 'HT', 'NT', 'Verbrauch ($unit)', 'Kosten (€)']);
      for (var item in _readingsWithConsumption) {
        double? cost;
        if (item.consumption != null && tariff != null) {
          cost = item.consumption! * tariff.costPerUnit;
        }
        rows.add([
          DateFormat('dd.MM.yyyy').format(item.reading.date),
          DateFormat('HH:mm').format(item.reading.date),
          item.reading.ht,
          item.reading.nt,
          item.consumption?.toStringAsFixed(2) ?? '',
          cost?.toStringAsFixed(2) ?? '',
        ]);
      }
    } else {
      rows.add(['Datum', 'Uhrzeit', 'Zählerstand ($unit)', 'Verbrauch ($unit)', 'Kosten (€)']);
       for (var item in _readingsWithConsumption) {
        double? cost;
        if (item.consumption != null && tariff != null) {
          cost = item.consumption! * tariff.costPerUnit;
        }
        rows.add([
          DateFormat('dd.MM.yyyy').format(item.reading.date),
          DateFormat('HH:mm').format(item.reading.date),
          item.reading.value,
          item.consumption?.toStringAsFixed(2) ?? '',
          cost?.toStringAsFixed(2) ?? '',
        ]);
      }
    }
    return rows;
  }
  
  Future<void> _exportCsv() async {
    final tariff = await AppDb.instance.getTariff(_selected!.id!);
    final unit = _selectedMeterType?.name == 'Strom' ? 'kWh' : 'm³';

    List<List<dynamic>> headerRows = [
      ['Tarifinformationen'],
      ['Arbeitspreis (€/$unit)', tariff?.costPerUnit.toStringAsFixed(4) ?? 'N/A'],
      ['Grundgebühr (€/Monat)', tariff?.baseFee.toStringAsFixed(2) ?? 'N/A'],
      [],
    ];

    final dataRows = await _prepareDataRows();
    final allRows = headerRows + dataRows;

    final csvData = const ListToCsvConverter().convert(allRows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/export_${_selected?.name}_${_selectedYear ?? 'alle'}.csv');
    await file.writeAsString(csvData);
    await Share.shareXFiles([XFile(file.path)], text: 'CSV Export');
  }

  Future<void> _exportExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Werte'];
    excel.delete('Sheet1');

    final tariff = await AppDb.instance.getTariff(_selected!.id!);
    final unit = _selectedMeterType?.name == 'Strom' ? 'kWh' : 'm³';

    sheet.appendRow([TextCellValue('Tarifinformationen')]);
    sheet.appendRow([TextCellValue('Arbeitspreis (€ pro $unit)'), TextCellValue(tariff?.costPerUnit.toStringAsFixed(4) ?? 'N/A')]);
    sheet.appendRow([TextCellValue('Grundgebühr (€ pro Monat)'), TextCellValue(tariff?.baseFee.toStringAsFixed(2) ?? 'N/A')]);
    sheet.appendRow([]);

    final dataRows = await _prepareDataRows();
    for (var row in dataRows) {
      sheet.appendRow(row.map((item) => TextCellValue(item.toString())).toList());
    }

    final dir = await getApplicationDocumentsDirectory();
    final bytes = excel.encode()!;
    final file = File('${dir.path}/export_${_selected?.name}_${_selectedYear ?? 'alle'}.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'Excel Export');
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final dataRows = await _prepareDataRows();
    final tariff = await AppDb.instance.getTariff(_selected!.id!);
    final unit = _selectedMeterType?.name == 'Strom' ? 'kWh' : 'm³';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(text: 'Export für ${_selected?.name} - ${_selectedYear ?? 'Alle Jahre'}', level: 0),
          pw.Header(text: 'Tarifinformationen', level: 2),
          pw.Text('Arbeitspreis: ${tariff?.costPerUnit.toStringAsFixed(4) ?? 'N/A'} € / $unit'),
          pw.Text('Grundgebühr: ${tariff?.baseFee.toStringAsFixed(2) ?? 'N/A'} € / Monat'),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: dataRows.first.cast<String>(),
            data: dataRows.skip(1).toList(),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/export_${_selected?.name}_${_selectedYear ?? 'alle'}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'PDF Export');
  }
  
  Future<void> _showManageEntryDialog(ReadingWithConsumption item) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Eintrag bearbeiten'),
              onTap: () {
                Navigator.pop(ctx);
                _editEntry(item.reading);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eintrag löschen'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteEntry(item.reading.id!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEntry(int readingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: const Text('Möchtest du diesen Eintrag wirklich endgültig löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );

    if (confirmed == true) {
      await AppDb.instance.deleteReading(readingId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eintrag gelöscht')));
      await _reloadReadings();
    }
  }

  Future<void> _editEntry(Reading reading) async {
    final valueCtrl = TextEditingController(text: reading.value?.toString() ?? '');
    final htCtrl = TextEditingController(text: reading.ht?.toString() ?? '');
    final ntCtrl = TextEditingController(text: reading.nt?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _selectedMeterType?.name == 'Strom'
              ? [
                  TextFormField(controller: htCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'HT-Wert')),
                  const SizedBox(height: 8),
                  TextFormField(controller: ntCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'NT-Wert')),
                ]
              : [
                  TextFormField(controller: valueCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Zählerstand')),
                ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Speichern')),
        ],
      ),
    );

    if (ok == true) {
      final updatedReading = reading.copyWith(
        value: _parseNum(valueCtrl.text),
        ht: _parseNum(htCtrl.text),
        nt: _parseNum(ntCtrl.text),
      );
      await AppDb.instance.updateReading(updatedReading);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eintrag aktualisiert')));
      await _reloadReadings();
    }
  }
  
  double? _parseNum(String? s) {
    if (s == null || s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.').trim());
  }

  @override
  Widget build(BuildContext context) {
    final unit = _selectedMeterType?.name == 'Strom' ? 'kWh' : 'm³';
    
    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Meter>(
                    isExpanded: true,
                    value: _selected,
                    items: _meters.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(),
                    onChanged: (m) {
                      if (m != null) {
                        setState(() {
                          _selected = m;
                          _selectedYear = DateTime.now().year;
                        });
                        _reloadReadings();
                      }
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Zähler'),
                  ),
                ),
                IconButton(
                  onPressed: _availableYears.isEmpty ? null : _showYearFilter,
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Nach Jahr filtern',
                ),
                IconButton(
                  onPressed: _readingsWithConsumption.isEmpty ? null : _export,
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Daten exportieren',
                ),
              ],
            ),
          ),
          if (_totalCostString.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16, 8),
              child: Text(
                'Gesamtkosten (${_selectedYear ?? 'Alle Jahre'}): $_totalCostString',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _readingsWithConsumption.isEmpty
                    ? Center(child: Text(_selected == null ? 'Bitte einen Zähler auswählen' : 'Keine Einträge für diesen Zähler vorhanden.'))
                    : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _isChartVisible
                                ? VerbrauchsDiagramm(
                                    monatsVerbrauch: _getChartData(),
                                    balkenFarbe: Theme.of(context).colorScheme.primary,
                                    einheit: unit,
                                  )
                                : const SizedBox(height: 0, width: double.infinity),
                          ),
                        ),
                        if (_isChartVisible) const SizedBox(height: 8),
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
                                    '${DateFormat('HH:mm', 'de_DE').format(reading.date)} Uhr'),
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
          ),
        ],
      );
  }
}
