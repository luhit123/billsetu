import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../modals/member.dart';
import '../modals/subscription_plan.dart';

class MembershipService {
  MembershipService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  String _requireOwnerId() {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('Sign in required');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _plansCol() {
    final uid = _requireOwnerId();
    return _firestore.collection('users').doc(uid).collection('subscription_plans');
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
        .map((snap) => snap.docs
            .map((d) => SubscriptionPlan.fromMap(d.data(), docId: d.id))
            .toList());
  }

  Future<List<SubscriptionPlan>> getActivePlans() async {
    final snap = await _plansCol()
        .where('isActive', isEqualTo: true)
        .orderBy('price')
        .get();
    return snap.docs
        .map((d) => SubscriptionPlan.fromMap(d.data(), docId: d.id))
        .toList();
  }

  Future<SubscriptionPlan?> getPlanById(String planId) async {
    if (planId.isEmpty) return null;
    final doc = await _plansCol().doc(planId).get();
    if (!doc.exists) return null;
    return SubscriptionPlan.fromMap(doc.data()!, docId: doc.id);
  }

  Future<SubscriptionPlan> savePlan(SubscriptionPlan plan) async {
    final uid = _requireOwnerId();
    final now = DateTime.now();
    final data = plan.copyWith(ownerId: uid, updatedAt: now).toMap();

    if (plan.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
      final ref = await _plansCol().add(data);
      return plan.copyWith(id: ref.id, ownerId: uid, createdAt: now, updatedAt: now);
    } else {
      await _plansCol().doc(plan.id).update(data);
      return plan.copyWith(ownerId: uid, updatedAt: now);
    }
  }

  Future<void> deletePlan(String planId) async {
    await _plansCol().doc(planId).delete();
  }

  Future<void> togglePlanActive(String planId, bool isActive) async {
    await _plansCol().doc(planId).update({
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Members CRUD ────────────────────────────────────────────────────────────

  Stream<List<Member>> watchMembers() {
    return _membersCol()
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Member.fromMap(d.data(), docId: d.id))
            .toList());
  }

  Stream<List<Member>> watchMembersByStatus(MemberStatus status) {
    return _membersCol()
        .where('status', isEqualTo: status.name)
        .orderBy('endDate')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Member.fromMap(d.data(), docId: d.id))
            .toList());
  }

  Future<Member> saveMember(Member member) async {
    final uid = _requireOwnerId();
    final now = DateTime.now();
    final data = member.copyWith(ownerId: uid, updatedAt: now).toMap();

    if (member.id.isEmpty) {
      data['createdAt'] = Timestamp.fromDate(now);
      final ref = await _membersCol().add(data);
      // Increment member count on plan
      if (member.planId.isNotEmpty) {
        await _plansCol().doc(member.planId).update({
          'memberCount': FieldValue.increment(1),
        });
      }
      return member.copyWith(id: ref.id, ownerId: uid, createdAt: now, updatedAt: now);
    } else {
      await _membersCol().doc(member.id).update(data);
      return member.copyWith(ownerId: uid, updatedAt: now);
    }
  }

  Future<void> deleteMember(String memberId, String planId) async {
    await _membersCol().doc(memberId).delete();
    if (planId.isNotEmpty) {
      await _plansCol().doc(planId).update({
        'memberCount': FieldValue.increment(-1),
      });
    }
  }

  Future<void> freezeMember(String memberId, DateTime freezeUntil) async {
    await _membersCol().doc(memberId).update({
      'status': MemberStatus.frozen.name,
      'frozenUntil': Timestamp.fromDate(freezeUntil),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> unfreezeMember(String memberId, DateTime newEndDate) async {
    await _membersCol().doc(memberId).update({
      'status': MemberStatus.active.name,
      'frozenUntil': null,
      'endDate': Timestamp.fromDate(newEndDate),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> renewMember(String memberId, DateTime newEnd, double amount) async {
    await _membersCol().doc(memberId).update({
      'status': MemberStatus.active.name,
      'endDate': Timestamp.fromDate(newEnd),
      'amountPaid': FieldValue.increment(amount),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Attendance ──────────────────────────────────────────────────────────────

  Future<void> markAttendance(String memberId, String memberName, String method) async {
    final uid = _requireOwnerId();
    final now = DateTime.now();
    await _attendanceCol(memberId).add(AttendanceLog(
      id: '',
      memberId: memberId,
      memberName: memberName,
      checkInTime: now,
      method: method,
      markedBy: uid,
    ).toMap());
    await _membersCol().doc(memberId).update({
      'attendanceCount': FieldValue.increment(1),
      'lastCheckIn': Timestamp.fromDate(now),
    });
  }

  Stream<List<AttendanceLog>> watchAttendance(String memberId, {int limit = 50}) {
    return _attendanceCol(memberId)
        .orderBy('checkInTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AttendanceLog.fromMap(d.data(), docId: d.id))
            .toList());
  }

  Future<List<AttendanceLog>> getTodayAttendance() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get all members first, then query each member's attendance subcollection
    final membersSnap = await _membersCol().get();
    final List<AttendanceLog> allLogs = [];

    for (final memberDoc in membersSnap.docs) {
      final snap = await _attendanceCol(memberDoc.id)
          .where('checkInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkInTime', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('checkInTime', descending: true)
          .get();
      allLogs.addAll(
        snap.docs.map((d) => AttendanceLog.fromMap(d.data(), docId: d.id)),
      );
    }

    // Sort combined results by checkInTime descending
    allLogs.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
    return allLogs;
  }

  // ── Dashboard Stats ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final snap = await _membersCol().get();
    final members = snap.docs.map((d) => Member.fromMap(d.data(), docId: d.id)).toList();

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
