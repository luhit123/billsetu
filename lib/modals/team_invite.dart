import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:billeasy/modals/team_role.dart';

/// Represents a pending invitation to join a team.
///
/// Stored at `teamInvites/{inviteId}` (auto-generated ID).
class TeamInvite {
  const TeamInvite({
    this.id = '',
    required this.teamId,
    this.teamBusinessName = '',
    this.invitedName = '',
    this.invitedPhone = '',
    this.invitedEmail = '',
    required this.role,
    this.status = 'pending',
    this.invitedBy = '',
    this.invitedByName = '',
    this.acceptedBy = '',
    this.createdAt,
    this.expiresAt,
    this.acceptedAt,
  });

  final String id;
  final String teamId;
  final String teamBusinessName;
  final String invitedName;
  final String invitedPhone;
  final String invitedEmail;
  final TeamRole role;

  /// 'pending' | 'accepted' | 'declined' | 'expired'
  final String status;

  final String invitedBy;
  final String invitedByName;
  final String acceptedBy;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;

  bool get isPending => status == 'pending';
  bool get isExpired =>
      status == 'expired' ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));

  /// Parses a date field that may be a Firestore [Timestamp] (from Firestore
  /// reads) or an [int] millis-since-epoch (from Cloud Function responses).
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  factory TeamInvite.fromMap(Map<String, dynamic> map, {String? id}) {
    return TeamInvite(
      id: id ?? map['id'] as String? ?? '',
      teamId: map['teamId'] as String? ?? '',
      teamBusinessName: map['teamBusinessName'] as String? ?? '',
      invitedName: map['invitedName'] as String? ?? '',
      invitedPhone: map['invitedPhone'] as String? ?? '',
      invitedEmail: map['invitedEmail'] as String? ?? '',
      role: TeamRole.fromString(map['role'] as String?),
      status: map['status'] as String? ?? 'pending',
      invitedBy: map['invitedBy'] as String? ?? '',
      invitedByName: map['invitedByName'] as String? ?? '',
      acceptedBy: map['acceptedBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      expiresAt: _parseDateTime(map['expiresAt']),
      acceptedAt: _parseDateTime(map['acceptedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'teamBusinessName': teamBusinessName,
      'invitedName': invitedName,
      'invitedPhone': invitedPhone,
      'invitedEmail': invitedEmail,
      'role': role.toStringValue(),
      'status': status,
      'invitedBy': invitedBy,
      'invitedByName': invitedByName,
      'acceptedBy': acceptedBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
    };
  }

  TeamInvite copyWith({
    String? id,
    String? teamId,
    String? teamBusinessName,
    String? invitedName,
    String? invitedPhone,
    String? invitedEmail,
    TeamRole? role,
    String? status,
    String? invitedBy,
    String? invitedByName,
    String? acceptedBy,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? acceptedAt,
  }) {
    return TeamInvite(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      teamBusinessName: teamBusinessName ?? this.teamBusinessName,
      invitedName: invitedName ?? this.invitedName,
      invitedPhone: invitedPhone ?? this.invitedPhone,
      invitedEmail: invitedEmail ?? this.invitedEmail,
      role: role ?? this.role,
      status: status ?? this.status,
      invitedBy: invitedBy ?? this.invitedBy,
      invitedByName: invitedByName ?? this.invitedByName,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }
}
