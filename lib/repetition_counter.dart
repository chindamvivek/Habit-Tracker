import 'package:flutter/material.dart';
import 'habit.dart';

class RepetitionCounter extends StatefulWidget {
  final Habit habit;
  final int initialReps;
  final Function(int) onFinish;
  final VoidCallback onFinishAll;

  const RepetitionCounter({
    super.key,
    required this.habit,
    required this.initialReps,
    required this.onFinish,
    required this.onFinishAll,
  });

  @override
  State<RepetitionCounter> createState() => _RepetitionCounterState();
}

class _RepetitionCounterState extends State<RepetitionCounter> {
  late int _selectedReps;
  late FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedReps = widget.initialReps > 0 ? widget.initialReps : 1;
    // Ensure selected reps doesn't exceed target
    if (_selectedReps > widget.habit.targetReps) {
      _selectedReps = widget.habit.targetReps;
    }
    _scrollController = FixedExtentScrollController(
      initialItem: _selectedReps - 1,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Darker variant of habit color for the counter background
    final Color backgroundColor = Colors.black.withValues(alpha: 0.15);
    final Color textColor = Colors.black;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Wheel Picker
          Expanded(
            flex: 1,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Highlighted selection bar
                  Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: _scrollController,
                    itemExtent: 40,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedReps = index + 1;
                      });
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.habit.targetReps,
                      builder: (context, index) {
                        final number = index + 1;
                        final isSelected = _selectedReps == number;
                        return Center(
                          child: Text(
                            "$number",
                            style: TextStyle(
                              fontSize: isSelected ? 22 : 18,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                              color: isSelected
                                  ? textColor
                                  : textColor.withValues(alpha: 0.3),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Right Side: Action Buttons
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // FINISH Button
                _buildActionButton(
                  onTap: () => widget.onFinish(_selectedReps),
                  color: Colors.black.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: textColor.withValues(alpha: 0.1),
                        ),
                        child: Text(
                          "$_selectedReps",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "FINISH",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            Text(
                              "$_selectedReps REPS",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // FINISH ALL Button
                _buildActionButton(
                  onTap: widget.onFinishAll,
                  color: const Color(0xFF67C23A), // Green color from reference
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        "FINISH ALL",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onTap,
    required Color color,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}
