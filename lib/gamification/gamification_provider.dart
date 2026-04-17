import 'dart:async';
import 'package:flutter/material.dart';
import 'package:habit_tracker/gamification/gamification_data.dart';
import 'package:habit_tracker/gamification/gamification_service.dart';
import 'package:habit_tracker/gamification/models/badge_model.dart';
import 'package:habit_tracker/gamification/models/gamification_stats.dart';
import 'package:habit_tracker/habit.dart';

class GamificationProvider extends ChangeNotifier {
  final GamificationService _service = GamificationService();

  GamificationStats? stats;
  List<BadgeModel> unlockedBadges = [];
  bool isLoading = true;

  // Animation event flags — screens listen to these
  bool justLeveledUp = false;
  int levelUpNewLevel = 1;
  String levelUpNewTitle = '';
  List<BadgeDefinition> newlyUnlockedBadges = [];

  // Per-habit undo cache — keyed by habit ID so undoing Habit A
  // doesn't accidentally revoke Habit B's XP (BUG-6 fix).
  final Map<String, ({int xp})> _undoCache = {};

  StreamSubscription<GamificationStats?>? _statsSub;
  StreamSubscription<List<BadgeModel>>? _badgesSub;

  // ─────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    await _service.initStats();

    _statsSub?.cancel();
    _statsSub = _service.getStatsStream().listen((s) {
      stats = s;
      isLoading = false;
      notifyListeners();
    });

    _badgesSub?.cancel();
    _badgesSub = _service.getBadgesStream().listen((badges) {
      unlockedBadges = badges;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _badgesSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HABIT COMPLETION HOOK
  // ─────────────────────────────────────────────────────────────────────────

  /// Call this from homepage.dart after a habit is marked complete.
  Future<void> onHabitCompleted({
    required List<Habit> allHabits,
    required Habit completedHabit,
    required DateTime date,
  }) async {
    final result = await _service.awardXpForCompletion(
      allHabits: allHabits,
      completedHabit: completedHabit,
      date: date,
    );

    // Cache per-habit so undo revokes the correct XP (BUG-6 fix).
    _undoCache[completedHabit.id] = (xp: result.xpEarned);

    // Set animation flags
    justLeveledUp = result.didLevelUp;
    levelUpNewLevel = result.newLevel;
    levelUpNewTitle = result.newLevelTitle;
    newlyUnlockedBadges = result.newlyUnlockedBadges;

    notifyListeners();

    // Auto-clear animation flags after a short delay (so the UI can react)
    Future.delayed(const Duration(seconds: 4), () {
      justLeveledUp = false;
      newlyUnlockedBadges = [];
      notifyListeners();
    });
  }

  /// Call this when a habit is un-completed (toggled off).
  ///
  /// [habitId] identifies which habit's XP to revoke from the cache.
  Future<void> onHabitUncompleted({required String habitId}) async {
    final cached = _undoCache.remove(habitId);
    await _service.revokeXpForUncompletion(
      xpToRevoke: cached?.xp ?? kXpPerHabit,
      wasPerfectDay: false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONVENIENCE GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  bool isBadgeUnlocked(String badgeId) =>
      unlockedBadges.any((b) => b.badgeId == badgeId);

  BadgeModel? getUnlockedBadge(String badgeId) {
    try {
      return unlockedBadges.firstWhere((b) => b.badgeId == badgeId);
    } catch (_) {
      return null;
    }
  }

  LevelDefinition get currentLevelDef => getLevelForXp(stats?.totalXp ?? 0);

  int get xpWithinCurrentLevel => getXpWithinLevel(stats?.totalXp ?? 0);

  int get xpRequiredForNextLevel =>
      getXpRequiredForNextLevel(stats?.totalXp ?? 0);

  double get levelProgress {
    final required = xpRequiredForNextLevel;
    if (required == 0) return 1.0; // Max level
    return (xpWithinCurrentLevel / required).clamp(0.0, 1.0);
  }
}
