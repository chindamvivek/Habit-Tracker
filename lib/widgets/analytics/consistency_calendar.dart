import 'package:flutter/material.dart';
import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/services/analytics_service.dart';
import 'package:intl/intl.dart';

class ConsistencyCalendar extends StatefulWidget {
  final List<Habit> habits;

  const ConsistencyCalendar({super.key, required this.habits});

  @override
  State<ConsistencyCalendar> createState() => _ConsistencyCalendarState();
}

class _ConsistencyCalendarState extends State<ConsistencyCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday; // 1=Mon, 7=Sun
    final daysInMonth = lastDayOfMonth.day;

    // Calculate offset for first day (0=Mon in our grid)
    // firstWeekday: 1=Mon, 7=Sun
    // We want 0=Mon, so offset = firstWeekday - 1
    final startOffset = firstWeekday - 1;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header with month/year and navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left),
                color: Colors.black,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right),
                color: Colors.black,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weekday headers - Monday Start
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),

          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 42, // 6 weeks max
            itemBuilder: (context, index) {
              final dayNumber = index - startOffset + 1;

              // Empty cell before month starts or after month ends
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                dayNumber,
              );
              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              final isPerfect = AnalyticsService.isPerfectDay(
                widget.habits,
                date,
              );

              final completionRatio = AnalyticsService.getCompletionRatio(
                widget.habits,
                date,
              );

              return _buildDayCell(
                dayNumber,
                isToday,
                isPerfect,
                completionRatio,
              );
            },
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFF5B67F1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Completed',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(width: 24),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.pink, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Today',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    int day,
    bool isToday,
    bool isPerfect,
    double completionRatio,
  ) {
    // Priority 1: Today Border -> Handled by border property
    // Priority 2: Perfect Day -> Blue Fill
    // Priority 3: Partial Progress -> Partial Indicator
    // Priority 4: Empty -> Transparent/White

    Color backgroundColor = Colors.transparent;
    Widget? backgroundWidget;
    Color textColor = Colors.grey[700]!;

    if (isPerfect) {
      backgroundColor = const Color(0xFF5B67F1);
      textColor = Colors.white;
    } else if (completionRatio > 0) {
      // Partial Progress
      backgroundWidget = CircularProgressIndicator(
        value: completionRatio,
        strokeWidth: 4,
        backgroundColor: Colors.grey[200],
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5B67F1)),
      );
      textColor = Colors.black; // Ensure text is visible
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background (Partial Indicator)
        if (backgroundWidget != null && !isPerfect)
          SizedBox(width: 36, height: 36, child: backgroundWidget),

        // Main Container (Fill & Border)
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            // Priority 1: Today Border always visible
            border: isToday ? Border.all(color: Colors.pink, width: 2) : null,
          ),
          child: Center(
            child: Text(
              day.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isToday && !isPerfect ? Colors.pink : textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
