/// Static game rules — never stored in Firestore, same for all users.
/// Update these only with an app release.
library;

// ─────────────────────────────────────────────────────────────────────────────
// XP RULES
// ─────────────────────────────────────────────────────────────────────────────

const int kXpPerHabit = 10;
const int kXpFirstOfDay = 5;
const int kXpStreakMilestone = 200;

const List<int> kStreakMilestones = [7, 30, 60, 100];

// ─────────────────────────────────────────────────────────────────────────────
// LEVEL DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class LevelDefinition {
  final int level;
  final String title;
  final int xpRequired; // XP needed FROM previous level to reach this level
  final int cumulativeXp; // Total lifetime XP needed to be AT this level

  const LevelDefinition({
    required this.level,
    required this.title,
    required this.xpRequired,
    required this.cumulativeXp,
  });
}

const List<LevelDefinition> kLevels = [
  LevelDefinition(level: 1, title: 'Seedling', xpRequired: 0, cumulativeXp: 0),
  LevelDefinition(
    level: 2,
    title: 'Sprout',
    xpRequired: 100,
    cumulativeXp: 100,
  ),
  LevelDefinition(
    level: 3,
    title: 'Growing',
    xpRequired: 200,
    cumulativeXp: 300,
  ),
  LevelDefinition(
    level: 4,
    title: 'Blooming',
    xpRequired: 350,
    cumulativeXp: 650,
  ),
  LevelDefinition(
    level: 5,
    title: 'Rooted',
    xpRequired: 500,
    cumulativeXp: 1150,
  ),
  LevelDefinition(
    level: 6,
    title: 'Steady',
    xpRequired: 750,
    cumulativeXp: 1900,
  ),
  LevelDefinition(
    level: 7,
    title: 'Unshaken',
    xpRequired: 1000,
    cumulativeXp: 2900,
  ),
  LevelDefinition(
    level: 8,
    title: 'Disciplined',
    xpRequired: 1500,
    cumulativeXp: 4400,
  ),
  LevelDefinition(
    level: 9,
    title: 'Iron Will',
    xpRequired: 2000,
    cumulativeXp: 6400,
  ),
  LevelDefinition(
    level: 10,
    title: 'Consistency Champion',
    xpRequired: 2500,
    cumulativeXp: 8900,
  ),
  LevelDefinition(
    level: 11,
    title: 'Habit Master',
    xpRequired: 3000,
    cumulativeXp: 11900,
  ),
  LevelDefinition(
    level: 12,
    title: 'Discipline Legend',
    xpRequired: 4000,
    cumulativeXp: 15900,
  ),
  LevelDefinition(
    level: 13,
    title: 'Unstoppable',
    xpRequired: 5000,
    cumulativeXp: 20900,
  ),
  LevelDefinition(
    level: 14,
    title: 'Mountain Mover',
    xpRequired: 6500,
    cumulativeXp: 27400,
  ),
  LevelDefinition(
    level: 15,
    title: 'Habit Guru',
    xpRequired: 8000,
    cumulativeXp: 35400,
  ),
  LevelDefinition(
    level: 16,
    title: 'Zen Master',
    xpRequired: 10000,
    cumulativeXp: 45400,
  ),
  LevelDefinition(
    level: 17,
    title: 'Enlightened',
    xpRequired: 12500,
    cumulativeXp: 57900,
  ),
  LevelDefinition(
    level: 18,
    title: 'Legendary',
    xpRequired: 15000,
    cumulativeXp: 72900,
  ),
  LevelDefinition(
    level: 19,
    title: 'Mythic',
    xpRequired: 20000,
    cumulativeXp: 92900,
  ),
  LevelDefinition(
    level: 20,
    title: 'Transcendent',
    xpRequired: 25000,
    cumulativeXp: 117900,
  ),
];

/// Returns which level the user is on given their lifetime totalXp.
LevelDefinition getLevelForXp(int totalXp) {
  LevelDefinition current = kLevels.first;
  for (final lvl in kLevels) {
    if (totalXp >= lvl.cumulativeXp) {
      current = lvl;
    } else {
      break;
    }
  }
  return current;
}

/// Returns XP accumulated WITHIN the current level (for progress bar).
int getXpWithinLevel(int totalXp) {
  final current = getLevelForXp(totalXp);
  return totalXp - current.cumulativeXp;
}

/// Returns XP needed to complete the current level (i.e. to level up).
int getXpRequiredForNextLevel(int totalXp) {
  final current = getLevelForXp(totalXp);
  if (current.level >= kLevels.length) return 0; // Max level
  final next =
      kLevels[current.level]; // kLevels is 0-indexed, level 1 = index 0
  return next.xpRequired;
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

enum BadgeCategory { streak, completion, special }

class BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final BadgeCategory category;

  /// For display only — human-readable requirement string
  final String requirementText;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.requirementText,
  });
}

const List<BadgeDefinition> kBadges = [
  // ── Streak Badges ──────────────────────────────────────────────────────────
  BadgeDefinition(
    id: 'spark',
    name: 'Spark',
    description: 'The fire has been lit',
    category: BadgeCategory.streak,
    requirementText: '3-day streak',
  ),
  BadgeDefinition(
    id: 'flame',
    name: 'Flame',
    description: 'Burning bright',
    category: BadgeCategory.streak,
    requirementText: '7-day streak',
  ),
  BadgeDefinition(
    id: 'blaze',
    name: 'Blaze',
    description: 'Nothing can stop you',
    category: BadgeCategory.streak,
    requirementText: '14-day streak',
  ),
  BadgeDefinition(
    id: 'inferno',
    name: 'Inferno',
    description: 'Unstoppable force',
    category: BadgeCategory.streak,
    requirementText: '30-day streak',
  ),
  BadgeDefinition(
    id: 'phoenix',
    name: 'Phoenix',
    description: 'Risen through consistency',
    category: BadgeCategory.streak,
    requirementText: '60-day streak',
  ),
  BadgeDefinition(
    id: 'eternal-flame',
    name: 'Eternal Flame',
    description: 'Legendary dedication',
    category: BadgeCategory.streak,
    requirementText: '100-day streak',
  ),

  // ── Completion Badges ──────────────────────────────────────────────────────
  BadgeDefinition(
    id: 'first-step',
    name: 'First Step',
    description: 'The journey begins',
    category: BadgeCategory.completion,
    requirementText: '10 total completions',
  ),
  BadgeDefinition(
    id: 'momentum-builder',
    name: 'Momentum Builder',
    description: 'Building speed',
    category: BadgeCategory.completion,
    requirementText: '100 total completions',
  ),
  BadgeDefinition(
    id: 'consistency-engine',
    name: 'Consistency Engine',
    description: 'Well-oiled machine',
    category: BadgeCategory.completion,
    requirementText: '500 total completions',
  ),
  BadgeDefinition(
    id: 'habit-machine',
    name: 'Habit Machine',
    description: 'Habits run on autopilot',
    category: BadgeCategory.completion,
    requirementText: '1,000 total completions',
  ),
  BadgeDefinition(
    id: 'legendary-grinder',
    name: 'Legendary Grinder',
    description: 'Absolute dedication',
    category: BadgeCategory.completion,
    requirementText: '5,000 total completions',
  ),

  // ── Special Badges ─────────────────────────────────────────────────────────
  BadgeDefinition(
    id: 'variety-master',
    name: 'Variety Master',
    description: 'Well-rounded',
    category: BadgeCategory.special,
    requirementText: 'Complete 10 different habits in a day',
  ),

  BadgeDefinition(
    id: 'discipline-guru',
    name: 'Discipline Guru',
    description: 'You\'ve mastered the basics',
    category: BadgeCategory.special,
    requirementText: 'Reach level 10',
  ),
  BadgeDefinition(
    id: 'habit-legend',
    name: 'Habit Legend',
    description: 'Absolute legend',
    category: BadgeCategory.special,
    requirementText: 'Reach level 20',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// BADGE HELPERS
// ─────────────────────────────────────────────────────────────────────────────

BadgeDefinition? getBadgeById(String id) {
  try {
    return kBadges.firstWhere((b) => b.id == id);
  } catch (_) {
    return null;
  }
}

String badgeCategoryLabel(BadgeCategory category) {
  switch (category) {
    case BadgeCategory.streak:
      return 'Streak Badges';
    case BadgeCategory.completion:
      return 'Completion Badges';
    case BadgeCategory.special:
      return 'Special Achievements';
  }
}
