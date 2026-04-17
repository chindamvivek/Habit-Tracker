import 'package:flutter/material.dart';
import 'package:habit_tracker/models/built_in_habit.dart';

/// Shows the 30-day plan for a selected built-in habit.
/// Reads the [thirtyDayPlan] list directly from the [BuiltInHabit] object
/// (already fetched before navigating here — no extra Firestore call needed).
///
/// The current day is highlighted based on [myHabit.completionHistory.length],
/// which equals the number of days the user has completed so far.
class ThirtyDayPlanScreen extends StatelessWidget {
  final BuiltInHabit habit;
  final MyBuiltInHabit myHabit;

  const ThirtyDayPlanScreen({
    super.key,
    required this.habit,
    required this.myHabit,
  });

  // The user's "current day" is the next uncompleted day (1-indexed).
  int get _currentDay => (myHabit.completionHistory.length + 1).clamp(1, 30);

  static const Map<String, List<Color>> _gradients = {
    'meditation': [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    'yoga': [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
    'walking': [Color(0xFF10B981), Color(0xFF059669)],
    'running': [Color(0xFFF59E0B), Color(0xFFEF4444)],
  };

  static const Map<String, IconData> _icons = {
    'self_improvement': Icons.self_improvement,
    'accessibility_new': Icons.accessibility_new,
    'directions_walk': Icons.directions_walk,
    'directions_run': Icons.directions_run,
  };

  @override
  Widget build(BuildContext context) {
    final gradient =
        _gradients[habit.id] ??
        [const Color(0xFF4E55E0), const Color(0xFF8B5CF6)];
    final icon = _icons[habit.iconName] ?? Icons.star;
    final plan = habit.thirtyDayPlan;
    final completedCount = myHabit.completionHistory.length.clamp(0, 30);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFFF5F5F7),
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.black),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(color: Color(0xFFF5F5F7)),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      bottom: -20,
                      child: Icon(
                        icon,
                        size: 200,
                        color: gradient.first.withValues(alpha: 0.05),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              habit.name,
                              style: const TextStyle(
                                color: Color(0xFF1D1D1F),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Guided 30-Day Plan',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.5),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Progress Summary ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: _ProgressSummaryCard(
                completedCount: completedCount,
                currentStreak: myHabit.currentStreak,
                gradientColors: gradient,
              ),
            ),
          ),

          // ── Day Cards ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList.builder(
              itemCount: plan.length,
              itemBuilder: (context, index) {
                final entry = plan[index];
                final dayNum = entry.day;
                final isCompleted = dayNum <= completedCount;
                final isCurrent = dayNum == _currentDay;
                final isFuture = dayNum > _currentDay;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DayCard(
                    entry: entry,
                    isCompleted: isCompleted,
                    isCurrent: isCurrent,
                    isFuture: isFuture,
                    gradientColors: gradient,
                    validationType: habit.validationType,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Progress Summary Card ────────────────────────────────────────────────────

class _ProgressSummaryCard extends StatelessWidget {
  final int completedCount;
  final int currentStreak;
  final List<Color> gradientColors;

  const _ProgressSummaryCard({
    required this.completedCount,
    required this.currentStreak,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final progress = completedCount / 30;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$completedCount of 30 days completed',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 4),
                  Text(
                    '$currentStreak',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'streak',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(gradientColors.first),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% complete',
            style: TextStyle(
              fontSize: 12,
              color: gradientColors.first,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Day Card ─────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final ThirtyDayPlanEntry entry;
  final bool isCompleted;
  final bool isCurrent;
  final bool isFuture;
  final List<Color> gradientColors;
  final String validationType;

  const _DayCard({
    required this.entry,
    required this.isCompleted,
    required this.isCurrent,
    required this.isFuture,
    required this.gradientColors,
    required this.validationType,
  });

  /// Returns a short goal label shown next to the day number.
  /// Timer habits → "X min"
  /// Step-counter habits → goal is already in the taskDescription first line.
  String get _goalLabel {
    if (validationType == 'timer') {
      return '${entry.durationMinutes} min';
    }
    // For step-counter habits the goal phrase is the first segment of
    // taskDescription (e.g. "Goal: 500 steps — …").
    // Extract and return only the "Goal: X" part.
    final desc = entry.taskDescription;
    final dashIdx = desc.indexOf(' — ');
    if (dashIdx != -1) return desc.substring(0, dashIdx);
    return ''; // fallback: nothing extra
  }

  @override
  Widget build(BuildContext context) {
    // Colour scheme per state
    final Color borderColor = isCurrent
        ? gradientColors.first.withValues(alpha: 0.3)
        : Colors.transparent;

    final Color dayCircleColor = isCurrent
        ? gradientColors.first
        : isCompleted
        ? Colors.green
        : const Color(0xFFF0F0F0);

    final Color dayTextColor = (isCurrent || isCompleted)
        ? Colors.white
        : const Color(0xFF1D1D1F);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrent
            ? gradientColors.first.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? gradientColors.first.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day circle
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: dayCircleColor,
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Center(
                    child: Text(
                      '${entry.day}',
                      style: TextStyle(
                        color: dayTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: gradientColors.first,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    Text(
                      'Day ${entry.day}  ·  $_goalLabel',
                      style: TextStyle(
                        color: isFuture
                            ? Colors.grey[500]
                            : const Color(0xFF1D1D1F),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // For step-counter habits, strip the "Goal: X — " prefix
                // from the taskDescription since it is already shown in
                // the header label above.
                Text(
                  validationType == 'timer'
                      ? entry.taskDescription
                      : _stripGoalPrefix(entry.taskDescription),
                  style: TextStyle(
                    color: isFuture ? Colors.grey[400] : Colors.grey[700],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                // Tip row
                if (!isFuture)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.tip,
                          style: TextStyle(
                            color: isCompleted
                                ? Colors.grey[500]
                                : gradientColors.first,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Strips the "Goal: X — " prefix used in step-counter task descriptions
  /// so the body text only shows the action part.
  String _stripGoalPrefix(String desc) {
    final dashIdx = desc.indexOf(' — ');
    if (dashIdx != -1) return desc.substring(dashIdx + 3);
    return desc;
  }
}
