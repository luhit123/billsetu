import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:billeasy/modals/invoice.dart';

class FirebaseService {
  FirebaseService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _invoicesCollection {
    return _firestore.collection('invoices');
  }

  CollectionReference<Map<String, dynamic>> _clientsCollection(String ownerId) {
    return _firestore.collection('users').doc(ownerId).collection('clients');
  }

  Stream<List<Invoice>> getInvoicesStream({
    String searchQuery = '',
    DateTime? startDate,
    DateTime? endDateExclusive,
  }) {
    final ownerId = _requireOwnerId();
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final hasDateRange = startDate != null && endDateExclusive != null;

    Query<Map<String, dynamic>> query = _invoicesCollection.where(
      'ownerId',
      isEqualTo: ownerId,
    );

    if (hasDateRange) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endDateExclusive))
          .orderBy('createdAt', descending: true);
    } else if (normalizedQuery.isEmpty) {
      query = query.orderBy('createdAt', descending: true);
    } else {
      query = query.orderBy('clientNameLower').startAt([normalizedQuery]).endAt(
        ['$normalizedQuery\uf8ff'],
      );
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Invoice.fromMap(doc.data(), docId: doc.id))
          .toList();
    });
  }

  Stream<List<Invoice>> getInvoicesForClientStream(String clientId) {
    final ownerId = _requireOwnerId();

    return _invoicesCollection
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Invoice.fromMap(doc.data(), docId: doc.id))
              .where((invoice) => invoice.clientId == clientId)
              .toList();
        });
  }

  Future<String> addInvoice(Invoice inv) async {
    final ownerId = _requireOwnerId();
    final now = DateTime.now();
    final docRef = inv.id.isNotEmpty
        ? _invoicesCollection.doc(inv.id)
        : _invoicesCollection.doc();

    final data = inv.toMap()
      ..['id'] = docRef.id
      ..['ownerId'] = ownerId;

    await _firestore.runTransaction((transaction) async {
      final clientRef = _clientsCollection(ownerId).doc(inv.clientId);
      final clientSnapshot = await transaction.get(clientRef);
      final clientData = <String, dynamic>{
        'id': inv.clientId,
        'name': inv.clientName,
        'nameLower': inv.clientName.trim().toLowerCase(),
        'updatedAt': Timestamp.fromDate(now),
      };

      if (!clientSnapshot.exists) {
        clientData['createdAt'] = Timestamp.fromDate(now);
      }

      transaction.set(docRef, data);
      transaction.set(clientRef, clientData, SetOptions(merge: true));
    });

    return docRef.id;
  }

  Future<void> updateInvoiceStatus(String id, InvoiceStatus status) async {
    final invoiceRef = await _resolveOwnedInvoiceRef(id);
    await invoiceRef.update({'status': status.name});
  }

  Future<void> deleteInvoice(String id) async {
    final invoiceRef = await _resolveOwnedInvoiceRef(id);
    await invoiceRef.delete();
  }

  String _requireOwnerId() {
    final currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw StateError('Sign in is required to access BillEasy data.');
    }

    return currentUser.uid;
  }

  Future<DocumentReference<Map<String, dynamic>>> _resolveOwnedInvoiceRef(
    String invoiceId,
  ) async {
    final ownerId = _requireOwnerId();
    final invoiceRef = _invoicesCollection.doc(invoiceId);
    final snapshot = await invoiceRef.get();

    if (!snapshot.exists) {
      throw StateError('Invoice not found.');
    }

    final data = snapshot.data();
    final invoiceOwnerId = data?['ownerId'] as String? ?? '';

    if (invoiceOwnerId != ownerId) {
      throw StateError('You do not have access to this invoice.');
    }

    return invoiceRef;
  }
}
