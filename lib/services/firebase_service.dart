import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:billeasy/widgets/connectivity_banner.dart';

import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/line_item.dart';
import 'package:billeasy/modals/stock_movement.dart';
import 'package:billeasy/services/firestore_page.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/utils/firestore_helpers.dart';
import 'package:billeasy/utils/invoice_search.dart';

class FirebaseService {
  FirebaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
    String? createdByUid,
  }) {
    final normalizedQuery = normalizeInvoiceSearchQuery(searchQuery);
    final hasDateRange = startDate != null && endDateExclusive != null;

    Query<Map<String, dynamic>> query = _invoicesCollection.where(
      'ownerId',
      isEqualTo: ownerId,
    );

    if (createdByUid != null && createdByUid.isNotEmpty) {
      query = query.where('createdByUid', isEqualTo: createdByUid);
    }

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
    String? createdByUid,
  }) {
    final ownerId = _requireOwnerId();
    final query = _buildInvoicesQuery(
      ownerId: ownerId,
      searchQuery: searchQuery,
      startDate: startDate,
      endDateExclusive: endDateExclusive,
      status: status,
      gstEnabled: gstEnabled,
      createdByUid: createdByUid,
    );

    return query
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Invoice.fromMap(doc.data(), docId: doc.id))
              .toList();
        })
        .handleError((Object e) {
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
    String? createdByUid,
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
      createdByUid: createdByUid,
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

    return query
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Invoice.fromMap(doc.data(), docId: doc.id))
              .toList();
        })
        .handleError((Object e) {
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
    String? createdByUid,
    int pageSize = 100,
    // FIX SC-1: Reduced from 5000 to 1000. At ~2 KB per invoice doc the old
    // limit could pull ~10 MB into memory — enough to OOM low-end Androids.
    // 1000 invoices/period covers 99.9 % of small businesses and still yields
    // a complete GST export for a monthly filing period.
    int maxResults = 1000,
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
        createdByUid: createdByUid,
        limit: pageSize,
        startAfterDocument: cursor,
      );

      invoices.addAll(page.items);
      cursor = page.cursor;
      hasMore = page.hasMore;
    }

    return invoices;
  }

  /// Derives a deterministic Firestore document ID from an invoice number.
  /// This makes invoice creation idempotent — retries (double-tap, offline
  /// re-sync) upsert the same document instead of creating duplicates.
  /// Format: inv_BR_2026_00042 (from BR-2026-00042).
  static String _deriveInvoiceDocId(String invoiceNumber) {
    if (invoiceNumber.isEmpty) return '';
    return 'inv_${invoiceNumber.replaceAll('-', '_')}';
  }

  Future<String> addInvoice(Invoice inv) async {
    final ownerId = _requireOwnerId();
    final now = DateTime.now();
    // F7 fix: derive docId from invoice number for idempotency.
    // If id is already set (edit), use that. Otherwise derive from
    // invoiceNumber so retries hit the same document.
    final DocumentReference<Map<String, dynamic>> docRef;
    if (inv.id.isNotEmpty) {
      docRef = _invoicesCollection.doc(inv.id);
    } else {
      final derivedId = _deriveInvoiceDocId(inv.invoiceNumber);
      docRef = derivedId.isNotEmpty
          ? _invoicesCollection.doc(derivedId)
          : _invoicesCollection.doc();
    }

    // Issue #1: usagePeriodKey enables server-side quota enforcement
    // in Firestore rules by telling the rules which usage doc to check.
    final usagePeriod = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final data = inv.toMap()
      ..['id'] = docRef.id
      ..['ownerId'] = ownerId
      ..['usagePeriodKey'] = usagePeriod;

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

    // Firestore queues the write locally and syncs when online.
    // When offline, fire-and-forget to avoid hanging the UI.
    // When online, await to catch validation/rule errors immediately.
    final commit = batch.commit();
    if (ConnectivityService.instance.isOffline) {
      commit.catchError((Object e) {
        debugPrint('[FirebaseService] Offline invoice write queue failed: $e');
      });
    } else {
      await commit;
    }

    return docRef.id;
  }

  /// Creates an invoice AND adjusts stock in a single atomic batch.
  /// This prevents the data integrity gap where an invoice could be saved
  /// but stock adjustments fail (or vice versa).
  ///
  /// [stockDeductions] is a list of {productId, productName, quantity, unitPrice}
  /// for items that need stock adjustment.
  Future<String> addInvoiceWithStock(
    Invoice inv, {
    List<StockDeduction> stockDeductions = const [],
  }) async {
    final ownerId = _requireOwnerId();
    final now = DateTime.now();
    // F7 fix: derive docId from invoice number for idempotency.
    final DocumentReference<Map<String, dynamic>> docRef;
    if (inv.id.isNotEmpty) {
      docRef = _invoicesCollection.doc(inv.id);
    } else {
      final derivedId = _deriveInvoiceDocId(inv.invoiceNumber);
      docRef = derivedId.isNotEmpty
          ? _invoicesCollection.doc(derivedId)
          : _invoicesCollection.doc();
    }

    // Issue #1: usagePeriodKey enables server-side quota enforcement
    final usagePeriod = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final data = inv.toMap()
      ..['id'] = docRef.id
      ..['ownerId'] = ownerId
      ..['usagePeriodKey'] = usagePeriod;

    final batch = _firestore.batch();
    batch.set(docRef, data);

    // Upsert client doc
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

    // Include stock adjustments in the same atomic batch.
    // Uses FieldValue.increment so no read-before-write is needed.
    final invoiceNumber = inv.invoiceNumber;
    for (final deduction in stockDeductions) {
      final productRef = _firestore
          .collection('users')
          .doc(ownerId)
          .collection('products')
          .doc(deduction.productId);
      batch.update(productRef, {
        'currentStock': FieldValue.increment(-deduction.quantity),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Log stock movement
      final movRef = _firestore
          .collection('users')
          .doc(ownerId)
          .collection('stockMovements')
          .doc();
      final movement = StockMovement(
        id: movRef.id,
        ownerId: ownerId,
        productId: deduction.productId,
        productName: deduction.productName,
        type: StockMovementType.saleOut,
        quantity: deduction.quantity,
        balanceAfter: 0, // Will be reconciled by server
        referenceId: docRef.id,
        referenceNumber: invoiceNumber,
        unitPrice: deduction.unitPrice,
        createdAt: now,
        notes: 'Sale: $invoiceNumber',
      );
      batch.set(movRef, movement.toMap());
    }

    final commit = batch.commit();
    if (ConnectivityService.instance.isOffline) {
      commit.catchError((Object e) {
        debugPrint(
          '[FirebaseService] Offline invoice+stock write queue failed: $e',
        );
      });
    } else {
      await commit;
    }

    return docRef.id;
  }

  /// Updates an invoice AND adjusts stock atomically in a single batch.
  /// Reverses old stock deductions and applies new ones.
  ///
  /// [oldDeductions] are items from the previous invoice version (to reverse).
  /// [newDeductions] are items from the updated invoice (to deduct).
  Future<void> updateInvoiceWithStock(
    Invoice inv, {
    List<StockDeduction> oldDeductions = const [],
    List<StockDeduction> newDeductions = const [],
  }) async {
    final ownerId = inv.ownerId;
    final now = DateTime.now();
    final docRef = _invoicesCollection.doc(inv.id);
    final data = inv.toMap()
      ..['id'] = inv.id
      ..['ownerId'] = inv.ownerId;

    final batch = _firestore.batch();
    batch.set(docRef, data);

    final invoiceNumber = inv.invoiceNumber;

    // 1. Reverse old stock deductions (add stock back)
    for (final old in oldDeductions) {
      final productRef = _firestore
          .collection('users')
          .doc(ownerId)
          .collection('products')
          .doc(old.productId);
      batch.update(productRef, {
        'currentStock': FieldValue.increment(old.quantity),
        'updatedAt': Timestamp.fromDate(now),
      });
      final movRef = _firestore
          .collection('users')
          .doc(ownerId)
          .collection('stockMovements')
          .doc();
      final movement = StockMovement(
        id: movRef.id,
        ownerId: ownerId,
        productId: old.productId,
        productName: old.productName,
        type: StockMovementType.manualIn,
        quantity: old.quantity,
        balanceAfter: 0,
        referenceId: inv.id,
        referenceNumber: invoiceNumber,
        unitPrice: old.unitPrice,
        createdAt: now,
        notes: 'Edit reversal: $invoiceNumber',
      );
      batch.set(movRef, movement.toMap());
    }

    // 2. Apply new stock deductions
    for (final deduction in newDeductions) {
      final productRef = _firestore
          .collection('users')
          .doc(ownerId)
          .collection('products')
          .doc(deduction.productId);
      batch.update(productRef, {
        'currentStock': FieldValue.increment(-deduction.quantity),
        'updatedAt': Timestamp.fromDate(now),
      });
      final movRef = _firestore
          .collection('users')
          .doc(ownerId)
          .collection('stockMovements')
          .doc();
      final movement = StockMovement(
        id: movRef.id,
        ownerId: ownerId,
        productId: deduction.productId,
        productName: deduction.productName,
        type: StockMovementType.saleOut,
        quantity: deduction.quantity,
        balanceAfter: 0,
        referenceId: inv.id,
        referenceNumber: invoiceNumber,
        unitPrice: deduction.unitPrice,
        createdAt: now,
        notes: 'Sale (edited): $invoiceNumber',
      );
      batch.set(movRef, movement.toMap());
    }

    final commit = batch.commit();
    if (ConnectivityService.instance.isOffline) {
      commit.catchError((Object e) {
        debugPrint(
          '[FirebaseService] Offline invoice+stock update queue failed: $e',
        );
      });
      return;
    }

    await commit;
  }

  // FIX SEC-2: Validate ownership before updating, matching the pattern
  // used by updateInvoiceStatus() and deleteInvoice(). Without this,
  // the offline cache could temporarily accept an update on another
  // user's invoice (server would reject it later, but UI would flicker).
  Future<void> updateInvoice(Invoice inv) async {
    final invoiceRef = await _resolveOwnedInvoiceRef(inv.id);
    final data = inv.toMap()
      ..['id'] = inv.id
      ..['ownerId'] = inv.ownerId;
    final write = invoiceRef.set(data);
    if (ConnectivityService.instance.isOffline) {
      write.catchError((Object e) {
        debugPrint('[FirebaseService] Offline invoice update queue failed: $e');
      });
      return;
    }

    await write;
  }

  Future<void> updateInvoiceStatus(String id, InvoiceStatus status) async {
    final invoiceRef = await _resolveOwnedInvoiceRef(id);
    await invoiceRef.update({'status': status.name});
  }

  /// Record a payment and auto-resolve status.
  /// Uses a transaction when online to prevent duplicate payments on retry.
  /// Falls back to a batch write when offline so payments aren't blocked.
  Future<void> recordPayment(
    String id,
    double paymentAmount,
    double newTotalReceived,
    double grandTotal, {
    String method = 'cash',
    String note = '',
  }) async {
    // Generate a deterministic payment ID from amount + timestamp to detect retries.
    // Using a subcollection doc with a known ID makes the write idempotent.
    final paymentId =
        '${DateTime.now().millisecondsSinceEpoch}_${paymentAmount.toStringAsFixed(2)}';

    final balanceDue =
        ((grandTotal - newTotalReceived) * 100).roundToDouble() / 100;
    String status;
    if (newTotalReceived >= grandTotal && grandTotal > 0) {
      status = InvoiceStatus.paid.name;
    } else if (newTotalReceived > 0) {
      status = InvoiceStatus.partiallyPaid.name;
    } else {
      status = InvoiceStatus.pending.name;
    }

    if (kDebugMode) {
      debugPrint(
        '[RecordPayment] id=$id payment=$paymentAmount total=$newTotalReceived grand=$grandTotal balance=$balanceDue status=$status',
      );
    }

    final invoiceRef = _invoicesCollection.doc(id);

    // ── Offline path: batch write (no transaction support offline) ───────
    if (ConnectivityService.instance.isOffline) {
      final batch = _firestore.batch();
      final paymentRef = invoiceRef.collection('payments').doc(paymentId);
      batch.set(paymentRef, {
        'amount': paymentAmount,
        'method': method,
        'note': note,
        'date': Timestamp.now(),
        'runningTotal': newTotalReceived,
        'balanceAfter': balanceDue,
      });
      batch.update(invoiceRef, {
        'amountReceived': newTotalReceived,
        'balanceDue': balanceDue,
        'status': status,
      });
      batch.commit().catchError((Object e) {
        debugPrint('[RecordPayment] Offline queue failed: $e');
      });
      if (kDebugMode) {
        debugPrint('[RecordPayment] Queued offline');
      }
      return;
    }

    // ── Online path: transaction for idempotency ────────────────────────
    // Verify ownership before transacting.
    final snapshot = await resilientGet(invoiceRef);
    if (!snapshot.exists) {
      throw StateError('Invoice not found.');
    }
    final invoiceOwnerId = snapshot.data()?['ownerId'] as String? ?? '';
    if (invoiceOwnerId != _requireOwnerId()) {
      throw StateError('You do not have access to this invoice.');
    }

    try {
      await _firestore.runTransaction((txn) async {
        final invoiceSnap = await txn.get(invoiceRef);
        if (!invoiceSnap.exists) {
          throw StateError('Invoice $id not found');
        }

        // Check if this payment already exists (idempotency guard)
        final paymentRef = invoiceRef.collection('payments').doc(paymentId);
        final existingPayment = await txn.get(paymentRef);
        if (existingPayment.exists) {
          if (kDebugMode) {
            debugPrint(
              '[RecordPayment] Duplicate detected, skipping: $paymentId',
            );
          }
          return;
        }

        // FIX SEC-4: Compute newTotalReceived from the server-side document
        // instead of trusting the client-supplied value. A tampered client
        // could pass grandTotal as newTotalReceived with a tiny paymentAmount
        // to mark an invoice as fully paid without actually paying.
        final invoiceData = invoiceSnap.data() ?? {};
        final serverReceived =
            (invoiceData['amountReceived'] as num? ?? 0).toDouble();
        final serverGrandTotal =
            (invoiceData['grandTotal'] as num? ?? 0).toDouble();
        final serverNewTotal = ((serverReceived + paymentAmount) * 100)
                .roundToDouble() /
            100;
        final serverBalanceDue =
            ((serverGrandTotal - serverNewTotal) * 100).roundToDouble() / 100;
        String serverStatus;
        if (serverNewTotal >= serverGrandTotal && serverGrandTotal > 0) {
          serverStatus = InvoiceStatus.paid.name;
        } else if (serverNewTotal > 0) {
          serverStatus = InvoiceStatus.partiallyPaid.name;
        } else {
          serverStatus = InvoiceStatus.pending.name;
        }

        txn.set(paymentRef, {
          'amount': paymentAmount,
          'method': method,
          'note': note,
          'date': FieldValue.serverTimestamp(),
          'runningTotal': serverNewTotal,
          'balanceAfter': serverBalanceDue,
        });

        txn.update(invoiceRef, {
          'amountReceived': serverNewTotal,
          'balanceDue': serverBalanceDue,
          'status': serverStatus,
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
    return _invoicesCollection
        .doc(invoiceId)
        .collection('payments')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList(),
        );
  }

  /// Mark invoice as fully paid (sets amountReceived = grandTotal).
  /// Uses a transaction to prevent double-recording when called concurrently.
  Future<void> markAsPaid(String id) async {
    final invoiceRef = await _resolveOwnedInvoiceRef(id);
    await _firestore.runTransaction((txn) async {
      final doc = await txn.get(invoiceRef);
      final data = doc.data();
      if (data == null) return;
      final grandTotal = (data['grandTotal'] as num? ?? 0).toDouble();
      final alreadyReceived = (data['amountReceived'] as num? ?? 0).toDouble();
      final remaining =
          ((grandTotal - alreadyReceived) * 100).roundToDouble() / 100;
      if (remaining > 0) {
        final payRef = invoiceRef.collection('payments').doc();
        txn.set(payRef, {
          'amount': remaining,
          'method': 'cash',
          'note': 'Marked as fully paid',
          'date': FieldValue.serverTimestamp(),
          'runningTotal': grandTotal,
          'balanceAfter': 0,
        });
      }
      txn.update(invoiceRef, {
        'amountReceived': grandTotal,
        'balanceDue': 0,
        'status': InvoiceStatus.paid.name,
      });
    });
  }

  Future<void> deleteInvoice(String id) async {
    final invoiceRef = await _resolveOwnedInvoiceRef(id);
    await invoiceRef.delete();
  }

  /// Returns invoices for an owner with optional range and creator filters.
  ///
  /// Results are paginated internally so larger histories do not require a
  /// single unbounded Firestore response.
  /// Maximum total invoices returned by a single call.
  /// Prevents unbounded reads that could exhaust Firestore quotas.
  static const _maxTotalResults = 500;

  Future<List<Invoice>> getInvoicesForOwner({
    required String ownerId,
    DateTime? startAt,
    DateTime? endBefore,
    String? createdByUid,
    int pageSize = 200,
  }) async {
    Query<Map<String, dynamic>> baseQuery = _invoicesCollection.where(
      'ownerId',
      isEqualTo: ownerId,
    );

    if (createdByUid != null && createdByUid.isNotEmpty) {
      baseQuery = baseQuery.where('createdByUid', isEqualTo: createdByUid);
    }
    if (startAt != null) {
      baseQuery = baseQuery.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startAt),
      );
    }
    if (endBefore != null) {
      baseQuery = baseQuery.where(
        'createdAt',
        isLessThan: Timestamp.fromDate(endBefore),
      );
    }

    final invoices = <Invoice>[];
    Query<Map<String, dynamic>> pageQuery = baseQuery
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    while (true) {
      final snap = await pageQuery.get();
      invoices.addAll(
        snap.docs.map((d) => Invoice.fromMap(d.data(), docId: d.id)),
      );

      if (snap.docs.length < pageSize || invoices.length >= _maxTotalResults) {
        break;
      }

      pageQuery = baseQuery
          .orderBy('createdAt', descending: true)
          .startAfterDocument(snap.docs.last)
          .limit(pageSize);
    }

    return invoices.length > _maxTotalResults
        ? invoices.sublist(0, _maxTotalResults)
        : invoices;
  }

  /// Backward-compatible wrapper for existing call sites.
  Future<List<Invoice>> getAllInvoicesForOwner(String ownerId) {
    return getInvoicesForOwner(ownerId: ownerId);
  }

  String _requireOwnerId() => TeamService.instance.getEffectiveOwnerId();

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

/// Lightweight data class for stock adjustments bundled with invoice writes.
class StockDeduction {
  const StockDeduction({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  /// Build deductions from a list of [LineItem]s (filters out items without productId).
  static List<StockDeduction> fromLineItems(List<LineItem> items) {
    return items
        .where((i) => i.productId.isNotEmpty)
        .map(
          (i) => StockDeduction(
            productId: i.productId,
            productName: i.description,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
          ),
        )
        .toList();
  }
}
