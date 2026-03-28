import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request POST_NOTIFICATIONS permission on Android 13+ (API 33+)
    if (Platform.isAndroid) {
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

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Save FCM token to Firestore
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
    _messaging.onTokenRefresh.listen(_saveToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const channel = AndroidNotificationChannel(
      'billraja_channel',
      'BillRaja Notifications',
      description: 'Invoice and payment notifications',
      importance: Importance.high,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'BillRaja',
      message.notification?.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Show overdue invoice reminder
  Future<void> scheduleOverdueCheck() async {
    // This is triggered by checking locally on app open
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
      await _localNotifications.show(
        1001,
        'Payment Overdue',
        '$count invoice${count > 1 ? 's are' : ' is'} overdue. Collect now!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'billraja_channel',
            'BillRaja Notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }
}
