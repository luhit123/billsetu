import 'package:billeasy/modals/analytics_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsService {
  AnalyticsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

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

  String _requireOwnerId() {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw StateError('Sign in is required to access analytics.');
    }
    return currentUser.uid;
  }
}
