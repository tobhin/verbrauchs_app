class Tariff {
  final int? id;
  final int meterId;
  final double costPerUnit;
  // --- NEU: Grundgebühr pro Monat ---
  final double baseFee;

  Tariff({
    this.id,
    required this.meterId,
    required this.costPerUnit,
    // --- UPDATE: Standardwert 0.0 ---
    this.baseFee = 0.0,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'meter_id': meterId,
        'cost_per_unit': costPerUnit,
        // --- NEU ---
        'base_fee': baseFee,
      };

  static Tariff fromMap(Map<String, Object?> m) => Tariff(
        id: m['id'] as int?,
        meterId: m['meter_id'] as int,
        costPerUnit: (m['cost_per_unit'] as num).toDouble(),
        // --- NEU: base_fee aus der DB lesen ---
        baseFee: ((m['base_fee'] ?? 0.0) as num).toDouble(),
      );
}