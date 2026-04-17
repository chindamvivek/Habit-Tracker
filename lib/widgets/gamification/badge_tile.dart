import 'package:flutter/material.dart';
import 'package:habit_tracker/gamification/gamification_data.dart';
import 'package:habit_tracker/gamification/models/badge_model.dart';
import 'package:intl/intl.dart';

class BadgeTile extends StatelessWidget {
  final BadgeDefinition definition;
  final BadgeModel? unlockedBadge; // null if still locked

  const BadgeTile({super.key, required this.definition, this.unlockedBadge});

  bool get isUnlocked => unlockedBadge != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isUnlocked ? _bgColor() : const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? _borderColor() : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: _borderColor().withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon / Padlock
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isUnlocked ? _iconBgColor() : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isUnlocked
                  ? Text(_emoji(), style: const TextStyle(fontSize: 22))
                  : Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.grey.shade400,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(height: 6),

          // Badge name
          Text(
            definition.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isUnlocked
                  ? const Color(0xFF1D1D1F)
                  : Colors.grey.shade400,
            ),
          ),

          const SizedBox(height: 2),

          // Requirement or unlock date
          Text(
            isUnlocked
                ? DateFormat('MMM d, yy').format(unlockedBadge!.unlockedAt)
                : definition.requirementText,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isUnlocked ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Color _bgColor() {
    switch (definition.category) {
      case BadgeCategory.streak:
        return const Color(0xFFFFF3E0);
      case BadgeCategory.completion:
        return const Color(0xFFE8F5E9);
      case BadgeCategory.special:
        return const Color(0xFFF3E5F5);
    }
  }

  Color _borderColor() {
    switch (definition.category) {
      case BadgeCategory.streak:
        return const Color(0xFFFFB74D);
      case BadgeCategory.completion:
        return const Color(0xFFA8DB63);
      case BadgeCategory.special:
        return const Color(0xFFE07BAA);
    }
  }

  Color _iconBgColor() {
    switch (definition.category) {
      case BadgeCategory.streak:
        return const Color(0xFFFFB74D).withValues(alpha: 0.25);
      case BadgeCategory.completion:
        return const Color(0xFFA8DB63).withValues(alpha: 0.25);
      case BadgeCategory.special:
        return const Color(0xFFE07BAA).withValues(alpha: 0.25);
    }
  }

  String _emoji() {
    switch (definition.id) {
      case 'spark':
        return '✨';
      case 'flame':
        return '🔥';
      case 'blaze':
        return '💥';
      case 'inferno':
        return '🌋';
      case 'phoenix':
        return '🦅';
      case 'eternal-flame':
        return '♾️';
      case 'first-step':
        return '👣';
      case 'momentum-builder':
        return '⚡';
      case 'consistency-engine':
        return '⚙️';
      case 'habit-machine':
        return '🤖';
      case 'legendary-grinder':
        return '💎';
      case 'variety-master':
        return '🎯';
      case 'comeback-king':
        return '🦁';
      case 'all-rounder':
        return '⚖️';
      case 'discipline-guru':
        return '🧘';
      case 'habit-legend':
        return '🌠';
      default:
        return '🏅';
    }
  }
}
