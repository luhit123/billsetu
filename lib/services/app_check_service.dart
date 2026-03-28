import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckService {
  AppCheckService._();

  static Future<void> activate() async {
    if (kIsWeb) {
      // Skip App Check on web until reCAPTCHA Enterprise is configured.
      return;
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
  }
}
