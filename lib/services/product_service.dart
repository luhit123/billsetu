import 'package:billeasy/modals/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:billeasy/services/firestore_page.dart';

class ProductService {
  ProductService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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

    return query.limit(limit).snapshots().map(
      (snap) =>
          snap.docs.map((d) => Product.fromMap(d.data(), docId: d.id)).toList(),
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

  Future<Product> saveProduct(Product product) async {
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
    final ownerId = _requireOwnerId();

    // Clear productId references in invoices that used this product
    final invoiceSnap = await _firestore
        .collection('invoices')
        .where('ownerId', isEqualTo: ownerId)
        .where('items', arrayContains: {'productId': productId})
        .limit(500)
        .get();

    // Firestore array queries are limited, so also do a broader cleanup
    // by querying invoices and clearing productId in their items
    if (invoiceSnap.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in invoiceSnap.docs) {
        final data = doc.data();
        final items = (data['items'] as List<dynamic>? ?? []).map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['productId'] == productId) {
            map['productId'] = '';
          }
          return map;
        }).toList();
        batch.update(doc.reference, {'items': items});
      }
      await batch.commit();
    }

    await _col(ownerId).doc(productId).delete();
  }

  // ── Auth guard ────────────────────────────────────────────────────────────

  String _requireOwnerId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in is required to manage products.');
    }
    return user.uid;
  }
}
