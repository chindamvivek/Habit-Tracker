import 'package:flutter/material.dart';
import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/services/analytics_service.dart';
import 'package:habit_tracker/widgets/analytics/summary_card.dart';
import 'package:habit_tracker/widgets/analytics/completion_chart.dart';
import 'package:habit_tracker/widgets/analytics/consistency_calendar.dart';

class AnalyticsScreen extends StatefulWidget {
  final List<Habit> habits;

  const AnalyticsScreen({super.key, required this.habits});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isWeeklyView = true;

  // Caching analytics results
  WeeklyChartResult? _cachedWeeklyResult;
  Map<int, int>? _cachedMonthlyData;
  int? _cachedCompletedCountWeekly;
  int? _cachedCompletedCountMonthly;
  int? _cachedBestStreak;
  List<Habit>? _lastHabits;

  void _calculateAnalytics() {
    // Only recalculate if habits have changed
    if (_lastHabits == widget.habits) return;

    final weekStart = AnalyticsService.getCurrentWeekStart();
    final currentMonth = AnalyticsService.getCurrentMonth();

    _cachedWeeklyResult = AnalyticsService.getWeeklyChartData(
      widget.habits,
      weekStart,
    );
    _cachedMonthlyData = AnalyticsService.getMonthlyChartData(
      widget.habits,
      currentMonth,
    );
    _cachedCompletedCountWeekly = AnalyticsService.getCompletedCountForWeek(
      widget.habits,
      weekStart,
    );
    _cachedCompletedCountMonthly = AnalyticsService.getCompletedCountForMonth(
      widget.habits,
      currentMonth,
    );
    // For streak, we only consider ACTIVE habits
    final activeHabits = widget.habits.where((h) => h.isActive).toList();
    _cachedBestStreak = AnalyticsService.getBestStreak(activeHabits);

    _lastHabits = widget.habits;
  }

  @override
  void initState() {
    super.initState();
    _calculateAnalytics();
  }

  @override
  void didUpdateWidget(AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.habits != oldWidget.habits) {
      _calculateAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    _calculateAnalytics(); // Ensure data is calculated

    final completedCount = _isWeeklyView
        ? _cachedCompletedCountWeekly ?? 0
        : _cachedCompletedCountMonthly ?? 0;

    final bestStreak = _cachedBestStreak ?? 0;

    final chartData = _isWeeklyView
        ? _cachedWeeklyResult?.data ?? {}
        : _cachedMonthlyData ?? {};

    // Generate labels dynamically based on data
    final chartLabels = _isWeeklyView
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : List.generate(
            (_cachedMonthlyData?.keys.isEmpty ?? true)
                ? 4
                : _cachedMonthlyData!.keys.reduce((a, b) => a > b ? a : b) + 1,
            (index) => 'W${index + 1}',
          );

    final chartTitle = _isWeeklyView ? 'This Week' : 'This Month';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your consistency',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Period Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isWeeklyView = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isWeeklyView
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _isWeeklyView
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              'Weekly',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _isWeeklyView
                                    ? const Color(0xFF1D1D1F)
                                    : Colors.grey[500],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isWeeklyView = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isWeeklyView
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: !_isWeeklyView
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              'Monthly',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: !_isWeeklyView
                                    ? const Color(0xFF1D1D1F)
                                    : Colors.grey[500],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Completed',
                        value: completedCount.toString(),
                        subtitle: _isWeeklyView
                            ? 'habits this week'
                            : 'habits this month',
                        backgroundColor: const Color(
                          0xFFFDD835,
                        ).withValues(alpha: 0.8),
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SummaryCard(
                        title: 'Best streak',
                        value: bestStreak.toString(),
                        subtitle: 'days in a row',
                        backgroundColor: const Color(
                          0xFF9CCC65,
                        ).withValues(alpha: 0.8),
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Chart
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: CompletionChart(
                    key: ValueKey(_isWeeklyView),
                    data: chartData,
                    isFuture: _isWeeklyView
                        ? _cachedWeeklyResult?.isFuture
                        : null,
                    labels: chartLabels,
                    title: chartTitle,
                  ),
                ),
                const SizedBox(height: 24),

                // Calendar (Last 35 Days)
                const Text(
                  'Last 35 Days',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 12),
                ConsistencyCalendar(habits: widget.habits),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
