// Datei: lib/utils/pdf_helper.dart

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart'; // KORREKTUR: Fehlender Import
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_service.dart';

Future<void> exportToPdf() async {
  final pdf = pw.Document();
  final font = await PdfGoogleFonts.robotoRegular();
  final boldFont = await PdfGoogleFonts.robotoBold();

  final meters = await AppDb.instance.fetchMeters(onlyActive: false);

  for (final meter in meters) {
    final readings = await AppDb.instance.fetchReadingsForMeter(meter.id!);
    if (readings.isEmpty) continue;

    final meterType = await AppDb.instance.fetchMeterTypeById(meter.meterTypeId);
    final isDualTariff = meterType?.name == 'Strom (HT/NT)';

    // Spalten-Header definieren
    final headers = isDualTariff
        ? ['Datum', 'HT-Stand', 'NT-Stand', 'HT-Verbr.', 'NT-Verbr.', 'Gesamtverbr.']
        : ['Datum', 'Zählerstand', 'Verbrauch'];

    List<List<String>> tableData = [headers];

    // Datenzeilen mit Verbrauchsberechnung erstellen
    for (var i = 0; i < readings.length; i++) {
      final current = readings[i];
      if (isDualTariff) {
        String htConsumption = '-';
        String ntConsumption = '-';
        String totalConsumption = '-';

        if (i < readings.length - 1) {
          final previous = readings[i + 1];
          final htCons = (current.ht ?? 0.0) - (previous.ht ?? 0.0);
          final ntCons = (current.nt ?? 0.0) - (previous.nt ?? 0.0);
          htConsumption = htCons.toStringAsFixed(2);
          ntConsumption = ntCons.toStringAsFixed(2);
          totalConsumption = (htCons + ntCons).toStringAsFixed(2);
        }
        tableData.add([
          DateFormat('dd.MM.yyyy').format(current.date),
          current.ht?.toStringAsFixed(2) ?? '-',
          current.nt?.toStringAsFixed(2) ?? '-',
          htConsumption,
          ntConsumption,
          totalConsumption,
        ]);
      } else {
        String consumption = '-';
        if (i < readings.length - 1) {
          final previous = readings[i + 1];
          final cons = (current.value ?? 0.0) - (previous.value ?? 0.0);
          consumption = cons.toStringAsFixed(2);
        }
        tableData.add([
          DateFormat('dd.MM.yyyy').format(current.date),
          current.value?.toStringAsFixed(2) ?? '-',
          consumption,
        ]);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Text(
              '${meter.name} (${meter.number ?? 'N/A'})',
              style: pw.TextStyle(font: boldFont, fontSize: 18),
            ),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(font: boldFont),
              cellStyle: pw.TextStyle(font: font),
              data: tableData,
            ),
          ];
        },
      ),
    );
  }

  final output = await getTemporaryDirectory();
  final file = File("${output.path}/export_${DateTime.now().millisecondsSinceEpoch}.pdf");
  await file.writeAsBytes(await pdf.save());

  await Share.shareXFiles([XFile(file.path)], text: 'Hier ist dein Datenexport.');
}