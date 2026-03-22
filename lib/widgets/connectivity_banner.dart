import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// A slim banner that slides in when the device goes offline.
/// Place at the top of your Scaffold body (e.g., inside a Column or Stack).
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  late final AnimationController _anim;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
    // Check initial state
    Connectivity().checkConnectivity().then(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final offline = results.contains(ConnectivityResult.none);
    if (offline == _isOffline) return;
    _isOffline = offline;
    if (offline) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
      axisAlignment: -1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.orange.shade800,
        child: const Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 18, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'You\'re offline — changes will sync when connected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Provides a global stream to check connectivity status.
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

  void dispose() {
    _sub?.cancel();
  }
}
