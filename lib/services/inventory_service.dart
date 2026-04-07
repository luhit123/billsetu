import 'package:billeasy/modals/stock_movement.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/widgets/connectivity_banner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class InventoryService {
  InventoryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _movCol(String ownerId) =>
      _db.collection('users').doc(ownerId).collection('stockMovements');

  CollectionReference<Map<String, dynamic>> _productCol(String ownerId) =>
      _db.collection('users').doc(ownerId).collection('products');

  /// Stream of stock movements for a specific product, newest first.
  Stream<List<StockMovement>> getMovementsForProduct(
    String productId, {
    int limit = 50,
  }) {
    final ownerId = _requireOwnerId();
    return _movCol(ownerId)
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => StockMovement.fromMap(d.data(), docId: d.id))
              .toList(),
        );
  }

  /// Manual stock adjustment (add or remove stock).
  ///
  /// Uses a Firestore transaction to read-before-write, preventing race
  /// conditions where concurrent sales could drive stock negative.
  Future<void> adjustStock({
    required String productId,
    required String productName,
    required double quantity, // positive = add, negative = remove
    required String reason,
    double unitPrice = 0,
    StockMovementType? movementType,
    String referenceId = '',
    String referenceNumber = '',
  }) async {
    final ownerId = _requireOwnerId();

    // Offline mode: fall back to batch + increment (best-effort).
    // Transactions require the server, so they can't run offline.
    if (ConnectivityService.instance.isOffline) {
      await _adjustStockOffline(
        ownerId: ownerId,
        productId: productId,
        productName: productName,
        quantity: quantity,
        reason: reason,
        unitPrice: unitPrice,
        movementType: movementType,
        referenceId: referenceId,
        referenceNumber: referenceNumber,
      );
      return;
    }

    final productRef = _productCol(ownerId).doc(productId);
    final now = DateTime.now();
    final type =
        movementType ??
        (quantity >= 0
            ? StockMovementType.manualIn
            : StockMovementType.manualOut);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(productRef);
      if (!snap.exists) {
        throw Exception('Product $productId not found');
      }

      final currentStock =
          (snap.data()?['currentStock'] as num?)?.toDouble() ?? 0;
      final newStock = currentStock + quantity;

      // Prevent negative stock on sale deductions
      if (quantity < 0 && newStock < 0) {
        debugPrint(
          '[InventoryService] Stock would go negative for $productId '
          '(current: $currentStock, adjustment: $quantity). Clamping to 0.',
        );
      }

      final finalStock = newStock < 0 ? 0.0 : newStock;

      txn.update(productRef, {
        'currentStock': finalStock,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Log the movement with accurate balanceAfter
      final movRef = _movCol(ownerId).doc();
      final movement = StockMovement(
        id: movRef.id,
        ownerId: ownerId,
        productId: productId,
        productName: productName,
        type: type,
        quantity: quantity.abs(),
        balanceAfter: finalStock,
        referenceId: referenceId,
        referenceNumber: referenceNumber,
        unitPrice: unitPrice,
        createdAt: now,
        notes: reason,
      );
      txn.set(movRef, movement.toMap());
    });
  }

  /// Offline fallback: uses batch + FieldValue.increment with a local cache
  /// guard to prevent stock from going negative when synced to the server.
  Future<void> _adjustStockOffline({
    required String ownerId,
    required String productId,
    required String productName,
    required double quantity,
    required String reason,
    double unitPrice = 0,
    StockMovementType? movementType,
    String referenceId = '',
    String referenceNumber = '',
  }) async {
    final now = DateTime.now();

    // Read locally cached stock to guard against negative values.
    // Firestore's offline cache will return the last-known value.
    double adjustedQuantity = quantity;
    if (quantity < 0) {
      try {
        final productRef = _productCol(ownerId).doc(productId);
        final snap = await productRef.get();
        if (snap.exists) {
          final currentStock =
              (snap.data()?['currentStock'] as num?)?.toDouble() ?? 0;
          if (currentStock + quantity < 0) {
            // Clamp so stock doesn't go below zero
            adjustedQuantity = -currentStock;
            debugPrint(
              '[InventoryService] Offline: clamping deduction for $productId '
              '(cached stock: $currentStock, requested: $quantity, clamped: $adjustedQuantity)',
            );
            if (adjustedQuantity == 0) return; // Nothing to deduct
          }
        }
      } catch (e) {
        debugPrint('[InventoryService] Offline cache read failed: $e');
        // Proceed with original quantity — best-effort
      }
    }

    final batch = _db.batch();
    final productRef = _productCol(ownerId).doc(productId);
    batch.update(productRef, {
      'currentStock': FieldValue.increment(adjustedQuantity),
      'updatedAt': Timestamp.fromDate(now),
    });

    final movRef = _movCol(ownerId).doc();
    final type =
        movementType ??
        (quantity >= 0
            ? StockMovementType.manualIn
            : StockMovementType.manualOut);
    final movement = StockMovement(
      id: movRef.id,
      ownerId: ownerId,
      productId: productId,
      productName: productName,
      type: type,
      quantity: adjustedQuantity.abs(),
      balanceAfter: 0,
      referenceId: referenceId,
      referenceNumber: referenceNumber,
      unitPrice: unitPrice,
      createdAt: now,
      notes: reason,
    );
    batch.set(movRef, movement.toMap());

    batch.commit().catchError((Object e) {
      debugPrint(
        '[InventoryService] Offline stock adjustment queue failed: $e',
      );
    });
  }

  /// Set opening stock for a product (used when first enabling inventory tracking).
  Future<void> setOpeningStock({
    required String productId,
    required String productName,
    required double quantity,
    double unitPrice = 0,
  }) async {
    final ownerId = _requireOwnerId();
    final now = DateTime.now();
    final batch = _db.batch();

    final productRef = _productCol(ownerId).doc(productId);
    batch.update(productRef, {
      'currentStock': quantity,
      'updatedAt': Timestamp.fromDate(now),
    });

    final movRef = _movCol(ownerId).doc();
    final movement = StockMovement(
      id: movRef.id,
      ownerId: ownerId,
      productId: productId,
      productName: productName,
      type: StockMovementType.openingStock,
      quantity: quantity,
      balanceAfter: quantity,
      unitPrice: unitPrice,
      createdAt: now,
      notes: 'Opening stock entry',
    );
    batch.set(movRef, movement.toMap());

    final commit = batch.commit();
    if (ConnectivityService.instance.isOffline) {
      commit.catchError((Object e) {
        debugPrint('[InventoryService] Offline opening stock queue failed: $e');
      });
      return;
    }

    await commit;
  }

  String _requireOwnerId() => TeamService.instance.getEffectiveOwnerId();
}
