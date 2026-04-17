import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to Firestore path: users/{userId}/badges/{badgeId}
class BadgeModel {
  final String badgeId;
  final String name;
  final DateTime unlockedAt;
  final int progress; // 0-100, used for progress-based badges before unlock
  final int timesEarned;

  const BadgeModel({
    required this.badgeId,
    required this.name,
    required this.unlockedAt,
    this.progress = 100,
    this.timesEarned = 1,
  });

  factory BadgeModel.fromMap(Map<String, dynamic> map) {
    return BadgeModel(
      badgeId: map['badgeId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      unlockedAt: (map['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      progress: (map['progress'] as int?) ?? 100,
      timesEarned: (map['timesEarned'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'badgeId': badgeId,
      'name': name,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
      'progress': progress,
      'timesEarned': timesEarned,
    };
  }
}
