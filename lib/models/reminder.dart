enum RepeatPlan { none, weekly, monthly, yearly }

class Reminder {
  final int? id;
  final int meterId;
  final String baseDate;
  final RepeatPlan repeat;
  final int? notificationId;

  Reminder({
    this.id,
    required this.meterId,
    required this.baseDate,
    required this.repeat,
    this.notificationId,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'meter_id': meterId,
        'base_date': baseDate,
        'repeat': repeat.toString().split('.').last,
        'notification_id': notificationId,
      };

  static Reminder fromMap(Map<String, Object?> m) {
    final repStr = (m['repeat'] as String);
    RepeatPlan rep;
    switch (repStr) {
      case 'weekly': rep = RepeatPlan.weekly; break;
      case 'monthly': rep = RepeatPlan.monthly; break;
      case 'yearly': rep = RepeatPlan.yearly; break;
      default: rep = RepeatPlan.none;
    }
    return Reminder(
      id: m['id'] as int?,
      meterId: m['meter_id'] as int,
      baseDate: m['base_date'] as String,
      repeat: rep,
      notificationId: m['notification_id'] as int?,
    );
  }
}