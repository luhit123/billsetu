import 'package:billeasy/modals/business_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  ProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  DocumentReference<Map<String, dynamic>> _profileDoc(String ownerId) {
    return _firestore.collection('users').doc(ownerId);
  }

  Stream<BusinessProfile?> watchCurrentProfile() {
    final ownerId = _requireOwnerId();

    return _profileDoc(ownerId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      return BusinessProfile.fromMap(data, ownerId: snapshot.id);
    });
  }

  Future<BusinessProfile?> getCurrentProfile() async {
    final ownerId = _requireOwnerId();
    final snapshot = await _profileDoc(ownerId).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return BusinessProfile.fromMap(data, ownerId: snapshot.id);
  }

  Future<void> saveCurrentProfile(BusinessProfile profile) async {
    final currentUser = _requireCurrentUser();

    await _profileDoc(currentUser.uid).set({
      ...profile.toMap(),
      'ownerId': currentUser.uid,
      'email': currentUser.email,
      'displayName': currentUser.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  User _requireCurrentUser() {
    final currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw StateError('Sign in is required to access your profile.');
    }

    return currentUser;
  }

  String _requireOwnerId() {
    return _requireCurrentUser().uid;
  }
}
