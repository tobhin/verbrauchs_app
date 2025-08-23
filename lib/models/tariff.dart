class Tariff {
  final int? id;
  final int meterId;
  final double costPerUnit;
  final double baseFee;

  Tariff({
    this.id,
    required this.meterId,
    required this.costPerUnit,
    this.baseFee = 0.0,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'meter_id': meterId,
        'cost_per_unit': costPerUnit,
        'base_fee': baseFee,
      };

  static Tariff fromMap(Map<String, Object?> m) => Tariff(
        id: m['id'] as int?,
        meterId: m['meter_id'] as int,
        costPerUnit: (m['cost_per_unit'] as num).toDouble(),
        baseFee: (m['base_fee'] as num? ?? 0.0).toDouble(),
      );
}