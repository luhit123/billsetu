import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/utils/firestore_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UsageTrackingService {
  UsageTrackingService._();
  static final UsageTrackingService instance = UsageTrackingService._();

  String? get _uid {
    try {
      return TeamService.instance.getEffectiveOwnerId();
    } catch (_) {
      return FirebaseAuth.instance.currentUser?.uid;
    }
  }

  String get _currentPeriodKey => DateFormat('yyyy-MM').format(DateTime.now());

  // ── In-memory cache (5-minute TTL) ────────────────────────────────────
  Map<String, int>? _cachedSummary;
  DateTime? _cacheTime;
  static const _cacheTtl = Duration(minutes: 5);
  bool get _isCacheValid =>
      _cachedSummary != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl;

  /// Invalidate cache after writes (invoice created, customer added, etc.)
  void invalidateCache() {
    _cachedSummary = null;
    _cacheTime = null;
  }

  DocumentReference<Map<String, dynamic>>? get _usageRef {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('usage')
        .doc(_currentPeriodKey);
  }

  // ── Read counts ───────────────────────────────────────────────────────

  Future<int> getInvoiceCount() async {
    final ref = _usageRef;
    if (ref == null) return 0;
    try {
      final doc = await resilientGet(ref);
      if (!doc.exists) return 0;
      return doc.data()?['invoicesCreated'] as int? ?? 0;
    } catch (_) {
      // If both server and cache fail, allow invoice creation
      return 0;
    }
  }

  Future<int> getWhatsAppShareCount() async {
    final ref = _usageRef;
    if (ref == null) return 0;
    final doc = await resilientGet(ref);
    if (!doc.exists) return 0;
    return doc.data()?['whatsappShares'] as int? ?? 0;
  }

  Future<int> getCustomerCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('clients')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getProductCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('products')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Returns all usage metrics as a map (cached for 5 minutes)
  Future<Map<String, int>> getUsageSummary() async {
    if (_isCacheValid) return _cachedSummary!;

    final results = await Future.wait([
      getInvoiceCount(),
      getWhatsAppShareCount(),
      getCustomerCount(),
      getProductCount(),
    ]);
    _cachedSummary = {
      'invoices': results[0],
      'whatsappShares': results[1],
      'customers': results[2],
      'products': results[3],
    };
    _cacheTime = DateTime.now();
    return _cachedSummary!;
  }

  // ── Increment counters ────────────────────────────────────────────────

  Future<void> incrementInvoiceCount() async {
    invalidateCache();
    final ref = _usageRef;
    if (ref == null) return;
    await ref.set({
      'invoicesCreated': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> incrementWhatsAppShareCount() async {
    invalidateCache();
    final ref = _usageRef;
    if (ref == null) return;
    await ref.set({
      'whatsappShares': FieldValue.increment(1),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  // ── Real-time stream ──────────────────────────────────────────────────

  Stream<Map<String, int>> watchUsage() {
    final ref = _usageRef;
    if (ref == null) return Stream.value({'invoices': 0, 'whatsappShares': 0});
    return ref.snapshots().map((doc) {
      if (!doc.exists) return {'invoices': 0, 'whatsappShares': 0, 'customers': 0, 'products': 0};
      final data = doc.data() ?? {};
      return {
        'invoices': data['invoicesCreated'] as int? ?? 0,
        'whatsappShares': data['whatsappShares'] as int? ?? 0,
      };
    });
  }
}
