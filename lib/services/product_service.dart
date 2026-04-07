import 'package:billeasy/modals/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:billeasy/services/firestore_page.dart';
import 'package:billeasy/services/team_service.dart';

class ProductService {
  ProductService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String ownerId) =>
      _firestore.collection('users').doc(ownerId).collection('products');

  Query<Map<String, dynamic>> _buildProductsQuery({
    required String ownerId,
    String searchQuery = '',
  }) {
    final q = searchQuery.trim().toLowerCase();

    Query<Map<String, dynamic>> query = _col(ownerId).orderBy('nameLower');

    if (q.isNotEmpty) {
      query = query.startAt([q]).endAt(['$q\uf8ff']);
    }

    return query;
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<Product>> getProductsStream({
    String searchQuery = '',
    int limit = 25,
  }) {
    final ownerId = _requireOwnerId();
    final query = _buildProductsQuery(
      ownerId: ownerId,
      searchQuery: searchQuery,
    );

    return query
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Product.fromMap(d.data(), docId: d.id))
              .toList(),
        );
  }

  Future<FirestorePage<Product>> getProductsPage({
    String searchQuery = '',
    int limit = 25,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    final ownerId = _requireOwnerId();
    final query = _buildProductsQuery(
      ownerId: ownerId,
      searchQuery: searchQuery,
    );

    return query.fetchPage<Product>(
      limit: limit,
      startAfterDocument: startAfterDocument,
      fromMap: (data, docId) => Product.fromMap(data, docId: docId),
    );
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Maximum allowed product name length.
  static const _kMaxNameLength = 200;

  Future<Product> saveProduct(Product product) async {
    // Input validation
    if (product.name.trim().isEmpty) {
      throw ArgumentError('Product name must not be empty');
    }
    if (product.name.length > _kMaxNameLength) {
      throw ArgumentError(
        'Product name must not exceed $_kMaxNameLength characters',
      );
    }

    final ownerId = _requireOwnerId();
    final now = DateTime.now();
    final ref = product.id.trim().isNotEmpty
        ? _col(ownerId).doc(product.id)
        : _col(ownerId).doc();

    final saved = product.copyWith(
      id: ref.id,
      createdAt: product.createdAt ?? now,
      updatedAt: now,
    );

    await ref.set(saved.toMap(), SetOptions(merge: true));
    return saved;
  }

  /// Maximum invoices to scan per page when clearing product references.
  static const _kDeletePageSize = 200;

  /// Upper bound on total invoices scanned during a product delete to
  /// prevent runaway reads on very large accounts.
  static const _kDeleteMaxScanned = 5000;

  Future<void> deleteProduct(String productId) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError('productId must not be empty');
    }

    final ownerId = _requireOwnerId();

    // Verify the product exists before doing the expensive invoice scan.
    final productSnap = await _col(ownerId).doc(productId).get();
    if (!productSnap.exists) {
      throw StateError('Product $productId not found');
    }

    // Paginate through invoices for this owner and clear productId
    // references in their items. Uses batched writes (max 500/batch).
    // Caps total scanned docs to prevent runaway reads on huge accounts.
    QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
    int totalScanned = 0;

    while (totalScanned < _kDeleteMaxScanned) {
      var query = _firestore
          .collection('invoices')
          .where('ownerId', isEqualTo: ownerId)
          .orderBy(FieldPath.documentId)
          .limit(_kDeletePageSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final invoiceSnap = await query.get();
      if (invoiceSnap.docs.isEmpty) break;

      totalScanned += invoiceSnap.docs.length;

      // Collect docs that reference this product, then batch-update.
      WriteBatch batch = _firestore.batch();
      int updates = 0;
      for (final doc in invoiceSnap.docs) {
        final data = doc.data();
        final rawItems = data['items'] as List<dynamic>? ?? [];
        final hasRef = rawItems.any(
          (item) => item is Map && item['productId'] == productId,
        );
        if (!hasRef) continue;

        final items = rawItems.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['productId'] == productId) {
            map['productId'] = '';
          }
          return map;
        }).toList();
        batch.update(doc.reference, {'items': items});
        updates++;

        // Firestore batch limit is 500 — commit and start a new batch.
        if (updates >= 490) {
          await batch.commit();
          batch = _firestore.batch();
          updates = 0;
        }
      }
      if (updates > 0) await batch.commit();

      if (invoiceSnap.docs.length < _kDeletePageSize) break;
      lastDoc = invoiceSnap.docs.last;
    }

    await _col(ownerId).doc(productId).delete();
  }

  // ── Auth guard ────────────────────────────────────────────────────────────

  String _requireOwnerId() => TeamService.instance.getEffectiveOwnerId();
}
