import 'package:billeasy/modals/analytics_models.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsService {
  AnalyticsService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _dashboardDoc(String ownerId) {
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('analytics')
        .doc('dashboard');
  }

  DocumentReference<Map<String, dynamic>> _gstSummaryDoc({
    required String ownerId,
    required String periodType,
    required String periodKey,
  }) {
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('analytics')
        .doc('gstSummaries')
        .collection('periods')
        .doc('${periodType}_$periodKey');
  }

  Stream<DashboardAnalytics?> watchDashboardSummary() {
    final ownerId = _requireOwnerId();
    return _dashboardDoc(ownerId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return DashboardAnalytics.fromMap(data);
    });
  }

  Stream<GstPeriodSummary?> watchGstPeriodSummary({
    required String periodType,
    required String periodKey,
  }) {
    final ownerId = _requireOwnerId();
    return _gstSummaryDoc(
      ownerId: ownerId,
      periodType: periodType,
      periodKey: periodKey,
    ).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return GstPeriodSummary.fromMap(data);
    });
  }

  /// Returns the last time the dashboard analytics were updated.
  /// Useful for showing a "last synced" indicator in the UI.
  Future<DateTime?> getLastSyncedAt() async {
    final ownerId = _requireOwnerId();
    final snapshot = await _dashboardDoc(ownerId).get();
    final data = snapshot.data();
    if (data == null) return null;
    final ts = data['updatedAt'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  String _requireOwnerId() => TeamService.instance.getEffectiveOwnerId();
}
