import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Helfer-Klasse, die wir intern nutzen
class _OcrCandidate {
  final double value;
  final String raw;
  final Rect box;
  final double score;
  _OcrCandidate({required this.value, required this.raw, required this.box, required this.score});
}

// Die ausgelagerte OCR-Funktion
Future<double?> tryOcrSmart({
  required String imagePath,
  required MeterTypeForOcr meterType,
  String? meterSerial,
  double? lastValue,
}) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final input = InputImage.fromFilePath(imagePath);
  final result = await recognizer.processImage(input);
  recognizer.close(); // Wichtig: Recognizer wieder schließen

  final serialClean = meterSerial?.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
  final candidates = <_OcrCandidate>[];
  final numberRe = RegExp(r'\d{2,}(?:[.,]\d{1,3})?');

  for (final block in result.blocks) {
    for (final line in block.lines) {
      final text = line.text.trim();
      final textClean = text.replaceAll(RegExp(r'\s'), '').toUpperCase();
      
      if (RegExp(r'[A-Z]').hasMatch(text)) continue;
      if (text.contains('-')) continue;
      if (serialClean != null && textClean.contains(serialClean)) continue;

      for (final m in numberRe.allMatches(text)) {
        final s = m.group(0)!;
        final v = double.tryParse(s.replaceAll(',', '.'));
        if (v == null) continue;

        double score = 0;
        score += (line.boundingBox.height / 10.0).clamp(0, 10);
        if (s.contains('.') || s.contains(',')) score += 0.5;
        
        bool plausible = (v >= 0 && v <= 9999999);
        if (!plausible) score -= 2.0;
        
        if (lastValue != null) {
          if (v < lastValue) score -= 3.0;
          if ((v - lastValue) > 100000) score -= 1.5;
        }

        candidates.add(_OcrCandidate(
          value: v,
          raw: s,
          box: line.boundingBox,
          score: score,
        ));
      }
    }
  }
  candidates.sort((a, b) => b.score.compareTo(a.score));
  return candidates.isNotEmpty ? candidates.first.value : null;
}

// Wir brauchen diesen Enum, damit der OcrService nicht das Meter-Model kennen muss
enum MeterTypeForOcr { strom, wasser, schmutzwasser, gas }