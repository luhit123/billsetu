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
  final String planDuration;
  final int planDurationDays;
  final String planTypeSnapshot;
  final int planGracePeriodDays;
  final bool planGstEnabled;
  final double planGstRate;
  final String planGstType;
  final double planEffectivePrice;
  final MemberStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? frozenUntil;
  final bool autoRenew;
  final double amountPaid;
  final double joiningFeePaid;
  final int attendanceCount;
  final DateTime? lastCheckIn;
  final bool isDeleted;
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
    this.planDuration = 'monthly',
    this.planDurationDays = 30,
    this.planTypeSnapshot = 'recurring',
    this.planGracePeriodDays = 0,
    this.planGstEnabled = false,
    this.planGstRate = 18,
    this.planGstType = 'cgst_sgst',
    this.planEffectivePrice = 0,
    this.status = MemberStatus.active,
    required this.startDate,
    required this.endDate,
    this.frozenUntil,
    this.autoRenew = true,
    this.amountPaid = 0,
    this.joiningFeePaid = 0,
    this.attendanceCount = 0,
    this.lastCheckIn,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive =>
      status == MemberStatus.active && endDate.isAfter(DateTime.now());
  bool get isExpired =>
      status == MemberStatus.expired || endDate.isBefore(DateTime.now());
  bool get isFrozen =>
      status == MemberStatus.frozen &&
      frozenUntil != null &&
      frozenUntil!.isAfter(DateTime.now());

  // ── SM-2: Effective state helpers ──────────────────────────────────
  // These account for the grace period and temporal boundaries so the UI
  // can show the *real* state even before the Cloud Function syncs.

  /// True when the membership is genuinely usable right now:
  /// status == active AND still within endDate + grace period.
  bool get isEffectivelyActive {
    if (status != MemberStatus.active) return false;
    final graceEnd = endDate.add(Duration(days: planGracePeriodDays));
    return DateTime.now().isBefore(graceEnd);
  }

  /// True when the membership has lapsed beyond its grace window,
  /// regardless of whether the Cloud Function has flipped the status yet.
  bool get isEffectivelyExpired {
    if (status == MemberStatus.expired || status == MemberStatus.cancelled) {
      return true;
    }
    if (status == MemberStatus.active) {
      final graceEnd = endDate.add(Duration(days: planGracePeriodDays));
      return DateTime.now().isAfter(graceEnd);
    }
    return false;
  }

  /// True when the membership is frozen AND the freeze window hasn't ended.
  bool get isEffectivelyFrozen {
    if (status != MemberStatus.frozen) return false;
    if (frozenUntil == null) return true; // indefinite freeze
    return DateTime.now().isBefore(frozenUntil!);
  }

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
    final parsedStartDate =
        (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    var parsedEndDate =
        (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    // Issue #18: Ensure endDate is never before startDate (defensive against corrupt data)
    if (parsedEndDate.isBefore(parsedStartDate)) {
      parsedEndDate = parsedStartDate;
    }
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
      planDuration: map['planDuration'] as String? ?? 'monthly',
      planDurationDays: map['planDurationDays'] as int? ?? 30,
      planTypeSnapshot: map['planTypeSnapshot'] as String? ?? 'recurring',
      planGracePeriodDays: map['planGracePeriodDays'] as int? ?? 0,
      planGstEnabled: map['planGstEnabled'] as bool? ?? false,
      planGstRate: (map['planGstRate'] as num?)?.toDouble() ?? 18,
      planGstType: map['planGstType'] as String? ?? 'cgst_sgst',
      planEffectivePrice: (map['planEffectivePrice'] as num?)?.toDouble() ?? 0,
      status: _parseStatus(map['status'] as String?),
      startDate: parsedStartDate,
      endDate: parsedEndDate,
      frozenUntil: (map['frozenUntil'] as Timestamp?)?.toDate(),
      autoRenew: map['autoRenew'] as bool? ?? true,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0,
      joiningFeePaid: (map['joiningFeePaid'] as num?)?.toDouble() ?? 0,
      attendanceCount: map['attendanceCount'] as int? ?? 0,
      lastCheckIn: (map['lastCheckIn'] as Timestamp?)?.toDate(),
      isDeleted: map['isDeleted'] as bool? ?? false,
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
      'planDuration': planDuration,
      'planDurationDays': planDurationDays,
      'planTypeSnapshot': planTypeSnapshot,
      'planGracePeriodDays': planGracePeriodDays,
      'planGstEnabled': planGstEnabled,
      'planGstRate': planGstRate,
      'planGstType': planGstType,
      'planEffectivePrice': planEffectivePrice,
      'status': status.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'frozenUntil': frozenUntil != null
          ? Timestamp.fromDate(frozenUntil!)
          : null,
      'autoRenew': autoRenew,
      'amountPaid': amountPaid,
      'joiningFeePaid': joiningFeePaid,
      'attendanceCount': attendanceCount,
      'lastCheckIn': lastCheckIn != null
          ? Timestamp.fromDate(lastCheckIn!)
          : null,
      'isDeleted': isDeleted,
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
    String? planDuration,
    int? planDurationDays,
    String? planTypeSnapshot,
    int? planGracePeriodDays,
    bool? planGstEnabled,
    double? planGstRate,
    String? planGstType,
    double? planEffectivePrice,
    MemberStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? frozenUntil,
    bool? autoRenew,
    double? amountPaid,
    double? joiningFeePaid,
    int? attendanceCount,
    DateTime? lastCheckIn,
    bool? isDeleted,
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
      planDuration: planDuration ?? this.planDuration,
      planDurationDays: planDurationDays ?? this.planDurationDays,
      planTypeSnapshot: planTypeSnapshot ?? this.planTypeSnapshot,
      planGracePeriodDays: planGracePeriodDays ?? this.planGracePeriodDays,
      planGstEnabled: planGstEnabled ?? this.planGstEnabled,
      planGstRate: planGstRate ?? this.planGstRate,
      planGstType: planGstType ?? this.planGstType,
      planEffectivePrice: planEffectivePrice ?? this.planEffectivePrice,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      frozenUntil: frozenUntil ?? this.frozenUntil,
      autoRenew: autoRenew ?? this.autoRenew,
      amountPaid: amountPaid ?? this.amountPaid,
      joiningFeePaid: joiningFeePaid ?? this.joiningFeePaid,
      attendanceCount: attendanceCount ?? this.attendanceCount,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      isDeleted: isDeleted ?? this.isDeleted,
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
  final DateTime? checkOutTime;
  final String method; // 'qr', 'code', 'manual', 'geo'
  final String markedBy;
  final double? latitude;
  final double? longitude;

  const AttendanceLog({
    required this.id,
    required this.memberId,
    this.memberName = '',
    required this.checkInTime,
    this.checkOutTime,
    this.method = 'manual',
    this.markedBy = '',
    this.latitude,
    this.longitude,
  });

  /// Total hours worked (null if not yet checked out).
  double? get totalHours {
    if (checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime).inMinutes / 60.0;
  }

  /// Whether the member is currently checked in (no checkout yet).
  bool get isCheckedIn => checkOutTime == null;

  factory AttendanceLog.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AttendanceLog(
      id: docId ?? map['id'] as String? ?? '',
      memberId: map['memberId'] as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      checkInTime:
          (map['checkInTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      checkOutTime: (map['checkOutTime'] as Timestamp?)?.toDate(),
      method: map['method'] as String? ?? 'manual',
      markedBy: map['markedBy'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'checkInTime': Timestamp.fromDate(checkInTime),
      if (checkOutTime != null)
        'checkOutTime': Timestamp.fromDate(checkOutTime!),
      'method': method,
      'markedBy': markedBy,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}
