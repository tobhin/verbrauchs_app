class Tariff {
  final int? id;
  final int meterId;
  final double costPerUnit;
  final double baseFee;
  final DateTime gueltigAb;
  final String? grund;

  Tariff({
    this.id,
    required this.meterId,
    required this.costPerUnit,
    this.baseFee = 0.0,
    required this.gueltigAb,
    this.grund,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'meter_id': meterId,
        'cost_per_unit': costPerUnit,
        'base_fee': baseFee,
        'gueltig_ab': gueltigAb.toIso8601String(),
        'grund': grund,
      };

  static Tariff fromMap(Map<String, Object?> m) => Tariff(
        id: m['id'] as int?,
        meterId: m['meter_id'] as int,
        costPerUnit: (m['cost_per_unit'] as num).toDouble(),
        baseFee: (m['base_fee'] as num? ?? 0.0).toDouble(),
        // Stellt sicher, dass das Datum immer korrekt gelesen wird
        gueltigAb: DateTime.parse(m['gueltig_ab'] as String? ?? DateTime(1970).toIso8601String()),
        grund: m['grund'] as String?,
      );
}