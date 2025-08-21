class Reading {
  final int? id;
  final int meterId;
  final DateTime date;
  final double? value;
  final double? ht;
  final double? nt;
  final String? imagePath;
  final int? tariffId;

  const Reading({
    this.id,
    required this.meterId,
    required this.date,
    this.value,
    this.ht,
    this.nt,
    this.imagePath,
    this.tariffId,
  });

  Reading copyWith({
    int? id,
    int? meterId,
    DateTime? date,
    double? value,
    double? ht,
    double? nt,
    String? imagePath,
    int? tariffId,
  }) {
    return Reading(
      id: id ?? this.id,
      meterId: meterId ?? this.meterId,
      date: date ?? this.date,
      value: value ?? this.value,
      ht: ht ?? this.ht,
      nt: nt ?? this.nt,
      imagePath: imagePath ?? this.imagePath,
      tariffId: tariffId ?? this.tariffId,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'meter_id': meterId,
        'date': date.toIso8601String(),
        'value': value,
        'ht': ht,
        'nt': nt,
        'image_path': imagePath,
        'tariff_id': tariffId,
      };

  static Reading fromMap(Map<String, Object?> m) => Reading(
        id: m['id'] as int?,
        meterId: m['meter_id'] as int,
        date: DateTime.parse(m['date'] as String),
        value: m['value'] as double?,
        ht: m['ht'] as double?,
        nt: m['nt'] as double?,
        imagePath: m['image_path'] as String?,
        tariffId: m['tariff_id'] as int?,
      );
}
