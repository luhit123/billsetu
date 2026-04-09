import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import 'package:billeasy/services/team_service.dart';

/// Monitors Firestore snapshot metadata to detect pending writes that
/// haven't synced to the server, and surfaces sync failure warnings.
///
/// Implements WidgetsBindingObserver to pause/resume the periodic timer
/// when the app enters background/foreground (Issue #13).
///
/// Usage:
///   SyncStatusService.instance.init();
///   // Listen in UI:
///   SyncStatusService.instance.hasPendingWrites  // ValueNotifier\<bool\>
///   SyncStatusService.instance.lastSyncError     // ValueNotifier\<String?\>
class SyncStatusService with WidgetsBindingObserver {
  SyncStatusService._();
  static final SyncStatusService instance = SyncStatusService._();

  bool _observerRegistered = false;

  final _firestore = FirebaseFirestore.instance;

  /// True when the local Firestore cache has writes that haven't reached
  /// the server yet.
  final ValueNotifier<bool> hasPendingWrites = ValueNotifier(false);

  /// Non-null when a sync operation has failed. Cleared on next successful sync.
  final ValueNotifier<String?> lastSyncError = ValueNotifier(null);

  /// Number of consecutive sync check failures.
  final ValueNotifier<int> pendingWriteAge = ValueNotifier(0);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _checkTimer;
  bool _previouslyHadPending = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background — pause the periodic timer to save resources
      _checkTimer?.cancel();
      _checkTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground — restart the timer
      if (_sub != null && _checkTimer == null) {
        _startCheckTimer();
      }
    }
  }

  void _startCheckTimer() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (hasPendingWrites.value) {
        pendingWriteAge.value += 1;
        if (pendingWriteAge.value >= 3) {
          lastSyncError.value =
              'Some changes haven\'t synced yet. Check your connection.';
        }
      } else {
        pendingWriteAge.value = 0;
      }
    });
  }

  /// Start monitoring the user's invoice collection for pending writes.
  /// Call once after authentication.
  void init() {
    _dispose();

    String ownerId;
    try {
      ownerId = TeamService.instance.getEffectiveOwnerId();
    } catch (_) {
      return; // Not authenticated yet
    }
    // Register lifecycle observer (Issue #13)
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }

    // Listen to the invoices collection with metadata changes.
    // We only need 1 document to detect pending writes.
    _sub = _firestore
        .collection('invoices')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        final pending = snapshot.metadata.hasPendingWrites;
        hasPendingWrites.value = pending;

        if (_previouslyHadPending && !pending) {
          // Writes just synced successfully — clear any error.
          lastSyncError.value = null;
          pendingWriteAge.value = 0;
          debugPrint('[SyncStatus] Pending writes synced successfully.');
        }

        _previouslyHadPending = pending;
      },
      onError: (Object error) {
        // permission-denied / unauthenticated means the server responded —
        // not a real sync issue (e.g. rules mismatch or token refresh).
        if (error is FirebaseException &&
            (error.code == 'permission-denied' ||
                error.code == 'unauthenticated')) {
          debugPrint('[SyncStatus] Ignoring auth/permission error: $error');
          return;
        }
        lastSyncError.value =
            'Sync error: ${error.toString().split('\n').first}';
        debugPrint('[SyncStatus] Stream error: $error');
      },
    );

    // Periodic check: if pending writes persist for too long, warn the user.
    _startCheckTimer();
  }

  void _dispose() {
    _sub?.cancel();
    _sub = null;
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  void dispose() {
    _dispose();
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
    hasPendingWrites.dispose();
    lastSyncError.dispose();
    pendingWriteAge.dispose();
  }
}
