import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// --- Date Utils ---

String toDateStr(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

String getTodayString(String timezone) {
  // We use the device's local time for simplicity as creating a full timezone
  // aware DateTime without a large package like 'timezone' is complex.
  // We store the timezone string for reference.
  final now = DateTime.now();
  final formatter = DateFormat('yyyy-MM-dd');
  return formatter.format(now);
}

// Check if a specific date string matches today's date
bool isToday(String dateString) {
  return dateString == getTodayString('');
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

// Check if completed today using primitives to avoid circular dependency with Habit class
bool isCompletedToday(List<String> completedDates, String? timezone) {
  final today = getTodayString(timezone ?? '');
  return completedDates.contains(today);
}

// Calculate streak based on completed dates and progress
int calculateStreak(
  List<String> completedDates, {
  Map<String, int>? dailyProgress,
  int? targetReps,
  String? goalMode, // 'off' | 'repeat'
  String? goalPeriod, // 'daily', 'weekly', 'monthly'
  int? weeklyFrequency,
  List<int>? weeklyDays, // 0=Mon, 6=Sun
  DateTime? startDate,
}) {
  // 1. Collect all completed dates from both sources
  final Set<String> allCompletionDates = Set<String>.from(completedDates);

  // Consider dailyProgress for REPEAT mode ONLY if targetReps is met
  if (goalMode == 'repeat' &&
      dailyProgress != null &&
      targetReps != null &&
      targetReps > 0) {
    dailyProgress.forEach((date, reps) {
      if (reps >= targetReps) {
        allCompletionDates.add(date);
      }
    });
  }

  if (allCompletionDates.isEmpty) return 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final formatter = DateFormat('yyyy-MM-dd');

  // --- Logic for Weekly Frequency (X times per week) ---
  if (goalPeriod == 'weekly' &&
      weeklyFrequency != null &&
      weeklyFrequency > 0 &&
      (weeklyDays == null || weeklyDays.isEmpty)) {
    // Streak is "consecutive successful weeks"
    int weekStreak = 0;

    // Start from the current week
    DateTime currentMonday = today.subtract(Duration(days: today.weekday - 1));
    bool firstWeekChecked = false;

    while (true) {
      final DateTime weekStart = currentMonday;

      // Count completions in this week
      int completions = 0;
      for (int i = 0; i < 7; i++) {
        final dateToCheck = weekStart.add(Duration(days: i));
        if (allCompletionDates.contains(formatter.format(dateToCheck))) {
          completions++;
        }
      }

      bool isWeekSuccessful = completions >= weeklyFrequency;

      if (isWeekSuccessful) {
        weekStreak++;
      } else {
        // Current week (the one the user is in) doesn't break the streak yet if it's not over.
        // A streak is broken if a PREVIOUS week was failed.
        if (firstWeekChecked) {
          break; // Streak broken at previous week
        }
        // If the current week is failed, we just don't count it yet, but continue to look at previous weeks
      }

      firstWeekChecked = true;
      currentMonday = currentMonday.subtract(const Duration(days: 7));

      // Boundary: Don't check before startDate
      if (startDate != null &&
          currentMonday.add(const Duration(days: 6)).isBefore(startDate)) {
        break;
      }
    }
    return weekStreak;
  }

  // --- Logic for Specific Days or Daily ---
  // A streak is maintained if completed on the "last scheduled day" prior to today.
  // We'll iterate backwards day by day.

  int streakCount = 0;
  DateTime checkDate = today;

  // BUG-9 fix: backstop to prevent infinite loop when startDate is null.
  const maxLookbackDays = 365;
  int iterations = 0;

  while (iterations < maxLookbackDays) {
    iterations++;
    final dateStr = formatter.format(checkDate);
    final bool completed = allCompletionDates.contains(dateStr);

    // Check if this date was scheduled
    bool isScheduled = true;
    if (weeklyDays != null && weeklyDays.isNotEmpty) {
      isScheduled = weeklyDays.contains(checkDate.weekday - 1);
    }
    // Note: Other periods (monthly) can be added here if needed

    if (completed) {
      streakCount++;
    } else if (isScheduled) {
      // If it was scheduled but not completed...
      if (checkDate.isBefore(today)) {
        // ...and it's a past date, the streak is broken.
        break;
      }
      // If it's today and not completed, the streak isn't broken YET (can still complete today).
    } else {
      // If NOT scheduled, just skip this day (don't break streak, don't increment count).
    }

    checkDate = checkDate.subtract(const Duration(days: 1));

    // Boundary: Stop if we go before start date
    if (startDate != null &&
        checkDate.isBefore(
          DateTime(startDate.year, startDate.month, startDate.day),
        )) {
      break;
    }
  }

  return streakCount;
}

// Calculate historical best streak (max contiguous completions)
int calculateHistoricalBestStreak(
  List<String> completedDates, {
  Map<String, int>? dailyProgress,
  int? targetReps,
  String? goalMode, // 'off' | 'repeat'
  String? goalPeriod, // 'daily', 'weekly', 'monthly'
  int? weeklyFrequency,
  List<int>? weeklyDays, // 0=Mon, 6=Sun
  DateTime? startDate,
}) {
  // 1. Collect all completed dates from both sources
  final Set<String> allCompletionDates = Set<String>.from(completedDates);

  // Consider dailyProgress for REPEAT mode ONLY if targetReps is met
  if (goalMode == 'repeat' &&
      dailyProgress != null &&
      targetReps != null &&
      targetReps > 0) {
    dailyProgress.forEach((date, reps) {
      if (reps >= targetReps) {
        allCompletionDates.add(date);
      }
    });
  }

  if (allCompletionDates.isEmpty) return 0;
  if (startDate == null) return 0;
  // We need start date to iterate forward. If null, fallback to 0 or current logic?
  // Assuming startDate is always present for valid habits.

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final formatter = DateFormat('yyyy-MM-dd');

  // Iterate from start date to today
  // Note: For efficiency, we could just sort completion dates and find gaps,
  // but we need to account for scheduled days (skip non-scheduled).

  // --- Logic for Weekly Frequency (X times per week) ---
  if (goalPeriod == 'weekly' &&
      weeklyFrequency != null &&
      weeklyFrequency > 0 &&
      (weeklyDays == null || weeklyDays.isEmpty)) {
    // Start from the Monday of the start week
    DateTime currentMonday = start.subtract(Duration(days: start.weekday - 1));
    int weekStreak = 0;
    int maxWeekStreak = 0;

    while (!currentMonday.isAfter(today)) {
      int completions = 0;
      final DateTime weekStart = currentMonday;

      for (int i = 0; i < 7; i++) {
        final dateToCheck = weekStart.add(Duration(days: i));
        if (allCompletionDates.contains(formatter.format(dateToCheck))) {
          completions++;
        }
      }

      bool isWeekSuccessful = completions >= weeklyFrequency;

      if (isWeekSuccessful) {
        weekStreak++;
      } else {
        // If the week is in the past, a failure breaks the streak.
        // If it's the current week, it doesn't break yet, but doesn't add to count.
        final sundayOfThisWeek = currentMonday.add(const Duration(days: 6));
        if (sundayOfThisWeek.isBefore(today)) {
          weekStreak = 0;
        }
      }

      if (weekStreak > maxWeekStreak) {
        maxWeekStreak = weekStreak;
      }

      currentMonday = currentMonday.add(const Duration(days: 7));
    }
    return maxWeekStreak;
  }

  // --- Logic for Daily or Specific Days ---
  int maxStreak = 0;
  int currentRun = 0;

  DateTime loopDate = start;
  while (!loopDate.isAfter(today)) {
    final dateStr = formatter.format(loopDate);
    final bool completed = allCompletionDates.contains(dateStr);

    // Check if this date was scheduled
    bool isScheduled = true;
    if (weeklyDays != null && weeklyDays.isNotEmpty) {
      isScheduled = weeklyDays.contains(loopDate.weekday - 1);
    }

    if (completed) {
      currentRun++;
    } else if (isScheduled) {
      // Not completed AND scheduled -> Break streak
      currentRun = 0;
    } else {
      // Not scheduled -> Maintain streak
    }

    if (currentRun > maxStreak) {
      maxStreak = currentRun;
    }

    loopDate = loopDate.add(const Duration(days: 1));
  }

  return maxStreak;
}

// Count completions in the week of a specific date
int countWeeklyCompletions({
  required DateTime date,
  required List<String> completedDates,
  required Map<String, int> dailyProgress,
  required String goalMode,
  required int targetReps,
}) {
  // Monday = 1, Sunday = 7
  final currentWeekday = date.weekday;
  // Start of week (Monday 00:00:00)
  final startOfWeek = DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: currentWeekday - 1));

  // End of week (Sunday 23:59:59.999)
  final endOfWeek = startOfWeek.add(
    const Duration(
      days: 6,
      hours: 23,
      minutes: 59,
      seconds: 59,
      milliseconds: 999,
    ),
  );

  // We collect all unique completion dates in this week
  final Set<String> uniqueCompletionDates = {};

  // 1. Check completedDates (explicit completions)
  for (final dateStr in completedDates) {
    try {
      final completedDate = DateTime.parse(dateStr);
      if (!completedDate.isBefore(startOfWeek) &&
          !completedDate.isAfter(endOfWeek)) {
        uniqueCompletionDates.add(dateStr);
      }
    } catch (_) {}
  }

  // 2. Check dailyProgress (for repeat mode habits)
  if (goalMode == 'repeat') {
    dailyProgress.forEach((dateStr, reps) {
      if (reps >= targetReps) {
        try {
          final progressDate = DateTime.parse(dateStr);
          if (!progressDate.isBefore(startOfWeek) &&
              !progressDate.isAfter(endOfWeek)) {
            uniqueCompletionDates.add(dateStr);
          }
        } catch (_) {}
      }
    });
  }

  return uniqueCompletionDates.length;
}

// Filter habits for a specific date
List<T> getHabitsForDate<T>(List<T> allHabits, DateTime selectedDate) {
  return allHabits.where((habit) {
    // Access habit properties via dynamic to avoid import cycle
    final dynamic h = habit;

    // Check start/end dates
    final startDate = h.startDate as DateTime?;
    final endDate = h.endDate as DateTime?;

    if (startDate != null &&
        selectedDate.isBefore(
          DateTime(startDate.year, startDate.month, startDate.day),
        )) {
      return false;
    }

    if (endDate != null &&
        selectedDate.isAfter(
          DateTime(endDate.year, endDate.month, endDate.day),
        )) {
      return false;
    }

    // Get goal period
    final goalPeriod = h.goalPeriod?.toString() ?? '';

    // Daily habits - always show if active
    if (goalPeriod.contains('daily')) {
      return true;
    }

    // Weekly habits
    if (goalPeriod.contains('weekly')) {
      final weeklyDays = h.weeklyDays as List<int>? ?? [];
      final weeklyFrequency = h.weeklyFrequency as int? ?? 0;

      // Specific days mode
      if (weeklyDays.isNotEmpty) {
        final selectedWeekday = selectedDate.weekday - 1; // 0=Mon, 6=Sun
        return weeklyDays.contains(selectedWeekday);
      }

      // Frequency mode
      if (weeklyFrequency > 0) {
        // ALWAYS show weekly frequency habits, regardless of completion status.
        // The UI will handle displaying "Finished this week" if the target is met.
        return true;
      }
    }

    // Default: show habit
    return true;
  }).toList();
}

// --- Color Utils ---

// Hex String to Color
Color hexToColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

// Color to Hex String
String colorToHex(Color color) {
  return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}

// --- Icon Utils ---

final Map<String, IconData> _iconMap = {
  'business_center_rounded': Icons.business_center_rounded,
  'bolt_rounded': Icons.bolt_rounded,
  'person_rounded': Icons.person_rounded,
  'account_balance_wallet_rounded': Icons.account_balance_wallet_rounded,
  'restaurant_rounded': Icons.restaurant_rounded,
  'headphones_rounded': Icons.headphones_rounded,
  'directions_run_rounded': Icons.directions_run_rounded,
  'menu_book_rounded': Icons.menu_book_rounded,
  'lock_rounded': Icons.lock_rounded,
  'iron_rounded': Icons.iron_rounded,
  'local_fire_department_rounded': Icons.local_fire_department_rounded,
  'eco_rounded': Icons.eco_rounded,
  // Add defaults/fallbacks
  'fitness_center': Icons.fitness_center,
  'help_outline': Icons.help_outline,
};

IconData iconNameToIconData(String iconName) {
  return _iconMap[iconName] ?? Icons.help_outline;
}

String iconDataToName(IconData icon) {
  // Reverse lookup (inefficient but safe for small map)
  for (var entry in _iconMap.entries) {
    if (entry.value.codePoint == icon.codePoint) {
      return entry.key;
    }
  }
  return 'help_outline';
}
