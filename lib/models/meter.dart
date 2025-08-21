class Meter {
  final int? id;
  final String name;
  final int meterTypeId;
  final String number;
  final bool active;
  final bool isFavorite;

  const Meter({
    this.id,
    required this.name,
    required this.meterTypeId,
    required this.number,
    this.active = true,
    this.isFavorite = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'meter_type_id': meterTypeId,
        'number': number,
        'active': active ? 1 : 0,
        'is_favorite': isFavorite ? 1 : 0,
      };

  static Meter fromMap(Map<String, Object?> m) => Meter(
        id: m['id'] as int?,
        name: (m['name'] ?? '') as String,
        meterTypeId: (m['meter_type_id'] ?? 1) as int,
        number: (m['number'] ?? '') as String,
        active: ((m['active'] ?? 1) as int) == 1,
        isFavorite: ((m['is_favorite'] ?? 0) as int) == 1,
      );
}
