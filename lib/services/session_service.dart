import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static String _prefsTokenKey(String uid) => 'br_active_sess_tok_$uid';

  /// Call after successful sign-in to claim this device as the active session.
  ///
  /// [onSessionRevoked] fires when another device takes over the session.
  ///
  /// On a normal app restart, the same device keeps its token in
  /// [SharedPreferences] and Firestore already matches — we **skip** the write
  /// so the backend does not treat every open as a "new login" (e.g. login
  /// alert email). After [reset] on sign-out, prefs are cleared so the next
  /// sign-in performs a real claim again.
  Future<void> claimSession({required VoidCallback onSessionRevoked}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('[SessionService] No user signed in — skipping session claim');
      return;
    }

    _onSessionRevoked = onSessionRevoked;
    _revoked = false;

    final prefs = await SharedPreferences.getInstance();
    final prefsKey = _prefsTokenKey(uid);
    final savedToken = prefs.getString(prefsKey);

    if (savedToken != null && savedToken.isNotEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        final session = doc.data()?['activeSession'];
        final remoteToken = session is Map<String, dynamic>
            ? session['token'] as String?
            : null;
        if (remoteToken == savedToken) {
          _currentSessionToken = savedToken;
          _claimConfirmed = true;
          debugPrint(
            '[SessionService] Resuming session (no Firestore write) — '
            'token=${savedToken.length >= 8 ? savedToken.substring(0, 8) : savedToken}...',
          );
          _startSessionListener(uid);
          return;
        }
      } catch (e) {
        debugPrint('[SessionService] Resume check failed, claiming fresh: $e');
      }
    }

    _claimConfirmed = false;

    // Generate a unique token for this session (new login or session takeover)
    _currentSessionToken = _generateToken();

    final tokenPrefix = (_currentSessionToken != null &&
            _currentSessionToken!.length >= 8)
        ? _currentSessionToken!.substring(0, 8)
        : 'null';
    debugPrint(
      '[SessionService] Claiming session: $_platformLabel, token=$tokenPrefix...',
    );

    // Start listening BEFORE writing so we catch the server-confirmed write.
    _startSessionListener(uid);

    // Write session claim to Firestore — 5-second timeout so a slow network
    // doesn't block the UI from becoming interactive.
    try {
      await _firestore.collection('users').doc(uid).set({
        'activeSession': {
          'token': _currentSessionToken,
          'platform': _platformLabel,
          'claimedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));

      _claimConfirmed = true;
      await prefs.setString(prefsKey, _currentSessionToken!);
      debugPrint('[SessionService] Session claim confirmed by server');
    } catch (e) {
      debugPrint('[SessionService] Failed to claim session: $e');
      // Don't block sign-in if session claim fails (e.g. offline or timeout).
      // Listener is already running — it will detect changes when back online.
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
  Future<void> reset() async {
    final uid = _auth.currentUser?.uid;
    _sessionSub?.cancel();
    _sessionSub = null;
    _currentSessionToken = null;
    _onSessionRevoked = null;
    _revoked = false;
    _claimConfirmed = false;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsTokenKey(uid));
    }
  }
}
