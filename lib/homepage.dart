import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:habit_tracker/calender_card.dart';
import 'package:habit_tracker/create_habit_screen.dart';
import 'package:habit_tracker/firestore_service.dart';
import 'package:habit_tracker/gamification/gamification_provider.dart';
import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/utils/habit_utils.dart' as utils;
import 'package:habit_tracker/habit_card.dart';
import 'package:habit_tracker/edit_habit_sheet.dart';
import 'package:habit_tracker/repetition_counter.dart';
import 'package:habit_tracker/habit_details.dart';
import 'package:habit_tracker/screens/analytics_screen.dart';
import 'package:habit_tracker/screens/progress_screen.dart';
import 'package:habit_tracker/screens/profile_screen.dart';
import 'package:habit_tracker/screens/habit_plan_entry_screen.dart';
import 'package:habit_tracker/screens/built_in_habits_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class Homepage extends StatefulWidget {
  final User user;
  const Homepage({super.key, required this.user});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final FirestoreService _firestoreService = FirestoreService();
  static const int _initialWeekIndex = 1000;

  late PageController _pageController;
  int _bottomNavIndex = 0;

  DateTime _currentDate = DateTime.now();
  bool _showBackToToday = false;
  String? _expandedHabitId; // Tracks which habit is expanded for reps
  List<Habit> _allHabits = []; // Full habit list for gamification calls

  late Stream<List<Habit>> _habitsStream;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialWeekIndex);

    // Add listener for Back to Today button visibility
    _pageController.addListener(_pageScrollListener);

    _habitsStream = _firestoreService.getHabitsStream();

    // Init gamification (creates stats doc if new user, starts Firestore streams)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GamificationProvider>().init();
    });
  }

  void _pageScrollListener() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? _initialWeekIndex.toDouble();
    // Show button if we are more than 0.5 pages away from center (current week)
    if ((page - _initialWeekIndex).abs() > 0.5) {
      if (!_showBackToToday) setState(() => _showBackToToday = true);
    } else {
      if (_showBackToToday) setState(() => _showBackToToday = false);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_pageScrollListener);
    _pageController.dispose();
    super.dispose();
  }

  void _scrollToToday() {
    if (!_pageController.hasClients) return;

    _pageController.animateToPage(
      _initialWeekIndex,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
    );

    setState(() {
      _currentDate = DateTime.now();
      // Button visibility handles itself via listener
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() => _currentDate = date);
  }

  Future<void> _signOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _addNewHabit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateHabitScreen()),
    );

    if (result != null && result is Habit) {
      // Add to Firestore
      try {
        await _firestoreService.addHabit(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Habit added successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding habit: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _updateHabit(Habit habit) async {
    try {
      await _firestoreService.updateHabit(habit);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating habit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteHabit(String id) async {
    try {
      await _firestoreService.deleteHabit(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting habit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editHabit(Habit habit) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditHabitSheet(
        habit: habit,
        onSave: _updateHabit,
        onDelete: () => _deleteHabit(habit.id),
      ),
    );
  }

  Future<void> _toggleHabitCompletion(Habit habit, DateTime date) async {
    // Use centralized validation from the Habit class
    final validationResult = habit.canCompleteOnDate(date);

    if (!validationResult.canComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            validationResult.errorMessage ?? 'Cannot complete habit',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final dateStr = utils.toDateStr(date);
    final isAlreadyCompleted = habit.isCompletedOnDate(date);

    if (habit.goalMode == 'repeat') {
      // Logic for repeat mode is now exclusively handled by the RepetitionCounter UI
      // Tapping the checkbox in REPEAT mode now ONLY toggles the expanded UI.
      // This function should not be reachable for repeat mode habits from the checkbox handler.
      return;
    } else {
      // 'off' mode: legacy toggle behavior
      final newCompletedDates = List<String>.from(habit.completedDates);
      if (isAlreadyCompleted) {
        newCompletedDates.remove(dateStr);
      } else {
        if (!newCompletedDates.contains(dateStr)) {
          newCompletedDates.add(dateStr);
        }
      }

      final updatedHabit = habit.copyWith(
        completedDates: newCompletedDates,
        lastCompletedDate: isAlreadyCompleted ? habit.lastCompletedDate : date,
      );
      await _updateHabit(updatedHabit);

      // ── Gamification XP hook ─────────────────────────────────────────
      if (!isAlreadyCompleted && mounted) {
        // Habit just completed — award XP
        context.read<GamificationProvider>().onHabitCompleted(
          allHabits: _allHabits,
          completedHabit: updatedHabit,
          date: date,
        );
      } else if (isAlreadyCompleted && mounted) {
        // Habit just uncompleted — revoke XP
        context.read<GamificationProvider>().onHabitUncompleted(
          habitId: habit.id,
        );
      }
    }
  }

  Future<void> _updateReps(Habit habit, DateTime date, int reps) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isAfter(today)) return; // Future date safeguard

    final dateStr = utils.toDateStr(date);
    final wasCompletedBefore = habit.isCompletedOnDate(date);

    final newDailyProgress = Map<String, int>.from(habit.dailyProgress);
    newDailyProgress[dateStr] = reps;

    final newCompletedDates = List<String>.from(habit.completedDates);
    if (reps >= habit.targetReps) {
      if (!newCompletedDates.contains(dateStr)) {
        newCompletedDates.add(dateStr);
      }
    } else {
      newCompletedDates.remove(dateStr);
    }

    final updatedHabit = habit.copyWith(
      dailyProgress: newDailyProgress,
      completedDates: newCompletedDates,
      lastCompletedDate: reps >= habit.targetReps
          ? date
          : habit.lastCompletedDate,
    );

    setState(() => _expandedHabitId = null); // Auto-close
    await _updateHabit(updatedHabit);

    // ── Gamification XP hook ─────────────────────────────────────────────
    final isNowCompleted = reps >= habit.targetReps;
    if (isNowCompleted && !wasCompletedBefore && mounted) {
      context.read<GamificationProvider>().onHabitCompleted(
        allHabits: _allHabits,
        completedHabit: updatedHabit,
        date: date,
      );
    } else if (!isNowCompleted && wasCompletedBefore && mounted) {
      context.read<GamificationProvider>().onHabitUncompleted(
        habitId: habit.id,
      );
    }
  }

  Future<void> _finishAll(Habit habit, DateTime date) async {
    await _updateReps(habit, date, habit.targetReps);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Calculate reference Monday for _initialWeekIndex
    final currentWeekday = now.weekday; // Mon=1, Sun=7
    final referenceMonday = now.subtract(Duration(days: currentWeekday - 1));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: StreamBuilder<List<Habit>>(
        stream: _habitsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allHabits = snapshot.data ?? [];
          _allHabits = allHabits;

          // Show screens based on bottom nav tab
          if (_bottomNavIndex == 1) {
            return AnalyticsScreen(habits: allHabits);
          }
          if (_bottomNavIndex == 2) {
            return const ProgressScreen();
          }
          if (_bottomNavIndex == 3) {
            return SettingsScreen(user: widget.user);
          }
          if (_bottomNavIndex == 4) {
            return const BuiltInHabitsScreen();
          }

          // Default Home view
          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final now = DateTime.now();
                              final isToday =
                                  _currentDate.year == now.year &&
                                  _currentDate.month == now.month &&
                                  _currentDate.day == now.day;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isToday
                                        ? "TODAY"
                                        : DateFormat(
                                            'MMM d',
                                          ).format(_currentDate).toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1D1D1F),
                                    ),
                                  ),
                                  Text(
                                    isToday
                                        ? DateFormat(
                                            'MMM d',
                                          ).format(_currentDate)
                                        : DateFormat(
                                            'EEEE',
                                          ).format(_currentDate),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _signOut,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                size: 24,
                                color: Color(0xFF4E55E0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Week-Based Calendar Strip
                Container(
                  // Full Width Container Background
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(color: Color(0xFFE0E0E0)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Static Weekday Headers
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children:
                              [
                                "MON",
                                "TUE",
                                "WED",
                                "THU",
                                "FRI",
                                "SAT",
                                "SUN",
                              ].map((day) {
                                return Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Infinite PageView for Dates
                      SizedBox(
                        height: 60, // Height for date numbers + underline
                        child: PageView.builder(
                          controller: _pageController,
                          // No item count needed for infinite
                          itemBuilder: (context, index) {
                            // Calculate the monday for this page index
                            final diffWeeks = index - _initialWeekIndex;
                            final pageStartMonday = referenceMonday.add(
                              Duration(days: diffWeeks * 7),
                            );

                            // Build Row of 7 days
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: List.generate(7, (dayIndex) {
                                final date = pageStartMonday.add(
                                  Duration(days: dayIndex),
                                );

                                final isToday = utils.isSameDay(
                                  date,
                                  DateTime.now(),
                                );
                                final isSelected = utils.isSameDay(
                                  date,
                                  _currentDate,
                                );
                                final isPast = date.isBefore(
                                  DateTime(now.year, now.month, now.day),
                                );

                                // Calculate completion ratio for this date
                                final habitsForDate = utils.getHabitsForDate(
                                  allHabits,
                                  date,
                                );
                                final dateStr = DateFormat(
                                  'yyyy-MM-dd',
                                ).format(date);

                                // Smart completion counting that excludes weekly frequency habits with met targets
                                int completedCount = 0;
                                int totalCount = 0;

                                for (final habit in habitsForDate) {
                                  // For weekly frequency habits, exclude them if weekly target is already met
                                  if (habit.goalPeriod == GoalPeriod.weekly &&
                                      habit.weeklyFrequency > 0) {
                                    // CRITICAL FIX: Always count if completed on this specific date
                                    if (habit.isCompletedOnDate(date)) {
                                      completedCount++;
                                      totalCount++;
                                    }
                                    // If NOT completed on this date, check if we should even count it
                                    else {
                                      final weeklyCompletions = habit
                                          .completionsInWeekOf(date);
                                      // If weekly target is NOT met yet, count as incomplete (0/1)
                                      if (weeklyCompletions <
                                          habit.weeklyFrequency) {
                                        totalCount++;
                                      }
                                      // If weekly target IS met, exclude entirely (0/0) - creating "rest day" effect
                                    }
                                  } else {
                                    // Regular habit - check if completed on this date
                                    if (habit.completedDates.contains(
                                      dateStr,
                                    )) {
                                      completedCount++;
                                    }
                                    totalCount++;
                                  }
                                }

                                final completionRatio = totalCount > 0
                                    ? completedCount / totalCount
                                    : 0.0;

                                return Expanded(
                                  child: Center(
                                    child: DateCard(
                                      date: date.day,
                                      isToday: isToday,
                                      isSelected: isSelected,
                                      isPast: isPast,
                                      onTap: () => _onDateSelected(date),
                                      containerColor: Colors.transparent,
                                      completionRatio: completionRatio,
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                if (_showBackToToday)
                  GestureDetector(
                    onTap: _scrollToToday,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4E55E0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Back to Today",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Habits View
                const SizedBox(height: 12),

                // Date-aware section header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Text(
                    'Habits for ${DateFormat('MMM d').format(_currentDate)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                ),

                Expanded(
                  child: () {
                    // Filter habits for selected date
                    final habits = utils.getHabitsForDate(
                      allHabits,
                      _currentDate,
                    );

                    if (habits.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy_rounded,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No habits scheduled',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'for ${DateFormat('MMMM d').format(_currentDate)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: habits.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final habit = habits[index];
                          final bool isCompleted = habit.isCompletedOnDate(
                            _currentDate,
                          );
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final currentDateOnly = DateTime(
                            _currentDate.year,
                            _currentDate.month,
                            _currentDate.day,
                          );
                          final bool isFuture = currentDateOnly.isAfter(today);
                          final bool isScheduled = habit.isScheduledForDate(
                            _currentDate,
                          );

                          // Check if weekly target is met (for weekly frequency habits)
                          final bool isWeeklyTargetMet =
                              habit.goalPeriod == GoalPeriod.weekly &&
                              habit.weeklyFrequency > 0 &&
                              habit.completionsInWeekOf(_currentDate) >=
                                  habit.weeklyFrequency &&
                              !habit.isCompletedOnDate(_currentDate);

                          final isInteractive =
                              !isFuture && isScheduled && !isWeeklyTargetMet;

                          final mainContent = Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HabitCard(
                                habit: habit,
                                isCompleted: isCompleted,
                                currentReps: habit.getRepsOnDate(_currentDate),
                                showCheckbox:
                                    true, // Always show space for consistent layout
                                isInteractive: isInteractive,
                                displayDate: _currentDate,
                                onTap: () => _editHabit(habit),
                                onPlanTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        HabitPlanEntryScreen(habit: habit),
                                  ),
                                ),
                                onComplete: !isInteractive
                                    ? null
                                    : () {
                                        if (habit.goalMode == 'repeat') {
                                          final currentReps = habit
                                              .getRepsOnDate(_currentDate);
                                          final isCompletedOnDate = habit
                                              .isCompletedOnDate(_currentDate);

                                          if (isCompletedOnDate) {
                                            _updateReps(habit, _currentDate, 0);
                                          } else if (habit.targetReps -
                                                  currentReps ==
                                              1) {
                                            _finishAll(habit, _currentDate);
                                          } else {
                                            setState(() {
                                              _expandedHabitId =
                                                  (_expandedHabitId == habit.id)
                                                  ? null
                                                  : habit.id;
                                            });
                                          }
                                        } else {
                                          _toggleHabitCompletion(
                                            habit,
                                            _currentDate,
                                          );
                                        }
                                      },
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) =>
                                    SizeTransition(
                                      sizeFactor: animation,
                                      axisAlignment: -1.0,
                                      child: child,
                                    ),
                                child:
                                    (_expandedHabitId == habit.id &&
                                        habit.goalMode == 'repeat' &&
                                        !isFuture)
                                    ? Padding(
                                        key: ValueKey('expanded_${habit.id}'),
                                        padding: EdgeInsets.only(
                                          top: 8,
                                          left: (isInteractive || isCompleted)
                                              ? 44.0
                                              : 0.0,
                                        ),
                                        child: RepetitionCounter(
                                          habit: habit,
                                          initialReps: habit.getRepsOnDate(
                                            _currentDate,
                                          ),
                                          onFinish: (reps) => _updateReps(
                                            habit,
                                            _currentDate,
                                            reps,
                                          ),
                                          onFinishAll: () =>
                                              _finishAll(habit, _currentDate),
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey('collapsed'),
                                        width: double.infinity,
                                        height: 0,
                                      ),
                              ),
                            ],
                          );

                          return mainContent;
                        },
                      ),
                    );
                  }(),
                ),
              ],
            ),
          );
        },
      ),

      // Bottom Navigation Bar
      floatingActionButton: _bottomNavIndex == 0
          ? FloatingActionButton(
              onPressed: _addNewHabit,
              backgroundColor: const Color(0xFF4E55E0),
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomAppBar(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          height: 80,
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, "Home", 0),
              _buildNavItem(Icons.show_chart_rounded, "Analytics", 1),
              _buildNavItem(Icons.emoji_events_rounded, "Progress", 2),
              _buildNavItem(Icons.person_outline_rounded, "Profile", 3),
              _buildNavItem(Icons.auto_awesome_rounded, "Built-in", 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _bottomNavIndex = index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: isSelected
                ? const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF4E55E0),
                  )
                : null,
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected ? const Color(0xFF4E55E0) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
