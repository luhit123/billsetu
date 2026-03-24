import 'package:billeasy/utils/firestore_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class UsageTrackingService {
  UsageTrackingService._();
  static final UsageTrackingService instance = UsageTrackingService._();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String get _currentPeriodKey => DateFormat('yyyy-MM').format(DateTime.now());

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
    final doc = await resilientGet(ref);
    if (!doc.exists) return 0;
    return doc.data()?['invoicesCreated'] as int? ?? 0;
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

  /// Returns all usage metrics as a map
  Future<Map<String, int>> getUsageSummary() async {
    final results = await Future.wait([
      getInvoiceCount(),
      getWhatsAppShareCount(),
      getCustomerCount(),
      getProductCount(),
    ]);
    return {
      'invoices': results[0],
      'whatsappShares': results[1],
      'customers': results[2],
      'products': results[3],
    };
  }

  // ── Increment counters ────────────────────────────────────────────────
  // Invoice counts are incremented server-side by the syncInvoiceAnalytics
  // Cloud Function trigger when a new invoice document is created. No client
  // write is needed (and is blocked by Firestore rules).

  /// Records a WhatsApp share via Cloud Function so the counter cannot be
  /// manipulated by a direct client write.
  Future<void> incrementWhatsAppShareCount() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFunctions.instance.httpsCallable('trackWhatsAppShare').call();
    } catch (e) {
      if (kDebugMode) debugPrint('[UsageTracking] trackWhatsAppShare failed: $e');
    }
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
