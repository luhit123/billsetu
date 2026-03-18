import 'package:billeasy/modals/customer_group.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerGroupService {
  CustomerGroupService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> _groupsCollection(String ownerId) {
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('customerGroups');
  }

  CollectionReference<Map<String, dynamic>> _clientsCollection(String ownerId) {
    return _firestore.collection('users').doc(ownerId).collection('clients');
  }

  Stream<List<CustomerGroup>> getGroupsStream() {
    final ownerId = _requireOwnerId();

    return _groupsCollection(ownerId).orderBy('nameLower').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => CustomerGroup.fromMap(doc.data(), docId: doc.id))
          .toList();
    });
  }

  Future<CustomerGroup> saveGroup(CustomerGroup group) async {
    final ownerId = _requireOwnerId();
    final now = DateTime.now();
    final docRef = group.id.trim().isNotEmpty
        ? _groupsCollection(ownerId).doc(group.id)
        : _groupsCollection(ownerId).doc();
    final previousSnapshot = group.id.trim().isNotEmpty
        ? await docRef.get()
        : null;
    final previousData = previousSnapshot?.data();
    final previousName = previousData?['name'] as String? ?? '';
    final savedGroup = group.copyWith(
      id: docRef.id,
      createdAt: group.createdAt ?? now,
      updatedAt: now,
    );

    await docRef.set(savedGroup.toMap(), SetOptions(merge: true));

    final didRenameExistingGroup =
        previousSnapshot != null &&
        previousSnapshot.exists &&
        previousName.trim() != savedGroup.name.trim();

    if (didRenameExistingGroup) {
      await _syncGroupNameOnClients(
        ownerId: ownerId,
        groupId: savedGroup.id,
        groupName: savedGroup.name,
        updatedAt: now,
      );
    }

    return savedGroup;
  }

  Future<void> _syncGroupNameOnClients({
    required String ownerId,
    required String groupId,
    required String groupName,
    required DateTime updatedAt,
  }) async {
    final snapshot = await _clientsCollection(
      ownerId,
    ).where('groupId', isEqualTo: groupId).get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'groupName': groupName,
        'updatedAt': Timestamp.fromDate(updatedAt),
      });
    }
    await batch.commit();
  }

  String _requireOwnerId() {
    final currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw StateError('Sign in is required to manage customer groups.');
    }

    return currentUser.uid;
  }
}
