import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../modals/member.dart';
import '../modals/team.dart';
import 'team_service.dart';
import '../modals/subscription_plan.dart';

class MembershipService {
  MembershipService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  String _requireOwnerId() => TeamService.instance.getEffectiveOwnerId();

  CollectionReference<Map<String, dynamic>> _plansCol() {
    final uid = _requireOwnerId();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('subscription_plans');
  }

  CollectionReference<Map<String, dynamic>> _membersCol() {
    final uid = _requireOwnerId();
    return _firestore.collection('users').doc(uid).collection('members');
  }

  CollectionReference<Map<String, dynamic>> _attendanceCol(String memberId) {
    final uid = _requireOwnerId();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('members')
        .doc(memberId)
        .collection('attendance');
  }

  // ── Plans CRUD ──────────────────────────────────────────────────────────────

  Stream<List<SubscriptionPlan>> watchPlans() {
    return _plansCol()
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SubscriptionPlan.fromMap(d.data(), docId: d.id))
              .where((plan) => !plan.isDeleted)
              .toList(),
        );
  }

  Future<List<SubscriptionPlan>> getActivePlans() async {
    final snap = await _plansCol()
        .where('isActive', isEqualTo: true)
        .orderBy('price')
        .get();
    return snap.docs
        .map((d) => SubscriptionPlan.fromMap(d.data(), docId: d.id))
        .where((plan) => !plan.isDeleted)
        .toList();
  }

  Future<SubscriptionPlan?> getPlanById(String planId) async {
    if (planId.isEmpty) return null;
    final doc = await _plansCol().doc(planId).get();
    if (!doc.exists) return null;
    return SubscriptionPlan.fromMap(doc.data()!, docId: doc.id);
  }

  Future<SubscriptionPlan> savePlan(SubscriptionPlan plan) async {
    final result = await _functions.httpsCallable('saveMembershipPlan').call({
      'planId': plan.id,
      'plan': {
        'name': plan.name,
        'description': plan.description,
        'benefits': plan.benefits,
        'duration': plan.duration.name,
        'customDays': plan.customDays,
        'price': plan.price,
        'joiningFee': plan.joiningFee,
        'discountPercent': plan.discountPercent,
        'gracePeriodDays': plan.gracePeriodDays,
        'planType': plan.planType.name,
        'autoRenew': plan.autoRenew,
        'isActive': plan.isActive,
        'colorHex': plan.colorHex,
        'gstEnabled': plan.gstEnabled,
        'gstRate': plan.gstRate,
        'gstType': plan.gstType,
      },
    });

    final savedId = result.data['planId'] as String? ?? plan.id;
    final savedDoc = await _plansCol().doc(savedId).get();
    if (!savedDoc.exists || savedDoc.data() == null) {
      throw StateError('Saved membership plan could not be loaded.');
    }
    return SubscriptionPlan.fromMap(savedDoc.data()!, docId: savedDoc.id);
  }

  Future<void> deletePlan(String planId) async {
    await _functions.httpsCallable('deleteMembershipPlan').call({
      'planId': planId,
    });
  }

  Future<void> togglePlanActive(String planId, bool isActive) async {
    await _functions.httpsCallable('setMembershipPlanActive').call({
      'planId': planId,
      'isActive': isActive,
    });
  }

  // ── Members CRUD ────────────────────────────────────────────────────────────

  Stream<List<Member>> watchMembers() {
    return _membersCol()
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Member.fromMap(d.data(), docId: d.id))
              .where((member) => !member.isDeleted)
              .toList(),
        );
  }

  Stream<List<Member>> watchMembersByStatus(MemberStatus status) {
    return _membersCol()
        .where('status', isEqualTo: status.name)
        .orderBy('endDate')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Member.fromMap(d.data(), docId: d.id))
              .where((member) => !member.isDeleted)
              .toList(),
        );
  }

  Future<Member> saveMember(Member member) async {
    final result = await _functions.httpsCallable('saveMembershipMember').call({
      'memberId': member.id,
      'member': {
        'name': member.name,
        'phone': member.phone,
        'email': member.email,
        'notes': member.notes,
        'planId': member.planId,
        'startDateMs': member.startDate.millisecondsSinceEpoch,
        'endDateMs': member.endDate.millisecondsSinceEpoch,
        'autoRenew': member.autoRenew,
        'amountPaid': member.amountPaid,
        'joiningFeePaid': member.joiningFeePaid,
      },
    });

    final savedId = result.data['memberId'] as String? ?? member.id;
    final savedDoc = await _membersCol().doc(savedId).get();
    if (!savedDoc.exists || savedDoc.data() == null) {
      throw StateError('Saved membership member could not be loaded.');
    }
    return Member.fromMap(savedDoc.data()!, docId: savedDoc.id);
  }

  Future<void> deleteMember(String memberId, String planId) async {
    await _functions.httpsCallable('deleteMembershipMember').call({
      'memberId': memberId,
    });
  }

  Future<void> freezeMember(String memberId, DateTime freezeUntil) async {
    await _functions.httpsCallable('freezeMembershipMember').call({
      'memberId': memberId,
      'freezeUntilMs': freezeUntil.millisecondsSinceEpoch,
    });
  }

  Future<DateTime> unfreezeMember(
    String memberId, [
    DateTime? legacyNewEndDate,
  ]) async {
    final result = await _functions
        .httpsCallable('unfreezeMembershipMember')
        .call({'memberId': memberId});
    final newEndMs = result.data['newEndDate'] as int?;
    if (newEndMs == null) {
      return legacyNewEndDate ?? DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(newEndMs);
  }

  Future<MembershipRenewalResult> renewMember(
    String memberId, [
    DateTime? legacyNewEnd,
    double? legacyAmount,
  ]) async {
    final result = await _functions.httpsCallable('renewMembershipMember').call(
      {'memberId': memberId},
    );
    final newEndMs = result.data['newEndDate'] as int?;
    final renewalAmount = (result.data['renewalAmount'] as num?)?.toDouble();
    return MembershipRenewalResult(
      newEndDate: newEndMs != null
          ? DateTime.fromMillisecondsSinceEpoch(newEndMs)
          : (legacyNewEnd ?? DateTime.now()),
      renewalAmount: renewalAmount ?? (legacyAmount ?? 0),
    );
  }

  // ── Attendance ──────────────────────────────────────────────────────────────

  Future<void> markAttendance(
    String memberId,
    String memberName,
    String method,
  ) async {
    await _functions.httpsCallable('markMembershipAttendance').call({
      'memberId': memberId,
      'method': method,
    });
  }

  Stream<List<AttendanceLog>> watchAttendance(
    String memberId, {
    int limit = 50,
  }) {
    return _attendanceCol(memberId)
        .orderBy('checkInTime', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AttendanceLog.fromMap(d.data(), docId: d.id))
              .toList(),
        );
  }

  Future<List<AttendanceLog>> getTodayAttendance() async {
    final uid = _requireOwnerId();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Single collectionGroup query replaces N+1 per-member queries.
    // Requires a Firestore composite index on 'attendance' collectionGroup:
    //   markedBy ASC, checkInTime ASC
    final snap = await _firestore
        .collectionGroup('attendance')
        .where('attendanceDomain', isEqualTo: 'membership')
        .where('markedBy', isEqualTo: uid)
        .where(
          'checkInTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('checkInTime', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('checkInTime', descending: true)
        .get();

    return snap.docs
        .map((d) => AttendanceLog.fromMap(d.data(), docId: d.id))
        .toList();
  }

  // ── Geo Attendance ──────────────────────────────────────────────────────────

  /// Team attendance collection: `teams/{teamId}/members/{memberId}/attendance`
  CollectionReference<Map<String, dynamic>> _teamAttendanceCol(
    String memberId,
  ) {
    final teamId = TeamService.instance.getEffectiveOwnerId();
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('members')
        .doc(memberId)
        .collection('attendance');
  }

  /// Check if coordinates are inside the team's office geofence.
  bool isInsideGeofence(double lat, double lng, Team team) {
    if (!team.hasOfficeLocation) return false;
    final distance = _haversineDistance(
      lat,
      lng,
      team.officeLatitude!,
      team.officeLongitude!,
    );
    return distance <= team.officeRadius;
  }

  /// Distance in meters between two coordinates (Haversine formula).
  double distanceToOffice(double lat, double lng, Team team) {
    if (!team.hasOfficeLocation) return double.infinity;
    return _haversineDistance(
      lat,
      lng,
      team.officeLatitude!,
      team.officeLongitude!,
    );
  }

  /// Geo check-in: records attendance with GPS coordinates.
  Future<String> geoCheckIn({
    required String memberId,
    required String memberName,
    required double latitude,
    required double longitude,
  }) async {
    final uid = TeamService.instance.getActualUserId();
    if (memberId != uid) {
      throw StateError('You can only check in for yourself.');
    }

    final result = await _functions.httpsCallable('teamGeoCheckIn').call({
      'latitude': latitude,
      'longitude': longitude,
    });

    return result.data['logId'] as String? ?? '';
  }

  /// Geo check-out: updates the existing attendance log with checkout time.
  Future<void> geoCheckOut({
    required String memberId,
    required String logId,
    required double latitude,
    required double longitude,
  }) async {
    final uid = TeamService.instance.getActualUserId();
    if (memberId != uid) {
      throw StateError('You can only check out for yourself.');
    }

    await _functions.httpsCallable('teamGeoCheckOut').call({'logId': logId});
  }

  /// Gets today's active check-in for a member (if any, no checkout yet).
  Future<AttendanceLog?> getActiveCheckIn(String memberId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _teamAttendanceCol(memberId)
        .where(
          'checkInTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .orderBy('checkInTime', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final log = AttendanceLog.fromMap(
      snap.docs.first.data(),
      docId: snap.docs.first.id,
    );
    return log.isCheckedIn ? log : null;
  }

  /// Watches attendance logs for a team member.
  Stream<List<AttendanceLog>> watchTeamAttendance(
    String memberId, {
    int limit = 50,
  }) {
    return _teamAttendanceCol(memberId)
        .orderBy('checkInTime', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AttendanceLog.fromMap(d.data(), docId: d.id))
              .toList(),
        );
  }

  Future<List<AttendanceLog>> getTeamAttendance(
    String memberId, {
    int limit = 50,
  }) async {
    final snap = await _teamAttendanceCol(
      memberId,
    ).orderBy('checkInTime', descending: true).limit(limit).get();
    return snap.docs
        .map((d) => AttendanceLog.fromMap(d.data(), docId: d.id))
        .toList();
  }

  /// Haversine formula for distance between two GPS points (in meters).
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0; // Earth's radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  // ── Dashboard Stats ─────────────────────────────────────────────────────────

  // Loads all members for field-level aggregation (revenue, expiry dates).
  // For very large gyms (>10K members), consider denormalizing stats into
  // a summary document updated by a Cloud Function trigger.
  Future<Map<String, dynamic>> getDashboardStats() async {
    final snap = await _membersCol().get();
    final members = snap.docs
        .map((d) => Member.fromMap(d.data(), docId: d.id))
        .where((member) => !member.isDeleted)
        .toList();

    final now = DateTime.now();
    int active = 0, expired = 0, frozen = 0, expiringThisWeek = 0;
    double totalRevenue = 0;

    for (final m in members) {
      totalRevenue += m.amountPaid + m.joiningFeePaid;
      if (m.status == MemberStatus.frozen) {
        frozen++;
      } else if (m.endDate.isBefore(now)) {
        expired++;
      } else {
        active++;
        if (m.endDate.difference(now).inDays <= 7) {
          expiringThisWeek++;
        }
      }
    }

    return {
      'totalMembers': members.length,
      'active': active,
      'expired': expired,
      'frozen': frozen,
      'expiringThisWeek': expiringThisWeek,
      'totalRevenue': totalRevenue,
    };
  }
}

class MembershipRenewalResult {
  const MembershipRenewalResult({
    required this.newEndDate,
    required this.renewalAmount,
  });

  final DateTime newEndDate;
  final double renewalAmount;
}
