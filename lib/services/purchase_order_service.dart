import 'dart:async';
import 'package:billeasy/modals/purchase_order.dart';
import 'package:billeasy/modals/stock_movement.dart';
import 'package:billeasy/widgets/connectivity_banner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseOrderService {
  PurchaseOrderService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Collections
  CollectionReference<Map<String, dynamic>> _poCol(String ownerId) =>
      _db.collection('users').doc(ownerId).collection('purchaseOrders');

  CollectionReference<Map<String, dynamic>> _movCol(String ownerId) =>
      _db.collection('users').doc(ownerId).collection('stockMovements');

  CollectionReference<Map<String, dynamic>> _productCol(String ownerId) =>
      _db.collection('users').doc(ownerId).collection('products');

  CollectionReference<Map<String, dynamic>> _counterCol(String ownerId) =>
      _db.collection('users').doc(ownerId).collection('poCounters');

  // ── Stream ──────────────────────────────────────────────────────────────

  Stream<List<PurchaseOrder>> getPurchaseOrdersStream({
    PurchaseOrderStatus? status,
    int limit = 50,
  }) {
    final ownerId = _requireOwnerId();
    Query<Map<String, dynamic>> q =
        _poCol(ownerId).orderBy('createdAt', descending: true);
    if (status != null) {
      q = q.where('status', isEqualTo: status.name);
    }
    return q.limit(limit).snapshots().map(
          (snap) => snap.docs
              .map((d) => PurchaseOrder.fromMap(d.data(), docId: d.id))
              .toList(),
        );
  }

  // ── CRUD ────────────────────────────────────────────────────────────────

  Future<PurchaseOrder> savePurchaseOrder(PurchaseOrder order) async {
    final ownerId = _requireOwnerId();
    final now = DateTime.now();

    String orderNumber = order.orderNumber;
    if (orderNumber.isEmpty) {
      orderNumber = await _reserveOrderNumber(ownerId, now.year);
    }

    final ref = order.id.isNotEmpty
        ? _poCol(ownerId).doc(order.id)
        : _poCol(ownerId).doc();

    final saved = order.copyWith(
      id: ref.id,
      ownerId: ownerId,
      orderNumber: orderNumber,
      createdAt: order.id.isEmpty ? now : order.createdAt,
    );

    await ref.set(saved.toMap(), SetOptions(merge: true));
    return saved;
  }

  /// Mark a PO as received. Updates stock for all items with productId.
  /// Uses a Firestore batch for atomicity.
  Future<void> markAsReceived(PurchaseOrder order) async {
    final ownerId = _requireOwnerId();
    final now = DateTime.now();
    final batch = _db.batch();

    // 1. Update PO status
    final poRef = _poCol(ownerId).doc(order.id);
    batch.update(poRef, {
      'status': PurchaseOrderStatus.received.name,
      'receivedAt': Timestamp.fromDate(now),
    });

    // 2. For each item linked to a product — update stock + create movement
    for (final item in order.items) {
      if (item.productId.isEmpty) continue;

      final productRef = _productCol(ownerId).doc(item.productId);

      // Increment stock atomically (merge: true creates doc if missing)
      batch.set(productRef, {
        'currentStock': FieldValue.increment(item.quantity),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      // Create stock movement record
      final movRef = _movCol(ownerId).doc();
      final movement = StockMovement(
        id: movRef.id,
        ownerId: ownerId,
        productId: item.productId,
        productName: item.productName,
        type: StockMovementType.purchaseIn,
        quantity: item.quantity,
        balanceAfter: 0, // Will be corrected by Firestore increment - approximate
        referenceId: order.id,
        referenceNumber: order.orderNumber,
        unitPrice: item.unitPrice,
        createdAt: now,
        notes: 'Received from PO ${order.orderNumber}',
      );
      batch.set(movRef, movement.toMap());
    }

    await batch.commit();
  }

  Future<void> cancelPurchaseOrder(String orderId) async {
    final ownerId = _requireOwnerId();
    await _poCol(ownerId).doc(orderId).update({
      'status': PurchaseOrderStatus.cancelled.name,
    });
  }

  Future<void> deletePurchaseOrder(String orderId) async {
    final ownerId = _requireOwnerId();
    await _poCol(ownerId).doc(orderId).delete();
  }

  // ── Order number sequencing ────────────────────────────────────────────

  Future<String> _reserveOrderNumber(String ownerId, int year) async {
    if (ConnectivityService.instance.isOffline) {
      return _localOrderNumber(year);
    }

    try {
      final counterRef = _counterCol(ownerId).doc(year.toString());
      int sequence = 1;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(counterRef);
        sequence =
            snap.exists ? ((snap.data()?['nextSequence'] as int?) ?? 1) : 1;
        tx.set(
          counterRef,
          {'nextSequence': sequence + 1, 'year': year},
          SetOptions(merge: true),
        );
      }).timeout(const Duration(seconds: 5));

      // Cache for offline fallback.
      final prefs = await SharedPreferences.getInstance();
      final key = 'last_po_seq_$year';
      if (sequence > (prefs.getInt(key) ?? 0)) {
        await prefs.setInt(key, sequence);
      }

      final seq = sequence.toString().padLeft(5, '0');
      return 'PO-$year-$seq';
    } catch (e) {
      debugPrint('[PurchaseOrder] Transaction failed, using local: $e');
      return _localOrderNumber(year);
    }
  }

  Future<String> _localOrderNumber(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_po_seq_$year';
    final last = prefs.getInt(key) ?? 0;
    final next = last + 1;
    await prefs.setInt(key, next);
    return 'PO-$year-${next.toString().padLeft(5, '0')}';
  }

  // ── Auth guard ─────────────────────────────────────────────────────────

  String _requireOwnerId() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in required to manage purchase orders.');
    }
    return uid;
  }
}
