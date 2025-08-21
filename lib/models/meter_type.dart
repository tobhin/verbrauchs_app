class MeterType {
  final int? id;
  final String name;
  final String iconName;
  final bool isDefault;

  const MeterType({
    this.id,
    required this.name,
    required this.iconName,
    this.isDefault = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'icon_name': iconName,
        'is_default': isDefault ? 1 : 0,
      };

  static MeterType fromMap(Map<String, Object?> m) => MeterType(
        id: m['id'] as int?,
        name: (m['name'] ?? '') as String,
        iconName: (m['icon_name'] ?? 'question_mark') as String,
        isDefault: ((m['is_default'] ?? 0) as int) == 1,
      );
}
