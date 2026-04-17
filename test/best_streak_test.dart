import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/habit_details.dart';
import 'package:habit_tracker/utils/habit_utils.dart' as utils;

void main() {
  group('Best Streak Reproduction', () {
    test(
      'Best Streak should track historical max, not just current streak',
      () {
        final today = DateTime.now();

        // Habit started 10 days ago
        // Completed for 4 days (days 10, 9, 8, 7 ago)
        // Missed for 1 day (day 6 ago)
        // Completed for 2 days (days 5, 4 ago)
        // Missed for rest

        final startDate = today.subtract(Duration(days: 10));
        final completedDates = [
          utils.toDateStr(today.subtract(Duration(days: 10))),
          utils.toDateStr(today.subtract(Duration(days: 9))),
          utils.toDateStr(today.subtract(Duration(days: 8))),
          utils.toDateStr(today.subtract(Duration(days: 7))),
          // Missed day 6
          utils.toDateStr(today.subtract(Duration(days: 5))),
          utils.toDateStr(today.subtract(Duration(days: 4))),
        ];

        final habit = Habit(
          id: '1',
          title: 'Test Habit',
          iconName: 'run',
          colorHex: '#000000',
          goalType: GoalType.cultivate,
          goalPeriod: GoalPeriod.daily,
          startDate: startDate,
          reminderEnabled: false,
          reminderTimes: [],
          completedDates: completedDates,
        );

        // Current behavior: streak is 0 (since it was missed recently)
        final currentStreak = habit.streak;
        expect(
          currentStreak,
          0,
          reason: "Current streak should be 0 as recent days are missed",
        );

        // Expected behavior: best streak should be 4 (the first run)
        final bestStreak = habit.bestStreak;
        expect(
          bestStreak,
          4,
          reason: "Best streak should be the max historical run (4)",
        );
      },
    );

    test('Best Streak for Weekly Frequency should track weeks', () {
      final today = DateTime.now();
      // Start 4 weeks ago
      final start = today.subtract(Duration(days: 28));

      // Monday of each week
      final week1Mon = start.subtract(Duration(days: start.weekday - 1));
      final week2Mon = week1Mon.add(Duration(days: 7));
      final week3Mon = week2Mon.add(Duration(days: 7)); // Failed week
      final week4Mon = week3Mon.add(Duration(days: 7));

      final completedDates = [
        // Week 1: 3 completions
        utils.toDateStr(week1Mon),
        utils.toDateStr(week1Mon.add(Duration(days: 1))),
        utils.toDateStr(week1Mon.add(Duration(days: 2))),
        // Week 2: 3 completions
        utils.toDateStr(week2Mon),
        utils.toDateStr(week2Mon.add(Duration(days: 1))),
        utils.toDateStr(week2Mon.add(Duration(days: 2))),
        // Week 3: 1 completion (Failed)
        utils.toDateStr(week3Mon),
        // Week 4: 3 completions
        utils.toDateStr(week4Mon),
        utils.toDateStr(week4Mon.add(Duration(days: 1))),
        utils.toDateStr(week4Mon.add(Duration(days: 2))),
      ];

      final habit = Habit(
        id: 'w1',
        title: 'Weekly Habit',
        iconName: 'run',
        colorHex: '#000000',
        goalType: GoalType.cultivate,
        goalPeriod: GoalPeriod.weekly,
        weeklyFrequency: 3,
        startDate: start,
        reminderEnabled: false,
        reminderTimes: [],
        completedDates: completedDates,
      );

      // Best streak should be 2 (Week 1 & 2)
      // Week 4 is also successful but it's a new run of 1.
      expect(
        habit.bestStreak,
        2,
        reason: "Best weekly streak should be 2 weeks",
      );
    });
  });
}
