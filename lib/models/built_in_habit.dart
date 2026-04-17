// Model classes for Built-in Habits feature.
// These are completely separate from the existing Habit model.

/// Represents a single day entry in the 30-day plan.
class ThirtyDayPlanEntry {
  final int day;
  final int durationMinutes;
  final String taskDescription;
  final String tip;

  const ThirtyDayPlanEntry({
    required this.day,
    required this.durationMinutes,
    required this.taskDescription,
    required this.tip,
  });

  factory ThirtyDayPlanEntry.fromMap(Map<String, dynamic> map) {
    return ThirtyDayPlanEntry(
      day: (map['day'] as num).toInt(),
      durationMinutes: (map['durationMinutes'] as num).toInt(),
      taskDescription: map['taskDescription'] as String? ?? '',
      tip: map['tip'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'durationMinutes': durationMinutes,
      'taskDescription': taskDescription,
      'tip': tip,
    };
  }
}

/// Represents a built-in habit as stored in the top-level `builtInHabits`
/// Firestore collection.
class BuiltInHabit {
  final String id;
  final String name;
  final String description;
  final String category;
  final String iconName;

  /// Either 'timer' (for Meditation / Yoga) or 'stepCounter' (for Walking / Running).
  final String validationType;

  final int defaultDurationMinutes;
  final List<ThirtyDayPlanEntry> thirtyDayPlan;

  const BuiltInHabit({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.iconName,
    required this.validationType,
    required this.defaultDurationMinutes,
    required this.thirtyDayPlan,
  });

  factory BuiltInHabit.fromMap(Map<String, dynamic> map, String id) {
    final rawPlan = map['thirtyDayPlan'] as List<dynamic>? ?? [];
    final plan = rawPlan
        .map(
          (e) =>
              ThirtyDayPlanEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return BuiltInHabit(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'star',
      validationType: map['validationType'] as String? ?? 'timer',
      defaultDurationMinutes:
          (map['defaultDurationMinutes'] as num?)?.toInt() ?? 10,
      thirtyDayPlan: plan,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'iconName': iconName,
      'validationType': validationType,
      'defaultDurationMinutes': defaultDurationMinutes,
      'thirtyDayPlan': thirtyDayPlan.map((e) => e.toMap()).toList(),
    };
  }
}

/// Represents a user's selected built-in habit, stored at
/// `users/{userId}/myBuiltInHabits/{habitId}`.
class MyBuiltInHabit {
  final String id; // Same as the BuiltInHabit document ID.
  final String name;
  final String validationType;
  final int defaultDurationMinutes;
  final int currentStreak;
  final DateTime? lastCompletedDate;

  /// A list of completion records, each being a "YYYY-MM-DD" string.
  final List<String> completionHistory;

  const MyBuiltInHabit({
    required this.id,
    required this.name,
    required this.validationType,
    required this.defaultDurationMinutes,
    this.currentStreak = 0,
    this.lastCompletedDate,
    this.completionHistory = const [],
  });

  factory MyBuiltInHabit.fromMap(Map<String, dynamic> map, String id) {
    DateTime? lastCompleted;
    final raw = map['lastCompletedDate'];
    if (raw != null) {
      // Firestore Timestamp comes in as a Map with _seconds/_nanoseconds when
      // accessed via fromMap; handle both Timestamp and plain String.
      try {
        // Works when using cloud_firestore Timestamp type directly.
        lastCompleted = (raw as dynamic).toDate() as DateTime?;
      } catch (_) {
        lastCompleted = null;
      }
    }

    return MyBuiltInHabit(
      id: id,
      name: map['name'] as String? ?? '',
      validationType: map['validationType'] as String? ?? 'timer',
      defaultDurationMinutes:
          (map['defaultDurationMinutes'] as num?)?.toInt() ?? 10,
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      lastCompletedDate: lastCompleted,
      completionHistory:
          (map['completionHistory'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'validationType': validationType,
      'defaultDurationMinutes': defaultDurationMinutes,
      'currentStreak': currentStreak,
      'completionHistory': completionHistory,
    };
  }

  MyBuiltInHabit copyWith({
    int? currentStreak,
    DateTime? lastCompletedDate,
    List<String>? completionHistory,
  }) {
    return MyBuiltInHabit(
      id: id,
      name: name,
      validationType: validationType,
      defaultDurationMinutes: defaultDurationMinutes,
      currentStreak: currentStreak ?? this.currentStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      completionHistory: completionHistory ?? this.completionHistory,
    );
  }
}
