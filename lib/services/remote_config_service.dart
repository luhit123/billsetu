import 'dart:async';
import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Centralized Firebase Remote Config service.
///
/// All remotely-configurable values live here. Other services read from this
/// singleton instead of hardcoding constants.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  FirebaseRemoteConfig? _rc;
  PackageInfo? _packageInfo;
  bool _initialized = false;

  final _updateController = StreamController<void>.broadcast();

  /// Emits whenever remote config values are refreshed.
  Stream<void> get onConfigUpdated => _updateController.stream;

  // ── Initialization ─────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      _rc = FirebaseRemoteConfig.instance;
      _packageInfo = await PackageInfo.fromPlatform();

      await _rc!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 1)
            : const Duration(minutes: 15),
      ));

      await _rc!.setDefaults(_defaults);

      // Fetch & activate — non-blocking after first load.
      try {
        await _rc!.fetchAndActivate();
      } catch (e) {
        debugPrint('[RemoteConfig] Initial fetch failed (using defaults): $e');
      }

      _initialized = true;

      // Listen for real-time config updates (Firebase RC v2).
      _rc!.onConfigUpdated.listen((_) async {
        await _rc!.activate();
        _updateController.add(null);
        debugPrint('[RemoteConfig] Config updated & activated');
      }, onError: (e) {
        debugPrint('[RemoteConfig] Real-time listener error: $e');
      });
    } catch (e) {
      debugPrint('[RemoteConfig] init() failed: $e');
      // Service remains uninitialized — all getters return safe defaults.
    }
  }

  // ── Default values ────────────────────────────────────────────────────

  static final Map<String, dynamic> _defaults = {
    // Force update / maintenance
    'min_supported_version': '1.0.0',
    'force_update_enabled': false,
    'force_update_title': 'Update Required',
    'force_update_message':
        'A new version of BillRaja is available. Please update to continue using the app.',
    'force_update_store_url':
        'https://play.google.com/store/apps/details?id=com.luhit.billeasy',
    'maintenance_enabled': false,
    'maintenance_title': 'Under Maintenance',
    'maintenance_message':
        'We\'re performing scheduled maintenance. We\'ll be back shortly!',

    // Plan limits — expired
    'expired_max_invoices': 5,
    'expired_max_customers': 5,
    'expired_max_products': 20,
    'expired_max_pdf_templates': 1,
    'expired_max_whatsapp_shares': 0,
    'expired_has_reports': false,
    'expired_has_purchase_orders': false,
    'expired_has_data_export': false,

    // Plan limits — pro
    'pro_max_invoices': -1,
    'pro_max_customers': -1,
    'pro_max_products': -1,
    'pro_max_pdf_templates': -1,
    'pro_max_whatsapp_shares': -1,
    'pro_has_reports': true,
    'pro_has_purchase_orders': true,
    'pro_has_data_export': true,

    // Pricing
    'pro_price_monthly': 99.0,
    'pro_price_annual': 999.0,

    // Subscription config
    'trial_duration_months': 6,
    'grace_period_days': 7,

    // Payment gateway
    'razorpay_key': '',

    // Review triggers
    'review_session_threshold': 5,
    'review_invoice_threshold': 3,

    // Feature flags
    'feature_purchase_orders': true,
    'feature_reports': true,
    'feature_data_export': true,
    'feature_whatsapp_share': true,
    'feature_membership': true,
    'feature_qr_attendance': true,

    // Upgrade screen copy
    'upgrade_title': 'Upgrade to Pro',
    'upgrade_cta_text': 'Upgrade to Pro',
    'upgrade_features_json':
        '[{"icon":"receipt_long","label":"Unlimited Invoices"},{"icon":"people","label":"Unlimited Customers"},{"icon":"inventory_2","label":"Unlimited Products"},{"icon":"picture_as_pdf","label":"20 PDF Templates"},{"icon":"chat","label":"Unlimited WhatsApp Sharing"},{"icon":"shopping_cart","label":"Purchase Orders"},{"icon":"bar_chart","label":"Reports & Analytics"},{"icon":"download","label":"Data Export"},{"icon":"palette","label":"Custom Branding"}]',

    // Plan comparison card — drives the Free vs Pro table on the upgrade screen.
    // Each item: icon, label, free (value or true/false), pro (value or true/false)
    'plan_comparison_json':
        '[{"icon":"receipt_long","label":"Invoices","free":"5/month","pro":"Unlimited"},{"icon":"people","label":"Customers","free":"5","pro":"Unlimited"},{"icon":"inventory_2","label":"Products & Inventory","free":"20","pro":"Unlimited"},{"icon":"picture_as_pdf","label":"PDF Templates","free":"1","pro":"All 20+"},{"icon":"currency_rupee","label":"GST Invoicing","free":true,"pro":true},{"icon":"qr_code","label":"UPI Payment Links & QR","free":true,"pro":true},{"icon":"language","label":"Multi-language Support","free":true,"pro":true},{"icon":"cloud_off","label":"Offline Mode","free":true,"pro":true},{"icon":"badge","label":"Digital Business Card","free":true,"pro":true},{"icon":"chat","label":"WhatsApp Sharing","free":false,"pro":true},{"icon":"shopping_cart","label":"Purchase Orders","free":false,"pro":true},{"icon":"bar_chart","label":"Reports & Analytics","free":false,"pro":true},{"icon":"assessment","label":"GST Reports & GSTR-3B","free":false,"pro":true},{"icon":"card_membership","label":"Membership Management","free":false,"pro":true},{"icon":"qr_code_scanner","label":"QR Attendance","free":false,"pro":true},{"icon":"download","label":"Data Export (CSV)","free":false,"pro":true},{"icon":"palette","label":"Custom Branding & Logo","free":false,"pro":true}]',

    // Promotional banner
    'promo_banner_enabled': false,
    'promo_banner_text': '',
    'promo_banner_color': '#0057FF',

    // Language control — empty string means all languages enabled.
    // Comma-separated list of AppLanguage enum names to show.
    // e.g. "english,hindi,bengali,tamil,telugu,marathi,gujarati"
    'enabled_languages': '',
  };

  // ── Safe helpers — return defaults when RC is not initialized ─────────

  bool _getBool(String key) =>
      _rc?.getBool(key) ?? (_defaults[key] as bool? ?? false);

  int _getInt(String key) =>
      _rc?.getInt(key) ?? (_defaults[key] as int? ?? 0);

  double _getDouble(String key) =>
      _rc?.getDouble(key) ?? ((_defaults[key] as num?)?.toDouble() ?? 0.0);

  String _getString(String key) =>
      _rc?.getString(key) ?? (_defaults[key] as String? ?? '');

  // ── Force Update / Maintenance ────────────────────────────────────────

  bool get forceUpdateEnabled => _getBool('force_update_enabled');
  String get minSupportedVersion => _getString('min_supported_version');
  String get forceUpdateTitle => _getString('force_update_title');
  String get forceUpdateMessage => _getString('force_update_message');
  String get forceUpdateStoreUrl => _getString('force_update_store_url');

  bool get maintenanceEnabled => _getBool('maintenance_enabled');
  String get maintenanceTitle => _getString('maintenance_title');
  String get maintenanceMessage => _getString('maintenance_message');

  /// Returns true if the app's current version is below [minSupportedVersion].
  bool get needsForceUpdate {
    if (!forceUpdateEnabled) return false;
    final version = _packageInfo?.version ?? '0.0.0';
    return _isVersionBelow(version, minSupportedVersion);
  }

  String get currentAppVersion => _packageInfo?.version ?? '0.0.0';

  // ── Plan Limits — Expired ─────────────────────────────────────────────

  int get expiredMaxInvoices => _getInt('expired_max_invoices');
  int get expiredMaxCustomers => _getInt('expired_max_customers');
  int get expiredMaxProducts => _getInt('expired_max_products');
  int get expiredMaxPdfTemplates => _getInt('expired_max_pdf_templates');
  int get expiredMaxWhatsAppShares => _getInt('expired_max_whatsapp_shares');
  bool get expiredHasReports => _getBool('expired_has_reports');
  bool get expiredHasPurchaseOrders => _getBool('expired_has_purchase_orders');
  bool get expiredHasDataExport => _getBool('expired_has_data_export');

  // ── Plan Limits — Pro ─────────────────────────────────────────────────

  int get proMaxInvoices => _getInt('pro_max_invoices');
  int get proMaxCustomers => _getInt('pro_max_customers');
  int get proMaxProducts => _getInt('pro_max_products');
  int get proMaxPdfTemplates => _getInt('pro_max_pdf_templates');
  int get proMaxWhatsAppShares => _getInt('pro_max_whatsapp_shares');
  bool get proHasReports => _getBool('pro_has_reports');
  bool get proHasPurchaseOrders => _getBool('pro_has_purchase_orders');
  bool get proHasDataExport => _getBool('pro_has_data_export');

  // ── Payment Gateway ──────────────────────────────────────────────────

  String get razorpayKey => _getString('razorpay_key');

  // ── Pricing ───────────────────────────────────────────────────────────

  double get proPriceMonthly => _getDouble('pro_price_monthly');
  double get proPriceAnnual => _getDouble('pro_price_annual');

  // ── Subscription Config ──────────────────────────────────────────────

  int get trialDurationMonths => _getInt('trial_duration_months');
  int get gracePeriodDays => _getInt('grace_period_days');

  // ── Review Triggers ───────────────────────────────────────────────────

  int get reviewSessionThreshold => _getInt('review_session_threshold');
  int get reviewInvoiceThreshold => _getInt('review_invoice_threshold');

  // ── Feature Flags ─────────────────────────────────────────────────────

  bool get featurePurchaseOrders => _getBool('feature_purchase_orders');
  bool get featureReports => _getBool('feature_reports');
  bool get featureDataExport => _getBool('feature_data_export');
  bool get featureWhatsAppShare => _getBool('feature_whatsapp_share');
  bool get featureMembership => _getBool('feature_membership');
  bool get featureQrAttendance => _getBool('feature_qr_attendance');

  // ── Upgrade Screen ────────────────────────────────────────────────────

  String get upgradeTitle => _getString('upgrade_title');
  String get upgradeCtaText => _getString('upgrade_cta_text');

  /// Plan comparison features for the upgrade screen Free vs Pro table.
  /// Each entry has: icon, label, free (String value or bool), pro (String value or bool).
  ///
  /// Limit-related "free" values are overridden with actual RC values so that
  /// changing e.g. `expired_max_invoices` automatically updates the comparison
  /// table without needing to also edit `plan_comparison_json`.
  List<Map<String, dynamic>> get planComparisonFeatures {
    try {
      final raw = _getString('plan_comparison_json');
      if (raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list.map<Map<String, dynamic>>((item) {
        final map = item as Map<String, dynamic>;
        final label = map['label']?.toString() ?? '';
        return {
          'icon': map['icon']?.toString() ?? '',
          'label': label,
          'free': _overrideFreeValue(label, map['free']),
          'pro': map['pro'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[RemoteConfig] Failed to parse plan comparison: $e');
      return [];
    }
  }

  /// Override free-column display strings with actual RC limit values.
  dynamic _overrideFreeValue(String label, dynamic original) {
    final lbl = label.toLowerCase();
    if (lbl.contains('invoice')) {
      final v = expiredMaxInvoices;
      return v <= 0 ? original : '$v/month';
    }
    if (lbl.contains('customer')) {
      final v = expiredMaxCustomers;
      return v <= 0 ? original : '$v';
    }
    if (lbl.contains('product')) {
      final v = expiredMaxProducts;
      return v <= 0 ? original : '$v';
    }
    if (lbl.contains('pdf template')) {
      final v = expiredMaxPdfTemplates;
      return v <= 0 ? original : '$v';
    }
    return original;
  }

  // ── Promo Banner ──────────────────────────────────────────────────────

  bool get promoBannerEnabled => _getBool('promo_banner_enabled');
  String get promoBannerText => _getString('promo_banner_text');
  String get promoBannerColor => _getString('promo_banner_color');

  // ── Language Control ──────────────────────────────────────────────────

  /// Returns the list of enabled language names (AppLanguage enum names).
  /// Empty list means all languages are enabled.
  List<String> get enabledLanguages {
    final raw = _getString('enabled_languages').trim();
    if (raw.isEmpty) return [];
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Compares two semver strings. Returns true if [current] < [minimum].
  static bool _isVersionBelow(String current, String minimum) {
    final cur = _parseVersion(current);
    final min = _parseVersion(minimum);
    for (var i = 0; i < 3; i++) {
      if (cur[i] < min[i]) return true;
      if (cur[i] > min[i]) return false;
    }
    return false;
  }

  static List<int> _parseVersion(String version) {
    final parts = version.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  /// Force a re-fetch and activate, bypassing the minimum fetch interval.
  Future<void> refetch() async {
    if (_rc == null) return;
    try {
      // Temporarily set interval to 0 to force a real network fetch
      await _rc!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));
      await _rc!.fetchAndActivate();
      // Restore normal interval
      await _rc!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 1)
            : const Duration(minutes: 15),
      ));
      _updateController.add(null);
    } catch (e) {
      debugPrint('[RemoteConfig] Refetch failed: $e');
    }
  }

  void dispose() {
    _updateController.close();
  }
}
