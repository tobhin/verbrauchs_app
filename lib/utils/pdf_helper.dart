// Datei: lib/utils/pdf_helper.dart

import 'dart.io';
// import 'package:flutter/services.dart'; // War unbenutzt
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:pdf/pdf.dart'; // War unbenutzt
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
// import '../models/meter.dart'; // War unbenutzt
import '../services/database_service.dart';

Future<void> exportToPdf() async {
  final pdf = pw.Document();
  final font = await PdfGoogleFonts.robotoRegular();
  final boldFont = await PdfGoogleFonts.robotoBold();

  final meters = await AppDb.instance.fetchMeters(onlyActive: false);

  for (final meter in meters) {
    final readings = await AppDb.instance.fetchReadingsForMeter(meter.id!);
    if (readings.isEmpty) continue;

    final meterType = await AppDb.instance.getMeterTypeById(meter.meterTypeId);
    final isDualTariff = meterType?.name == 'Strom';

    List<List<String>> tableData = [];
    tableData.add(isDualTariff ? ['Datum', 'HT', 'NT'] : ['Datum', 'Zählerstand']);

    for (final reading in readings) {
      tableData.add(isDualTariff
          ? [
              DateFormat('dd.MM.yyyy').format(reading.date),
              reading.ht?.toStringAsFixed(2) ?? '-',
              reading.nt?.toStringAsFixed(2) ?? '-',
            ]
          : [
              DateFormat('dd.MM.yyyy').format(reading.date),
              reading.value?.toStringAsFixed(2) ?? '-',
            ]);
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${meter.name} (${meter.number ?? 'N/A'})',
                style: pw.TextStyle(font: boldFont, fontSize: 18),
              ),
              pw.SizedBox(height: 16),
              // KORRIGIERT: Veraltete Methode ersetzt
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(font: boldFont),
                cellStyle: pw.TextStyle(font: font),
                data: tableData,
              ),
            ],
          );
        },
      ),
    );
  }

  final output = await getTemporaryDirectory();
  final file = File("${output.path}/export_${DateTime.now().millisecondsSinceEpoch}.pdf");
  await file.writeAsBytes(await pdf.save());

  await Share.shareXFiles([XFile(file.path)], text: 'Hier ist dein Datenexport.');
}