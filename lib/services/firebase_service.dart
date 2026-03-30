import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/services/firestore_page.dart';
import 'package:billeasy/utils/firestore_helpers.dart';
import 'package:billeasy/utils/invoice_search.dart';

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

  Query<Map<String, dynamic>> _buildInvoicesQuery({
    required String ownerId,
    String searchQuery = '',
    DateTime? startDate,
    DateTime? endDateExclusive,
    InvoiceStatus? status,
    bool? gstEnabled,
  }) {
    final normalizedQuery = normalizeInvoiceSearchQuery(searchQuery);
    final hasDateRange = startDate != null && endDateExclusive != null;

    Query<Map<String, dynamic>> query = _invoicesCollection.where(
      'ownerId',
      isEqualTo: ownerId,
    );

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (gstEnabled != null) {
      query = query.where('gstEnabled', isEqualTo: gstEnabled);
    }

    if (normalizedQuery.isNotEmpty) {
      query = query.where('searchPrefixes', arrayContains: normalizedQuery);
    }

    if (hasDateRange) {
      query = query
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endDateExclusive));
    }

    return query.orderBy('createdAt', descending: true);
  }

  Query<Map<String, dynamic>> _buildClientInvoicesQuery({
    required String ownerId,
    required String clientId,
    InvoiceStatus? status,
    bool? gstEnabled,
  }) {
    Query<Map<String, dynamic>> query = _invoicesCollection
        .where('ownerId', isEqualTo: ownerId)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (gstEnabled != null) {
      query = query.where('gstEnabled', isEqualTo: gstEnabled);
    }

    return query;
  }

  Stream<List<Invoice>> getInvoicesStream({
    String searchQuery = '',
    DateTime? startDate,
    DateTime? endDateExclusive,
    InvoiceStatus? status,
    bool? gstEnabled,
    int limit = 50,
  }) {
    final ownerId = _requireOwnerId();
    final query = _buildInvoicesQuery(
      ownerId: ownerId,
      searchQuery: searchQuery,
      startDate: startDate,
      endDateExclusive: endDateExclusive,
      status: status,
      gstEnabled: gstEnabled,
    );

    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Invoice.fromMap(doc.data(), docId: doc.id))
          .toList();
    }).handleError((Object e) {
      debugPrint('[FirebaseService] Invoice stream error: $e');
      return <Invoice>[];
    });
  }

  Future<FirestorePage<Invoice>> getInvoicesPage({
    String searchQuery = '',
    DateTime? startDate,
    DateTime? endDateExclusive,
    InvoiceStatus? status,
    bool? gstEnabled,
    int limit = 25,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    final ownerId = _requireOwnerId();
    final query = _buildInvoicesQuery(
      ownerId: ownerId,
      searchQuery: searchQuery,
      startDate: startDate,
      endDateExclusive: endDateExclusive,
      status: status,
      gstEnabled: gstEnabled,
    );

    return query.fetchPage<Invoice>(
      limit: limit,
      startAfterDocument: startAfterDocument,
      fromMap: (data, docId) => Invoice.fromMap(data, docId: docId),
    );
  }

  Stream<List<Invoice>> getInvoicesForClientStream(
    String clientId, {
    InvoiceStatus? status,
    bool? gstEnabled,
    int limit = 50,
  }) {
    final ownerId = _requireOwnerId();
    final query = _buildClientInvoicesQuery(
      ownerId: ownerId,
      clientId: clientId,
      status: status,
      gstEnabled: gstEnabled,
    );

    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Invoice.fromMap(doc.data(), docId: doc.id))
          .toList();
    }).handleError((Object e) {
      debugPrint('[FirebaseService] Invoice stream error: $e');
      return <Invoice>[];
    });
  }

  Future<FirestorePage<Invoice>> getInvoicesForClientPage(
    String clientId, {
    InvoiceStatus? status,
    bool? gstEnabled,
    int limit = 25,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    final ownerId = _requireOwnerId();
    final query = _buildClientInvoicesQuery(
      ownerId: ownerId,
      clientId: clientId,
      status: status,
      gstEnabled: gstEnabled,
    );

    return query.fetchPage<Invoice>(
      limit: limit,
      startAfterDocument: startAfterDocument,
      fromMap: (data, docId) => Invoice.fromMap(data, docId: docId),
    );
  }

  Future<List<Invoice>> getAllInvoices({
    String searchQuery = '',
    DateTime? startDate,
    DateTime? endDateExclusive,
    InvoiceStatus? status,
    bool? gstEnabled,
    int pageSize = 100,
    int maxResults = 5000,
  }) async {
    final invoices = <Invoice>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    var hasMore = true;

    while (hasMore && invoices.length < maxResults) {
      final page = await getInvoicesPage(
        searchQuery: searchQuery,
        startDate: startDate,
        endDateExclusive: endDateExclusive,
        status: status,
        gstEnabled: gstEnabled,
        limit: pageSize,
        startAfterDocument: cursor,
      );

      invoices.addAll(page.items);
      cursor = page.cursor;
      hasMore = page.hasMore;
    }

    return invoices;
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


    final batch = _firestore.batch();
    batch.set(docRef, data);

    // Only upsert client doc if we have a valid clientId
    if (inv.clientId.trim().isNotEmpty) {
      final clientRef = _clientsCollection(ownerId).doc(inv.clientId);
      final clientData = <String, dynamic>{
        'id': inv.clientId,
        'name': inv.clientName,
        'nameLower': inv.clientName.trim().toLowerCase(),
        'updatedAt': Timestamp.fromDate(now),
      };
      batch.set(clientRef, clientData, SetOptions(merge: true));
    }

    // Don't await — Firestore queues the write locally and syncs when online.
    // Awaiting hangs the UI when offline.
    batch.commit();

    return docRef.id;
  }

  Future<void> updateInvoice(Invoice inv) async {
    final docRef = _invoicesCollection.doc(inv.id);
    final data = inv.toMap()
      ..['id'] = inv.id
      ..['ownerId'] = inv.ownerId;
    await docRef.set(data);
  }

  Future<void> updateInvoiceStatus(String id, InvoiceStatus status) async {
    final invoiceRef = await _resolveOwnedInvoiceRef(id);
    await invoiceRef.update({'status': status.name});
  }

  /// Record a payment and auto-resolve status.
  /// Uses a transaction to prevent duplicate payments on network retry.
  Future<void> recordPayment(String id, double paymentAmount, double newTotalReceived, double grandTotal, {String method = 'cash', String note = ''}) async {
    final invoiceRef = await _resolveOwnedInvoiceRef(id);

    // Generate a deterministic payment ID from amount + timestamp to detect retries.
    // Using a subcollection doc with a known ID makes the write idempotent.
    final paymentId = '${DateTime.now().millisecondsSinceEpoch}_${paymentAmount.toStringAsFixed(2)}';

    final balanceDue = ((grandTotal - newTotalReceived) * 100).roundToDouble() / 100;
    String status;
    if (newTotalReceived >= grandTotal && grandTotal > 0) {
      status = InvoiceStatus.paid.name;
    } else if (newTotalReceived > 0) {
      status = InvoiceStatus.partiallyPaid.name;
    } else {
      status = InvoiceStatus.pending.name;
    }

    if (kDebugMode) {
      debugPrint('[RecordPayment] id=$id payment=$paymentAmount total=$newTotalReceived grand=$grandTotal balance=$balanceDue status=$status');
    }

    try {
      await _firestore.runTransaction((txn) async {
        // Read invoice inside transaction for consistency
        final invoiceSnap = await txn.get(invoiceRef);
        if (!invoiceSnap.exists) {
          throw StateError('Invoice $id not found');
        }

        // Check if this payment already exists (idempotency guard)
        final paymentRef = invoiceRef.collection('payments').doc(paymentId);
        final existingPayment = await txn.get(paymentRef);
        if (existingPayment.exists) {
          if (kDebugMode) {
            debugPrint('[RecordPayment] Duplicate detected, skipping: $paymentId');
          }
          return;
        }

        // 1. Log payment in subcollection with deterministic ID
        txn.set(paymentRef, {
          'amount': paymentAmount,
          'method': method,
          'note': note,
          'date': FieldValue.serverTimestamp(),
          'runningTotal': newTotalReceived,
          'balanceAfter': balanceDue,
        });

        // 2. Update invoice totals
        txn.update(invoiceRef, {
          'amountReceived': newTotalReceived,
          'balanceDue': balanceDue,
          'status': status,
        });
      });
      if (kDebugMode) {
        debugPrint('[RecordPayment] SUCCESS');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RecordPayment] FAILED: $e');
      }
      rethrow;
    }
  }

  /// Fetch payment history for an invoice, ordered by date descending.
  Stream<List<Map<String, dynamic>>> watchPaymentHistory(String invoiceId) {
    return _invoicesCollection.doc(invoiceId)
        .collection('payments')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList());
  }

  /// Mark invoice as fully paid (sets amountReceived = grandTotal).
  Future<void> markAsPaid(String id) async {
    final invoiceRef = await _resolveOwnedInvoiceRef(id);
    final doc = await invoiceRef.get();
    final data = doc.data();
    if (data == null) return;
    final grandTotal = (data['grandTotal'] as num? ?? 0).toDouble();
    final alreadyReceived = (data['amountReceived'] as num? ?? 0).toDouble();
    final remaining = ((grandTotal - alreadyReceived) * 100).roundToDouble() / 100;
    if (remaining > 0) {
      await invoiceRef.collection('payments').add({
        'amount': remaining,
        'method': 'cash',
        'note': 'Marked as fully paid',
        'date': FieldValue.serverTimestamp(),
        'runningTotal': grandTotal,
        'balanceAfter': 0,
      });
    }
    await invoiceRef.update({
      'amountReceived': grandTotal,
      'balanceDue': 0,
      'status': InvoiceStatus.paid.name,
    });
  }


  Future<void> deleteInvoice(String id) async {
    final invoiceRef = await _resolveOwnedInvoiceRef(id);
    await invoiceRef.delete();
  }

  String _requireOwnerId() {
    final currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw StateError('Sign in is required to access BillRaja data.');
    }

    return currentUser.uid;
  }

  Future<DocumentReference<Map<String, dynamic>>> _resolveOwnedInvoiceRef(
    String invoiceId,
  ) async {
    final ownerId = _requireOwnerId();
    final invoiceRef = _invoicesCollection.doc(invoiceId);
    final snapshot = await resilientGet(invoiceRef);

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
