import 'package:flutter/material.dart';

import 'habit.dart';
import 'habit_details.dart';

class HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final bool isCompleted;
  final bool showCheckbox;
  final int currentReps;

  final DateTime? displayDate;
  final bool isInteractive;

  /// Optional callback triggered when the user taps the AI Plan icon button.
  /// When null, the plan button is not shown.
  final VoidCallback? onPlanTap;

  const HabitCard({
    super.key,
    required this.habit,
    this.onTap,
    this.onComplete,
    this.isCompleted = false,
    this.showCheckbox = true,
    this.currentReps = 0,
    this.displayDate,
    this.isInteractive = true,
    this.onPlanTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status relative to the displayed date (defaults to today)
    final date = displayDate ?? DateTime.now();
    final bool isActive = habit.isActiveOnDate(date);
    final bool hasStarted = habit.hasStartedOnDate(date);
    final bool isExpired = habit.isExpiredOnDate(date);

    // Check if weekly target is met (for graying effect)
    final bool isWeeklyTargetMet =
        habit.goalPeriod == GoalPeriod.weekly &&
        habit.weeklyFrequency > 0 &&
        habit.completionsInWeekOf(date) >= habit.weeklyFrequency &&
        !isCompleted;

    // Darker icon color for contrast on the card background
    final Color iconColor = Colors.black.withValues(alpha: 0.8);

    final bool showBar = habit.weeklyFrequency > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (showBar) _buildFrequencyBar(),
            Padding(
              padding: EdgeInsets.only(
                top: showBar
                    ? 28.0
                    : 0.0, // Reduced top padding to match shorter bar top
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showCheckbox && (isInteractive || isCompleted)) ...[
                    _buildCheckbox(),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 84),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isWeeklyTargetMet
                              ? Colors.grey[300]
                              : habit.color,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildListLayout(
                          iconColor,
                          isCompleted,
                          isActive,
                          hasStarted,
                          isExpired,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckbox() {
    return GestureDetector(
      onTap: !isInteractive ? null : onComplete,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted
              ? Colors.black
              : !isInteractive
              ? Colors.black.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.1),
          border: !isCompleted && !isInteractive
              ? Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 2)
              : null,
        ),
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null, // Removed Icons.block for a cleaner disabled look
      ),
    );
  }

  Widget _buildFrequencyBar() {
    // Determine if checkbox is actually being shown to calculate offset
    final bool isCheckboxVisible =
        showCheckbox && (isInteractive || isCompleted);

    // Offset calculation for alignment with the habit card
    // Checkbox width (32) + spacing (12) = 44
    final double leftOffset = isCheckboxVisible ? 44.0 : 0.0;

    final date = displayDate ?? DateTime.now();
    final currentWeeklyCount = habit.completionsInWeekOf(date);

    // Check if weekly target is met for graying effect
    final bool isWeeklyTargetMet =
        habit.goalPeriod == GoalPeriod.weekly &&
        habit.weeklyFrequency > 0 &&
        currentWeeklyCount >= habit.weeklyFrequency &&
        !isCompleted;

    return Container(
      margin: EdgeInsets.only(left: leftOffset),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 20),
      decoration: BoxDecoration(
        color: isWeeklyTargetMet
            ? Colors.grey[400] // Gray when target met
            : const Color(0xFF2D3243), // Dark navy from reference
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Text(
        "$currentWeeklyCount/${habit.weeklyFrequency} DAYS FINISHED THIS WEEK",
        style: TextStyle(
          color: isWeeklyTargetMet ? Colors.grey[700] : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildListLayout(
    Color iconColor,
    bool isCompleted,
    bool isActive,
    bool hasStarted,
    bool isExpired,
  ) {
    String progressText = "";

    // Priority 1: Weekly completion (if target met for the week and not completed today)
    final date = displayDate ?? DateTime.now();
    final weeklyCompletions = habit.completionsInWeekOf(date);

    if (habit.weeklyFrequency > 0 &&
        weeklyCompletions >= habit.weeklyFrequency &&
        !isCompleted) {
      progressText = "✓ Completed this week";
    }

    // Priority 2: Repeat mode progress (inside card)
    if (progressText.isEmpty && habit.goalMode == 'repeat') {
      if (currentReps >= habit.targetReps) {
        progressText = "Finished";
      } else {
        progressText = "$currentReps/${habit.targetReps} reps";
      }
    }

    // Priority 3: Status messages
    if (progressText.isEmpty) {
      if (isCompleted) {
        progressText = "Completed!";
      } else if (isExpired) {
        progressText = "Expired";
      } else if (!hasStarted) {
        progressText =
            "Starts on: ${habit.startDate.day}/${habit.startDate.month}";
      }
    }

    // Priority 3: Weekly progress (only if frequency bar is NOT shown)
    if (progressText.isEmpty &&
        !isCompleted &&
        !isExpired &&
        habit.weeklyFrequency == 0) {
      final weeklyText = habit.getWeeklyProgressTextFor(date);
      if (weeklyText != null) {
        progressText = weeklyText;
      }
    }

    return Row(
      children: [
        // Left: Icon
        Icon(habit.icon, color: iconColor, size: 28),
        const SizedBox(width: 16),

        // Middle: Title and Goal
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  text: habit.title,
                  children: [
                    TextSpan(
                      text: " · ${habit.goalType.name.capitalize()}",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              if (progressText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  progressText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCompleted
                        ? Colors.black.withValues(alpha: 0.6)
                        : (isExpired || !hasStarted)
                        ? Colors.red
                        : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Right: Streak Badge (Only if streak > 0)
        if (habit.streak > 0) ...[
          const SizedBox(width: 8),
          _buildStreakBadge(),
        ],
        // AI Plan button (shown only when onPlanTap is provided)
        if (onPlanTap != null) ...[
          const SizedBox(width: 4),
          _buildPlanButton(),
        ],
      ],
    );
  }

  Widget _buildStreakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flash_on_rounded, size: 12),
          const SizedBox(width: 2),
          Text(
            "${habit.streak}",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanButton() {
    return GestureDetector(
      onTap: onPlanTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.auto_awesome_outlined,
          size: 16,
          color: Colors.black,
        ),
      ),
    );
  }
}
