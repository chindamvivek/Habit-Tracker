import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to Firestore path: users/{userId}/gamification/stats
class GamificationStats {
  final int level;
  final int currentXp; // XP within current level (for the progress bar display)
  final int totalXp; // Lifetime XP — source of truth for level calculation
  final int currentStreak;
  final int longestStreak;
  final String? lastActiveDate; // "YYYY-MM-DD"
  final int totalCompletions;
  final int
  maxHabitsInOneDay; // Highest number of habits completed in a single day
  final DateTime? lastUpdated;

  const GamificationStats({
    required this.level,
    required this.currentXp,
    required this.totalXp,
    required this.currentStreak,
    required this.longestStreak,
    this.lastActiveDate,
    required this.totalCompletions,
    required this.maxHabitsInOneDay,
    this.lastUpdated,
  });

  factory GamificationStats.empty() => const GamificationStats(
    level: 1,
    currentXp: 0,
    totalXp: 0,
    currentStreak: 0,
    longestStreak: 0,
    lastActiveDate: null,
    totalCompletions: 0,
    maxHabitsInOneDay: 0,
  );

  factory GamificationStats.fromMap(Map<String, dynamic> map) {
    return GamificationStats(
      level: (map['level'] as int?) ?? 1,
      currentXp: (map['currentXp'] as int?) ?? 0,
      totalXp: (map['totalXp'] as int?) ?? 0,
      currentStreak: (map['currentStreak'] as int?) ?? 0,
      longestStreak: (map['longestStreak'] as int?) ?? 0,
      lastActiveDate: map['lastActiveDate'] as String?,
      totalCompletions: (map['totalCompletions'] as int?) ?? 0,
      maxHabitsInOneDay: (map['maxHabitsInOneDay'] as int?) ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'level': level,
      'currentXp': currentXp,
      'totalXp': totalXp,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastActiveDate': lastActiveDate,
      'totalCompletions': totalCompletions,
      'maxHabitsInOneDay': maxHabitsInOneDay,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  GamificationStats copyWith({
    int? level,
    int? currentXp,
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    String? lastActiveDate,
    int? totalCompletions,
    int? maxHabitsInOneDay,
  }) {
    return GamificationStats(
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
      totalXp: totalXp ?? this.totalXp,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      maxHabitsInOneDay: maxHabitsInOneDay ?? this.maxHabitsInOneDay,
    );
  }
}
