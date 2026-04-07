import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Enforces single-session login: only one device can be active at a time.
///
/// On sign-in, a unique session token is written to `users/{uid}.activeSession`.
/// A real-time listener watches this field — if another device overwrites it,
/// the current device detects the mismatch and triggers a sign-out callback.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentSessionToken;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sessionSub;
  VoidCallback? _onSessionRevoked;

  /// Whether this session has been kicked by another device.
  bool _revoked = false;
  bool get isRevoked => _revoked;

  /// True once the initial claim write has been confirmed by the server.
  bool _claimConfirmed = false;

  /// The platform label for display (e.g. "Web", "Android", "iOS").
  static String get _platformLabel {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      default:
        return 'Unknown';
    }
  }

  /// Generate a random session token.
  static String _generateToken() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Call after successful sign-in to claim this device as the active session.
  ///
  /// [onSessionRevoked] fires when another device takes over the session.
  Future<void> claimSession({required VoidCallback onSessionRevoked}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('[SessionService] No user signed in — skipping session claim');
      return;
    }

    _onSessionRevoked = onSessionRevoked;
    _revoked = false;
    _claimConfirmed = false;

    // Generate a unique token for this session
    _currentSessionToken = _generateToken();

    debugPrint('[SessionService] Claiming session: $_platformLabel, token=${_currentSessionToken!.substring(0, 8)}...');

    // Start listening BEFORE writing so we catch the server-confirmed write.
    _startSessionListener(uid);

    // Write session claim to Firestore
    try {
      await _firestore.collection('users').doc(uid).set({
        'activeSession': {
          'token': _currentSessionToken,
          'platform': _platformLabel,
          'claimedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      _claimConfirmed = true;
      debugPrint('[SessionService] Session claim confirmed by server');
    } catch (e) {
      debugPrint('[SessionService] Failed to claim session: $e');
      // Don't block sign-in if session claim fails (e.g. offline)
      // Listener is already running — it will detect changes when back online
    }
  }

  /// Listen for session changes. If another device overwrites the token,
  /// this session is revoked.
  void _startSessionListener(String uid) {
    _sessionSub?.cancel();
    _sessionSub = _firestore
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return;

      final data = snapshot.data()!;
      final session = data['activeSession'] as Map<String, dynamic>?;
      if (session == null) return;

      final remoteToken = session['token'] as String?;
      if (remoteToken == null) return;

      // Skip local-only cache events — only act on server-confirmed data.
      // This prevents false-positive revocations from stale cache.
      final isFromServer = !snapshot.metadata.hasPendingWrites;

      debugPrint(
        '[SessionService] Snapshot: remote=${remoteToken.substring(0, 8)}...'
        ' local=${_currentSessionToken?.substring(0, 8)}...'
        ' fromServer=$isFromServer'
        ' claimConfirmed=$_claimConfirmed',
      );

      if (_currentSessionToken == null || _revoked) return;

      // If this is our own token, nothing to do
      if (remoteToken == _currentSessionToken) return;

      // Only revoke based on server-confirmed data (not stale local cache)
      if (!isFromServer) return;

      // If our claim hasn't been confirmed yet, don't revoke — we might just
      // be seeing the previous session's token before our write lands.
      if (!_claimConfirmed) return;

      final platform = session['platform'] as String? ?? 'another device';
      debugPrint(
        '[SessionService] Session REVOKED — taken over by $platform',
      );
      _revoked = true;
      _sessionSub?.cancel();
      _sessionSub = null;
      _onSessionRevoked?.call();
    });
  }

  /// Clean up listeners and state. Call on sign-out.
  void reset() {
    _sessionSub?.cancel();
    _sessionSub = null;
    _currentSessionToken = null;
    _onSessionRevoked = null;
    _revoked = false;
    _claimConfirmed = false;
  }
}
