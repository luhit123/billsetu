import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:billeasy/modals/team_role.dart';

/// Represents a member of a team.
///
/// Stored at `teams/{teamId}/members/{uid}`.
class TeamMember {
  const TeamMember({
    required this.uid,
    required this.role,
    this.displayName = '',
    this.phone = '',
    this.email = '',
    this.status = 'active',
    this.invitedBy = '',
    this.invitedAt,
    this.joinedAt,
    this.updatedAt,
  });

  final String uid;
  final TeamRole role;
  final String displayName;
  final String phone;
  final String email;

  /// 'invited' | 'active' | 'removed'
  final String status;

  final String invitedBy;
  final DateTime? invitedAt;
  final DateTime? joinedAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';
  bool get isInvited => status == 'invited';

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      uid: map['uid'] as String? ?? '',
      role: TeamRole.fromString(map['role'] as String?),
      displayName: map['displayName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      invitedBy: map['invitedBy'] as String? ?? '',
      invitedAt: (map['invitedAt'] as Timestamp?)?.toDate(),
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role.toStringValue(),
      'displayName': displayName,
      'phone': phone,
      'email': email,
      'status': status,
      'invitedBy': invitedBy,
      'invitedAt': invitedAt != null ? Timestamp.fromDate(invitedAt!) : FieldValue.serverTimestamp(),
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TeamMember copyWith({
    String? uid,
    TeamRole? role,
    String? displayName,
    String? phone,
    String? email,
    String? status,
    String? invitedBy,
    DateTime? invitedAt,
    DateTime? joinedAt,
    DateTime? updatedAt,
  }) {
    return TeamMember(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      invitedBy: invitedBy ?? this.invitedBy,
      invitedAt: invitedAt ?? this.invitedAt,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
