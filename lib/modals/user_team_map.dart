import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:billeasy/modals/team_role.dart';

/// Single-document lookup that answers "which team does this user belong to?"
///
/// Stored at `userTeamMap/{userId}`. Read once at app startup and cached for
/// the session. For solo users this document does not exist — the absence is
/// itself the signal that the user is not on any team.
class UserTeamMap {
  const UserTeamMap({
    required this.teamId,
    required this.role,
    this.teamBusinessName = '',
    this.isOwner = false,
    this.joinedAt,
  });

  /// The owner's Firebase UID — this is the team ID and the data-path key.
  final String teamId;

  final TeamRole role;
  final String teamBusinessName;
  final bool isOwner;
  final DateTime? joinedAt;

  factory UserTeamMap.fromMap(Map<String, dynamic> map) {
    return UserTeamMap(
      teamId: map['teamId'] as String? ?? '',
      role: TeamRole.fromString(map['role'] as String?),
      teamBusinessName: map['teamBusinessName'] as String? ?? '',
      isOwner: map['isOwner'] as bool? ?? false,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'role': role.toStringValue(),
      'teamBusinessName': teamBusinessName,
      'isOwner': isOwner,
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
