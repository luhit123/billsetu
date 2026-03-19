class AppCheckService {
  AppCheckService._();

  // App Check is intentionally disabled during development.
  // Re-enable before production release by restoring FirebaseAppCheck.instance.activate().
  static Future<void> activate() async {}
}
