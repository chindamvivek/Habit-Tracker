import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:habit_tracker/habit.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get Habits Stream
  Stream<List<Habit>> getHabitsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('habits')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Habit.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  // Add Habit
  Future<void> addHabit(Habit habit) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = habit.toMap();
    data['userId'] = user.uid;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await _db.collection('habits').add(data);
  }

  // Update Habit
  Future<void> updateHabit(Habit habit) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = habit.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await _db.collection('habits').doc(habit.id).update(data);
  }

  // Delete Habit (and its AI-generated plan subcollection, if any)
  Future<void> deleteHabit(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Firestore does NOT cascade-delete subcollections, so we must
    // explicitly delete all `plan/` documents before removing the habit.
    final planSnap = await _db
        .collection('habits')
        .doc(id)
        .collection('plan')
        .get();

    if (planSnap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in planSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await _db.collection('habits').doc(id).delete();
  }

  // (toggleCompletion was removed — it was an empty stub never called anywhere)

  // --- User Profile Methods ---

  // Save User Name
  Future<void> saveUserName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).set({
      'name': name,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get User Name
  Future<String?> getUserName() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!['name'] as String?;
    }
    return null;
  }

  // Check if User Has Profile (name set)
  Future<bool> userHasProfile() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.exists && doc.data() != null && doc.data()!['name'] != null;
  }
}
