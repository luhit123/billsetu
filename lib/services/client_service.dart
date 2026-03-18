import 'package:billeasy/modals/client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientService {
  ClientService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> _clientsCollection(String ownerId) {
    return _firestore.collection('users').doc(ownerId).collection('clients');
  }

  Stream<List<Client>> getClientsStream({
    String searchQuery = '',
    String? groupId,
  }) {
    final ownerId = _requireOwnerId();
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final normalizedGroupId = groupId?.trim() ?? '';

    Query<Map<String, dynamic>> query = _clientsCollection(
      ownerId,
    ).orderBy('nameLower');

    if (normalizedQuery.isNotEmpty) {
      query = query.startAt([normalizedQuery]).endAt([
        '$normalizedQuery\uf8ff',
      ]);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Client.fromMap(doc.data(), docId: doc.id))
          .where((client) {
            if (normalizedGroupId.isEmpty) {
              return true;
            }

            if (normalizedGroupId == '__ungrouped__') {
              return client.groupId.trim().isEmpty;
            }

            return client.groupId == normalizedGroupId;
          })
          .toList();
    });
  }

  Stream<Client?> watchClient(String clientId) {
    final ownerId = _requireOwnerId();
    return _clientsCollection(ownerId).doc(clientId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }

      return Client.fromMap(data, docId: snapshot.id);
    });
  }

  Future<Client?> getClient(String clientId) async {
    final ownerId = _requireOwnerId();
    final snapshot = await _clientsCollection(ownerId).doc(clientId).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return Client.fromMap(data, docId: snapshot.id);
  }

  Future<Client> saveClient(Client client) async {
    final ownerId = _requireOwnerId();
    final now = DateTime.now();
    final docRef = client.id.trim().isNotEmpty
        ? _clientsCollection(ownerId).doc(client.id)
        : _clientsCollection(ownerId).doc();
    final savedClient = client.copyWith(
      id: docRef.id,
      createdAt: client.createdAt ?? now,
      updatedAt: now,
    );

    await docRef.set(savedClient.toMap(), SetOptions(merge: true));
    return savedClient;
  }

  Future<Client> updateClientGroup({
    required Client client,
    required String groupId,
    required String groupName,
  }) {
    return saveClient(client.copyWith(groupId: groupId, groupName: groupName));
  }

  Future<void> deleteClient(String clientId) async {
    final ownerId = _requireOwnerId();
    await _clientsCollection(ownerId).doc(clientId).delete();
  }

  String _requireOwnerId() {
    final currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw StateError('Sign in is required to manage customers.');
    }

    return currentUser.uid;
  }
}
