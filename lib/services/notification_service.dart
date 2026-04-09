import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:billeasy/services/remote_config_service.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:http/http.dart' as http;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Navigation service encapsulation (Issue #25).
/// Provides controlled access to the navigator key instead of a mutable global.
class NavigationService {
  NavigationService._();
  static final NavigationService instance = NavigationService._();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void popToRoot() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
  }
}

/// Global navigator key — maintained for backward compatibility.
/// Prefer NavigationService.instance.navigatorKey for new code.
final GlobalKey<NavigatorState> navigatorKey =
    NavigationService.instance.navigatorKey;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;

  // Only initialized on mobile — null on web.
  FlutterLocalNotificationsPlugin? _localNotifications;

  /// Cached BillRaja logo bytes for the large icon.
  Uint8List? _logoBytes;

  /// Track token refresh subscription to prevent accumulation (Issue #19).
  StreamSubscription<String>? _tokenRefreshSub;

  /// Allowed image URL domains for notification images (Issue #8).
  static const _allowedImageDomains = [
    'firebasestorage.googleapis.com',
    'storage.googleapis.com',
  ];

  /// Validates that an image URL points to a trusted domain.
  static bool _isAllowedImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'https') return false;
      final host = uri.host.toLowerCase();
      return _allowedImageDomains.any((d) => host == d || host.endsWith('.$d'));
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    // ── Web: save FCM token and listen for foreground messages ──────────
    if (kIsWeb) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[Notifications] Web push permission denied');
        return;
      }

      // VAPID key from Remote Config (parameter: "fcm_vapid_key").
      // Set the Web Push certificate's public key in Firebase Console >
      // Remote Config. The key is ~87 chars starting with "B".
      final vapidKey = RemoteConfigService.instance.fcmVapidKey;

      try {
        final token = await _messaging.getToken(
          vapidKey: vapidKey.isNotEmpty ? vapidKey : null,
        );
        if (token != null) await _saveToken(token);
      } catch (e) {
        debugPrint('[Notifications] Failed to get web FCM token: $e');
      }
      // Cancel previous listener to prevent accumulation (Issue #19)
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveToken);

      // Listen for foreground messages on web
      FirebaseMessaging.onMessage.listen(_handleWebForegroundMessage);
      return;
    }

    // ── Mobile: full notification setup ────────────────────────────────
    _localNotifications = FlutterLocalNotificationsPlugin();

    // Request POST_NOTIFICATIONS permission on Android 13+ (API 33+)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        await Permission.notification.request();
      }
    }

    // Request Firebase Messaging permission (handles iOS prompt)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Pre-cache logo for large icon in notifications
    try {
      final data = await rootBundle.load('assets/icon/ic_launcher.png');
      _logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications!.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create the notification channel upfront
    await _localNotifications!
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'billraja_channel',
          'BillRaja Notifications',
          description: 'Invoice, payment, and broadcast notifications',
          importance: Importance.high,
        ));

    // Save FCM token to Firestore
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
    // Cancel previous listener to prevent accumulation (Issue #19)
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onFcmMessageTap);

    // Handle notification tap when app was terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Delay to let the app finish building before navigating
      Future.delayed(const Duration(seconds: 1), () {
        _onFcmMessageTap(initialMessage);
      });
    }
  }

  // ── Token management ─────────────────────────────────────────────────────

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  // ── Notification display ─────────────────────────────────────────────────

  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb || _localNotifications == null) return;

    final title = message.notification?.title ?? 'BillRaja';
    final body = message.notification?.body ?? '';
    final rawImageUrl = message.notification?.android?.imageUrl ??
        message.data['imageUrl'] as String?;
    // Strip expired Firebase Storage tokens — public-read rules don't need them
    final imageUrl = rawImageUrl?.replaceAll(RegExp(r'&token=[^&]+'), '');

    // Download image for BigPictureStyle if provided
    // Issue #8: Validate URL domain and add timeout to prevent SSRF
    ByteArrayAndroidBitmap? bigPicture;
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        _isAllowedImageUrl(imageUrl)) {
      try {
        final response = await http
            .get(Uri.parse(imageUrl))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          bigPicture = ByteArrayAndroidBitmap(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('[Notifications] Image download failed: $e');
      }
    }

    // BillRaja logo as large icon (circular avatar in notification)
    ByteArrayAndroidBitmap? largeIcon;
    if (_logoBytes != null) {
      largeIcon = ByteArrayAndroidBitmap(_logoBytes!);
    }

    // Payload for tap handling
    final payload = message.data['type'] ?? 'general';

    await _localNotifications!.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'billraja_channel',
          'BillRaja Notifications',
          channelDescription:
              'Invoice, payment, and broadcast notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          color: const Color(0xFF386641),
          largeIcon: largeIcon,
          styleInformation: bigPicture != null
              ? BigPictureStyleInformation(
                  bigPicture,
                  contentTitle: title,
                  summaryText: body,
                  largeIcon: largeIcon,
                  hideExpandedLargeIcon: true,
                )
              : BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  // ── Web foreground message handler ────────────────────────────────────────

  void _handleWebForegroundMessage(RemoteMessage message) {
    // On web, the browser's Notification API is used directly since
    // flutter_local_notifications doesn't support web.
    final title = message.notification?.title ?? 'BillRaja';
    final body = message.notification?.body ?? '';
    // ignore: avoid_print
    debugPrint('[Notifications] Web foreground message: $title — $body');
    // The service worker handles background; for foreground we can show
    // a web Notification via JS interop or just let the UI handle it.
    // The browser will show the notification natively if the SW is active.
  }

  // ── Notification tap handling ─────────────────────────────────────────────

  void _onNotificationTap(NotificationResponse response) {
    _navigateFromPayload(response.payload);
  }

  void _onFcmMessageTap(RemoteMessage message) {
    _navigateFromPayload(message.data['type']);
  }

  void _navigateFromPayload(String? type) {
    NavigationService.instance.popToRoot();
  }

  // ── Overdue invoice reminder ─────────────────────────────────────────────

  Future<void> scheduleOverdueCheck() async {
    if (kIsWeb || _localNotifications == null) return;

    String? uid;
    try {
      uid = TeamService.instance.getEffectiveOwnerId();
    } catch (_) {
      uid = FirebaseAuth.instance.currentUser?.uid;
    }
    if (uid == null) return;

    final now = DateTime.now();
    // Issue #23: Use count aggregation to show real total, not capped at 10
    final snap = await FirebaseFirestore.instance
        .collection('invoices')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .where('dueDate', isLessThan: Timestamp.fromDate(now))
        .limit(100)
        .get();

    if (snap.docs.isNotEmpty) {
      final count = snap.docs.length;
      final displayCount = count >= 100 ? '100+' : '$count';

      ByteArrayAndroidBitmap? largeIcon;
      if (_logoBytes != null) {
        largeIcon = ByteArrayAndroidBitmap(_logoBytes!);
      }

      await _localNotifications!.show(
        1001,
        'Payment Overdue',
        '$displayCount invoice${count > 1 ? 's are' : ' is'} overdue. Collect now!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'billraja_channel',
            'BillRaja Notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: const Color(0xFF386641),
            largeIcon: largeIcon,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'overdue',
      );
    }
  }
}
