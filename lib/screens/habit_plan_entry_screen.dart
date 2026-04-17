import 'package:flutter/material.dart';
import 'package:habit_tracker/habit.dart';
import 'package:habit_tracker/services/gemini_service.dart';
import 'package:habit_tracker/services/habit_plan_service.dart';
import 'package:habit_tracker/screens/habit_plan_screen.dart';
import 'package:habit_tracker/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Smart router screen for the AI-generated 30-day habit plan.
///
/// - If no plan exists → shows the "Generate My Plan" page.
/// - If plan already exists → pushes [HabitPlanScreen] immediately.
class HabitPlanEntryScreen extends StatefulWidget {
  final Habit habit;

  const HabitPlanEntryScreen({super.key, required this.habit});

  @override
  State<HabitPlanEntryScreen> createState() => _HabitPlanEntryScreenState();
}

class _HabitPlanEntryScreenState extends State<HabitPlanEntryScreen> {
  final _planService = HabitPlanService();
  final _geminiService = GeminiService();

  _Status _status = _Status.checking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAndRoute();
  }

  Future<void> _checkAndRoute() async {
    try {
      final exists = await _planService.hasPlan(widget.habit.id);
      if (!mounted) return;
      if (exists) {
        _navigateToPlan();
      } else {
        setState(() => _status = _Status.empty);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _generate() async {
    setState(() {
      _status = _Status.generating;
      _error = null;
    });

    try {
      final result = await _geminiService.generateHabitPlan(widget.habit.title);
      await _planService.savePlan(widget.habit.id, result.days, result.links);
      if (!mounted) return;
      _navigateToPlan();
    } on ApiKeyNotSetException {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _error = 'apiKeyNotSet';
      });
    } on HabitPlanParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _error = 'AI returned invalid data:\n${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _error = 'Something went wrong:\n$e';
      });
    }
  }

  void _navigateToPlan() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HabitPlanScreen(habit: widget.habit)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Status.checking:
        return const Center(child: CircularProgressIndicator());

      case _Status.generating:
        return _buildGeneratingView();

      case _Status.empty:
        return _buildGeneratePromptView();

      case _Status.error:
        return _buildErrorView();
    }
  }

  // ─── Checking / Generating ────────────────────────────────────────────────

  Widget _buildGeneratingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (ctx, v, child) => Opacity(opacity: v, child: child),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4E55E0), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Building Your 30-Day Plan…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Our AI is crafting a personalised plan for\n"${widget.habit.title}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Generate prompt ──────────────────────────────────────────────────────

  Widget _buildGeneratePromptView() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFFF5F5F7),
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            'AI Habit Plan',
            style: TextStyle(
              color: Color(0xFF1D1D1F),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Hero illustration
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4E55E0), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        bottom: -20,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 160,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '✨ Powered by Gemini AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.habit.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '30-Day Personalised Plan',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'What you\'ll get',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 16),
                _FeatureRow(
                  icon: Icons.calendar_month_outlined,
                  title: '30 progressive daily tasks',
                  subtitle: 'Each day builds on the last',
                ),
                const SizedBox(height: 12),
                _FeatureRow(
                  icon: Icons.tips_and_updates_outlined,
                  title: 'Expert tips per day',
                  subtitle: 'Practical coaching advice',
                ),
                const SizedBox(height: 12),
                _FeatureRow(
                  icon: Icons.link_outlined,
                  title: 'Curated reference videos',
                  subtitle: 'YouTube links to learn more',
                ),
                const SizedBox(height: 12),
                _FeatureRow(
                  icon: Icons.verified_outlined,
                  title: 'Smart validation',
                  subtitle: 'Timer, pedometer or self-report per task',
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E55E0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _generate,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Generate My Plan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
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
      ],
    );
  }

  // ─── Error ────────────────────────────────────────────────────────────────

  Widget _buildErrorView() {
    final isMissingKey = _error == 'apiKeyNotSet';

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isMissingKey
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMissingKey ? Icons.key_off_rounded : Icons.error_outline,
              size: 36,
              color: isMissingKey ? Colors.orange.shade700 : Colors.red,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isMissingKey ? 'API Key Required' : 'Generation Failed',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isMissingKey
                ? 'You need to set up your Gemini API key in Settings to generate AI habit plans.'
                : _error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: isMissingKey
                      ? () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            // Wait for settings screen to pop, then check
                            // if they've saved the key and auto-retry
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SettingsScreen(user: user),
                              ),
                            );
                            _generate();
                          }
                        }
                      : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E55E0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isMissingKey ? 'Go to Settings' : 'Retry',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Status enum ──────────────────────────────────────────────────────────────

enum _Status { checking, empty, generating, error }

// ─── Feature row helper ───────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF4E55E0).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF4E55E0), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
