import 'reading.dart';

// Diese Klasse bündelt eine Lesung mit dem berechneten Verbrauch zum vorherigen Wert.
class ReadingWithConsumption {
  final Reading reading;
  final double? consumption; // Für Eintarifzähler
  final double? htConsumption; // Für HT-Verbrauch
  final double? ntConsumption; // Für NT-Verbrauch

  ReadingWithConsumption({
    required this.reading,
    this.consumption,
    this.htConsumption,
    this.ntConsumption,
  });

  // Berechnet den Gesamtverbrauch, egal ob Eintarif oder Zweitarif
  double? get totalConsumption {
    if (consumption != null) {
      return consumption;
    }
    if (htConsumption != null || ntConsumption != null) {
      return (htConsumption ?? 0.0) + (ntConsumption ?? 0.0);
    }
    return null;
  }
}