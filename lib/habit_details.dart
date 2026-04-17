import 'package:flutter/material.dart';

enum GoalType { cultivate, quit }

enum GoalUnit {
  count,
  steps,
  km,
  miles,
  meters,
  seconds,
  minutes,
  hours,
  calories,
  pages,
  custom,
}

enum GoalPeriod { daily, weekly, monthly }

class HabitDetails {
  final String title;
  final IconData icon;
  final Color color;

  final GoalType goalType;
  final GoalPeriod goalPeriod;
  final String goalMode; // 'off' | 'repeat'
  final int targetReps; // 1-50

  final DateTime startDate;
  final DateTime? endDate;

  final bool reminderEnabled;
  final List<TimeOfDay> reminderTimes;

  const HabitDetails({
    required this.title,
    required this.icon,
    required this.color,
    required this.goalType,
    required this.goalPeriod,
    required this.goalMode,
    required this.targetReps,
    required this.startDate,
    this.endDate,
    required this.reminderEnabled,
    required this.reminderTimes,
  });
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
