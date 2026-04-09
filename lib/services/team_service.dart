import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billeasy/modals/effective_permissions.dart';
import 'package:billeasy/modals/team.dart';
import 'package:billeasy/modals/team_invite.dart';
import 'package:billeasy/modals/team_member.dart';
import 'package:billeasy/modals/team_role.dart';
import 'package:billeasy/modals/user_team_map.dart';

/// Centralised team-awareness layer.
///
/// **The single pivot point for multi-user access:**
/// [getEffectiveOwnerId] returns the team owner's UID when the current user is
/// a team member, or the user's own UID when they are solo/owner. Every service
/// that previously used `currentUser.uid` as the data-path key now calls this
/// method instead, making the entire data layer team-aware without structural
/// changes.
class TeamService {
  TeamService._();
  static final TeamService instance = TeamService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ── Cached state ───────────────────────────────────────────────────────────

  UserTeamMap? _cachedMap;
  Team? _cachedTeam;
  StreamSubscription<DocumentSnapshot>? _mapSub;
  StreamSubscription<DocumentSnapshot>? _teamSub;
  final StreamController<TeamRole> _roleController =
      StreamController<TeamRole>.broadcast();

  // FIX T-1: Callback invoked when the user is removed from a team by the
  // owner (the userTeamMap document disappears while the user is online).
  // The UI layer (e.g. main.dart) registers a callback that shows a SnackBar
  // and navigates to the home screen.
  void Function()? onRemovedFromTeam;

  /// Tracks the last successful cache update from listeners.
  /// If stale (>10 min), permissions are force-refreshed on next access.
  DateTime _lastSuccessfulUpdate = DateTime.now();
  // FIX T-2: Reduced from 10 min to 2 min so revoked permissions are
  // detected sooner when the real-time listener has silently failed.
  static const _staleCacheThreshold = Duration(minutes: 2);
  static String _mapCacheKey(String uid) => 'team_service_map_v1_$uid';
  static String _teamCacheKey(String uid) => 'team_service_team_v1_$uid';

  /// Real-time stream of role changes (e.g. owner demotes a manager mid-session).
  Stream<TeamRole> get roleStream => _roleController.stream;

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Call once after sign-in (in main.dart, after ProfileService.init).
  ///
  /// Reads `userTeamMap/{uid}` and caches the result. For solo users the
  /// document does not exist — [_cachedMap] stays null and [getEffectiveOwnerId]
  /// returns the user's own UID. Zero behaviour change for existing users.
  Future<void> init() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _restoreCachedState(uid);

    try {
      final doc = await _firestore.collection('userTeamMap').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        _cachedMap = UserTeamMap.fromMap(doc.data()!);
        _persistCachedState(uid);
      } else {
        _cachedMap = null;
        _cachedTeam = null;
        _clearCachedState(uid);
      }
    } catch (e) {
      // Offline or permission error — prefer last known team state over
      // pretending the user is a solo owner.
      if (kDebugMode) debugPrint('[TeamService] init failed, using cached team state: $e');
    }

    // Fetch the team doc for permission overrides.
    await _loadTeamDoc();

    // Start real-time listeners.
    _startMapListener(uid);
    _startTeamListener();
  }

  Future<void> _loadTeamDoc() async {
    if (_cachedMap == null) {
      _cachedTeam = null;
      return;
    }
    try {
      final teamId = _cachedMap!.teamId;
      final doc = await _firestore.collection('teams').doc(teamId).get();
      if (doc.exists && doc.data() != null) {
        _cachedTeam = Team.fromMap(doc.data()!);
        final uid = _auth.currentUser?.uid;
        if (uid != null) {
          _persistCachedState(uid);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[TeamService] team doc load failed: $e');
    }
  }

  void _startMapListener(String uid) {
    _mapSub?.cancel();
    _mapSub = _firestore
        .collection('userTeamMap')
        .doc(uid)
        .snapshots()
        .listen(
          (snap) {
            final wasOnTeam = _cachedMap != null && !_cachedMap!.isOwner;
            if (snap.exists && snap.data() != null) {
              _cachedMap = UserTeamMap.fromMap(snap.data()!);
            } else {
              _cachedMap = null;
              _cachedTeam = null;
            }
            _lastSuccessfulUpdate = DateTime.now();
            _startTeamListener(); // Re-subscribe when team changes
            _roleController.add(currentRole);
            _persistCachedState(uid);

            // FIX T-1: Detect involuntary removal — the member's userTeamMap
            // doc was deleted by the owner while the user was online. Skip if
            // the user left voluntarily via leaveTeam().
            if (wasOnTeam && _cachedMap == null && !_userInitiatedLeave) {
              onRemovedFromTeam?.call();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (kDebugMode) debugPrint('[TeamService] userTeamMap listener failed: $error');
            // FIX T-2: Force immediate refresh on next `can` access so stale
            // permissions don't persist after a listener failure.
            _lastSuccessfulUpdate = DateTime(0);
            _roleController.add(currentRole);
          },
        );
  }

  void _startTeamListener() {
    _teamSub?.cancel();
    if (_cachedMap == null) {
      _cachedTeam = null;
      return;
    }
    final teamId = _cachedMap!.teamId;
    _teamSub = _firestore
        .collection('teams')
        .doc(teamId)
        .snapshots()
        .listen(
          (snap) {
            if (snap.exists && snap.data() != null) {
              _cachedTeam = Team.fromMap(snap.data()!);
              _lastSuccessfulUpdate = DateTime.now();
              // Broadcast so UI rebuilds with new permission overrides
              _roleController.add(currentRole);
              final uid = _auth.currentUser?.uid;
              if (uid != null) {
                _persistCachedState(uid);
              }
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (kDebugMode) debugPrint('[TeamService] team doc listener failed: $error');
            // FIX T-2: Force immediate refresh on next `can` access.
            _lastSuccessfulUpdate = DateTime(0);
          },
        );
  }

  // ── Core accessor ──────────────────────────────────────────────────────────

  /// Returns the UID whose Firestore data the current user should operate on.
  ///
  /// - Solo user / team owner → `currentUser.uid` (unchanged from legacy)
  /// - Team member → the owner's UID stored in [_cachedMap.teamId]
  String getEffectiveOwnerId() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw StateError('Sign in required');

    if (_cachedMap != null && !_cachedMap!.isOwner) {
      return _cachedMap!.teamId;
    }
    return currentUser.uid;
  }

  /// Returns the actual authenticated user's UID (never the team owner's).
  /// Use for operations that must be attributed to the acting user.
  String getActualUserId() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw StateError('Sign in required');
    return currentUser.uid;
  }

  // ── Role & status ──────────────────────────────────────────────────────────

  /// Current user's role. Defaults to [TeamRole.owner] for solo users,
  /// ensuring zero UI gating changes for existing users.
  TeamRole get currentRole => _cachedMap?.role ?? TeamRole.owner;

  /// Effective permissions for the current user, merging role defaults with
  /// any overrides the team owner has configured.
  ///
  /// For solo users: returns owner defaults (all true) — zero behaviour change.
  /// If the cache is stale (>2 min without a listener update), triggers a
  /// background refresh so the next access gets fresh data.
  EffectivePermissions get can {
    if (_cachedMap != null &&
        DateTime.now().difference(_lastSuccessfulUpdate) >
            _staleCacheThreshold) {
      // Trigger a background refresh — don't block the caller.
      _loadTeamDoc();
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        _firestore
            .collection('userTeamMap')
            .doc(uid)
            .get()
            .then((doc) {
              if (doc.exists && doc.data() != null) {
                _cachedMap = UserTeamMap.fromMap(doc.data()!);
                _lastSuccessfulUpdate = DateTime.now();
                _roleController.add(currentRole);
              }
            })
            .catchError((_) {});
      }
    }
    final role = currentRole;
    final overrides = _cachedTeam?.rolePermissions[role.toStringValue()] ?? {};
    return EffectivePermissions(role, overrides);
  }

  /// Whether the user is part of someone else's team (not solo, not owner).
  bool get isTeamMember => _cachedMap != null && !_cachedMap!.isOwner;

  /// Whether the user is the team owner (has created a team).
  bool get isTeamOwner => _cachedMap?.isOwner ?? false;

  /// Whether the user is on a team (either as owner or member).
  bool get isOnTeam => _cachedMap != null;

  /// Whether the user is operating solo (no team involvement).
  bool get isSolo => _cachedMap == null;

  /// The cached Team document (null if solo or not yet loaded).
  Team? get cachedTeam => _cachedTeam;

  /// The business name of the team the user belongs to (empty if solo).
  String get teamBusinessName => _cachedMap?.teamBusinessName ?? '';

  /// The member's display name as set by the owner during invitation.
  String get memberDisplayName => _cachedMap?.displayName ?? '';

  // ── Team creation ──────────────────────────────────────────────────────────

  /// Creates a new team for the current user (the owner).
  /// Should only be called by Pro subscribers from the team management screen.
  Future<void> createTeam({
    required String businessName,
    required String ownerName,
    required String ownerPhone,
    String ownerEmail = '',
  }) async {
    final uid = getActualUserId();
    if (kDebugMode) debugPrint('[TeamService] createTeam uid=$uid auth.uid=${_auth.currentUser?.uid}');

    await _functions.httpsCallable('createTeamCF', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call({
      'businessName': businessName,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'ownerEmail': ownerEmail,
    });

    // Update local cache
    final mapEntry = UserTeamMap(
      teamId: uid,
      role: TeamRole.owner,
      teamBusinessName: businessName,
      isOwner: true,
    );
    final team = Team(
      ownerId: uid,
      ownerName: ownerName,
      ownerPhone: ownerPhone,
      ownerEmail: ownerEmail,
      businessName: businessName,
      memberCount: 1,
    );

    _cachedMap = mapEntry;
    _cachedTeam = team;
    _roleController.add(TeamRole.owner);
    _persistCachedState(uid);
  }

  // ── Invite management ──────────────────────────────────────────────────────

  /// Invites a new member via Cloud Function (validates permissions server-side).
  Future<void> inviteMember({
    required String name,
    required String phone,
    String email = '',
    required TeamRole role,
  }) async {
    await _functions.httpsCallable('createTeamInvite', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call({
      'name': name,
      'phone': phone,
      'email': email,
      'role': role.toStringValue(),
    });
  }

  /// Returns pending invites for the current user (matched by phone/email).
  Future<List<TeamInvite>> getPendingInvites() async {
    try {
      final result = await _functions
          .httpsCallable(
            'checkPendingInvites',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call();
      final List<dynamic> invites = result.data['invites'] ?? [];
      return invites
          .map((e) => TeamInvite.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[TeamService] checkPendingInvites failed: ${e.code} — ${e.message} details=${e.details}',
        );
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[TeamService] checkPendingInvites failed: $e');
      rethrow;
    }
  }

  /// Accepts an invite via Cloud Function.
  Future<void> acceptInvite(String inviteId) async {
    await _functions.httpsCallable('acceptTeamInvite', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call({
      'inviteId': inviteId,
    });
    // Re-init to pick up the new userTeamMap entry.
    await init();
  }

  /// Declines an invite via Cloud Function.
  Future<void> declineInvite(String inviteId) async {
    await _functions.httpsCallable('declineTeamInvite', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call({
      'inviteId': inviteId,
    });
  }

  // ── Member management (owner-only) ─────────────────────────────────────────

  /// Streams team members (for the team management screen).
  Stream<List<TeamMember>> watchMembers() {
    final teamId = getEffectiveOwnerId();
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('members')
        .where('status', isEqualTo: 'active')
        .limit(100) // P-3: Safety cap for large Enterprise teams.
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => TeamMember.fromMap(d.data())).toList(),
        );
  }

  /// Removes a team member via Cloud Function.
  Future<void> removeMember(String memberUid) async {
    await _functions.httpsCallable('removeTeamMember', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call({
      'memberUid': memberUid,
    });
  }

  /// Changes a member's role via Cloud Function.
  Future<void> changeRole(String memberUid, TeamRole newRole) async {
    await _functions.httpsCallable('changeTeamMemberRole', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call({
      'memberUid': memberUid,
      'role': newRole.toStringValue(),
    });
  }

  /// True if the user initiated the leave (vs being removed by owner).
  bool _userInitiatedLeave = false;

  /// Whether the last team departure was voluntary.
  bool get wasVoluntaryLeave => _userInitiatedLeave;

  /// Current user leaves the team they belong to.
  Future<void> leaveTeam() async {
    _userInitiatedLeave = true;
    // Cancel listeners BEFORE the Cloud Function runs, so stale listeners
    // don't fire and hit permission-denied on the now-removed member doc.
    _mapSub?.cancel();
    _teamSub?.cancel();
    _mapSub = null;
    _teamSub = null;
    _cachedMap = null;
    _cachedTeam = null;
    await _functions.httpsCallable('leaveTeam', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call();
    // Terminate Firestore and clear offline cache to discard any pending
    // writes that were queued under the old team context — those writes
    // would fail with PERMISSION_DENIED now that we're no longer a member.
    try {
      await _firestore.terminate();
      await _firestore.clearPersistence();
    } catch (e) {
      if (kDebugMode) debugPrint('[TeamService] Cache clear after leave failed: $e');
    }
    await init();
  }

  // ── Team info ──────────────────────────────────────────────────────────────

  /// Gets the team document for the current team.
  Future<Team?> getTeam() async {
    final teamId = getEffectiveOwnerId();
    final doc = await _firestore.collection('teams').doc(teamId).get();
    if (doc.exists && doc.data() != null) {
      return Team.fromMap(doc.data()!);
    }
    return null;
  }

  /// Streams pending invites for the current team (owner/manager view).
  Stream<List<TeamInvite>> watchPendingInvites() {
    final teamId = getEffectiveOwnerId();
    return _firestore
        .collection('teamInvites')
        .where('teamId', isEqualTo: teamId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TeamInvite.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  /// Cancels a pending invite.
  Future<void> cancelInvite(String inviteId) async {
    await _functions.httpsCallable('cancelTeamInvite', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call({
      'inviteId': inviteId,
    });
  }

  // ── Permission management (owner-only) ─────────────────────────────────────

  /// Updates the permission overrides for a specific role.
  /// Only stores values that differ from the role's defaults.
  Future<void> updateRolePermissions(
    TeamRole role,
    Map<String, bool> overrides,
  ) async {
    // Only store values that differ from defaults
    final cleaned = <String, bool>{};
    for (final entry in overrides.entries) {
      if (entry.value != role.defaultFor(entry.key)) {
        cleaned[entry.key] = entry.value;
      }
    }
    await _functions.httpsCallable('updateTeamRolePermissions', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call({
      'role': role.toStringValue(),
      'overrides': cleaned,
    });
  }

  /// Updates the office geofence for the current team.
  Future<void> updateOfficeLocation({
    required double latitude,
    required double longitude,
    required double radius,
    String address = '',
  }) async {
    await _functions.httpsCallable('updateTeamOfficeLocation', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call({
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'address': address,
    });
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Called on sign-out. Clears all cached state.
  void reset() {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _clearCachedState(uid);
    }
    _mapSub?.cancel();
    _teamSub?.cancel();
    _mapSub = null;
    _teamSub = null;
    _cachedMap = null;
    _cachedTeam = null;
    _userInitiatedLeave = false;
  }

  void dispose() {
    _mapSub?.cancel();
    _teamSub?.cancel();
    _roleController.close();
  }

  Future<void> _restoreCachedState(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final rawMap = prefs.getString(_mapCacheKey(uid));
    if (rawMap != null && rawMap.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMap);
        if (decoded is Map) {
          _cachedMap = _cachedUserTeamMapFromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {}
    }

    final rawTeam = prefs.getString(_teamCacheKey(uid));
    if (rawTeam != null && rawTeam.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTeam);
        if (decoded is Map) {
          _cachedTeam = _cachedTeamFromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
  }

  Future<void> _persistCachedState(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (_cachedMap == null) {
      await prefs.remove(_mapCacheKey(uid));
      await prefs.remove(_teamCacheKey(uid));
      return;
    }

    await prefs.setString(
      _mapCacheKey(uid),
      jsonEncode(_cachedUserTeamMapToJson(_cachedMap!)),
    );

    if (_cachedTeam != null) {
      await prefs.setString(
        _teamCacheKey(uid),
        jsonEncode(_cachedTeamToJson(_cachedTeam!)),
      );
    } else {
      await prefs.remove(_teamCacheKey(uid));
    }
  }

  Future<void> _clearCachedState(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mapCacheKey(uid));
    await prefs.remove(_teamCacheKey(uid));
  }

  Map<String, dynamic> _cachedUserTeamMapToJson(UserTeamMap value) {
    return {
      'teamId': value.teamId,
      'role': value.role.toStringValue(),
      'teamBusinessName': value.teamBusinessName,
      'isOwner': value.isOwner,
      'joinedAt': value.joinedAt?.toIso8601String(),
    };
  }

  UserTeamMap _cachedUserTeamMapFromJson(Map<String, dynamic> json) {
    return UserTeamMap(
      teamId: json['teamId'] as String? ?? '',
      role: TeamRole.fromString(json['role'] as String?),
      teamBusinessName: json['teamBusinessName'] as String? ?? '',
      isOwner: json['isOwner'] as bool? ?? false,
      joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> _cachedTeamToJson(Team value) {
    return {
      'ownerId': value.ownerId,
      'ownerName': value.ownerName,
      'ownerPhone': value.ownerPhone,
      'ownerEmail': value.ownerEmail,
      'businessName': value.businessName,
      'memberCount': value.memberCount,
      'maxMembers': value.maxMembers,
      'isActive': value.isActive,
      'officeLatitude': value.officeLatitude,
      'officeLongitude': value.officeLongitude,
      'officeRadius': value.officeRadius,
      'officeAddress': value.officeAddress,
      'requireGeofenceOnCheckout': value.requireGeofenceOnCheckout,
      'rolePermissions': value.rolePermissions,
      'createdAt': value.createdAt?.toIso8601String(),
      'updatedAt': value.updatedAt?.toIso8601String(),
    };
  }

  Team _cachedTeamFromJson(Map<String, dynamic> json) {
    final permissions = <String, Map<String, bool>>{};
    final rawPermissions = json['rolePermissions'];
    if (rawPermissions is Map) {
      for (final entry in rawPermissions.entries) {
        final rawValue = entry.value;
        if (rawValue is Map) {
          permissions[entry.key as String] = rawValue.map(
            (key, value) => MapEntry(key as String, value == true),
          );
        }
      }
    }

    return Team(
      ownerId: json['ownerId'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? '',
      ownerPhone: json['ownerPhone'] as String? ?? '',
      ownerEmail: json['ownerEmail'] as String? ?? '',
      businessName: json['businessName'] as String? ?? '',
      memberCount: json['memberCount'] as int? ?? 0,
      maxMembers: json['maxMembers'] as int? ?? 5,
      isActive: json['isActive'] as bool? ?? true,
      officeLatitude: (json['officeLatitude'] as num?)?.toDouble(),
      officeLongitude: (json['officeLongitude'] as num?)?.toDouble(),
      officeRadius: (json['officeRadius'] as num?)?.toDouble() ?? 200,
      officeAddress: json['officeAddress'] as String? ?? '',
      requireGeofenceOnCheckout: json['requireGeofenceOnCheckout'] as bool? ?? false,
      rolePermissions: permissions,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
