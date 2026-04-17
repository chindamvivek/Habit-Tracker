/// Model representing a single day in an AI-generated 30-day habit plan.
/// Stored in Firestore at habits/{habitId}/plan/{day}.
class HabitPlanDay {
  final int day;
  final int durationMinutes;
  final String taskDescription;
  final String tip;

  /// 'timer' | 'pedometer' | 'self_report'
  final String validationType;

  /// Only set when validationType == 'pedometer'.
  final int? stepTarget;

  /// Whether this day has been completed by the user.
  final bool isCompleted;

  const HabitPlanDay({
    required this.day,
    required this.durationMinutes,
    required this.taskDescription,
    required this.tip,
    required this.validationType,
    this.stepTarget,
    this.isCompleted = false,
  });

  factory HabitPlanDay.fromMap(Map<String, dynamic> map) {
    return HabitPlanDay(
      day: (map['day'] as num).toInt(),
      durationMinutes: (map['durationMinutes'] as num).toInt(),
      taskDescription: map['taskDescription'] as String? ?? '',
      tip: map['tip'] as String? ?? '',
      validationType: map['validationType'] as String? ?? 'self_report',
      stepTarget: map['stepTarget'] != null
          ? (map['stepTarget'] as num).toInt()
          : null,
      isCompleted: map['completedAt'] != null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'durationMinutes': durationMinutes,
      'taskDescription': taskDescription,
      'tip': tip,
      'validationType': validationType,
      'stepTarget': stepTarget,
      'completedAt': null,
    };
  }
}
