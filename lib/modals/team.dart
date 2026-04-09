import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a team owned by a BillRaja subscriber.
///
/// Stored at `teams/{teamId}` where teamId equals the owner's Firebase UID.
/// This alignment means no extra lookup is needed — the team ID IS the owner
/// ID that all existing data is keyed under.
class Team {
  const Team({
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    this.ownerEmail = '',
    required this.businessName,
    this.memberCount = 0,
    this.maxMembers = 5,
    this.isActive = true,
    this.rolePermissions = const {},
    this.officeLatitude,
    this.officeLongitude,
    this.officeRadius = 200,
    this.officeAddress = '',
    this.requireGeofenceOnCheckout = false,
    this.createdAt,
    this.updatedAt,
  });

  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final String ownerEmail;
  final String businessName;
  final int memberCount;
  final int maxMembers;
  final bool isActive;

  /// Office geofence location for attendance.
  final double? officeLatitude;
  final double? officeLongitude;
  final double officeRadius; // meters
  final String officeAddress;

  /// If true, geo check-out also validates the geofence (default: false).
  final bool requireGeofenceOnCheckout;

  /// Whether office location is configured for geofence attendance.
  bool get hasOfficeLocation => officeLatitude != null && officeLongitude != null;

  /// Per-role permission overrides set by the owner.
  /// Structure: `{ "sales": { "canAddProduct": true, ... }, ... }`
  /// Only non-default values are stored.
  final Map<String, Map<String, bool>> rolePermissions;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Team.fromMap(Map<String, dynamic> map) {
    // Parse rolePermissions: { "sales": { "canX": true } }
    final rawPerms = map['rolePermissions'] as Map<String, dynamic>?;
    final rolePerms = <String, Map<String, bool>>{};
    if (rawPerms != null) {
      for (final entry in rawPerms.entries) {
        final perms = entry.value;
        if (perms is Map) {
          rolePerms[entry.key] = perms.map(
            (k, v) => MapEntry(k as String, v as bool),
          );
        }
      }
    }

    return Team(
      ownerId: map['ownerId'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? '',
      ownerPhone: map['ownerPhone'] as String? ?? '',
      ownerEmail: map['ownerEmail'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      memberCount: map['memberCount'] as int? ?? 0,
      maxMembers: map['maxMembers'] as int? ?? 5,
      isActive: map['isActive'] as bool? ?? true,
      officeLatitude: (map['officeLatitude'] as num?)?.toDouble(),
      officeLongitude: (map['officeLongitude'] as num?)?.toDouble(),
      officeRadius: (map['officeRadius'] as num?)?.toDouble() ?? 200,
      officeAddress: map['officeAddress'] as String? ?? '',
      requireGeofenceOnCheckout: map['requireGeofenceOnCheckout'] as bool? ?? false,
      rolePermissions: rolePerms,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'ownerEmail': ownerEmail,
      'businessName': businessName,
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'isActive': isActive,
      if (officeLatitude != null) 'officeLatitude': officeLatitude,
      if (officeLongitude != null) 'officeLongitude': officeLongitude,
      'officeRadius': officeRadius,
      'officeAddress': officeAddress,
      'requireGeofenceOnCheckout': requireGeofenceOnCheckout,
      'rolePermissions': rolePermissions,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Team copyWith({
    String? ownerId,
    String? ownerName,
    String? ownerPhone,
    String? ownerEmail,
    String? businessName,
    int? memberCount,
    int? maxMembers,
    bool? isActive,
    double? officeLatitude,
    double? officeLongitude,
    double? officeRadius,
    String? officeAddress,
    bool? requireGeofenceOnCheckout,
    Map<String, Map<String, bool>>? rolePermissions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Team(
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      businessName: businessName ?? this.businessName,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers ?? this.maxMembers,
      isActive: isActive ?? this.isActive,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      officeRadius: officeRadius ?? this.officeRadius,
      officeAddress: officeAddress ?? this.officeAddress,
      requireGeofenceOnCheckout: requireGeofenceOnCheckout ?? this.requireGeofenceOnCheckout,
      rolePermissions: rolePermissions ?? this.rolePermissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
