import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// reCAPTCHA v3 site key for web.
/// Set at build time: --dart-define=RECAPTCHA_SITE_KEY=6Lc...
/// Get a key at https://www.google.com/recaptcha/admin/create (v3)
const _recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

class AppCheckService {
  AppCheckService._();

  static Future<void> activate() async {
    if (kIsWeb) {
      if (_recaptchaSiteKey.isEmpty) {
        // No site key configured — App Check is inactive on web.
        // Provide --dart-define=RECAPTCHA_SITE_KEY=<key> at build time to enforce it.
        // Silently skip in debug/local dev; production builds should always pass the key.
        return;
      }
      await FirebaseAppCheck.instance.activate(
        // ignore: deprecated_member_use
        webProvider: ReCaptchaV3Provider(_recaptchaSiteKey),
      );
      return;
    }
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      // ignore: deprecated_member_use
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
  }
}
