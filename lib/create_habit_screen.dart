import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'habit.dart';
import 'habit_details.dart';
import 'theme_provider.dart';
import 'package:habit_tracker/utils/habit_utils.dart';

class CreateHabitScreen extends StatefulWidget {
  const CreateHabitScreen({super.key});

  @override
  State<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends State<CreateHabitScreen> {
  late TextEditingController _nameController;

  late IconData _selectedIcon;
  late Color _selectedColor;
  late GoalType _goalType;
  late GoalPeriod _goalPeriod;
  late String _goalMode;
  late int _targetReps;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _reminderEnabled;
  late List<TimeOfDay> _reminderTimes;
  late String _selectedInterval;

  // Weekly specific state
  List<int> _weeklyDays = [];
  int _weeklyFrequency = 0;

  bool _showNameError = false;

  @override
  void initState() {
    super.initState();
    _selectedInterval = "Every day";
    _nameController = TextEditingController();
    _selectedIcon = Icons.fitness_center;
    _selectedColor = ThemeProvider.primaryYellow;
    _goalType = GoalType.cultivate;
    _goalPeriod = GoalPeriod.daily;
    _goalMode = 'off';
    _targetReps = 1;
    _startDate = DateTime.now();
    _endDate = null;
    _reminderEnabled = false;
    _reminderTimes = [];
    _weeklyDays = [];
    _weeklyFrequency = 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Let's start a new habit",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 36), // Balance the close button
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Field
                    const Text(
                      "Name",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      onChanged: (val) {
                        if (_showNameError) {
                          setState(() => _showNameError = false);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "Type habit name",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        errorText: _showNameError ? "Name is required" : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF4E55E0),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF4E55E0),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Description Field
                    // Goal Type Section (My Goal is To)
                    const Text(
                      "My Goal is To",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(30), // Pill shape
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _goalType = GoalType.cultivate,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _goalType == GoalType.cultivate
                                      ? ThemeProvider.primaryBlue
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Center(
                                  child: Text(
                                    "Cultivate",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _goalType == GoalType.cultivate
                                          ? Colors.white
                                          : const Color(0xFF1D1D1F),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _goalType = GoalType.quit),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _goalType == GoalType.quit
                                      ? ThemeProvider.primaryBlue
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Center(
                                  child: Text(
                                    "Quit",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _goalType == GoalType.quit
                                          ? Colors.white
                                          : const Color(0xFF1D1D1F),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Intervals Dropdown
                    const Text(
                      "Intervals",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedInterval,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.black,
                          ),
                          items: ["Every day", "Weekly", "Monthly"].map((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              if (val == "Weekly") {
                                // Show weekly options modal
                                _showWeeklyOptionsModal();
                              } else {
                                setState(() {
                                  _selectedInterval = val;
                                  if (val == "Every day") {
                                    _goalPeriod = GoalPeriod.daily;
                                  } else if (val == "Monthly") {
                                    _goalPeriod = GoalPeriod.monthly;
                                  }
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    if (_selectedInterval == "Weekly") ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap:
                            _showWeeklyOptionsModal, // Allow editing by tapping
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ThemeProvider.primaryBlue.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ThemeProvider.primaryBlue,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: ThemeProvider.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _weeklyFrequency > 0
                                    ? "$_weeklyFrequency days per week"
                                    : _weeklyDays.isNotEmpty
                                    ? _getWeeklyDaysString()
                                    : "Set weekly schedule",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeProvider.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Goal Section
                    const Text(
                      "Goal",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildGoalSection(),

                    const SizedBox(height: 24),

                    // Icon Grid
                    const Text(
                      "Icon",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildIconGrid(),

                    const SizedBox(height: 24),

                    // Dates Section
                    _buildDateSection(),

                    const SizedBox(height: 24),

                    // Reminders Section
                    _buildReminderSection(),

                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeProvider.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _saveHabit,
                        child: const Text(
                          "Create Habit",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconGrid() {
    final List<Map<String, dynamic>> iconOptions = [
      {
        'icon': Icons.business_center_rounded,
        'color': ThemeProvider.primaryYellow,
      },
      {'icon': Icons.bolt_rounded, 'color': ThemeProvider.primaryPink},
      {'icon': Icons.person_rounded, 'color': const Color(0xFF9BD4FF)},
      {
        'icon': Icons.account_balance_wallet_rounded,
        'color': ThemeProvider.primaryGreen,
      },
      {'icon': Icons.restaurant_rounded, 'color': const Color(0xFFFF9458)},
      {'icon': Icons.headphones_rounded, 'color': const Color(0xFFC6FFD6)},
      {
        'icon': Icons.directions_run_rounded,
        'color': ThemeProvider.primaryYellow,
      },
      {'icon': Icons.menu_book_rounded, 'color': ThemeProvider.primaryPink},
      {'icon': Icons.lock_rounded, 'color': const Color(0xFFBBCAFF)},
      {'icon': Icons.iron_rounded, 'color': ThemeProvider.primaryGreen},
      {
        'icon': Icons.local_fire_department_rounded,
        'color': const Color(0xFFFF9458),
      },
      {'icon': Icons.eco_rounded, 'color': const Color(0xFFC6FFD6)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: iconOptions.length,
      itemBuilder: (context, index) {
        final option = iconOptions[index];
        final isSelected = _selectedIcon == option['icon'];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedIcon = option['icon'];
              _selectedColor = option['color'];
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: option['color'],
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: Colors.black, width: 2)
                  : null,
            ),
            child: Icon(option['icon'], color: Colors.black, size: 24),
          ),
        );
      },
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Dates",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            Row(
              children: [
                const Text(
                  "Set End Date",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _endDate != null,
                    activeThumbColor: ThemeProvider.primaryBlue,
                    onChanged: (val) {
                      setState(() {
                        if (val) {
                          _endDate = DateTime.now().add(
                            const Duration(days: 30),
                          );
                        } else {
                          _endDate = null;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_endDate != null) ...[
          const SizedBox(height: 8),
          _buildPickerButton(
            icon: Icons.event_busy_rounded,
            label: "End Date",
            value: "${_endDate!.day}/${_endDate!.month}/${_endDate!.year}",
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate!,
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
                builder: (context, child) => _buildDatePickerTheme(child!),
              );
              if (picked != null) setState(() => _endDate = picked);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Reminders",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: _reminderEnabled,
                activeThumbColor: ThemeProvider.primaryBlue,
                onChanged: (val) {
                  setState(() {
                    _reminderEnabled = val;
                    if (val && _reminderTimes.isEmpty) {
                      _reminderTimes = [const TimeOfDay(hour: 9, minute: 0)];
                    }
                  });
                },
              ),
            ),
          ],
        ),
        if (_reminderEnabled) ...[
          const SizedBox(height: 8),
          _buildPickerButton(
            icon: Icons.access_time_rounded,
            label: "Reminder Time",
            value: _reminderTimes.isEmpty
                ? "Not set"
                : _reminderTimes.first.format(context),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _reminderTimes.isNotEmpty
                    ? _reminderTimes.first
                    : const TimeOfDay(hour: 9, minute: 0),
                builder: (context, child) => _buildDatePickerTheme(child!),
              );
              if (picked != null) {
                setState(() => _reminderTimes = [picked]);
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black54),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerTheme(Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4E55E0),
          onPrimary: Colors.white,
          onSurface: Colors.black,
        ),
      ),
      child: child,
    );
  }

  Widget _buildGoalSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Goal Mode Row
          GestureDetector(
            onTap: _showGoalModePicker,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Goal",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _goalMode.capitalize(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_right_rounded,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_goalMode == 'repeat') ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1),
            ),
            // Repeats Row
            GestureDetector(
              onTap: _showRepeatsPicker,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Repeats",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _targetReps.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showGoalModePicker() {
    final List<String> modes = ["Off", "Repeat"];
    int selectedIndex = modes.indexOf(_goalMode.capitalize());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 350,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text(
                "Goal",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 45,
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedIndex,
                  ),
                  onSelectedItemChanged: (index) {
                    selectedIndex = index;
                  },
                  children: modes.map((m) {
                    return Center(
                      child: Text(
                        m,
                        style: const TextStyle(color: Colors.black),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F5F7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "CANCEL",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E55E0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() {
                              _goalMode = modes[selectedIndex].toLowerCase();
                            });
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "SAVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRepeatsPicker() {
    int tempReps = _targetReps;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 350,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text(
                "Repeats",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 45,
                  scrollController: FixedExtentScrollController(
                    initialItem: _targetReps - 1,
                  ),
                  onSelectedItemChanged: (index) {
                    tempReps = index + 1;
                  },
                  children: List.generate(50, (index) {
                    return Center(
                      child: Text(
                        (index + 1).toString(),
                        style: const TextStyle(color: Colors.black),
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F5F7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "CANCEL",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4E55E0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() {
                              _targetReps = tempReps;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "SAVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveHabit() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _showNameError = true);
      return;
    }

    // Strip time components for accurate date comparisons
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDateStripped = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    DateTime? endDateStripped;
    if (_endDate != null) {
      endDateStripped = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
      );
    }

    // Validation: Start Date cannot be in the past for new habits
    if (startDateStripped.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Start date cannot be in the past for new habits."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation: End Date cannot be before Start Date
    if (endDateStripped != null &&
        endDateStripped.isBefore(startDateStripped)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("End date cannot be before start date."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation for Weekly
    if (_goalPeriod == GoalPeriod.weekly) {
      if (_weeklyDays.isEmpty && _weeklyFrequency == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select a weekly schedule."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final newHabit = Habit(
      iconName: iconDataToName(_selectedIcon),
      title: _nameController.text.trim(),
      colorHex: colorToHex(_selectedColor),
      goalType: _goalType,
      goalPeriod: _goalPeriod,
      goalMode: _goalMode,
      targetReps: _targetReps,
      startDate: startDateStripped,
      endDate: endDateStripped,
      reminderEnabled: _reminderEnabled,
      reminderTimes: _reminderTimes,
      timezone: DateTime.now().timeZoneName,
      completedDates: [],
      weeklyDays: _weeklyDays,
      weeklyFrequency: _weeklyFrequency,
    );

    Navigator.pop(context, newHabit);
  }

  void _showWeeklyOptionsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Local state for the modal
        List<int> tempWeeklyDays = List.from(_weeklyDays);
        int tempWeeklyFrequency = _weeklyFrequency;

        // Ensure mutually exclusive default if none selected
        if (tempWeeklyDays.isEmpty && tempWeeklyFrequency == 0) {
          // Default to option A (Specific days) empty or option B?
          // Let's just leave them empty and let user select
        }

        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              height: 500,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Weekly Schedule",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 24),

                  // Option A: Specific days
                  const Text(
                    "On specific days",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ["M", "T", "W", "T", "F", "S", "S"]
                        .asMap()
                        .entries
                        .map((entry) {
                          final index = entry.key;
                          final label = entry.value;
                          final isSelected = tempWeeklyDays.contains(index);
                          return GestureDetector(
                            onTap: () {
                              setStateModal(() {
                                // If selecting a specific day, clear frequency mode
                                tempWeeklyFrequency = 0;
                                if (isSelected) {
                                  tempWeeklyDays.remove(index);
                                } else {
                                  tempWeeklyDays.add(index);
                                }
                                tempWeeklyDays.sort();
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? ThemeProvider.primaryBlue
                                    : const Color(0xFFF5F5F7),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),

                  const SizedBox(height: 32),

                  // Option B: Frequency
                  const Text(
                    "OR X days per week",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [1, 2, 3, 4, 5, 6].map((frequency) {
                      final isSelected = tempWeeklyFrequency == frequency;
                      return GestureDetector(
                        onTap: () {
                          setStateModal(() {
                            // If selecting frequency, clear specific days
                            tempWeeklyDays.clear();
                            tempWeeklyFrequency = frequency;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ThemeProvider.primaryBlue
                                : const Color(0xFFF5F5F7),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              frequency.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const Spacer(),

                  // Done Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeProvider.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Validation
                        if (tempWeeklyDays.isEmpty &&
                            tempWeeklyFrequency == 0) {
                          // Allow closing but maybe warn? Or just don't set as weekly?
                          // For now, if nothing selected, we assume they cancelled or didn't mean to select weekly.
                          // But to be UX friendly, let's just pop. The main save will catch empty schedule.
                          Navigator.pop(context);
                          return;
                        }

                        setState(() {
                          _weeklyDays = tempWeeklyDays;
                          _weeklyFrequency = tempWeeklyFrequency;
                          _selectedInterval = "Weekly";
                          _goalPeriod = GoalPeriod.weekly;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Done",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getWeeklyDaysString() {
    if (_weeklyDays.isEmpty) return "";
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return _weeklyDays.map((i) => days[i]).join(", ");
  }
}
