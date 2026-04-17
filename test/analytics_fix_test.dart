import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/habit_details.dart';
import 'package:habit_tracker/services/analytics_service.dart';
import 'package:habit_tracker/utils/habit_utils.dart' as utils;

void main() {
  group('Analytics Fixes Verification', () {
    test('Best Streak should be 0 if no active habits have streaks', () {
      final habit1 = Habit(
        id: '1',
        title: 'Archived Habit',
        iconName: 'run',
        colorHex: '#000000',
        goalType: GoalType.cultivate,
        goalPeriod: GoalPeriod.daily,
        startDate: DateTime.now().subtract(Duration(days: 10)),
        endDate: DateTime.now().subtract(Duration(days: 1)), // Expired
        reminderEnabled: false,
        reminderTimes: [],
        completedDates: [
          utils.toDateStr(DateTime.now().subtract(Duration(days: 2))),
          utils.toDateStr(DateTime.now().subtract(Duration(days: 3))),
        ],
      );

      final habit2 = Habit(
        id: '2',
        title: 'Active Habit',
        iconName: 'walk',
        colorHex: '#000000',
        goalType: GoalType.cultivate,
        goalPeriod: GoalPeriod.daily,
        startDate: DateTime.now().subtract(Duration(days: 5)),
        reminderEnabled: false,
        reminderTimes: [],
        completedDates: [], // No streak
      );

      // Simulate filtering in UI
      final activeHabits = [habit1, habit2].where((h) => h.isActive).toList();

      // habit1 is not active, habit2 has 0 streak
      expect(activeHabits.length, 1);
      expect(activeHabits.first.id, '2');
      expect(AnalyticsService.getBestStreak(activeHabits), 0);
    });

    test('Completion Ratio should be correct', () {
      final date = DateTime.now();
      final dateStr = utils.toDateStr(date);

      final habit1 = Habit(
        id: '1',
        title: 'Habit 1',
        iconName: 'run',
        colorHex: '#000000',
        goalType: GoalType.cultivate,
        goalPeriod: GoalPeriod.daily,
        startDate: date.subtract(Duration(days: 1)),
        reminderEnabled: false,
        reminderTimes: [],
        completedDates: [dateStr],
      );

      final habit2 = Habit(
        id: '2',
        title: 'Habit 2',
        iconName: 'walk',
        colorHex: '#000000',
        goalType: GoalType.cultivate,
        goalPeriod: GoalPeriod.daily,
        startDate: date.subtract(Duration(days: 1)),
        reminderEnabled: false,
        reminderTimes: [],
        completedDates: [], // Not completed today
      );

      final habits = [habit1, habit2];

      // 1 out of 2 completed = 0.5
      expect(AnalyticsService.getCompletionRatio(habits, date), 0.5);
    });

    test('Completion Ratio should use filtered habits correctly', () {
      final date = DateTime.now();

      // Future habit (not started yet)
      final habitFuture = Habit(
        id: '3',
        title: 'Future Habit',
        iconName: 'sleep',
        colorHex: '#000000',
        goalType: GoalType.cultivate,
        goalPeriod: GoalPeriod.daily,
        startDate: date.add(Duration(days: 10)),
        reminderEnabled: false,
        reminderTimes: [],
      );

      final habitActive = Habit(
        id: '4',
        title: 'Active Habit',
        iconName: 'work',
        colorHex: '#000000',
        goalType: GoalType.cultivate,
        goalPeriod: GoalPeriod.daily,
        startDate: date.subtract(Duration(days: 1)),
        reminderEnabled: false,
        reminderTimes: [],
        completedDates: [utils.toDateStr(date)],
      );

      final habits = [habitFuture, habitActive];

      // getCompletionRatio uses utils.getHabitsForDate internally
      // utils.getHabitsForDate should exclude habitFuture for 'date'
      // So only habitActive should be counted. 1/1 = 1.0

      expect(AnalyticsService.getCompletionRatio(habits, date), 1.0);
    });
  });
}
