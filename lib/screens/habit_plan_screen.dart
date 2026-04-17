import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:habit_tracker/gamification/gamification_provider.dart';
import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/models/habit_plan_day.dart';
import 'package:habit_tracker/services/habit_plan_service.dart';
import 'package:habit_tracker/widgets/habit_plan_validator.dart';

/// Displays the full 30-day AI-generated plan for a habit.
/// Streams day data from Firestore in real-time.
class HabitPlanScreen extends StatefulWidget {
  final Habit habit;

  const HabitPlanScreen({super.key, required this.habit});

  @override
  State<HabitPlanScreen> createState() => _HabitPlanScreenState();
}

class _HabitPlanScreenState extends State<HabitPlanScreen> {
  final HabitPlanService _service = HabitPlanService();
  List<String> _referenceLinks = [];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    final links = await _service.getReferenceLinks(widget.habit.id);
    if (mounted) setState(() => _referenceLinks = links);
  }

  /// Current plan day = completed days + 1, clamped to [1, 30].
  int _currentDay(List<HabitPlanDay> plan) {
    final completed = plan.where((d) => d.isCompleted).length;
    return (completed + 1).clamp(1, 30);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: StreamBuilder<List<HabitPlanDay>>(
        stream: _service.streamPlan(widget.habit.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final plan = snap.data ?? [];
          if (plan.isEmpty) {
            return const Center(child: Text('No plan data found.'));
          }

          final completedCount = plan.where((d) => d.isCompleted).length;
          final currentDay = _currentDay(plan);
          final progress = completedCount / 30;

          return CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: const Color(0xFFF5F5F7),
                surfaceTintColor: Colors.transparent,
                iconTheme: const IconThemeData(color: Colors.black),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: const Color(0xFFF5F5F7),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -30,
                          bottom: -10,
                          child: Icon(
                            widget.habit.icon,
                            size: 200,
                            color: widget.habit.color.withValues(alpha: 0.06),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4E55E0,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    '✨ AI Generated Plan',
                                    style: TextStyle(
                                      color: Color(0xFF4E55E0),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.habit.title,
                                  style: const TextStyle(
                                    color: Color(0xFF1D1D1F),
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
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

              // ── Reference links ─────────────────────────────────────
              if (_referenceLinks.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _ReferenceLinkRow(links: _referenceLinks),
                  ),
                ),

              // ── Progress card ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _ProgressCard(
                    completedCount: completedCount,
                    progress: progress,
                    habitColor: widget.habit.color,
                  ),
                ),
              ),

              // ── Day cards ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverList.builder(
                  itemCount: plan.length,
                  itemBuilder: (context, index) {
                    final day = plan[index];
                    final isCurrent = day.day == currentDay;
                    final isFuture = day.day > currentDay;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DayCard(
                        day: day,
                        habit: widget.habit,
                        isCurrent: isCurrent,
                        isFuture: isFuture,
                        onStartTask: isCurrent
                            ? () => _startTask(context, day)
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _startTask(BuildContext context, HabitPlanDay day) {
    if (day.validationType == 'self_report') {
      _showSelfReportDialog(context, day);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HabitPlanValidator(
            habitId: widget.habit.id,
            habitTitle: widget.habit.title,
            habitColor: widget.habit.color,
            day: day.day,
            validationType: day.validationType,
            durationMinutes: day.durationMinutes,
            stepTarget: day.stepTarget,
            onComplete: () {
              // Navigator.pop handled inside validator's "Back to Plan" button
            },
          ),
        ),
      );
    }
  }

  void _showSelfReportDialog(BuildContext context, HabitPlanDay day) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Day ${day.day} Complete?'),
        content: Text(day.taskDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4E55E0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.markDayComplete(widget.habit.id, day.day);

              // ── Gamification XP hook (BUG-3 fix) ─────────────────────
              if (context.mounted) {
                context.read<GamificationProvider>().onHabitCompleted(
                  allHabits: [],
                  completedHabit: widget.habit,
                  date: DateTime.now(),
                );
              }

              if (!context.mounted) return;
              _showCelebration(context);
            },
            child: const Text('Yes, Done! ✅'),
          ),
        ],
      ),
    );
  }

  void _showCelebration(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (ctx, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: widget.habit.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.celebration,
                    size: 44,
                    color: widget.habit.color,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '🎉 Great Work!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Day complete! Keep up the streak!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E55E0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reference Links Row ──────────────────────────────────────────────────────

class _ReferenceLinkRow extends StatelessWidget {
  final List<String> links;

  const _ReferenceLinkRow({required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reference Videos',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(links.length, (i) {
            return GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(links[i]);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4E55E0).withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_outline,
                      size: 16,
                      color: Color(0xFF4E55E0),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Watch Video ${i + 1}',
                      style: const TextStyle(
                        color: Color(0xFF4E55E0),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── Progress Card ────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final int completedCount;
  final double progress;
  final Color habitColor;

  const _ProgressCard({
    required this.completedCount,
    required this.progress,
    required this.habitColor,
  });

  @override
  Widget build(BuildContext context) {
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: habitColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(habitColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Day Card ─────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final HabitPlanDay day;
  final Habit habit;
  final bool isCurrent;
  final bool isFuture;
  final VoidCallback? onStartTask;

  const _DayCard({
    required this.day,
    required this.habit,
    required this.isCurrent,
    required this.isFuture,
    this.onStartTask,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isCurrent
        ? habit.color.withValues(alpha: 0.3)
        : Colors.transparent;

    final Color circleColor = isCurrent
        ? habit.color
        : day.isCompleted
        ? Colors.green
        : const Color(0xFFF0F0F0);

    final Color circleTextColor = (isCurrent || day.isCompleted)
        ? Colors.white
        : const Color(0xFF1D1D1F);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrent ? habit.color.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? habit.color.withValues(alpha: 0.1)
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
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: day.isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: circleTextColor,
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
                          color: habit.color,
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
                      'Day ${day.day}  ·  ${_goalLabel()}',
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
                Text(
                  day.taskDescription,
                  style: TextStyle(
                    color: isFuture ? Colors.grey[400] : Colors.grey[700],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (!isFuture && day.tip.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          day.tip,
                          style: TextStyle(
                            color: day.isCompleted
                                ? Colors.grey[500]
                                : habit.color,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isCurrent && onStartTask != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: habit.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: onStartTask,
                      child: const Text(
                        "Start Today's Task",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _goalLabel() {
    if (day.validationType == 'timer') {
      return '${day.durationMinutes} min';
    } else if (day.validationType == 'pedometer') {
      final target = day.stepTarget ?? day.durationMinutes;
      return '$target steps';
    }
    return 'Self-check';
  }
}
