import 'package:flutter/material.dart';

class HowToEarnCard extends StatelessWidget {
  const HowToEarnCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to Earn XP',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 14),
          ..._items.map(_buildRow),
        ],
      ),
    );
  }

  static const List<_EarnItem> _items = [
    _EarnItem(emoji: '✅', label: 'Complete a habit', xp: '+10 XP'),
    _EarnItem(emoji: '🌅', label: 'First habit of the day', xp: '+5 XP bonus'),
    _EarnItem(emoji: '🔥', label: '7-day streak milestone', xp: '+200 XP'),
    _EarnItem(emoji: '🔥', label: '30-day streak milestone', xp: '+200 XP'),
    _EarnItem(emoji: '🔥', label: '60-day streak milestone', xp: '+200 XP'),
    _EarnItem(emoji: '🔥', label: '100-day streak milestone', xp: '+200 XP'),
  ];

  Widget _buildRow(_EarnItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1D1D1F)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF5B6CFF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              item.xp,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B6CFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnItem {
  final String emoji;
  final String label;
  final String xp;
  const _EarnItem({required this.emoji, required this.label, required this.xp});
}
