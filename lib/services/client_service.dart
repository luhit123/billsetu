import 'package:billeasy/modals/client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:billeasy/services/firestore_page.dart';

class ClientService {
  ClientService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> _clientsCollection(String ownerId) {
    return _firestore.collection('users').doc(ownerId).collection('clients');
  }

  Query<Map<String, dynamic>> _buildClientsQuery({
    required String ownerId,
    String searchQuery = '',
    String groupId = '',
  }) {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    Query<Map<String, dynamic>> query = _clientsCollection(
      ownerId,
    ).orderBy('nameLower');

    // Push non-ungrouped groupId filtering to Firestore to avoid
    // client-side filtering after pagination.
    if (groupId.isNotEmpty && groupId != '__ungrouped__') {
      query = query.where('groupId', isEqualTo: groupId);
    }

    if (normalizedQuery.isNotEmpty) {
      query = query.startAt([normalizedQuery]).endAt([
        '$normalizedQuery\uf8ff',
      ]);
    }

    return query;
  }

  Stream<List<Client>> getClientsStream({
    String searchQuery = '',
    String? groupId,
    int limit = 50,
  }) {
    final ownerId = _requireOwnerId();
    final normalizedGroupId = groupId?.trim() ?? '';

    Query<Map<String, dynamic>> query = _buildClientsQuery(
      ownerId: ownerId,
      searchQuery: searchQuery,
      groupId: normalizedGroupId,
    );

    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Client.fromMap(doc.data(), docId: doc.id))
          .where((client) {
            // Only __ungrouped__ needs client-side filtering since Firestore
            // cannot query documents where groupId is empty/absent.
            if (normalizedGroupId == '__ungrouped__') {
              return client.groupId.trim().isEmpty;
            }

            return true;
          })
          .toList();
    });
  }

  Future<FirestorePage<Client>> getClientsPage({
    String searchQuery = '',
    String? groupId,
    int limit = 25,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    final ownerId = _requireOwnerId();
    final normalizedGroupId = groupId?.trim() ?? '';
    final query = _buildClientsQuery(
      ownerId: ownerId,
      searchQuery: searchQuery,
      groupId: normalizedGroupId,
    );

    final page = await query.fetchPage<Client>(
      limit: limit,
      startAfterDocument: startAfterDocument,
      fromMap: (data, docId) => Client.fromMap(data, docId: docId),
    );

    // __ungrouped__ requires client-side filtering because Firestore cannot
    // efficiently query documents where groupId is empty/absent.
    if (normalizedGroupId != '__ungrouped__') {
      return page;
    }

    final filteredItems = page.items
        .where((client) => client.groupId.trim().isEmpty)
        .toList(growable: false);

    return FirestorePage<Client>(
      items: filteredItems,
      hasMore: page.hasMore,
      cursor: page.cursor,
    );
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
