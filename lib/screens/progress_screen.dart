import 'dart:math';
import 'package:flutter/material.dart';
import 'package:habit_tracker/gamification/gamification_data.dart';
import 'package:habit_tracker/gamification/gamification_provider.dart';
import 'package:habit_tracker/widgets/gamification/badge_tile.dart';
import 'package:habit_tracker/widgets/gamification/how_to_earn_card.dart';
import 'package:habit_tracker/widgets/gamification/level_list_item.dart';
import 'package:habit_tracker/widgets/gamification/xp_hero_card.dart';
import 'package:provider/provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;
  // Key for scrolling to current level
  final ScrollController _levelScrollController = ScrollController();
  bool _levelsExpanded = false;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _levelScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<GamificationProvider>();
    if (provider.justLeveledUp) {
      _confettiController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GamificationProvider>(
      builder: (context, provider, _) {
        // Trigger confetti when level-up fires
        if (provider.justLeveledUp && !_confettiController.isAnimating) {
          _confettiController.forward(from: 0);
        }

        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF5B6CFF)),
          );
        }

        final stats = provider.stats;
        if (stats == null) {
          return const Center(child: Text('No stats available'));
        }

        final levelDef = provider.currentLevelDef;

        return Stack(
          children: [
            // ── Main scrollable content ────────────────────────────────
            Scaffold(
              backgroundColor: const Color(0xFFF2F3F5),
              body: SafeArea(
                child: CustomScrollView(
                  slivers: [
                    // ── Header ─────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1D1D1F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your gamification journey',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Notification banners (level-up / badge) ────────
                    if (provider.justLeveledUp)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: _LevelUpBanner(
                            level: provider.levelUpNewLevel,
                            title: provider.levelUpNewTitle,
                          ),
                        ),
                      ),

                    if (provider.newlyUnlockedBadges.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                          child: Column(
                            children: provider.newlyUnlockedBadges
                                .map((b) => _BadgeUnlockBanner(badge: b))
                                .toList(),
                          ),
                        ),
                      ),

                    // ── SECTION 1: Hero XP Card ────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: XpHeroCard(
                          stats: stats,
                          levelDef: levelDef,
                          xpWithinLevel: provider.xpWithinCurrentLevel,
                          xpForNextLevel: provider.xpRequiredForNextLevel,
                          levelProgress: provider.levelProgress,
                        ),
                      ),
                    ),

                    // ── SECTION 2: Level Road ──────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Level Road',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1D1D1F),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(
                                () => _levelsExpanded = !_levelsExpanded,
                              ),
                              child: Text(
                                _levelsExpanded ? 'Show less' : 'Show all',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF5B6CFF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                        child: Column(
                          children: _buildLevelItems(levelDef.level),
                        ),
                      ),
                    ),

                    // ── SECTION 3: Badge Grid ──────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                        child: const Text(
                          'Badges',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                      ),
                    ),

                    ..._buildBadgeSections(provider),

                    // ── SECTION 4: How to Earn XP ──────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: const HowToEarnCard(),
                      ),
                    ),

                    // Bottom padding
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),

            // ── Confetti overlay (renders on top) ──────────────────────
            if (provider.justLeveledUp)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, _) => CustomPaint(
                    painter: _ConfettiPainter(_confettiController.value),
                    size: Size.infinite,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildLevelItems(int currentLevel) {
    final levelsToShow = _levelsExpanded
        ? kLevels
        : kLevels.where((l) {
            final diff = (l.level - currentLevel).abs();
            return diff <= 2 || l.level == 1 || l.level == kLevels.length;
          }).toList();

    return levelsToShow.map((lvl) {
      return LevelListItem(
        levelDef: lvl,
        isCurrentLevel: lvl.level == currentLevel,
        isUnlocked: lvl.level < currentLevel,
      );
    }).toList();
  }

  List<Widget> _buildBadgeSections(GamificationProvider provider) {
    final categories = BadgeCategory.values;
    final result = <Widget>[];

    for (final category in categories) {
      final badgesInCategory = kBadges
          .where((b) => b.category == category)
          .toList();

      // Category header
      result.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Text(
              badgeCategoryLabel(category),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8B95A7),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );

      // Grid
      result.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final badge = badgesInCategory[index];
              final unlocked = provider.getUnlockedBadge(badge.id);
              return BadgeTile(definition: badge, unlockedBadge: unlocked);
            }, childCount: badgesInCategory.length),
          ),
        ),
      );
    }

    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION BANNERS
// ─────────────────────────────────────────────────────────────────────────────

class _LevelUpBanner extends StatelessWidget {
  final int level;
  final String title;

  const _LevelUpBanner({required this.level, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B6CFF), Color(0xFF7B3FE4)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LEVEL UP!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Level $level — $title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeUnlockBanner extends StatelessWidget {
  final BadgeDefinition badge;

  const _BadgeUnlockBanner({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFE9C46A), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Badge Unlocked!',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFA0820D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  badge.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFETTI PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final Random _rng = Random(42);

  // Pre-generate confetti pieces for consistency
  static final List<_ConfettiPiece> _pieces = List.generate(80, (i) {
    return _ConfettiPiece(
      x: _rng.nextDouble(),
      startY: -0.1 - _rng.nextDouble() * 0.5,
      speed: 0.3 + _rng.nextDouble() * 0.7,
      size: 5 + _rng.nextDouble() * 6,
      color: _confettiColors[i % _confettiColors.length],
      rotation: _rng.nextDouble() * pi * 2,
      rotationSpeed: (_rng.nextDouble() - 0.5) * 4,
      sway: (_rng.nextDouble() - 0.5) * 0.05,
    );
  });

  static const List<Color> _confettiColors = [
    Color(0xFF5B6CFF),
    Color(0xFF7B3FE4),
    Color(0xFFA8DB63),
    Color(0xFFE9C46A),
    Color(0xFFE07BAA),
    Color(0xFF90CAF9),
  ];

  _ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;
    for (final piece in _pieces) {
      final t = (progress * piece.speed).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = (piece.x + piece.sway * t) * size.width;
      final y = (piece.startY + t * 1.5) * size.height;

      if (y < 0 || y > size.height) continue;

      final opacity = (1.0 - (t * 0.8)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = piece.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.rotation + piece.rotationSpeed * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 0.5,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => progress != old.progress;
}

class _ConfettiPiece {
  final double x;
  final double startY;
  final double speed;
  final double size;
  final Color color;
  final double rotation;
  final double rotationSpeed;
  final double sway;

  const _ConfettiPiece({
    required this.x,
    required this.startY,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.sway,
  });
}
