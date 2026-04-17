import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/habit_details.dart';
import 'package:habit_tracker/utils/habit_utils.dart' as utils;

class WeeklyChartResult {
  final Map<int, int> data;
  final Map<int, bool> isFuture;

  WeeklyChartResult({required this.data, required this.isFuture});
}

class AnalyticsService {
  /// Get total completed habits count for a specific week
  /// [weekStart] should be a Monday
  /// Weekly frequency habits are counted once per week if target is met
  /// This represents "successful habits" not individual completion events
  static int getCompletedCountForWeek(List<Habit> habits, DateTime weekStart) {
    int totalCompletions = 0;
    final Set<String> countedWeeklyHabits = {};

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final habitsForDate = utils.getHabitsForDate(habits, date);

      for (final habit in habitsForDate) {
        // For weekly frequency habits, count once per week if target met
        if (habit.goalPeriod == GoalPeriod.weekly &&
            habit.weeklyFrequency > 0) {
          if (!countedWeeklyHabits.contains(habit.id)) {
            final weeklyCompletions = habit.completionsInWeekOf(date);
            if (weeklyCompletions >= habit.weeklyFrequency) {
              totalCompletions++;
              countedWeeklyHabits.add(habit.id);
            }
          }
        } else {
          // For daily habits, count each completion
          if (habit.isCompletedOnDate(date)) {
            totalCompletions++;
          }
        }
      }
    }

    return totalCompletions;
  }

  /// Get total completed habits count for a specific month
  /// Weekly frequency habits are counted once per week if target is met
  /// This represents "successful habits" not individual completion events
  static int getCompletedCountForMonth(List<Habit> habits, DateTime month) {
    int totalCompletions = 0;
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final Set<String> countedWeeklyHabits = {};

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(month.year, month.month, day);
      final habitsForDate = utils.getHabitsForDate(habits, date);

      // Reset weekly habit tracking at the start of each week (Monday)
      if (date.weekday == 1) {
        countedWeeklyHabits.clear();
      }

      for (final habit in habitsForDate) {
        // For weekly frequency habits, count once per week if target met
        if (habit.goalPeriod == GoalPeriod.weekly &&
            habit.weeklyFrequency > 0) {
          if (!countedWeeklyHabits.contains(habit.id)) {
            final weeklyCompletions = habit.completionsInWeekOf(date);
            if (weeklyCompletions >= habit.weeklyFrequency) {
              totalCompletions++;
              countedWeeklyHabits.add(habit.id);
            }
          }
        } else {
          // For daily habits, count each completion
          if (habit.isCompletedOnDate(date)) {
            totalCompletions++;
          }
        }
      }
    }

    return totalCompletions;
  }

  /// Get the best (longest) current streak among all habits
  static int getBestStreak(List<Habit> habits) {
    if (habits.isEmpty) return 0;

    int maxStreak = 0;
    for (final habit in habits) {
      if (habit.bestStreak > maxStreak) {
        maxStreak = habit.bestStreak;
      }
    }

    return maxStreak;
  }

  /// Get completion data for weekly chart
  /// Returns WeeklyChartResult with data and future flags
  /// Weekly frequency habits show a bar for each day they were completed
  static WeeklyChartResult getWeeklyChartData(
    List<Habit> habits,
    DateTime weekStart,
  ) {
    final Map<int, int> data = {};
    final Map<int, bool> isFuture = {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      isFuture[i] = dateOnly.isAfter(today);

      final habitsForDate = utils.getHabitsForDate(habits, date);

      int completions = 0;
      for (final habit in habitsForDate) {
        // For weekly frequency habits, count each day's completion
        if (habit.goalPeriod == GoalPeriod.weekly &&
            habit.weeklyFrequency > 0) {
          // Count this day's completion
          if (habit.isCompletedOnDate(date)) {
            completions++;
          }
        } else {
          // For daily habits, count each completion
          if (habit.isCompletedOnDate(date)) {
            completions++;
          }
        }
      }

      data[i] = completions;
    }

    return WeeklyChartResult(data: data, isFuture: isFuture);
  }

  /// Get completion data for monthly chart
  /// Returns Map with week index -> completion count
  /// Uses iterative grouping to ensure Monday-start calendar alignment
  /// Weekly frequency habits show in the count for each day they were completed
  static Map<int, int> getMonthlyChartData(List<Habit> habits, DateTime month) {
    final Map<int, int> chartData = {};
    final lastDay = DateTime(month.year, month.month + 1, 0);

    int weekIndex = 0;

    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(month.year, month.month, day);

      // Increment week index whenever we hit a Monday (except the first day)
      if (day > 1 && date.weekday == DateTime.monday) {
        weekIndex++;
      }

      // Initialize week data if not exists
      chartData[weekIndex] = chartData[weekIndex] ?? 0;

      final habitsForDate = utils.getHabitsForDate(habits, date);

      for (final habit in habitsForDate) {
        // For weekly frequency habits, count each day's completion
        if (habit.goalPeriod == GoalPeriod.weekly &&
            habit.weeklyFrequency > 0) {
          // Count this day's completion
          if (habit.isCompletedOnDate(date)) {
            chartData[weekIndex] = chartData[weekIndex]! + 1;
          }
        } else {
          // For daily habits, count each completion
          if (habit.isCompletedOnDate(date)) {
            chartData[weekIndex] = chartData[weekIndex]! + 1;
          }
        }
      }
    }

    return chartData;
  }

  /// Check if a specific day had 100% completion (perfect day)
  /// Returns false for future dates
  static bool isPerfectDay(List<Habit> habits, DateTime date) {
    // Don't evaluate future dates
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isAfter(today)) {
      return false;
    }

    final habitsForDate = utils.getHabitsForDate(habits, date);

    if (habitsForDate.isEmpty) return false;

    for (final habit in habitsForDate) {
      if (!habit.isCompletedOnDate(date)) {
        return false;
      }
    }

    return true;
  }

  /// Get the current week's Monday
  static DateTime getCurrentWeekStart() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon, 7=Sun
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: weekday - 1));
  }

  /// Get the current month
  static DateTime getCurrentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Get the completion ratio for a specific date (0.0 to 1.0)
  /// Returns 0.0 for future dates or if no habits exist
  static double getCompletionRatio(List<Habit> habits, DateTime date) {
    // Don't evaluate future dates
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isAfter(today)) {
      return 0.0;
    }

    final habitsForDate = utils.getHabitsForDate(habits, date);

    if (habitsForDate.isEmpty) return 0.0;

    int completedCount = 0;
    for (final habit in habitsForDate) {
      if (habit.isCompletedOnDate(date)) {
        completedCount++;
      }
    }

    return completedCount / habitsForDate.length;
  }
}
