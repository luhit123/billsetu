import 'package:cloud_firestore/cloud_firestore.dart';

enum MemberStatus { active, expired, frozen, cancelled }

class Member {
  final String id;
  final String ownerId;
  final String name;
  final String phone;
  final String email;
  final String photoUrl;
  final String notes;
  final String planId;
  final String planName;
  final MemberStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? frozenUntil;
  final bool autoRenew;
  final double amountPaid;
  final double joiningFeePaid;
  final int attendanceCount;
  final DateTime? lastCheckIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Member({
    required this.id,
    required this.ownerId,
    required this.name,
    this.phone = '',
    this.email = '',
    this.photoUrl = '',
    this.notes = '',
    required this.planId,
    this.planName = '',
    this.status = MemberStatus.active,
    required this.startDate,
    required this.endDate,
    this.frozenUntil,
    this.autoRenew = true,
    this.amountPaid = 0,
    this.joiningFeePaid = 0,
    this.attendanceCount = 0,
    this.lastCheckIn,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == MemberStatus.active && endDate.isAfter(DateTime.now());
  bool get isExpired => status == MemberStatus.expired || endDate.isBefore(DateTime.now());
  bool get isFrozen => status == MemberStatus.frozen && frozenUntil != null && frozenUntil!.isAfter(DateTime.now());

  int get daysLeft {
    if (isExpired) return 0;
    if (isFrozen) return endDate.difference(DateTime.now()).inDays;
    return endDate.difference(DateTime.now()).inDays;
  }

  String get daysLeftLabel {
    final d = daysLeft;
    if (d <= 0) return 'Expired';
    if (d == 1) return '1 day left';
    return '$d days left';
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory Member.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Member(
      id: docId ?? map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      planId: map['planId'] as String? ?? '',
      planName: map['planName'] as String? ?? '',
      status: _parseStatus(map['status'] as String?),
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      frozenUntil: (map['frozenUntil'] as Timestamp?)?.toDate(),
      autoRenew: map['autoRenew'] as bool? ?? true,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0,
      joiningFeePaid: (map['joiningFeePaid'] as num?)?.toDouble() ?? 0,
      attendanceCount: map['attendanceCount'] as int? ?? 0,
      lastCheckIn: (map['lastCheckIn'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'nameLower': name.toLowerCase(),
      'phone': phone,
      'email': email,
      'photoUrl': photoUrl,
      'notes': notes,
      'planId': planId,
      'planName': planName,
      'status': status.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'frozenUntil': frozenUntil != null ? Timestamp.fromDate(frozenUntil!) : null,
      'autoRenew': autoRenew,
      'amountPaid': amountPaid,
      'joiningFeePaid': joiningFeePaid,
      'attendanceCount': attendanceCount,
      'lastCheckIn': lastCheckIn != null ? Timestamp.fromDate(lastCheckIn!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Member copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? phone,
    String? email,
    String? photoUrl,
    String? notes,
    String? planId,
    String? planName,
    MemberStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? frozenUntil,
    bool? autoRenew,
    double? amountPaid,
    double? joiningFeePaid,
    int? attendanceCount,
    DateTime? lastCheckIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Member(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      frozenUntil: frozenUntil ?? this.frozenUntil,
      autoRenew: autoRenew ?? this.autoRenew,
      amountPaid: amountPaid ?? this.amountPaid,
      joiningFeePaid: joiningFeePaid ?? this.joiningFeePaid,
      attendanceCount: attendanceCount ?? this.attendanceCount,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static MemberStatus _parseStatus(String? s) {
    if (s == null) return MemberStatus.active;
    return MemberStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => MemberStatus.active,
    );
  }
}

class AttendanceLog {
  final String id;
  final String memberId;
  final String memberName;
  final DateTime checkInTime;
  final String method; // 'qr', 'code', 'manual'
  final String markedBy;

  const AttendanceLog({
    required this.id,
    required this.memberId,
    this.memberName = '',
    required this.checkInTime,
    this.method = 'manual',
    this.markedBy = '',
  });

  factory AttendanceLog.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AttendanceLog(
      id: docId ?? map['id'] as String? ?? '',
      memberId: map['memberId'] as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      checkInTime: (map['checkInTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      method: map['method'] as String? ?? 'manual',
      markedBy: map['markedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'checkInTime': Timestamp.fromDate(checkInTime),
      'method': method,
      'markedBy': markedBy,
    };
  }
}
