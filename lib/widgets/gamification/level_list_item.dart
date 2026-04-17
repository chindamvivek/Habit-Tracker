import 'package:flutter/material.dart';
import 'package:habit_tracker/gamification/gamification_data.dart';

class LevelListItem extends StatelessWidget {
  final LevelDefinition levelDef;
  final bool isCurrentLevel;
  final bool isUnlocked;

  const LevelListItem({
    super.key,
    required this.levelDef,
    required this.isCurrentLevel,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color bgColor;
    final Color textColor;
    final String chipLabel;
    final Color chipColor;
    final Color chipTextColor;

    if (isCurrentLevel) {
      borderColor = const Color(0xFF5B6CFF);
      bgColor = const Color(0xFF5B6CFF).withValues(alpha: 0.08);
      textColor = const Color(0xFF1D1D1F);
      chipLabel = 'Current';
      chipColor = const Color(0xFF5B6CFF);
      chipTextColor = Colors.white;
    } else if (isUnlocked) {
      borderColor = const Color(0xFFA8DB63);
      bgColor = const Color(0xFFA8DB63).withValues(alpha: 0.07);
      textColor = const Color(0xFF1D1D1F);
      chipLabel = 'Unlocked';
      chipColor = const Color(0xFFA8DB63);
      chipTextColor = const Color(0xFF2D5A10);
    } else {
      borderColor = Colors.transparent;
      bgColor = Colors.white;
      textColor = Colors.grey.shade500;
      chipLabel = '';
      chipColor = Colors.transparent;
      chipTextColor = Colors.transparent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: borderColor,
          width: isCurrentLevel || isUnlocked ? 1.5 : 0,
        ),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          // Level number badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCurrentLevel
                  ? const Color(0xFF5B6CFF)
                  : isUnlocked
                  ? const Color(0xFFA8DB63)
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${levelDef.level}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isCurrentLevel
                      ? Colors.white
                      : isUnlocked
                      ? const Color(0xFF2D5A10)
                      : Colors.grey.shade500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title & XP
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  levelDef.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  levelDef.level == 1
                      ? 'Starting level'
                      : '+${_formatNum(levelDef.xpRequired)} XP to reach',
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnlocked || isCurrentLevel
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),

          // State chip
          if (chipLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                chipLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: chipTextColor,
                ),
              ),
            )
          else
            Icon(
              Icons.lock_outline_rounded,
              color: Colors.grey.shade300,
              size: 18,
            ),
        ],
      ),
    );
  }

  String _formatNum(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return '$n';
  }
}
