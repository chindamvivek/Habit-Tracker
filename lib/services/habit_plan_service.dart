import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/models/habit_plan_day.dart';

/// Manages all Firestore I/O for AI-generated habit plans.
///
/// Firestore schema (additive — no existing documents modified):
///   habits/{habitId}/plan/{dayNumber}   ← one doc per day
///   habits/{habitId}.referenceLinks     ← List(String) added after generation
class HabitPlanService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ─── Plan existence check ─────────────────────────────────────────────────

  /// Returns true if the plan sub-collection already has at least one document.
  Future<bool> hasPlan(String habitId) async {
    final snap = await _db
        .collection('habits')
        .doc(habitId)
        .collection('plan')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ─── Save plan ────────────────────────────────────────────────────────────

  /// Batch-writes 30 plan day documents and stores referenceLinks on the
  /// parent habit document. Safe to call only once (hasPlan guard in caller).
  Future<void> savePlan(
    String habitId,
    List<Map<String, dynamic>> days,
    List<String> links,
  ) async {
    final batch = _db.batch();
    final planRef = _db.collection('habits').doc(habitId).collection('plan');

    for (final dayMap in days) {
      final day = (dayMap['day'] as num).toInt();
      batch.set(planRef.doc(day.toString()), dayMap);
    }

    // Store referenceLinks on the parent habit document.
    batch.update(_db.collection('habits').doc(habitId), {
      'referenceLinks': links,
    });

    await batch.commit();
  }

  // ─── Read plan ────────────────────────────────────────────────────────────

  /// Streams all 30 plan days, ordered by day number.
  Stream<List<HabitPlanDay>> streamPlan(String habitId) {
    return _db
        .collection('habits')
        .doc(habitId)
        .collection('plan')
        .orderBy('day')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => HabitPlanDay.fromMap(doc.data())).toList(),
        );
  }

  /// Reads the referenceLinks stored on the parent habit document.
  Future<List<String>> getReferenceLinks(String habitId) async {
    final doc = await _db.collection('habits').doc(habitId).get();
    if (!doc.exists) return [];
    final raw = doc.data()?['referenceLinks'];
    if (raw is List) return raw.whereType<String>().toList();
    return [];
  }

  // ─── Mark day complete ────────────────────────────────────────────────────

  /// Marks a specific plan day as complete and updates the habit's streak.
  ///
  /// Uses a Firestore transaction to:
  ///  1. Add today to `completedDates` array
  ///  2. Recompute `streak` from the full Habit model (avoids stale fields)
  ///  3. Set `lastCompletedDate` to now
  ///  4. Mark the plan day `completedAt`
  Future<void> markDayComplete(String habitId, int day) async {
    final uid = _uid;
    if (uid == null) return;

    final today = _todayStr();
    final habitDocRef = _db.collection('habits').doc(habitId);
    final dayDocRef = habitDocRef.collection('plan').doc(day.toString());

    await _db.runTransaction((txn) async {
      final habitSnap = await txn.get(habitDocRef);
      if (!habitSnap.exists) return;

      final data = habitSnap.data()!;

      // Build updated completedDates list
      final rawDates = data['completedDates'];
      final completedDates = <String>[
        if (rawDates is List) ...rawDates.whereType<String>(),
      ];
      if (!completedDates.contains(today)) {
        completedDates.add(today);
      }

      // Compute new streak from the Habit model (uses the same logic as
      // the habit card, so Firestore streak value stays in sync).
      final updatedData = Map<String, dynamic>.from(data)
        ..['completedDates'] = completedDates;
      final habit = Habit.fromMap(updatedData, habitId);
      final newStreak = habit.streak;

      // Write plan day completion
      txn.update(dayDocRef, {'completedAt': FieldValue.serverTimestamp()});

      // Write habit updates
      txn.update(habitDocRef, {
        'completedDates': completedDates,
        'streak': newStreak,
        'lastCompletedDate': FieldValue.serverTimestamp(),
      });
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
