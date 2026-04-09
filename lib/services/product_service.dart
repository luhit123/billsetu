import 'package:billeasy/modals/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

    // Call the Cloud Function to clean up product references in invoices.
    // This avoids expensive client-side pagination through thousands of invoices.
    try {
      await FirebaseFunctions.instance
          .httpsCallable('cleanupProductReferences',
              options: HttpsCallableOptions(timeout: Duration(seconds: 60)))
          .call({'productId': productId});
    } catch (e) {
      throw StateError('Failed to cleanup product references: $e');
    }

    // Delete the product document.
    await _col(ownerId).doc(productId).delete();
  }

  // ── Auth guard ────────────────────────────────────────────────────────────

  String _requireOwnerId() => TeamService.instance.getEffectiveOwnerId();
}
