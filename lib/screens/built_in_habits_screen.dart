import 'package:flutter/material.dart';
import 'package:habit_tracker/models/built_in_habit.dart';
import 'package:habit_tracker/services/built_in_habits_service.dart';
import 'package:habit_tracker/screens/thirty_day_plan_screen.dart';
import 'package:habit_tracker/widgets/habit_validator.dart';

/// A standalone screen that:
/// - Seeds the 4 built-in habits the first time they are needed.
/// - Shows all 4 available built-in habits with a "Start" button.
/// - Shows the user's personal dashboard for habits they have already started.
/// - Does NOT touch ANY existing collections or screens.
class BuiltInHabitsScreen extends StatefulWidget {
  const BuiltInHabitsScreen({super.key});

  @override
  State<BuiltInHabitsScreen> createState() => _BuiltInHabitsScreenState();
}

class _BuiltInHabitsScreenState extends State<BuiltInHabitsScreen>
    with SingleTickerProviderStateMixin {
  final BuiltInHabitsService _service = BuiltInHabitsService();

  List<BuiltInHabit> _allHabits = [];
  bool _loading = true;
  String? _error;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      await _service.seedBuiltInHabitsIfNeeded();
      final habits = await _service.getBuiltInHabits();
      if (mounted) {
        setState(() {
          _allHabits = habits;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _startHabit(BuiltInHabit habit) async {
    try {
      await _service.startBuiltInHabit(habit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${habit.name} added to your habits!'),
            backgroundColor: const Color(0xFF4E55E0),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        // Switch to "My Habits" tab automatically.
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openValidator(BuildContext context, MyBuiltInHabit myHabit) {
    int duration = myHabit.defaultDurationMinutes;
    final builtIn = _allHabits.where((h) => h.id == myHabit.id).firstOrNull;
    if (builtIn != null && builtIn.thirtyDayPlan.isNotEmpty) {
      final currentDay = (myHabit.completionHistory.length + 1).clamp(1, 30);
      final entry = builtIn.thirtyDayPlan.firstWhere(
        (e) => e.day == currentDay,
        orElse: () => builtIn.thirtyDayPlan.last,
      );
      duration = entry.durationMinutes;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HabitValidatorScreen(
          myHabit: myHabit,
          targetDurationMinutes: duration,
        ),
      ),
    );
  }

  void _openThirtyDayPlan(BuiltInHabit habit, MyBuiltInHabit myHabit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThirtyDayPlanScreen(habit: habit, myHabit: myHabit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildError()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _BuildAllHabitsTab(
                          habits: _allHabits,
                          service: _service,
                          onStart: _startHabit,
                        ),
                        _BuildMyHabitsTab(
                          allHabits: _allHabits,
                          service: _service,
                          onValidate: _openValidator,
                          onPlan: _openThirtyDayPlan,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4E55E0), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Built-in Habits',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  Text(
                    'Guided 30-day programs',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: const Color(0xFF4E55E0),
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[700],
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Explore'),
            Tab(text: 'My Habits'),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('Something went wrong:\n$_error', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _initData, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ─── Explore Tab ──────────────────────────────────────────────────────────────

class _BuildAllHabitsTab extends StatefulWidget {
  final List<BuiltInHabit> habits;
  final BuiltInHabitsService service;
  final Future<void> Function(BuiltInHabit) onStart;

  const _BuildAllHabitsTab({
    required this.habits,
    required this.service,
    required this.onStart,
  });

  @override
  State<_BuildAllHabitsTab> createState() => _BuildAllHabitsTabState();
}

class _BuildAllHabitsTabState extends State<_BuildAllHabitsTab> {
  Set<String> _startedIds = {};
  bool _loadingStarted = true;

  @override
  void initState() {
    super.initState();
    widget.service.getMyBuiltInHabitsStream().listen((list) {
      if (mounted) {
        setState(() {
          _startedIds = list.map((h) => h.id).toSet();
          _loadingStarted = false;
        });
      }
    });
  }

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
    if (_loadingStarted) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: widget.habits.length,
      itemBuilder: (context, i) {
        final habit = widget.habits[i];
        final started = _startedIds.contains(habit.id);
        final gradientColors =
            _gradients[habit.id] ??
            [const Color(0xFF4E55E0), const Color(0xFF8B5CF6)];
        final icon = _icons[habit.iconName] ?? Icons.star;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
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
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: gradientColors.first.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: gradientColors.first, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          habit.category,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Body
              Text(
                habit.description,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.schedule,
                    label: '30-Day Plan',
                    color: gradientColors.first,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: habit.validationType == 'timer'
                        ? Icons.timer
                        : Icons.directions_walk,
                    label: habit.validationType == 'timer'
                        ? 'Timer'
                        : 'Pedometer',
                    color: gradientColors.first,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: started
                      ? Container(
                          key: const ValueKey('started'),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Already Started — See My Habits tab',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          key: const ValueKey('not-started'),
                          onPressed: () => widget.onStart(habit),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D1D1F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Start This Habit',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── My Habits Tab ────────────────────────────────────────────────────────────

class _BuildMyHabitsTab extends StatelessWidget {
  final List<BuiltInHabit> allHabits;
  final BuiltInHabitsService service;
  final void Function(BuildContext, MyBuiltInHabit) onValidate;
  final void Function(BuiltInHabit, MyBuiltInHabit) onPlan;

  const _BuildMyHabitsTab({
    required this.allHabits,
    required this.service,
    required this.onValidate,
    required this.onPlan,
  });

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
    return StreamBuilder<List<MyBuiltInHabit>>(
      stream: service.getMyBuiltInHabitsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final myHabits = snapshot.data ?? [];

        if (myHabits.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.self_improvement, size: 72, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No habits started yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Go to Explore and start a built-in habit.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          itemCount: myHabits.length,
          itemBuilder: (context, i) {
            final myHabit = myHabits[i];
            final gradient =
                _gradients[myHabit.id] ??
                [const Color(0xFF4E55E0), const Color(0xFF8B5CF6)];

            // Find the full BuiltInHabit definition for the 30-day plan lookup.
            final builtIn = allHabits
                .where((h) => h.id == myHabit.id)
                .firstOrNull;

            int currentTargetDuration = myHabit.defaultDurationMinutes;
            if (builtIn != null && builtIn.thirtyDayPlan.isNotEmpty) {
              final currentDay = (myHabit.completionHistory.length + 1).clamp(
                1,
                30,
              );
              final entry = builtIn.thirtyDayPlan.firstWhere(
                (e) => e.day == currentDay,
                orElse: () => builtIn.thirtyDayPlan.last,
              );
              currentTargetDuration = entry.durationMinutes;
            }

            return FutureBuilder<bool>(
              future: service.isCompletedToday(myHabit.id),
              builder: (context, completedSnap) {
                final completedToday = completedSnap.data ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
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
                      // Header row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: gradient.first.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _icons[builtIn?.iconName ?? ''] ?? Icons.star,
                              color: gradient.first,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  myHabit.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${myHabit.validationType == 'timer' ? 'Timer' : 'Pedometer'} · $currentTargetDuration min',
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Today badge
                          if (completedToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Done',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Streak info
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              label: 'Streak',
                              value: '${myHabit.currentStreak}🔥',
                            ),
                            _StatItem(
                              label: 'Day',
                              value:
                                  '${(myHabit.completionHistory.length).clamp(0, 30)}/30',
                            ),
                            _StatItem(
                              label: 'Total Done',
                              value: '${myHabit.completionHistory.length}',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          if (!completedToday)
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () => onValidate(context, myHabit),
                                icon: Icon(
                                  myHabit.validationType == 'timer'
                                      ? Icons.play_arrow_rounded
                                      : Icons.directions_walk,
                                  size: 20,
                                ),
                                label: const Text('Start Today'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D1D1F),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          if (!completedToday) const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: builtIn != null
                                  ? () => onPlan(builtIn, myHabit)
                                  : null,
                              icon: const Icon(Icons.calendar_month, size: 20),
                              label: const Text('Plan'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1D1D1F),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
