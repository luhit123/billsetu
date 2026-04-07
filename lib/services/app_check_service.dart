import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckService {
  AppCheckService._();

  static const String _webSiteKey = String.fromEnvironment(
    'FIREBASE_APPCHECK_WEB_SITE_KEY',
  );

  static Future<void> activate() async {
    if (kIsWeb) {
      if (_webSiteKey.isEmpty) {
        debugPrint(
          'App Check skipped on web: set FIREBASE_APPCHECK_WEB_SITE_KEY to enable reCAPTCHA Enterprise.',
        );
        return;
      }

      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(_webSiteKey),
      );
      return;
    }

    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
    );
  }
}
