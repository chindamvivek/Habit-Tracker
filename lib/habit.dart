import 'package:flutter/material.dart';
import 'package:habit_tracker/utils/habit_utils.dart' as utils;
import 'habit_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  final String id;
  String iconName; // e.g., "directions_run"
  String title;
  String colorHex; // e.g., "#FF5733"

  GoalType goalType;
  GoalPeriod goalPeriod;

  // Simplified Goal System
  String goalMode; // 'off' | 'repeat'
  int targetReps; // 1-50

  DateTime startDate;
  DateTime? endDate;

  bool reminderEnabled;
  List<TimeOfDay> reminderTimes;

  // New completion fields
  DateTime? lastCompletedDate;
  List<String> completedDates; // "YYYY-MM-DD"
  Map<String, int> dailyProgress; // "YYYY-MM-DD" -> count
  String timezone; // "Asia/Kolkata"

  int get streak => utils.calculateStreak(
    completedDates,
    dailyProgress: dailyProgress,
    targetReps: targetReps,
    goalMode: goalMode,
    goalPeriod: goalPeriod.name,
    weeklyFrequency: weeklyFrequency,
    weeklyDays: weeklyDays,
    startDate: startDate,
  );

  int get bestStreak => utils.calculateHistoricalBestStreak(
    completedDates,
    dailyProgress: dailyProgress,
    targetReps: targetReps,
    goalMode: goalMode,
    goalPeriod: goalPeriod.name,
    weeklyFrequency: weeklyFrequency,
    weeklyDays: weeklyDays,
    startDate: startDate,
  );

  // Weekly Habit Fields
  List<int> weeklyDays; // 0=Mon, 6=Sun
  int weeklyFrequency; // e.g., 3 times a week

  Habit({
    String? id,
    required this.iconName,
    required this.title,
    required this.colorHex,
    required this.goalType,
    required this.goalPeriod,
    this.goalMode = 'off',
    this.targetReps = 1,
    required this.startDate,
    this.endDate,
    required this.reminderEnabled,
    required this.reminderTimes,
    this.lastCompletedDate,
    this.completedDates = const [],
    this.dailyProgress = const {},
    this.timezone = '',
    this.weeklyDays = const [],
    this.weeklyFrequency = 0,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // Helper getters
  IconData get icon => utils.iconNameToIconData(iconName);
  Color get color => utils.hexToColor(colorHex);

  bool get isCompletedToday => isCompletedOnDate(DateTime.now());

  bool isCompletedOnDate(DateTime date) {
    final dateStr = utils.toDateStr(date);
    if (goalMode == 'repeat') {
      final reps = dailyProgress[dateStr] ?? 0;
      return reps >= targetReps;
    }
    return completedDates.contains(dateStr);
  }

  int getRepsOnDate(DateTime date) {
    final dateStr = utils.toDateStr(date);
    if (isCompletedOnDate(date)) return targetReps;
    return dailyProgress[dateStr] ?? 0;
  }

  /// Validates whether this habit can be completed on the given date.
  /// Returns a result object with validation status and optional error message.
  CompletionValidationResult canCompleteOnDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    // Check 1: Cannot complete future dates
    if (dateOnly.isAfter(today)) {
      return CompletionValidationResult.failure(
        'Cannot complete habits on future dates',
      );
    }

    // Check 2: Habit must be active on this date
    if (!isActiveOnDate(date)) {
      return CompletionValidationResult.failure(
        'This habit was not active on this date.',
      );
    }

    // Check 3: Habit must be scheduled for this date
    if (!isScheduledForDate(date)) {
      return CompletionValidationResult.failure(
        'This habit was not scheduled for this date.',
      );
    }

    // Check 4: For weekly frequency, prevent over-completion
    if (goalPeriod == GoalPeriod.weekly &&
        weeklyFrequency > 0 &&
        !isCompletedOnDate(date)) {
      final currentCompletions = completionsInWeekOf(date);
      if (currentCompletions >= weeklyFrequency) {
        return CompletionValidationResult.failure(
          'Weekly target already met ($currentCompletions/$weeklyFrequency)',
        );
      }
    }

    return CompletionValidationResult.success();
  }

  bool isActiveOnDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (d.isBefore(start)) return false;

    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (d.isAfter(end)) return false;
    }
    return true;
  }

  // Helper to check if habit is expired
  bool get isExpired {
    if (endDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return today.isAfter(end);
  }

  // Helper to check if habit has started
  bool get hasStarted {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return !today.isBefore(start);
  }

  // Date-aware status methods
  bool hasStartedOnDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return !d.isBefore(start);
  }

  bool isExpiredOnDate(DateTime date) {
    if (endDate == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return d.isAfter(end);
  }

  // Helper to check if habit is currently active (started and not expired)
  bool get isActive {
    if (endDate == null) return hasStarted;
    return hasStarted && !isExpired;
  }

  // Helper to get time string for display
  String get timeString {
    if (reminderTimes.isEmpty) return "Anytime";
    final time = reminderTimes.first;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  // Copy with method
  Habit copyWith({
    String? iconName,
    String? title,
    String? colorHex,
    GoalType? goalType,
    GoalPeriod? goalPeriod,
    String? goalMode,
    int? targetReps,
    DateTime? startDate,
    DateTime? endDate,
    bool? reminderEnabled,
    List<TimeOfDay>? reminderTimes,
    DateTime? lastCompletedDate,
    List<String>? completedDates,
    Map<String, int>? dailyProgress,
    String? timezone,
    List<int>? weeklyDays,
    int? weeklyFrequency,
  }) {
    return Habit(
      id: id,
      iconName: iconName ?? this.iconName,
      title: title ?? this.title,
      colorHex: colorHex ?? this.colorHex,
      goalType: goalType ?? this.goalType,
      goalPeriod: goalPeriod ?? this.goalPeriod,
      goalMode: goalMode ?? this.goalMode,
      targetReps: targetReps ?? this.targetReps,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      completedDates: completedDates ?? this.completedDates,
      dailyProgress: dailyProgress ?? this.dailyProgress,
      timezone: timezone ?? this.timezone,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      weeklyFrequency: weeklyFrequency ?? this.weeklyFrequency,
    );
  }

  // Create from HabitDetails
  factory Habit.fromDetails(HabitDetails details) {
    // Default timezone handling
    final timezone = DateTime.now().timeZoneName;

    return Habit(
      iconName: utils.iconDataToName(details.icon),
      title: details.title,
      colorHex: utils.colorToHex(details.color),
      goalType: details.goalType,
      goalPeriod: details.goalPeriod,
      goalMode: details.goalMode,
      targetReps: details.targetReps,
      startDate: details.startDate,
      endDate: details.endDate,
      reminderEnabled: details.reminderEnabled,
      reminderTimes: details.reminderTimes,
      timezone: timezone,
      completedDates: [],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'iconName': iconName,
      'colorHex': colorHex,
      'goalType': goalType.name,
      'goalPeriod': goalPeriod.name,
      'goalMode': goalMode,
      'targetReps': targetReps,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'reminderEnabled': reminderEnabled,
      'reminderTimes': reminderTimes
          .map((t) => '${t.hour}:${t.minute}')
          .toList(),
      'lastCompletedDate': lastCompletedDate != null
          ? Timestamp.fromDate(lastCompletedDate!)
          : null,
      'completedDates': completedDates,
      'dailyProgress': dailyProgress,
      'timezone': timezone,
      'streak': streak,
      'weeklyDays': weeklyDays,
      'weeklyFrequency': weeklyFrequency,
    };
  }

  bool get isScheduledForToday => isScheduledForDate(DateTime.now());

  bool isScheduledForDate(DateTime date) {
    if (!isActiveOnDate(date)) return false;

    // Daily and Monthly are always "scheduled" if active
    if (goalPeriod == GoalPeriod.daily || goalPeriod == GoalPeriod.monthly) {
      return true;
    }

    if (goalPeriod == GoalPeriod.weekly) {
      // Specific days mode
      if (weeklyDays.isNotEmpty) {
        // weekday returns 1 for Monday, 7 for Sunday
        // our list stores 0 for Monday, 6 for Sunday
        final dayIndex = date.weekday - 1;
        return weeklyDays.contains(dayIndex);
      }

      // Frequency mode (X days per week)
      if (weeklyFrequency > 0) {
        // Always return true to allow habit to be displayed all week
        // The UI will handle showing "finished" state when target is met
        return true;
      }
    }

    return true; // Default fallback
  }

  int completionsInWeekOf(DateTime date) {
    return utils.countWeeklyCompletions(
      date: date,
      completedDates: completedDates,
      dailyProgress: dailyProgress,
      goalMode: goalMode,
      targetReps: targetReps,
    );
  }

  int get completionsThisWeek => completionsInWeekOf(DateTime.now());

  String? getWeeklyProgressTextFor(DateTime date) {
    if (goalPeriod == GoalPeriod.weekly && weeklyFrequency > 0) {
      final count = completionsInWeekOf(date);
      return "$count/$weeklyFrequency this week";
    }
    return null;
  }

  // Create from Map (Firestore)
  factory Habit.fromMap(Map<String, dynamic> map, String id) {
    // Migration logic for old fields
    int migrationTargetReps = map['targetReps'] ?? map['goalValue'] ?? 1;
    String migrationGoalMode =
        map['goalMode'] ?? (migrationTargetReps > 1 ? 'repeat' : 'off');

    return Habit(
      id: id,
      title: map['title'] ?? '',
      iconName: map['iconName'] ?? 'help_outline',
      colorHex: map['colorHex'] ?? '#FFC107',
      goalType: GoalType.values.firstWhere(
        (e) => e.name == map['goalType'],
        orElse: () => GoalType.cultivate,
      ),
      goalPeriod: GoalPeriod.values.firstWhere(
        (e) => e.name == map['goalPeriod'],
        orElse: () => GoalPeriod.daily,
      ),
      goalMode: migrationGoalMode,
      targetReps: migrationTargetReps,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      reminderEnabled: map['reminderEnabled'] ?? false,
      reminderTimes:
          (map['reminderTimes'] as List<dynamic>?)?.map((t) {
            final parts = t.toString().split(':');
            return TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }).toList() ??
          [],
      lastCompletedDate: (map['lastCompletedDate'] as Timestamp?)?.toDate(),
      completedDates:
          (map['completedDates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dailyProgress:
          (map['dailyProgress'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), v as int),
          ) ??
          {},
      timezone: map['timezone'] ?? '',
      weeklyDays: List<int>.from(map['weeklyDays'] ?? []),
      weeklyFrequency: map['weeklyFrequency'] ?? 0,
    );
  }
}

/// Result of habit completion validation
class CompletionValidationResult {
  final bool canComplete;
  final String? errorMessage;

  CompletionValidationResult({required this.canComplete, this.errorMessage});

  factory CompletionValidationResult.success() =>
      CompletionValidationResult(canComplete: true);

  factory CompletionValidationResult.failure(String message) =>
      CompletionValidationResult(canComplete: false, errorMessage: message);
}
