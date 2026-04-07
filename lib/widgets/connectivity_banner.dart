import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ConnectivityBanner — lightweight floating connectivity indicator
//
// States:
//   hidden          → fully online, nothing shown
//   offlineExpanded → short offline toast, then collapses
//   offlineCompact  → small persistent chip while still offline
//   synced          → green "Back online" toast, then hides
//
// Usage: wire into MaterialApp.builder (see main.dart) so every screen gets it
// automatically with zero per-screen setup.
// ══════════════════════════════════════════════════════════════════════════════

enum _BannerState { hidden, offlineExpanded, offlineCompact, synced }

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late final StreamSubscription<List<ConnectivityResult>> _sub;

  _BannerState _bannerState = _BannerState.hidden;
  Timer? _collapseTimer;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
    // Seed immediately without showing the larger toast on initial load.
    Connectivity()
        .checkConnectivity()
        .then((r) => _onChanged(r, animate: false));
  }

  void _onChanged(List<ConnectivityResult> results, {bool animate = true}) {
    final offline = results.contains(ConnectivityResult.none);

    if (offline) {
      _hideTimer?.cancel();
      _collapseTimer?.cancel();

      if (!mounted) return;
      setState(() {
        _bannerState = animate
            ? _BannerState.offlineExpanded
            : _BannerState.offlineCompact;
      });

      if (animate) {
        _collapseTimer = Timer(const Duration(seconds: 4), () {
          if (!mounted || _bannerState != _BannerState.offlineExpanded) return;
          setState(() => _bannerState = _BannerState.offlineCompact);
        });
      }
    } else {
      if (_bannerState == _BannerState.hidden) return; // nothing to dismiss

      _collapseTimer?.cancel();
      _hideTimer?.cancel();

      if (!mounted) return;
      setState(() => _bannerState = _BannerState.synced);
      _hideTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _bannerState = _BannerState.hidden);
      });
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _hideTimer?.cancel();
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerState == _BannerState.hidden) {
      return const SizedBox.shrink();
    }

    final isOffline = _bannerState == _BannerState.offlineExpanded ||
        _bannerState == _BannerState.offlineCompact;
    final isExpanded = _bannerState == _BannerState.offlineExpanded ||
        _bannerState == _BannerState.synced;
    final bg = isOffline ? const Color(0xFFB45309) : const Color(0xFF15803D);
    final icon = isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded;
    final msg = isOffline
        ? 'Offline mode - syncing later'
        : 'Back online - syncing';

    return IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, -0.08),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: isExpanded
                  ? _ExpandedConnectivityPill(
                      key: ValueKey(_bannerState),
                      backgroundColor: bg,
                      icon: icon,
                      message: msg,
                    )
                  : _CompactConnectivityChip(
                      key: const ValueKey('offlineCompact'),
                      backgroundColor: bg,
                      icon: icon,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedConnectivityPill extends StatelessWidget {
  const _ExpandedConnectivityPill({
    super.key,
    required this.backgroundColor,
    required this.icon,
    required this.message,
  });

  final Color backgroundColor;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Material(
        color: backgroundColor,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactConnectivityChip extends StatelessWidget {
  const _CompactConnectivityChip({
    super.key,
    required this.backgroundColor,
    required this.icon,
  });

  final Color backgroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            const Text(
              'Offline',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ConnectivityService — lightweight singleton for offline checks in code
//
// Two-layer check:
//   1. connectivity_plus tells us if the OS has a network interface up.
//   2. A periodic Firestore ping verifies actual server reachability.
// Both must pass for isOffline to be false.
// ══════════════════════════════════════════════════════════════════════════════

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();

  /// True when the OS reports no network OR a Firestore ping has failed.
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  /// True when the OS reports no network interface at all.
  bool _osOffline = false;

  /// True when a Firestore ping has recently failed despite OS connectivity.
  bool _serverUnreachable = false;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _pingTimer;

  void init() {
    _sub = _connectivity.onConnectivityChanged.listen(_onOsConnectivityChanged);
    _connectivity.checkConnectivity().then((results) {
      _osOffline = results.contains(ConnectivityResult.none);
      _recalculate();
    });

    // Periodic reachability check every 30 seconds when OS says online.
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_osOffline) _checkFirestoreReachability();
    });
  }

  void _onOsConnectivityChanged(List<ConnectivityResult> results) {
    _osOffline = results.contains(ConnectivityResult.none);
    _recalculate();

    // When OS comes back online, immediately verify server reachability
    // so we don't stay in "offline" mode longer than necessary.
    if (!_osOffline) _checkFirestoreReachability();
  }

  /// Lightweight Firestore ping — attempts to read Firestore server time.
  /// On failure, marks server as unreachable.
  Future<void> _checkFirestoreReachability() async {
    try {
      // Use a very small read to test connectivity.
      // enableNetwork/disableNetwork are not needed — just attempt a
      // server-only read of a non-existent doc. If it throws, we're offline.
      await FirebaseFirestore.instance
          .collection('_ping')
          .doc('health')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      // Success (even if doc doesn't exist) — server is reachable.
      if (_serverUnreachable) {
        _serverUnreachable = false;
        _recalculate();
      }
    } on FirebaseException catch (e) {
      // PERMISSION_DENIED means the server *responded* — we're online.
      // Only treat UNAVAILABLE / timeout as truly unreachable.
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        if (_serverUnreachable) {
          _serverUnreachable = false;
          _recalculate();
        }
      } else {
        if (!_serverUnreachable) {
          _serverUnreachable = true;
          _recalculate();
        }
      }
    } catch (_) {
      // Timeout or network error — server unreachable.
      if (!_serverUnreachable) {
        _serverUnreachable = true;
        _recalculate();
      }
    }
  }

  void _recalculate() {
    _isOffline = _osOffline || _serverUnreachable;
  }

  void dispose() {
    _pingTimer?.cancel();
    _sub?.cancel();
  }
}
