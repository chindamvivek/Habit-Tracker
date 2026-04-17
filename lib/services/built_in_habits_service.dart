import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habit_tracker/models/built_in_habit.dart';

/// The seed-data version. Bump this integer whenever the plan data changes.
/// On load, if the stored version in any document is less than this, all
/// builtInHabits documents are deleted and re-seeded automatically.
const int _kSeedVersion = 2;

/// Service handling all Firestore operations for the Built-in Habits feature.
/// Operates on two distinct collection paths:
///   - `builtInHabits`                          (global, read by all users)
///   - `users/{uid}/myBuiltInHabits`            (per-user, private)
class BuiltInHabitsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _builtInRef =>
      _db.collection('builtInHabits');

  CollectionReference<Map<String, dynamic>>? get _myRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('myBuiltInHabits');
  }

  // ─── Seed (with version check) ────────────────────────────────────────────

  /// Seeds (or re-seeds) the 4 built-in habits into Firestore.
  ///
  /// Version check: if the first document's `version` field is less than
  /// [_kSeedVersion], ALL existing documents are deleted and re-seeded.
  /// This ensures existing users get updated data automatically.
  Future<void> seedBuiltInHabitsIfNeeded() async {
    final snapshot = await _builtInRef.limit(1).get();

    if (snapshot.docs.isNotEmpty) {
      final storedVersion =
          (snapshot.docs.first.data()['version'] as num?)?.toInt() ?? 0;
      if (storedVersion >= _kSeedVersion) return; // Already up to date.

      // Delete all outdated documents.
      final all = await _builtInRef.get();
      final deleteBatch = _db.batch();
      for (final doc in all.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
    }

    // Write fresh seed data.
    final batch = _db.batch();
    for (final habit in _seedData()) {
      final docRef = _builtInRef.doc(habit.id);
      batch.set(docRef, {...habit.toMap(), 'version': _kSeedVersion});
    }
    await batch.commit();
  }

  // ─── Built-in Collection ──────────────────────────────────────────────────

  /// Returns all four built-in habit definitions from the global collection.
  Future<List<BuiltInHabit>> getBuiltInHabits() async {
    final snapshot = await _builtInRef.get();
    return snapshot.docs
        .map((doc) => BuiltInHabit.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ─── User's Selected Habits ───────────────────────────────────────────────

  /// Streams the habits the current user has started.
  Stream<List<MyBuiltInHabit>> getMyBuiltInHabitsStream() {
    final ref = _myRef;
    if (ref == null) return Stream.value([]);

    return ref.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => MyBuiltInHabit.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  /// Starts a built-in habit for the current user.
  /// Creates the document under `users/{uid}/myBuiltInHabits/{habitId}`.
  Future<void> startBuiltInHabit(BuiltInHabit habit) async {
    final ref = _myRef;
    if (ref == null) return;

    final existing = await ref.doc(habit.id).get();
    if (existing.exists) return; // Already started — do nothing.

    final myHabit = MyBuiltInHabit(
      id: habit.id,
      name: habit.name,
      validationType: habit.validationType,
      defaultDurationMinutes: habit.defaultDurationMinutes,
    );

    await ref.doc(habit.id).set({
      ...myHabit.toMap(),
      'startedAt': FieldValue.serverTimestamp(),
      'lastCompletedDate': null,
    });
  }

  /// Returns a single `MyBuiltInHabit` document for the current user, or null.
  Future<MyBuiltInHabit?> getMyHabit(String habitId) async {
    final ref = _myRef;
    if (ref == null) return null;

    final doc = await ref.doc(habitId).get();
    if (!doc.exists) return null;
    return MyBuiltInHabit.fromMap(doc.data()!, doc.id);
  }

  /// Marks a habit complete for today, updates streak and completion history.
  /// Returns the new streak value so the UI can display it immediately.
  Future<int> markHabitComplete(String habitId) async {
    final ref = _myRef;
    if (ref == null) return 0;

    final doc = await ref.doc(habitId).get();
    if (!doc.exists) return 0;

    final habit = MyBuiltInHabit.fromMap(doc.data()!, doc.id);
    final todayStr = _todayStr();

    // Guard: already completed today.
    if (habit.completionHistory.contains(todayStr)) {
      return habit.currentStreak;
    }

    // BUG-7 fix: allow a 1-day grace window for streak continuation.
    // Check yesterday and the day before yesterday.
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dayBeforeYesterday = DateTime.now().subtract(const Duration(days: 2));
    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final yesterdayStr = fmtDate(yesterday);
    final dayBeforeStr = fmtDate(dayBeforeYesterday);

    final continuesStreak =
        habit.completionHistory.contains(yesterdayStr) ||
        habit.completionHistory.contains(dayBeforeStr);
    final newStreak = continuesStreak ? habit.currentStreak + 1 : 1;

    final newHistory = [...habit.completionHistory, todayStr];

    await ref.doc(habitId).update({
      'currentStreak': newStreak,
      'lastCompletedDate': FieldValue.serverTimestamp(),
      'completionHistory': newHistory,
    });

    return newStreak;
  }

  /// Checks if this habit has already been completed today.
  Future<bool> isCompletedToday(String habitId) async {
    final ref = _myRef;
    if (ref == null) return false;

    final doc = await ref.doc(habitId).get();
    if (!doc.exists) return false;

    final habit = MyBuiltInHabit.fromMap(doc.data()!, doc.id);
    return habit.completionHistory.contains(_todayStr());
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ─── Seed Data ────────────────────────────────────────────────────────────

  List<BuiltInHabit> _seedData() {
    return [_meditationHabit(), _yogaHabit(), _walkingHabit(), _runningHabit()];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MEDITATION — timer-based, progressive minutes (5→10→15→20→25)
  // ══════════════════════════════════════════════════════════════════════════

  BuiltInHabit _meditationHabit() {
    /// Returns the timer duration in minutes for a given day.
    int dur(int day) {
      if (day <= 6) return 5;
      if (day <= 13) return 10;
      if (day <= 20) return 15;
      if (day <= 27) return 20;
      return 25;
    }

    final tasks = [
      // Day 1 – 6 · 5 min
      'Sit comfortably, close your eyes, and focus entirely on your natural breath for 5 minutes.',
      'Follow your breath in and out. When your mind wanders, gently return to the breath.',
      'Count each exhale from 1 to 10, then start again. Notice the gaps between breaths.',
      'Try box breathing: inhale 4 s, hold 4 s, exhale 4 s, hold 4 s — for 5 minutes.',
      'Simply observe sounds in your environment without labeling them. Just listen.',
      'Rest your attention lightly on the sensations of breathing at the tip of your nose.',
      // Day 7 – 13 · 10 min
      'Begin a slow body scan: start at your feet, notice sensations, move up to your head.',
      'Scan each body part for 30 seconds. Release tension on every exhale.',
      'Focus on areas of tightness — breathe warmth into them without forcing anything.',
      'Mentally soften your forehead, jaw, shoulders, and hands as you scan.',
      'Alternate between breath awareness and body sensations every 2 minutes.',
      'Close with 2 minutes of simple breath-following after the full body scan.',
      'Combine body scan with 4-7-8 breathing (inhale 4, hold 7, exhale 8).',
      // Day 14 – 20 · 15 min
      'Loving-kindness meditation: silently repeat "May I be happy, may I be healthy, may I be at peace."',
      'Extend the phrases to someone you love: "May you be happy, may you be healthy…"',
      'Send loving-kindness to a neutral person — a stranger you saw today.',
      'Now send it to a difficult person in your life. Notice any resistance.',
      'Radiate loving-kindness outward in all directions — your street, city, world.',
      'Alternate loving-kindness with 5 minutes of breath awareness to anchor the practice.',
      'Let loving-kindness and simple awareness blend. Rest in open, warm presence.',
      // Day 21 – 27 · 20 min
      'Open-awareness: let go of any object of focus. Notice whatever arises — sound, sensation, thought.',
      'Thoughts are clouds; awareness is the sky. Watch them pass without following.',
      'Notice the brief silence between two thoughts. Rest in that gap as long as you can.',
      'Alternate 5 min breath, 5 min body scan, 5 min loving-kindness, 5 min open awareness.',
      'Stay with pure awareness for the full 20 minutes. Return gently each time you drift.',
      'Notice how awareness is already present — you do not need to create it.',
      'Sit with the question "Who is aware?" Rest in presence, not in an answer.',
      // Day 28 – 30 · 25 min
      'Complete integration: start with breath (5 min) → body scan (5 min) → loving-kindness (5 min) → open awareness (10 min).',
      'Move freely between techniques based on what feels alive. Trust your inner compass.',
      'Sit in pure stillness for 25 minutes. You have built a real meditation practice. Celebrate.',
    ];

    final tips = [
      'Find a quiet spot and sit with your spine tall but not rigid.',
      'Close your eyes and breathe naturally — no need to control the breath.',
      "Don't fight thoughts — just observe them, then return.",
      'Use a gentle alarm so you are not watching the clock.',
      'Morning meditation sets a calm tone for the entire day.',
      'Consistency matters far more than perfect stillness.',
      'Scan slowly — there is no hurry. You have 10 minutes.',
      'Notice sensations without labeling them as good or bad.',
      'Release tension on the exhale, not by forcing.',
      'Progressive relaxation helps ease physical stress.',
      'Smile slightly — it activates a calm nervous system response.',
      'Return gently when distracted — that return IS the practice.',
      'End with a moment of gratitude for the time you just gave yourself.',
      'Place one hand on your heart as you say the loving-kindness phrases.',
      'Feel a warm glow in your chest when repeating the phrases.',
      'Include yourself in your circle of compassion — always.',
      'Compassion for difficult people does not mean you condone their actions.',
      'Even 20 seconds of kind intention is powerful.',
      'The phrases are seeds — plant them without expecting immediate flowers.',
      'Kindness to self flows outward naturally. Start there.',
      'Let thoughts arrive and depart like guests — welcome but not permanent.',
      'The sky never moves even though clouds constantly cross it.',
      'Rest in the gap between heartbeats. Rest in the gap between thoughts.',
      'There is nowhere to get to — you are already here.',
      'Awareness does not come and go. Only its objects do.',
      'The sense of "I am aware" is already the answer.',
      'You are the observer — vast, open, undisturbed.',
      'Carry this spaciousness silently through your day.',
      'Share your calm presence — it is the best gift you can give.',
      'Congratulations — 30 days! You have built a real meditation habit.',
    ];

    return BuiltInHabit(
      id: 'meditation',
      name: 'Meditation',
      description:
          'Cultivate inner peace and mental clarity through daily mindfulness practice.',
      category: 'Mindfulness',
      iconName: 'self_improvement',
      validationType: 'timer',
      defaultDurationMinutes: 10,
      thirtyDayPlan: List.generate(30, (i) {
        final day = i + 1;
        return ThirtyDayPlanEntry(
          day: day,
          durationMinutes: dur(day),
          taskDescription: tasks[i],
          tip: tips[i],
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // YOGA — timer-based, per-day unique pose guidance
  // Week 1: Standing · Week 2: Seated · Week 3: Balance · Week 4: Full flow
  // ══════════════════════════════════════════════════════════════════════════

  BuiltInHabit _yogaHabit() {
    int dur(int day) {
      if (day <= 7) return 10;
      if (day <= 14) return 15;
      if (day <= 21) return 20;
      return 25;
    }

    final tasks = [
      // ── Week 1: Standing Poses (10 min) ──────────────────────────────────
      // Day 1
      'Mountain Pose (Tadasana) — Beginner · Targets: posture & full body awareness.\n'
          'Stand with feet hip-width apart, arms at sides, spine tall. Press all four corners of each foot into the floor. Breathe deeply and hold for 8–10 breaths.',
      // Day 2
      'Forward Fold (Uttanasana) — Beginner · Targets: hamstrings & lower back.\n'
          'From Mountain Pose, exhale and hinge at the hips, folding forward. Let your head hang heavy and bend your knees slightly if needed. Hold for 8 breaths, releasing tension with each exhale.',
      // Day 3
      'Warrior I (Virabhadrasana I) — Beginner · Targets: legs, hips & shoulders.\n'
          'Step your left foot back into a lunge, front knee over ankle. Raise arms overhead, palms face each other. Square your hips forward and hold for 5 breaths each side.',
      // Day 4
      'Warrior II (Virabhadrasana II) — Beginner · Targets: legs, hips & core.\n'
          'From Warrior I, open your hips and arms wide — front arm forward, back arm behind. Gaze over your front fingers. Hold 5 breaths each side, keeping the front knee over the ankle.',
      // Day 5
      'Triangle Pose (Trikonasana) — Beginner · Targets: side body, hamstrings & hips.\n'
          'Stand with feet wide, turn right foot out 90°. Reach right arm down to shin or block, left arm to sky. Keep both legs straight and chest open. Hold 5 breaths each side.',
      // Day 6
      'Chair Pose (Utkatasana) — Beginner · Targets: quads, glutes & core.\n'
          'Feet together, bend your knees as if sitting back into a chair. Arms reach up alongside ears. Keep weight in your heels and hold for 6–8 breaths. Feel your thighs burn.',
      // Day 7
      'Standing Side Stretch — Beginner · Targets: obliques & spine.\n'
          'Stand in Mountain Pose. Inhale, reach right arm overhead, exhale and lean to the left creating a long arc with your body. Hold 5 breaths each side. Return to centre on each inhale.',

      // ── Week 2: Seated Poses (15 min) ────────────────────────────────────
      // Day 8
      'Staff Pose + Seated Forward Fold (Dandasana / Paschimottanasana) — Beginner · Targets: spine & hamstrings.\n'
          'Sit with legs straight, spine tall. On an exhale, hinge forward from the hips and reach for your feet or shins. Hold for 8 breaths. Inhale to lengthen, exhale to deepen.',
      // Day 9
      'Butterfly Pose (Baddha Konasana) — Beginner · Targets: inner thighs & hips.\n'
          'Sit with soles of feet together, knees dropped to sides. Hold your feet, sit tall and gently flutter your knees. For a deeper stretch, fold forward from the hips for 6 breaths.',
      // Day 10
      'Seated Spinal Twist (Ardha Matsyendrasana) — Beginner · Targets: spine & outer hips.\n'
          'Sit with legs extended. Cross your right foot over your left knee. Inhale to lengthen, exhale and twist right, placing your left elbow outside your right knee. Hold 5 breaths each side.',
      // Day 11
      'Cat-Cow Flow (Marjaryasana-Bitilasana) — Beginner · Targets: spine mobility.\n'
          'On hands and knees, tabletop position. Inhale — drop belly, lift chest and tailbone (Cow). Exhale — round spine to the sky, tuck chin and tailbone (Cat). Flow for 10 rounds.',
      // Day 12
      'Child\'s Pose + Puppy Pose — Beginner · Targets: lower back, shoulders & hips.\n'
          'From tabletop, widen your knees and sink your hips to your heels, arms extended forward (Puppy Pose — 5 breaths). Then pull hips fully to heels for Child\'s Pose (5 breaths). Breathe into your back.',
      // Day 13
      'Bridge Pose (Setu Bandha Sarvangasana) — Beginner · Targets: glutes, hamstrings & lower back.\n'
          'Lie on your back, feet flat and hip-width apart. Press into your feet and lift your hips to form a straight line. Interlace hands under your back. Hold 6–8 breaths. Lower slowly on an exhale.',
      // Day 14
      'Seated Sequence: Staff → Forward Fold → Butterfly → Twist (each side) — Beginner/Intermediate · Targets: full lower body & spine.\n'
          'Flow through all four seated poses, spending 3 breaths in each. Move with your breath — inhale to lengthen, exhale to deepen. End in Child\'s Pose for 5 breaths.',

      // ── Week 3: Balance Poses (20 min) ───────────────────────────────────
      // Day 15
      'Tree Pose (Vrksasana) — Intermediate · Targets: balance, ankles & focus.\n'
          'Stand on your right foot. Place your left foot on your calf or inner thigh (not the knee). Hands at heart or raised overhead. Fix your gaze on a still point. Hold 6 breaths each side.',
      // Day 16
      'Warrior III (Virabhadrasana III) — Intermediate · Targets: balance, hamstrings & core.\n'
          'From Mountain Pose, shift weight to your right foot. Hinge forward and lift your left leg back, forming a T-shape. Arms can reach forward. Hold 4 breaths each side. Keep the core engaged.',
      // Day 17
      'Eagle Pose (Garudasana) — Intermediate · Targets: balance, shoulders & outer hips.\n'
          'Bend your knees slightly. Cross your right thigh over the left. Wrap your right foot behind the left calf. Wrap your right arm under the left, palms touching. Sit deeper. Hold 5 breaths each side.',
      // Day 18
      'Half Moon Pose (Ardha Chandrasana) — Intermediate · Targets: balance, hip abductors & core.\n'
          'From Triangle, bend the front knee, shift weight forward, and lift the back leg parallel to the floor. Open your chest and stack your hips. Use a block under your hand if needed. Hold 4 breaths each side.',
      // Day 19
      'Dancer Pose (Natarajasana) — Intermediate · Targets: balance, chest & hip flexors.\n'
          'Stand on your right foot. Bend your left knee and hold the inner ankle behind you. Kick the foot back and up while reaching your right arm forward. Hold 4 breaths each side. Gaze fixed ahead.',
      // Day 20
      'Plank + Side Plank (Vasisthasana) — Intermediate · Targets: core, arms & balance.\n'
          'Hold High Plank for 5 breaths. Rotate to Side Plank on the right hand, feet stacked or staggered, left arm to sky. Hold 4 breaths. Return to Plank, then switch sides. Keep hips lifted throughout.',
      // Day 21
      'Balance Flow: Tree → Warrior III → Eagle → Side Plank (each side) — Intermediate · Targets: total body balance & core.\n'
          'Flow through each balance pose spending 3 breaths per pose, each side. Move mindfully and breathe through the wobbles. End with 3 minutes of Savasana.',

      // ── Week 4: Full Flow Sequences (25 min) ──────────────────────────────
      // Day 22
      'Sun Salutation A (Surya Namaskar A) × 4 rounds — Intermediate · Targets: full body warmup.\n'
          'Start in Mountain Pose. Inhale — arms up. Exhale — Forward Fold. Inhale — Half Lift. Exhale — Plank → Chaturanga. Inhale — Upward Dog. Exhale — Downward Dog (5 breaths). Repeat 4 times.',
      // Day 23
      'Sun Salutation B (Surya Namaskar B) × 3 rounds — Intermediate · Targets: full body strength & flexibility.\n'
          'Add Chair Pose and Warrior I to Sun Salutation A. Inhale — Chair. Exhale — Forward Fold. Inhale — Half Lift. Exhale — Plank → Chaturanga → Updog → Downdog. Step to Warrior I (each side), then finish. Repeat 3 times.',
      // Day 24
      'Power Sequence: Warrior I → Warrior II → Reverse Warrior → Triangle → Side Angle (each side, 4 breaths each) — Intermediate · Targets: legs, hips & lateral strength.\n'
          'Flow through the five standing poses on one side without stopping, synchronising movement with breath. Repeat the full sequence on the second side. Rest in Child\'s Pose between sides.',
      // Day 25
      'Core Flow: Boat Pose (Navasana) + Leg Lowers + Bicycle Crunches — Intermediate · Targets: deep core & hip flexors.\n'
          'Sit in Boat Pose for 5 breaths. Lower legs slowly to 45° and hold 3 breaths. Alternate elbow-to-knee bicycle for 20 reps. Rest then repeat twice. Finish with Bridge Pose for 5 breaths.',
      // Day 26
      'Hip-Opening Flow: Low Lunge → Lizard Pose → Pigeon Pose (each side, hold 6 breaths each) — Intermediate · Targets: deep hip flexors, glutes & groin.\n'
          'From Downward Dog, step your right foot to Low Lunge. Walk the foot out wide to Lizard (elbows to floor if able). Slide back to Sleeping Pigeon, fold over the front shin. Repeat left side.',
      // Day 27
      'Backbend Sequence: Bridge → Wheel (Urdhva Dhanurasana) × 2 + Camel (Ustrasana) — Intermediate · Targets: spine extension, chest & hip flexors.\n'
          'Warm up with 2 rounds of Bridge Pose (6 breaths each). Plant hands by your shoulders and press into Wheel for 5 breaths if able — otherwise stay in Bridge. Transition to kneeling and try Camel. End in Child\'s Pose.',
      // Day 28
      'Yin Sequence: Butterfly → Dragonfly → Supine Twist (hold each 2–3 minutes) — Intermediate · Targets: deep connective tissue, hips & spine.\n'
          'Move slowly into each pose and surrender to gravity rather than forcing. Breathe into resistance. This is a restorative session — no muscular effort needed. End with 5 minutes of Savasana.',
      // Day 29
      'Full 25-min Flow: Salutation A × 2 → Power Sequence → Balance Pose → Hip Opener → Savasana — Intermediate · Targets: full body integration.\n'
          'Combine the techniques from all four weeks into one seamless session. Move intuitively — let your breath lead. End with 4 minutes of Savasana, feeling the work you have done.',
      // Day 30
      'Celebration Flow — Your Choice — Intermediate · Targets: everything.\n'
          'Pick your favourite poses from the 30 days and create your own 25-minute sequence. Begin with Sun Salutations and end in Savasana. You have built a genuine yoga practice. Honour that.',
    ];

    final tips = [
      'Use a non-slip mat and practice barefoot for better grip.',
      'Never force a stretch — breathe into resistance and let it release.',
      'Sink the back heel toward the floor rather than lifting it.',
      'Keep the front shin vertical — knee directly over ankle.',
      'Use a yoga block under your bottom hand if needed.',
      'Engage your core to protect your lower back in every pose.',
      'A slight bend in the knee prevents hyperextension.',
      'Hinge from the hips — not the waist — for all forward folds.',
      'Pair each inhale with length, each exhale with depth.',
      'Never twist from the lower back — initiate the twist from the navel up.',
      'The breath should remain smooth. If you gasp, come out slightly.',
      'Child\'s Pose is always a valid rest — use it whenever you need.',
      'Bridge strengthens the posterior chain as well as opening the front body.',
      'Move at a pace where breath leads movement, never the other way around.',
      'Fix your gaze (drishti) on a still point to hold balance poses longer.',
      'Micro-bend the standing knee to protect the joint in balance poses.',
      'Wrapping the arms in Eagle compresses the shoulders — release is the stretching moment.',
      'Keep your standing hip from swinging outward in Half Moon.',
      'The more you kick back in Dancer, the more you can reach forward.',
      'Keep your body in one straight plank line from head to heels.',
      'Wobbling is part of balance — smile through it.',
      'Land toe-ball-heel in each lunge to protect the knee.',
      'In Chair Pose (Sun Sal B), keep the knees directly over the toes.',
      'Move through the warrior sequence without resting — build endurance.',
      'Exhale fully during exertion — this is what engages the deep core.',
      'Pigeon Pose can be intense — breathe slowly and you will open.',
      'Always warm up with Bridge before attempting Wheel.',
      'In Yin yoga, you should feel a mild, dull ache — never sharp pain.',
      'Your body is different every day — honour exactly where you are today.',
      '30 days of yoga! Your flexibility, strength and focus have all grown. Well done.',
    ];

    return BuiltInHabit(
      id: 'yoga',
      name: 'Yoga',
      description:
          'Build flexibility, strength, and balance through mindful movement.',
      category: 'Fitness',
      iconName: 'accessibility_new',
      validationType: 'timer',
      defaultDurationMinutes: 20,
      thirtyDayPlan: List.generate(30, (i) {
        final day = i + 1;
        return ThirtyDayPlanEntry(
          day: day,
          durationMinutes: dur(day),
          taskDescription: tasks[i],
          tip: tips[i],
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WALKING — pedometer-based, step goals stored in durationMinutes
  // Progressive: 500 → 1000 → 1500 → 2000 → 2500 → 3000 → 5000 → 7000 → 10000
  // ══════════════════════════════════════════════════════════════════════════

  BuiltInHabit _walkingHabit() {
    /// Step target for a given day — stored in durationMinutes field.
    int steps(int day) {
      if (day <= 3) return 500;
      if (day <= 6) return 1000;
      if (day <= 9) return 1500;
      if (day <= 12) return 2000;
      if (day <= 16) return 2500;
      if (day <= 20) return 3000;
      if (day <= 23) return 5000;
      if (day <= 26) return 7000;
      return 10000;
    }

    String task(int day) {
      final s = steps(day);
      if (day <= 3) {
        return 'Goal: $s steps — Easy stroll. Walk at your natural pace in a comfortable spot. Focus on good posture: head up, shoulders relaxed.';
      }
      if (day <= 6) {
        return 'Goal: $s steps — Steady walk. Pick a consistent route. Swing your arms naturally to engage your core and maintain rhythm.';
      }
      if (day <= 9) {
        return 'Goal: $s steps — Brisk walk. Aim for 100 steps per minute. You should be able to speak in sentences but feel slightly out of breath.';
      }
      if (day <= 12) {
        return 'Goal: $s steps — Brisk walk with intention. Focus on heel-to-toe foot strike and a tall spinal posture throughout. Push gently past comfort.';
      }
      if (day <= 16) {
        return 'Goal: $s steps — Interval walk. Alternate 2 minutes brisk pace with 1 minute slow pace. This trains your cardiovascular system more efficiently.';
      }
      if (day <= 20) {
        return 'Goal: $s steps — Power walk. Drive your arms more forcefully and lengthen your stride. Keep the core lightly engaged throughout.';
      }
      if (day <= 23) {
        return 'Goal: $s steps — High-step day. Find a longer route with some gentle hills if possible. Take breaks only if truly necessary.';
      }
      if (day <= 26) {
        return 'Goal: $s steps — Extended power walk. Split into two sessions if needed (morning + evening). Track your favourite route and try to beat your pace.';
      }
      return 'Goal: $s steps — 10,000 steps! The gold-standard daily target. Walk continuously or across multiple short sessions. You\'ve earned this milestone.';
    }

    final tips = [
      'Wear comfortable, well-fitting shoes — your feet will thank you.',
      'Swing your arms naturally to engage your core and improve balance.',
      'Walk in nature when possible — it reduces stress and lifts mood.',
      'Posture check: head up, chest open, shoulders away from ears.',
      'Start 5 minutes slower than you think you need to — warm up properly.',
      'Listening to music or a podcast makes every walk more enjoyable.',
      'Track your steps with your phone or a fitness band.',
      'At 100 steps/min you\'re at a brisk, cardio-beneficial pace.',
      'Try a new route to keep your brain engaged and your feet exploring.',
      'A walking buddy doubles accountability and enjoyment.',
      'Hydrate before long walks, especially in warm weather.',
      'Alternate fast and slow every 2 minutes for interval benefits.',
      'Interval training improves cardiovascular fitness 25% faster.',
      'Focus on heel-to-toe foot strike to protect your joints.',
      'Power walking burns more calories per km than casual walking.',
      'Keep your core gently braced — it protects your lower back.',
      'Notice your surroundings mindfully — walking is a great meditation.',
      'Push slightly beyond today\'s comfort zone. That is growth.',
      'Celebrate 2,500-step days — that is 25% of the gold standard!',
      'Stretch your calves and hip flexors for 2 minutes after each walk.',
      'A gentle incline (stairs or hill) adds 30% more caloric burn.',
      'Your legs are measurably stronger than on Day 1. Feel it.',
      'Stretch calves, hamstrings and quads after these longer walks.',
      'Walking after meals aids digestion and regulates blood sugar.',
      'You have built a powerful, evidence-backed daily movement habit.',
      'Focus on distance covered, not just step count or time.',
      'Even bad-weather days count — find a covered route or walk indoors.',
      'Notice how much lighter and more energised you feel after walking.',
      'Share this habit with a friend or family member who needs it.',
      '30 days! 10,000 steps is now your daily baseline. You are a walker.',
    ];

    return BuiltInHabit(
      id: 'walking',
      name: 'Walking',
      description:
          'Improve cardiovascular health with daily brisk walking sessions.',
      category: 'Cardio',
      iconName: 'directions_walk',
      validationType: 'stepCounter',
      defaultDurationMinutes: 500, // Day 1 default
      thirtyDayPlan: List.generate(30, (i) {
        final day = i + 1;
        return ThirtyDayPlanEntry(
          day: day,
          durationMinutes: steps(day),
          taskDescription: task(day),
          tip: tips[i],
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RUNNING — pedometer-based, km goals converted to steps (km × 1312)
  // durationMinutes stores the integer step count.
  // The km label is embedded in the task description.
  // ══════════════════════════════════════════════════════════════════════════

  BuiltInHabit _runningHabit() {
    /// Kilometre goal for a given day.
    double km(int day) {
      if (day <= 3) return 1.0;
      if (day <= 6) return 1.5;
      if (day <= 9) return 2.0;
      if (day <= 12) return 2.5;
      if (day <= 16) return 3.0;
      if (day <= 20) return 3.5;
      if (day <= 24) return 4.0;
      if (day <= 27) return 4.5;
      return 5.0;
    }

    /// Step conversion: 1 km = 1312 average steps.
    int stepsFor(int day) => (km(day) * 1312).round();

    String task(int day) {
      final k = km(day);
      final kStr = k == k.truncateToDouble() ? '${k.toInt()}.0' : '$k';
      if (day <= 3) {
        return 'Goal: $kStr km — Run/walk intervals. Alternate 1 min running with 2 min walking until you reach your distance goal. Focus on relaxed form, not speed.';
      }
      if (day <= 6) {
        return 'Goal: $kStr km — Easy jog. Keep a conversational pace — you should be able to say a full sentence. Land midfoot and keep your shoulders relaxed.';
      }
      if (day <= 9) {
        return 'Goal: $kStr km — Steady jog. Maintain a consistent pace throughout. Breathe rhythmically: 2 steps in, 2 steps out. Warm up with 2 min brisk walk first.';
      }
      if (day <= 12) {
        return 'Goal: $kStr km — Comfortable run. You should feel challenged but controlled. Aim for 160–170 steps per minute. Cool down with a 2-min walk and stretch.';
      }
      if (day <= 16) {
        return 'Goal: $kStr km — Fartlek run. Vary your speed naturally — surge for 30 seconds whenever you pass a landmark, then ease back. This builds speed endurance.';
      }
      if (day <= 20) {
        return 'Goal: $kStr km — Tempo run. Run at a "comfortably hard" effort — you can speak in short phrases but not hold a conversation. Builds your lactate threshold.';
      }
      if (day <= 24) {
        return 'Goal: $kStr km — Long easy run. Slow down by 60–90 seconds per km compared to normal pace. The distance is the work. Stay hydrated throughout.';
      }
      if (day <= 27) {
        return 'Goal: $kStr km — Progressive run. Start easy (first km), build to moderate (middle km), finish strong (last km). Cool down thoroughly afterwards.';
      }
      return 'Goal: $kStr km — Peak run! This is your 30-day distance milestone. Run at a pace you can sustain the whole way. Celebrate your achievement at the finish.';
    }

    final tips = [
      'Alternate 1 min run / 2 min walk — this is how beginners build endurance safely.',
      'Land midfoot, not on your heel. It reduces impact forces significantly.',
      'Keep your pace conversational at first — speed comes later.',
      'Warm up with 2 minutes of brisk walking before every run.',
      'Cool down and stretch hamstrings, calves and hip flexors after each session.',
      'Rest days prevent injury — honour them as much as run days.',
      'Your body is adapting. Slight muscle soreness is normal and good.',
      'Increase weekly distance by no more than 10% to avoid overuse injuries.',
      'Easy runs should feel truly easy — resist the urge to push.',
      'Focus on time on your feet and distance, not pace.',
      'Run with relaxed shoulders, soft hands and a forward gaze.',
      'Rhythmic breathing: try 2 steps inhale, 2 steps exhale.',
      'Fartlek is Swedish for "speed play" — make it feel like a game.',
      'Consistency over speed — always. Slow runners who show up beat fast ones who don\'t.',
      'Notice how your recovery heart rate has improved since Day 1.',
      'Cadence goal: ~170 steps per minute for optimal efficiency.',
      'Short, quick strides are more efficient than long, slow ones.',
      'Stay hydrated — drink 250 ml water 30 min before longer runs.',
      'Listen carefully: soreness fades within 24 h. Pain that lingers is a warning.',
      'A rest day today prevents a rest month later.',
      'Tempo pace = comfortably hard. You can speak in 3–4 word phrases.',
      'Tempo runs are the single biggest tool for improving race performance.',
      'Long runs build aerobic capacity, mental toughness and fat-burning efficiency.',
      'A progressive run teaches your legs to run fast when already fatigued.',
      'You are faster and stronger than you were on Day 1 — believe it.',
      'Protein within 30 minutes of running aids muscle repair and recovery.',
      'Sleep is when your running adaptations actually occur. Prioritise it.',
      'Mental toughness is built one kilometre at a time. You have it now.',
      'You have proven you are a runner. 4.5 km is a genuine achievement.',
      '30 days and 5 km complete! Your running journey is just beginning.',
    ];

    return BuiltInHabit(
      id: 'running',
      name: 'Running',
      description:
          'Boost stamina and endurance with progressive running workouts.',
      category: 'Cardio',
      iconName: 'directions_run',
      validationType: 'stepCounter',
      defaultDurationMinutes: 1312, // Day 1 default: 1.0 km
      thirtyDayPlan: List.generate(30, (i) {
        final day = i + 1;
        return ThirtyDayPlanEntry(
          day: day,
          durationMinutes: stepsFor(day),
          taskDescription: task(day),
          tip: tips[i],
        );
      }),
    );
  }
}
