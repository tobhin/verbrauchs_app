// Datei: lib/utils/excel_helper.dart

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_service.dart';

Future<void> exportToExcel() async {
  var excel = Excel.createExcel();
  final meters = await AppDb.instance.fetchMeters(onlyActive: false);

  for (final meter in meters) {
    final readings = await AppDb.instance.fetchReadingsForMeter(meter.id!);
    if (readings.isEmpty) continue;

    String sheetName = meter.name.replaceAll(RegExp(r'[\*/:?\[\]]'), '').trim();
    if (sheetName.length > 31) {
      sheetName = sheetName.substring(0, 31);
    }
    
    Sheet sheetObject = excel[sheetName];

    final meterType = await AppDb.instance.fetchMeterTypeById(meter.meterTypeId);
    final isDualTariff = meterType?.name == 'Strom (HT/NT)';

    // Header
    if (isDualTariff) {
      sheetObject.appendRow([
        TextCellValue('Datum'),
        TextCellValue('HT-Stand'),
        TextCellValue('NT-Stand'),
        TextCellValue('HT-Verbrauch'),
        TextCellValue('NT-Verbrauch'),
        TextCellValue('Gesamtverbrauch'),
      ]);
    } else {
      sheetObject.appendRow([
        TextCellValue('Datum'),
        TextCellValue('Zählerstand'),
        TextCellValue('Verbrauch'),
      ]);
    }

    // Data Rows mit Verbrauchsberechnung
    for (var i = 0; i < readings.length; i++) {
      final current = readings[i];
      if (isDualTariff) {
        double? htConsumption;
        double? ntConsumption;
        if (i < readings.length - 1) {
          final previous = readings[i + 1];
          htConsumption = (current.ht ?? 0.0) - (previous.ht ?? 0.0);
          ntConsumption = (current.nt ?? 0.0) - (previous.nt ?? 0.0);
        }
        sheetObject.appendRow([
          TextCellValue(DateFormat('dd.MM.yyyy').format(current.date)),
          DoubleCellValue(current.ht ?? 0.0),
          DoubleCellValue(current.nt ?? 0.0),
          if (htConsumption != null) DoubleCellValue(htConsumption) else TextCellValue(''),
          if (ntConsumption != null) DoubleCellValue(ntConsumption) else TextCellValue(''),
          if (htConsumption != null && ntConsumption != null) DoubleCellValue(htConsumption + ntConsumption) else TextCellValue(''),
        ]);
      } else {
        double? consumption;
        if (i < readings.length - 1) {
          final previous = readings[i + 1];
          consumption = (current.value ?? 0.0) - (previous.value ?? 0.0);
        }
        sheetObject.appendRow([
          TextCellValue(DateFormat('dd.MM.yyyy').format(current.date)),
          DoubleCellValue(current.value ?? 0.0),
          if (consumption != null) DoubleCellValue(consumption) else TextCellValue(''),
        ]);
      }
    }
  }
  
  // Save and Share
  final output = await getTemporaryDirectory();
  final fileBytes = excel.save();
  if (fileBytes != null) {
    final file = File("${output.path}/export_${DateTime.now().millisecondsSinceEpoch}.xlsx")
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);
    
    await Share.shareXFiles([XFile(file.path)], text: 'Hier ist dein Datenexport.');
  }
}