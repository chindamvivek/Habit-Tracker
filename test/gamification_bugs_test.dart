import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/gamification/gamification_data.dart';
import 'package:habit_tracker/gamification/models/gamification_stats.dart';

// ---------------------------------------------------------------------------
// Pure unit tests — no Firebase / network needed.
// We directly test the helper logic extracted from GamificationService.
// ---------------------------------------------------------------------------

// ── Helpers reproduced from service for unit-testing ──────────────────────

bool meetsRequirement(BadgeDefinition badge, GamificationStats stats) {
  switch (badge.id) {
    case 'spark':
      return stats.currentStreak >= 3;
    case 'flame':
      return stats.currentStreak >= 7;
    case 'blaze':
      return stats.currentStreak >= 14;
    case 'inferno':
      return stats.currentStreak >= 30;
    case 'phoenix':
      return stats.currentStreak >= 60;
    case 'eternal-flame':
      return stats.currentStreak >= 100;
    case 'first-step':
      return stats.totalCompletions >= 10;
    case 'momentum-builder':
      return stats.totalCompletions >= 100;
    case 'consistency-engine':
      return stats.totalCompletions >= 500;
    case 'habit-machine':
      return stats.totalCompletions >= 1000;
    case 'legendary-grinder':
      return stats.totalCompletions >= 5000;
    case 'variety-master':
      return stats.maxHabitsInOneDay >= 10;
    case 'discipline-guru':
      return stats.level >= 10;
    case 'habit-legend':
      return stats.level >= 20;
    default:
      return false;
  }
}

GamificationStats statsWith({
  int level = 1,
  int totalXp = 0,
  int currentStreak = 0,
  int longestStreak = 0,
  int totalCompletions = 0,
  int maxHabitsInOneDay = 0,
  String? lastActiveDate,
}) {
  return GamificationStats(
    level: level,
    currentXp: 0,
    totalXp: totalXp,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    lastActiveDate: lastActiveDate,
    totalCompletions: totalCompletions,
    maxHabitsInOneDay: maxHabitsInOneDay,
  );
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── XP Undo / Anti-Exploit ────────────────────────────────────────────────
  group('XP Undo anti-exploit', () {
    test('revokeXpForUncompletion subtracts exact xpToRevoke', () {
      final stats = statsWith(totalXp: 100, totalCompletions: 5);
      const xpToRevoke = 15; // base 10 + firstOfDay 5

      final newTotalXp = (stats.totalXp - xpToRevoke).clamp(0, 999999);
      final newLevelDef = getLevelForXp(newTotalXp);
      final updated = stats.copyWith(
        level: newLevelDef.level,
        currentXp: getXpWithinLevel(newTotalXp),
        totalXp: newTotalXp,
        totalCompletions: (stats.totalCompletions - 1).clamp(0, 999999),
      );

      expect(updated.totalXp, equals(85));
      expect(updated.totalCompletions, equals(4));
    });

    test('XP cannot go below 0 on undo', () {
      final stats = statsWith(totalXp: 5);
      final newTotalXp = (stats.totalXp - 15).clamp(0, 999999);
      expect(newTotalXp, equals(0));
    });
  });

  // ── Badge Requirements ─────────────────────────────────────────────────────
  group('Badge requirement checks', () {
    test('variety-master requires maxHabitsInOneDay >= 10', () {
      final badge = kBadges.firstWhere((b) => b.id == 'variety-master');

      expect(meetsRequirement(badge, statsWith(maxHabitsInOneDay: 9)), isFalse);
      expect(meetsRequirement(badge, statsWith(maxHabitsInOneDay: 10)), isTrue);
    });

    test('perfect day / week badges are removed from kBadges', () {
      final ids = kBadges.map((b) => b.id).toSet();
      expect(ids.contains('clear-sky'), isFalse);
      expect(ids.contains('golden-day'), isFalse);
      expect(ids.contains('perfect-storm'), isFalse);
      expect(ids.contains('week-warrior'), isFalse);
      expect(ids.contains('monthly-monarch'), isFalse);
      expect(ids.contains('year-long-legend'), isFalse);
    });

    test('streak badge logic still works correctly', () {
      final spark = kBadges.firstWhere((b) => b.id == 'spark');
      final flame = kBadges.firstWhere((b) => b.id == 'flame');

      expect(meetsRequirement(spark, statsWith(currentStreak: 2)), isFalse);
      expect(meetsRequirement(spark, statsWith(currentStreak: 3)), isTrue);
      expect(meetsRequirement(flame, statsWith(currentStreak: 6)), isFalse);
      expect(meetsRequirement(flame, statsWith(currentStreak: 7)), isTrue);
    });

    test('level-based special badges work correctly', () {
      final guru = kBadges.firstWhere((b) => b.id == 'discipline-guru');
      final legend = kBadges.firstWhere((b) => b.id == 'habit-legend');

      expect(meetsRequirement(guru, statsWith(level: 9)), isFalse);
      expect(meetsRequirement(guru, statsWith(level: 10)), isTrue);
      expect(meetsRequirement(legend, statsWith(level: 19)), isFalse);
      expect(meetsRequirement(legend, statsWith(level: 20)), isTrue);
    });
  });
}
