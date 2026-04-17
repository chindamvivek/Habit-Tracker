import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:provider/provider.dart';
import 'package:habit_tracker/gamification/gamification_provider.dart';
import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/habit_details.dart';
import 'package:habit_tracker/services/habit_plan_service.dart';

/// Full-screen validation widget for AI-generated habit plan days.
///
/// Unlike [HabitValidatorScreen] (which depends on [MyBuiltInHabit]),
/// this widget accepts plain parameters derived from the general [Habit] model
/// and [HabitPlanDay], making it fully self-contained.
///
/// - [validationType] == 'timer'     → Countdown timer (non-skippable)
/// - [validationType] == 'pedometer' → Live pedometer, marks complete on target
class HabitPlanValidator extends StatefulWidget {
  final String habitId;
  final String habitTitle;
  final Color habitColor;
  final int day;
  final String validationType;
  final int durationMinutes;
  final int? stepTarget;
  final VoidCallback onComplete;

  const HabitPlanValidator({
    super.key,
    required this.habitId,
    required this.habitTitle,
    required this.habitColor,
    required this.day,
    required this.validationType,
    required this.durationMinutes,
    this.stepTarget,
    required this.onComplete,
  });

  @override
  State<HabitPlanValidator> createState() => _HabitPlanValidatorState();
}

class _HabitPlanValidatorState extends State<HabitPlanValidator>
    with TickerProviderStateMixin {
  final HabitPlanService _service = HabitPlanService();

  // ── Shared ─────────────────────────────────────────────────────────
  bool _started = false;
  bool _completed = false;

  // ── Timer mode ─────────────────────────────────────────────────────
  Timer? _timer;
  late int _remainingSeconds;
  late AnimationController _ringController;
  late Animation<double> _ringAnim;

  // ── Pedometer mode ─────────────────────────────────────────────────
  StreamSubscription<StepCount>? _stepSub;
  int _startSteps = 0;
  int _currentSteps = 0;
  bool _pedometerAvailable = true;

  // ── Derived ────────────────────────────────────────────────────────
  bool get _isTimer => widget.validationType == 'timer';
  int get _totalSeconds => widget.durationMinutes * 60;
  int get _stepThreshold => widget.stepTarget ?? widget.durationMinutes;
  int get _stepsDone => (_currentSteps - _startSteps).clamp(0, 99999);

  static const Map<String, List<Color>> _gradients = {
    'timer': [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    'pedometer': [Color(0xFFF59E0B), Color(0xFFEF4444)],
    'self_report': [Color(0xFF10B981), Color(0xFF059669)],
  };

  List<Color> get _gradient =>
      _gradients[widget.validationType] ??
      [const Color(0xFF4E55E0), const Color(0xFF8B5CF6)];

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _totalSeconds;
    _ringController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );
    _ringAnim = Tween(begin: 1.0, end: 0.0).animate(_ringController);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stepSub?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  // ── Timer logic ────────────────────────────────────────────────────

  void _startTimer() {
    setState(() => _started = true);
    _ringController.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        _finishSession();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  // ── Pedometer logic ────────────────────────────────────────────────

  void _startPedometer() {
    setState(() => _started = true);
    _stepSub = Pedometer.stepCountStream.listen((event) {
      if (_startSteps == 0) _startSteps = event.steps;
      setState(() => _currentSteps = event.steps);
    }, onError: (_) => setState(() => _pedometerAvailable = false));
  }

  void _completePedometer() {
    if (_stepsDone < _stepThreshold) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You need $_stepThreshold steps. Current: $_stepsDone. Keep going!',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    _stepSub?.cancel();
    _finishSession();
  }

  // ── Shared finish ──────────────────────────────────────────────────

  Future<void> _finishSession() async {
    setState(() => _completed = true);
    await _service.markDayComplete(widget.habitId, widget.day);

    // ── Gamification XP hook (BUG-3 fix) ─────────────────────────────
    if (mounted) {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final dummyHabit = Habit(
        id: widget.habitId,
        iconName: 'fitness_center',
        title: widget.habitTitle,
        colorHex: '#4E55E0',
        goalType: GoalType.cultivate,
        goalPeriod: GoalPeriod.daily,
        startDate: now,
        reminderEnabled: false,
        reminderTimes: [],
        completedDates: [todayStr],
      );
      context.read<GamificationProvider>().onHabitCompleted(
        allHabits: [],
        completedHabit: dummyHabit,
        date: now,
      );
    }

    widget.onComplete();
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: _completed ? _buildSuccessView() : _buildActiveView(),
    );
  }

  Widget _buildActiveView() {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: Center(
              child: _isTimer ? _buildTimerContent() : _buildPedometerContent(),
            ),
          ),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.habitTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1D1F),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Day ${widget.day}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Timer content ──────────────────────────────────────────────────

  Widget _buildTimerContent() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final progress = _remainingSeconds / _totalSeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: AnimatedBuilder(
              animation: _ringAnim,
              builder: (_, child) => CustomPaint(
                painter: _RingPainter(
                  progress: _started ? progress : 1.0,
                  colors: _gradient,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1D1D1F),
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        _started ? 'remaining' : 'duration',
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
          ),
          const SizedBox(height: 24),
          Text(
            '${widget.durationMinutes} min session',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.7),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ── Pedometer content ──────────────────────────────────────────────

  Widget _buildPedometerContent() {
    final percent = (_stepsDone / _stepThreshold).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
            'Goal: $_stepThreshold steps',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.7),
              fontSize: 15,
            ),
          ),
          if (!_pedometerAvailable)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Pedometer unavailable on this device.',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  // ── Action bar ─────────────────────────────────────────────────────

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _gradient.first,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          onPressed: _started
              ? (_isTimer ? null : _completePedometer)
              : (_isTimer ? _startTimer : _startPedometer),
          child: Text(
            _started ? (_isTimer ? 'In Progress…' : 'Mark Complete') : 'Start',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  // ── Success view ───────────────────────────────────────────────────

  Widget _buildSuccessView() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _gradient),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '🎉 Day Complete!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Great work on Day ${widget.day}!',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gradient.first,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    int count = 0;
                    Navigator.popUntil(context, (_) => count++ >= 2);
                  },
                  child: const Text(
                    'Back to Plan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ring Painter ─────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;

  _RingPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    const strokeWidth = 12.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.grey.withValues(alpha: 0.15),
    );

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: colors).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.colors != colors;
}
