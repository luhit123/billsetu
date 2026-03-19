import 'package:billeasy/modals/stock_movement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventoryService {
  InventoryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

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
        .map((snap) => snap.docs
            .map((d) => StockMovement.fromMap(d.data(), docId: d.id))
            .toList());
  }

  /// Manual stock adjustment (add or remove stock).
  Future<void> adjustStock({
    required String productId,
    required String productName,
    required double quantity, // positive = add, negative = remove
    required String reason,
    double unitPrice = 0,
  }) async {
    final ownerId = _requireOwnerId();
    final now = DateTime.now();
    final batch = _db.batch();

    // Update product stock
    final productRef = _productCol(ownerId).doc(productId);
    batch.update(productRef, {
      'currentStock': FieldValue.increment(quantity),
      'updatedAt': Timestamp.fromDate(now),
    });

    // Log movement
    final movRef = _movCol(ownerId).doc();
    final type =
        quantity >= 0 ? StockMovementType.manualIn : StockMovementType.manualOut;
    final movement = StockMovement(
      id: movRef.id,
      ownerId: ownerId,
      productId: productId,
      productName: productName,
      type: type,
      quantity: quantity.abs(),
      balanceAfter: 0,
      unitPrice: unitPrice,
      createdAt: now,
      notes: reason,
    );
    batch.set(movRef, movement.toMap());

    await batch.commit();
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

    await batch.commit();
  }

  String _requireOwnerId() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in required.');
    return uid;
  }
}
