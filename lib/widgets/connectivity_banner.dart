import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ConnectivityBanner — slim animated status bar shown on ALL screens
//
// States:
//   hidden  → fully online, nothing shown
//   offline → orange "You're offline — changes will sync when connected"
//   synced  → green  "Back online — syncing your data…"  (auto-hides after 3 s)
//
// Usage: wire into MaterialApp.builder (see main.dart) so every screen gets it
// automatically with zero per-screen setup.
// ══════════════════════════════════════════════════════════════════════════════

enum _BannerState { hidden, offline, synced }

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final StreamSubscription<List<ConnectivityResult>> _sub;

  _BannerState _bannerState = _BannerState.hidden;
  Timer? _syncedTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
    // Seed immediately without animation
    Connectivity()
        .checkConnectivity()
        .then((r) => _onChanged(r, animate: false));
  }

  void _onChanged(List<ConnectivityResult> results, {bool animate = true}) {
    final offline = results.contains(ConnectivityResult.none);

    if (offline) {
      // Going / staying offline
      _syncedTimer?.cancel();
      if (_bannerState == _BannerState.offline) return; // already showing
      if (mounted) setState(() => _bannerState = _BannerState.offline);
      if (animate) {
        _anim.forward();
      } else {
        _anim.value = 1.0;
      }
    } else {
      // Coming back online
      if (_bannerState == _BannerState.hidden) return; // nothing to dismiss

      // Flash green "synced" then dismiss after 3 seconds
      _syncedTimer?.cancel();
      if (mounted) setState(() => _bannerState = _BannerState.synced);
      _anim.value = 1.0; // stay visible (now green)
      _syncedTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _anim.reverse().then((_) {
          if (mounted) setState(() => _bannerState = _BannerState.hidden);
        });
      });
    }
  }

  @override
  void dispose() {
    _syncedTimer?.cancel();
    _sub.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerState == _BannerState.hidden && _anim.isDismissed) {
      return const SizedBox.shrink();
    }

    final isOffline = _bannerState == _BannerState.offline;
    final bg   = isOffline ? const Color(0xFFB45309) : const Color(0xFF15803D);
    final icon = isOffline ? Icons.cloud_off_rounded  : Icons.cloud_done_rounded;
    final msg  = isOffline
        ? "You're offline — changes will sync when connected"
        : 'Back online — syncing your data…';

    // When used as a Positioned overlay at top:0, the banner must absorb
    // the status bar height so the text sits below the clock/icons row.
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
      axisAlignment: -1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        color: bg,
        // Top padding = status bar so message clears the system bar.
        // Bottom padding keeps the pill nicely spaced.
        padding: EdgeInsets.fromLTRB(16, statusBarHeight + 6, 16, 9),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
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
// ══════════════════════════════════════════════════════════════════════════════

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void init() {
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      _isOffline = results.contains(ConnectivityResult.none);
    });
    _connectivity.checkConnectivity().then((results) {
      _isOffline = results.contains(ConnectivityResult.none);
    });
  }

  void dispose() => _sub?.cancel();
}
