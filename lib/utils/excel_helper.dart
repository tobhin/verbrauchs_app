// Datei: lib/utils/excel_helper.dart

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
// import '../models/meter.dart'; // War unbenutzt
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

    final meterType = await AppDb.instance.getMeterTypeById(meter.meterTypeId);
    final isDualTariff = meterType?.name == 'Strom';

    // Header
    if (isDualTariff) {
      sheetObject.appendRow([
        TextCellValue('Datum'), // KORRIGIERT: "const" entfernt
        TextCellValue('HT'),    // KORRIGIERT: "const" entfernt
        TextCellValue('NT')     // KORRIGIERT: "const" entfernt
      ]);
    } else {
      sheetObject.appendRow([
        TextCellValue('Datum'),       // KORRIGIERT: "const" entfernt
        TextCellValue('Zählerstand') // KORRIGIERT: "const" entfernt
      ]);
    }

    // Data Rows
    for (final reading in readings) {
      if (isDualTariff) {
        sheetObject.appendRow([
          TextCellValue(DateFormat('dd.MM.yyyy').format(reading.date)),
          DoubleCellValue(reading.ht ?? 0.0),
          DoubleCellValue(reading.nt ?? 0.0),
        ]);
      } else {
        sheetObject.appendRow([
          TextCellValue(DateFormat('dd.MM.yyyy').format(reading.date)),
          DoubleCellValue(reading.value ?? 0.0),
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