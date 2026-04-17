import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habit_tracker/gamification/gamification_data.dart';
import 'package:habit_tracker/gamification/models/badge_model.dart';
import 'package:habit_tracker/gamification/models/gamification_stats.dart';
import 'package:habit_tracker/habit.dart';
import 'package:intl/intl.dart';

class GamificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _statsRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('gamification')
        .doc('stats');
  }

  CollectionReference<Map<String, dynamic>>? get _badgesRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('badges');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates the stats document if it doesn't exist yet (new user).
  Future<void> initStats() async {
    final ref = _statsRef;
    if (ref == null) return;
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set(GamificationStats.empty().toMap());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAMS
  // ─────────────────────────────────────────────────────────────────────────

  Stream<GamificationStats?> getStatsStream() {
    final ref = _statsRef;
    if (ref == null) return Stream.value(null);
    return ref.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return GamificationStats.fromMap(snap.data()!);
    });
  }

  Stream<List<BadgeModel>> getBadgesStream() {
    final ref = _badgesRef;
    if (ref == null) return Stream.value([]);
    return ref.snapshots().map(
      (snap) => snap.docs.map((d) => BadgeModel.fromMap(d.data())).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FETCH CURRENT STATS (one-time)
  // ─────────────────────────────────────────────────────────────────────────

  Future<GamificationStats> fetchStats() async {
    final ref = _statsRef;
    if (ref == null) return GamificationStats.empty();
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) return GamificationStats.empty();
    return GamificationStats.fromMap(doc.data()!);
  }

  Future<Set<String>> fetchUnlockedBadgeIds() async {
    final ref = _badgesRef;
    if (ref == null) return {};
    final snap = await ref.get();
    return snap.docs.map((d) => d.id).toSet();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WRITE STATS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _writeStats(GamificationStats stats) async {
    final ref = _statsRef;
    if (ref == null) return;
    await ref.set(stats.toMap(), SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CORE: AWARD XP AFTER HABIT COMPLETION
  // ─────────────────────────────────────────────────────────────────────────

  /// Called after a habit is toggled to "completed" on [date].
  /// [completedHabit] — the habit that was just completed.
  /// Returns a [XpAwardResult] describing what happened (used by provider to
  /// trigger animations / notifications).
  Future<XpAwardResult> awardXpForCompletion({
    required List<Habit> allHabits,
    required Habit completedHabit,
    required DateTime date,
  }) async {
    final ref = _statsRef;
    if (ref == null) return XpAwardResult.empty();

    // Read current stats fresh
    GamificationStats stats = await fetchStats();
    final todayStr = DateFormat('yyyy-MM-dd').format(date);

    // ── 1. Base XP ────────────────────────────────────────────────────────
    int xpEarned = kXpPerHabit;

    // ── 2. First habit of the day bonus ───────────────────────────────────
    // Simpler heuristic: if lastActiveDate != todayStr, this is the first.
    final isFirstToday = (stats.lastActiveDate != todayStr);
    if (isFirstToday) {
      xpEarned += kXpFirstOfDay;
    }

    // ── 3. Update total completions ───────────────────────────────────────
    final newTotalCompletions = stats.totalCompletions + 1;

    // ── 4. Streak update ──────────────────────────────────────────────────
    final streakResult = _calculateNewStreak(
      currentStreak: stats.currentStreak,
      longestStreak: stats.longestStreak,
      lastActiveDate: stats.lastActiveDate,
      todayStr: todayStr,
    );
    // Check streak milestone XP
    bool streakMilestoneHit = false;
    if (kStreakMilestones.contains(streakResult.currentStreak) &&
        !kStreakMilestones.contains(stats.currentStreak)) {
      xpEarned += kXpStreakMilestone;
      streakMilestoneHit = true;
    }

    // ── 5. Track max habits completed in a single day ─────────────────────
    // Count how many habits have been completed today (including the current one)
    final completedTodayCount = allHabits.where((h) {
      final habit = (h.id == completedHabit.id) ? completedHabit : h;
      return habit.isActiveOnDate(date) && habit.isCompletedOnDate(date);
    }).length;
    final newMaxHabitsInOneDay = completedTodayCount > stats.maxHabitsInOneDay
        ? completedTodayCount
        : stats.maxHabitsInOneDay;

    // ── 7. Compute new XP and level ───────────────────────────────────────
    final newTotalXp = stats.totalXp + xpEarned;
    final newLevelDef = getLevelForXp(newTotalXp);
    final newCurrentXp = getXpWithinLevel(newTotalXp);
    final didLevelUp = newLevelDef.level > stats.level;

    // ── 7. Build updated stats ────────────────────────────────────────────
    final updatedStats = stats.copyWith(
      level: newLevelDef.level,
      currentXp: newCurrentXp,
      totalXp: newTotalXp,
      currentStreak: streakResult.currentStreak,
      longestStreak: streakResult.longestStreak,
      lastActiveDate: todayStr,
      totalCompletions: newTotalCompletions,
      maxHabitsInOneDay: newMaxHabitsInOneDay,
    );

    // ── 8. Write to Firestore ─────────────────────────────────────────────
    await _writeStats(updatedStats);

    // ── 9. Check and unlock badges ────────────────────────────────────────
    final unlockedBadgeIds = await fetchUnlockedBadgeIds();
    final newlyUnlocked = await _checkAndUnlockBadges(
      stats: updatedStats,
      alreadyUnlocked: unlockedBadgeIds,
    );

    return XpAwardResult(
      xpEarned: xpEarned,
      didLevelUp: didLevelUp,
      newLevel: newLevelDef.level,
      newLevelTitle: newLevelDef.title,
      streakMilestoneHit: streakMilestoneHit,
      newStreak: streakResult.currentStreak,
      newlyUnlockedBadges: newlyUnlocked,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UNDO: Called when a habit is uncompleted (de-toggled)
  // ─────────────────────────────────────────────────────────────────────────

  /// Revokes XP when a completion is undone.
  ///
  /// [xpToRevoke] — the exact XP that was awarded for this completion
  ///   (pass in the [XpAwardResult.xpEarned] from the original award call).
  /// [wasPerfectDay] — whether this completion triggered a perfect day.
  ///   If true, `perfectDays` is decremented and the perfect-week counter
  ///   is also rolled back if this was the 7th consecutive perfect day.
  Future<void> revokeXpForUncompletion({
    required int xpToRevoke,
    required bool wasPerfectDay,
  }) async {
    final stats = await fetchStats();

    final newTotalXp = (stats.totalXp - xpToRevoke).clamp(0, 999999);
    final newLevelDef = getLevelForXp(newTotalXp);

    final updatedStats = stats.copyWith(
      level: newLevelDef.level,
      currentXp: getXpWithinLevel(newTotalXp),
      totalXp: newTotalXp,
      totalCompletions: (stats.totalCompletions - 1).clamp(0, 999999),
    );
    await _writeStats(updatedStats);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  _StreakResult _calculateNewStreak({
    required int currentStreak,
    required int longestStreak,
    required String? lastActiveDate,
    required String todayStr,
  }) {
    if (lastActiveDate == todayStr) {
      // Already active today — don't increment again
      return _StreakResult(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
      );
    }

    int newStreak;
    if (lastActiveDate == null) {
      newStreak = 1;
    } else {
      final last = DateTime.parse(lastActiveDate);
      final today = DateTime.parse(todayStr);
      final diff = today.difference(last).inDays;
      // Allow up to 2-day gaps to account for habits scheduled on
      // specific weekdays (e.g., Mon/Wed/Fri). This keeps the
      // gamification streak consistent with habit_utils.calculateStreak
      // which skips non-scheduled days.
      newStreak = (diff <= 2) ? currentStreak + 1 : 1;
    }

    final newLongest = newStreak > longestStreak ? newStreak : longestStreak;
    return _StreakResult(currentStreak: newStreak, longestStreak: newLongest);
  }

  Future<List<BadgeDefinition>> _checkAndUnlockBadges({
    required GamificationStats stats,
    required Set<String> alreadyUnlocked,
  }) async {
    final toUnlock = <BadgeDefinition>[];

    for (final badge in kBadges) {
      if (alreadyUnlocked.contains(badge.id)) continue;
      if (_meetsRequirement(badge, stats)) {
        toUnlock.add(badge);
      }
    }

    // Write each newly unlocked badge to Firestore
    for (final badge in toUnlock) {
      await _writeBadge(badge);
    }

    return toUnlock;
  }

  bool _meetsRequirement(BadgeDefinition badge, GamificationStats stats) {
    switch (badge.id) {
      // ── Streak ──────────────────────────────────────────────────────────
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

      // ── Completions ──────────────────────────────────────────────────────
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

      // ── Special ──────────────────────────────────────────────────────────
      case 'variety-master':
        return stats.maxHabitsInOneDay >= 10;

      // ── Level-based specials ─────────────────────────────────────────────
      case 'discipline-guru':
        return stats.level >= 10;
      case 'habit-legend':
        return stats.level >= 20;

      default:
        return false;
    }
  }

  Future<void> _writeBadge(BadgeDefinition badge) async {
    final ref = _badgesRef;
    if (ref == null) return;
    final model = BadgeModel(
      badgeId: badge.id,
      name: badge.name,
      unlockedAt: DateTime.now(),
    );
    await ref.doc(badge.id).set(model.toMap());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT VALUE OBJECTS
// ─────────────────────────────────────────────────────────────────────────────

class XpAwardResult {
  final int xpEarned;
  final bool didLevelUp;
  final int newLevel;
  final String newLevelTitle;
  final bool streakMilestoneHit;
  final int newStreak;
  final List<BadgeDefinition> newlyUnlockedBadges;

  const XpAwardResult({
    required this.xpEarned,
    required this.didLevelUp,
    required this.newLevel,
    required this.newLevelTitle,
    required this.streakMilestoneHit,
    required this.newStreak,
    required this.newlyUnlockedBadges,
  });

  factory XpAwardResult.empty() => const XpAwardResult(
    xpEarned: 0,
    didLevelUp: false,
    newLevel: 1,
    newLevelTitle: '',
    streakMilestoneHit: false,
    newStreak: 0,
    newlyUnlockedBadges: [],
  );
}

class _StreakResult {
  final int currentStreak;
  final int longestStreak;
  const _StreakResult({
    required this.currentStreak,
    required this.longestStreak,
  });
}
