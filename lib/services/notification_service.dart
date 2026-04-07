import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:http/http.dart' as http;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Global navigator key — set from MaterialApp so notification taps can
/// navigate without a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;

  // Only initialized on mobile — null on web.
  FlutterLocalNotificationsPlugin? _localNotifications;

  /// Cached BillRaja logo bytes for the large icon.
  Uint8List? _logoBytes;

  Future<void> initialize() async {
    // ── Web: only save FCM token and listen for messages ────────────────
    if (kIsWeb) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await _messaging.getToken(
        vapidKey: null, // Add your VAPID key here if you want web push
      );
      if (token != null) await _saveToken(token);
      _messaging.onTokenRefresh.listen(_saveToken);
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
    _messaging.onTokenRefresh.listen(_saveToken);

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
    final imageUrl = message.notification?.android?.imageUrl ??
        message.data['imageUrl'] as String?;

    // Download image for BigPictureStyle if provided
    ByteArrayAndroidBitmap? bigPicture;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          bigPicture = ByteArrayAndroidBitmap(response.bodyBytes);
        }
      } catch (_) {}
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
          color: const Color(0xFF0057FF),
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

  // ── Notification tap handling ─────────────────────────────────────────────

  void _onNotificationTap(NotificationResponse response) {
    _navigateFromPayload(response.payload);
  }

  void _onFcmMessageTap(RemoteMessage message) {
    _navigateFromPayload(message.data['type']);
  }

  void _navigateFromPayload(String? type) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
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
    final snap = await FirebaseFirestore.instance
        .collection('invoices')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .where('dueDate', isLessThan: Timestamp.fromDate(now))
        .limit(10)
        .get();

    if (snap.docs.isNotEmpty) {
      final count = snap.docs.length;

      ByteArrayAndroidBitmap? largeIcon;
      if (_logoBytes != null) {
        largeIcon = ByteArrayAndroidBitmap(_logoBytes!);
      }

      await _localNotifications!.show(
        1001,
        'Payment Overdue',
        '$count invoice${count > 1 ? 's are' : ' is'} overdue. Collect now!',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'billraja_channel',
            'BillRaja Notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: const Color(0xFF0057FF),
            largeIcon: largeIcon,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'overdue',
      );
    }
  }
}
