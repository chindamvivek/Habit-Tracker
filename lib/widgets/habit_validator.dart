import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:provider/provider.dart';
import 'package:habit_tracker/gamification/gamification_provider.dart';
import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/habit_details.dart';
import 'package:habit_tracker/models/built_in_habit.dart';
import 'package:habit_tracker/services/built_in_habits_service.dart';

/// Full-screen validation screen for Built-in Habits.
///
/// - [validationType] == 'timer'       → Meditation / Yoga
///   Shows a non-skippable countdown. Marks complete when it hits 0.
///
/// - [validationType] == 'stepCounter' → Walking / Running
///   Records step count at "Start", samples live while the user walks/runs,
///   then checks delta against threshold when "Complete" is tapped.
///   Threshold: Walking ≥ 500 steps | Running ≥ 1000 steps.
class HabitValidatorScreen extends StatefulWidget {
  final MyBuiltInHabit myHabit;
  final int targetDurationMinutes;

  const HabitValidatorScreen({
    super.key,
    required this.myHabit,
    required this.targetDurationMinutes,
  });

  @override
  State<HabitValidatorScreen> createState() => _HabitValidatorScreenState();
}

class _HabitValidatorScreenState extends State<HabitValidatorScreen>
    with TickerProviderStateMixin {
  final BuiltInHabitsService _service = BuiltInHabitsService();

  // ── Shared ─────────────────────────────────────────────────────
  bool _started = false;
  bool _completed = false;
  bool _marking = false; // Firestore write in progress
  String? _errorMessage;
  int _newStreak = 0; // Streak value after the Firestore write

  // ── Timer mode ─────────────────────────────────────────────────
  Timer? _countdown;
  late int _remainingSeconds;
  late AnimationController _ringController;
  late Animation<double> _ringAnim;

  // ── Pedometer mode ─────────────────────────────────────────────
  StreamSubscription<StepCount>? _stepSub;
  int _startSteps = 0;
  int _currentSteps = 0;
  bool _pedometerAvailable = true;

  // ── Derived ─────────────────────────────────────────────────────
  bool get _isTimer => widget.myHabit.validationType == 'timer';
  int get _totalSeconds => widget.targetDurationMinutes * 60;
  // For timer habits targetDurationMinutes = minutes.
  // For pedometer habits targetDurationMinutes = step target (seed stores steps there).
  int get _stepThreshold => widget.targetDurationMinutes;
  int get _stepsDone => (_currentSteps - _startSteps).clamp(0, 99999);

  /// Human-readable goal label shown in the pedometer UI.
  /// Running  → converts steps back to km  (steps / 1312)
  /// Walking  → shows steps directly
  String get _goalDisplayLabel {
    final isRunning = widget.myHabit.id == 'running';
    if (isRunning) {
      final km = _stepThreshold / 1312;
      final kmStr = km % 1 == 0 ? '${km.toInt()}.0' : km.toStringAsFixed(1);
      return 'Goal: $kmStr km';
    }
    return 'Goal: $_stepThreshold steps';
  }

  // ── Gradient colours ────────────────────────────────────────────
  static const Map<String, List<Color>> _gradients = {
    'meditation': [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    'yoga': [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
    'walking': [Color(0xFF10B981), Color(0xFF059669)],
    'running': [Color(0xFFF59E0B), Color(0xFFEF4444)],
  };

  List<Color> get _gradient =>
      _gradients[widget.myHabit.id] ??
      [const Color(0xFF4E55E0), const Color(0xFF8B5CF6)];

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _totalSeconds;

    _ringController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );
    _ringAnim = Tween<double>(begin: 1.0, end: 0.0).animate(_ringController);
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _ringController.dispose();
    _stepSub?.cancel();
    super.dispose();
  }

  // ─── Timer mode logic ──────────────────────────────────────────

  void _startTimer() {
    setState(() {
      _started = true;
      _errorMessage = null;
    });
    _ringController.forward();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        t.cancel();
        _onTimerFinished();
      }
    });
  }

  void _onTimerFinished() async {
    setState(() {
      _marking = true;
    });
    try {
      final newStreak = await _service.markHabitComplete(widget.myHabit.id);
      if (!mounted) return;
      _awardGamificationXp();
      setState(() {
        _completed = true;
        _marking = false;
        _newStreak = newStreak;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _marking = false;
          _errorMessage = 'Could not save completion: $e';
        });
      }
    }
  }

  // ─── Pedometer mode logic ──────────────────────────────────────

  void _startPedometer() async {
    setState(() {
      _started = true;
      _errorMessage = null;
    });
    try {
      // Subscribe to step count stream.
      _stepSub = Pedometer.stepCountStream.listen(
        (event) {
          if (!mounted) return;
          setState(() {
            if (_startSteps == 0 && event.steps > 0) {
              // First reading — record baseline.
              _startSteps = event.steps;
            }
            _currentSteps = event.steps;
          });
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _pedometerAvailable = false;
              _errorMessage =
                  'Step sensor unavailable on this device.\nUse the "Simulate Steps" button to test.';
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _pedometerAvailable = false;
          _errorMessage = 'Could not access pedometer: $e';
        });
      }
    }
  }

  Future<void> _completePedometer() async {
    if (_stepsDone < _stepThreshold) {
      setState(() {
        _errorMessage =
            'Only $_stepsDone steps detected. You need at least $_stepThreshold steps to complete this habit.';
      });
      return;
    }
    setState(() {
      _marking = true;
      _errorMessage = null;
    });
    try {
      final newStreak = await _service.markHabitComplete(widget.myHabit.id);
      if (mounted) {
        _awardGamificationXp();
        setState(() {
          _completed = true;
          _marking = false;
          _newStreak = newStreak;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _marking = false;
          _errorMessage = 'Error saving: $e';
        });
      }
    }
  }

  /// Awards gamification XP for built-in habit completion.
  /// Built-in habits are separate from user habits, so allHabits is empty
  /// (perfect-day check only applies to regular user habits).
  void _awardGamificationXp() {
    final dummyHabit = Habit(
      id: widget.myHabit.id,
      iconName: 'fitness_center',
      title: widget.myHabit.name,
      colorHex: '#4E55E0',
      goalType: GoalType.cultivate,
      goalPeriod: GoalPeriod.daily,
      startDate: DateTime.now(),
      reminderEnabled: false,
      reminderTimes: [],
      completedDates: [_todayStr()],
    );
    context.read<GamificationProvider>().onHabitCompleted(
      allHabits: [],
      completedHabit: dummyHabit,
      date: DateTime.now(),
    );
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // Simulate 1000 steps (emulator / no-sensor fallback).
  void _simulateSteps() {
    setState(() {
      if (_startSteps == 0) _startSteps = 1000;
      _currentSteps = _startSteps + _stepThreshold + 50;
      _errorMessage = null;
    });
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: _completed ? _buildSuccessView() : _buildActiveView(),
    );
  }

  // ─── Active workout view ───────────────────────────────────────

  Widget _buildActiveView() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isTimer ? _buildTimerContent() : _buildPedometerContent(),
          ),
          if (_errorMessage != null) _buildErrorBanner(),
          _buildBottomAction(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_started && _isTimer && !_completed) {
                // Warn user about losing timer progress.
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: Colors.white,
                    title: const Text(
                      'Leave session?',
                      style: TextStyle(color: Colors.black),
                    ),
                    content: Text(
                      'Your timer progress will be lost and the habit will not be marked complete.',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Stay',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // close dialog
                          Navigator.pop(context); // close validator
                        },
                        child: const Text(
                          'Leave',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.myHabit.name,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Day ${widget.myHabit.completionHistory.length + 1} · ${widget.targetDurationMinutes} min',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Timer content ─────────────────────────────────────────────

  Widget _buildTimerContent() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ring
          SizedBox(
            width: 240,
            height: 240,
            child: AnimatedBuilder(
              animation: _ringAnim,
              builder: (context, anim) => CustomPaint(
                painter: _RingPainter(
                  progress: _started ? _ringAnim.value : 1.0,
                  colors: _gradient,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                        ),
                      ),
                      Text(
                        _started ? 'remaining' : 'duration',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_started)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Colors.black.withValues(alpha: 0.5),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Timer cannot be skipped',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Pedometer content ─────────────────────────────────────────

  Widget _buildPedometerContent() {
    final percent = (_stepsDone / _stepThreshold).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Step arc
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _RingPainter(progress: percent, colors: _gradient),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_stepsDone',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'steps',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _goalDisplayLabel,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.7),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(_gradient.first),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(percent * 100).toStringAsFixed(0)}% of goal',
            style: TextStyle(
              color: _gradient.first,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          // Debug raw steps
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'DEBUG: Raw Sensor Steps: $_currentSteps',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.5),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          // Simulate button (emulator/no-sensor fallback)
          if (_started && !_pedometerAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: OutlinedButton.icon(
                onPressed: _simulateSteps,
                icon: const Icon(Icons.science_outlined, size: 16),
                label: const Text('Simulate Steps (Dev Mode)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black.withValues(alpha: 0.8),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Error banner ──────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom action button ──────────────────────────────────────

  Widget _buildBottomAction() {
    if (!_started) {
      // START button
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: _GradientButton(
          label: _isTimer ? 'Start Timer' : 'Start Tracking Steps',
          icon: _isTimer ? Icons.play_arrow_rounded : Icons.directions_walk,
          colors: _gradient,
          onPressed: _isTimer ? _startTimer : _startPedometer,
        ),
      );
    }

    if (_isTimer) {
      // Timer running — show nothing (timer auto-completes)
      return const SizedBox.shrink();
    }

    // Pedometer — show COMPLETE button
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: _marking
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _GradientButton(
              label: 'Mark Complete',
              icon: Icons.check_circle_outline,
              colors: _gradient,
              onPressed: _completePedometer,
            ),
    );
  }

  // ─── Success view ──────────────────────────────────────────────

  Widget _buildSuccessView() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated checkmark container
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _gradient),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _gradient.first.withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Habit Complete! 🎉',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isTimer
                    ? 'Excellent focus! Your ${widget.targetDurationMinutes}-minute session is done.'
                    : 'Great work! You hit your step goal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.7),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Streak badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      _newStreak > 0
                          ? 'Day $_newStreak streak!'
                          : 'Streak updated!',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
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
                    'Back to My Habits',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// A gradient-filled full-width button.
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the countdown / step-progress ring.
class _RingPainter extends CustomPainter {
  final double progress; // 1.0 = full, 0.0 = empty
  final List<Color> colors;

  _RingPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 14.0;
    const startAngle = -3.14159 / 2; // 12 o'clock
    final sweepAngle = 2 * 3.14159 * progress;

    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    final shader = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: colors,
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    final fgPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.colors != colors;
}
