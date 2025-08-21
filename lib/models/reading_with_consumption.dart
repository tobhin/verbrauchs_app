import 'reading.dart';

// Diese Klasse bündelt eine Lesung mit dem berechneten Verbrauch zum vorherigen Wert.
class ReadingWithConsumption {
  final Reading reading;
  final double? consumption;

  ReadingWithConsumption({required this.reading, this.consumption});
}