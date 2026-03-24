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

  late final FirebaseRemoteConfig _rc;
  late final PackageInfo _packageInfo;

  final _updateController = StreamController<void>.broadcast();

  /// Emits whenever remote config values are refreshed.
  Stream<void> get onConfigUpdated => _updateController.stream;

  // ── Initialization ─────────────────────────────────────────────────────

  Future<void> init() async {
    _rc = FirebaseRemoteConfig.instance;
    _packageInfo = await PackageInfo.fromPlatform();

    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: kDebugMode
          ? const Duration(minutes: 5)
          : const Duration(hours: 1),
    ));

    await _rc.setDefaults(_defaults);

    // Fetch & activate — non-blocking after first load.
    try {
      await _rc.fetchAndActivate();
    } catch (e) {
      debugPrint('[RemoteConfig] Initial fetch failed (using defaults): $e');
    }

    // Listen for real-time config updates (Firebase RC v2).
    _rc.onConfigUpdated.listen((_) async {
      await _rc.activate();
      _updateController.add(null);
      if (kDebugMode) debugPrint('[RemoteConfig] Config updated & activated');
    }, onError: (e) {
      if (kDebugMode) debugPrint('[RemoteConfig] Real-time listener error: $e');
    });
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
    'expired_has_eway_bill': false,
    'expired_has_purchase_orders': false,
    'expired_has_data_export': false,

    // Plan limits — pro
    'pro_max_invoices': -1,
    'pro_max_customers': -1,
    'pro_max_products': -1,
    'pro_max_pdf_templates': -1,
    'pro_max_whatsapp_shares': -1,
    'pro_has_reports': true,
    'pro_has_eway_bill': true,
    'pro_has_purchase_orders': true,
    'pro_has_data_export': true,

    // Pricing
    'pro_price_monthly': 129.0,
    'pro_price_annual': 999.0,

    // Review triggers
    'review_session_threshold': 5,
    'review_invoice_threshold': 3,

    // Feature flags
    'feature_eway_bill': true,
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
        '[{"icon":"receipt_long","label":"Unlimited Invoices"},{"icon":"people","label":"Unlimited Customers"},{"icon":"inventory_2","label":"Unlimited Products"},{"icon":"picture_as_pdf","label":"20 PDF Templates"},{"icon":"chat","label":"Unlimited WhatsApp Sharing"},{"icon":"shopping_cart","label":"Purchase Orders"},{"icon":"bar_chart","label":"Reports & Analytics"},{"icon":"local_shipping","label":"E-Way Bill"},{"icon":"download","label":"Data Export"},{"icon":"palette","label":"Custom Branding"}]',

    // Promotional banner
    'promo_banner_enabled': false,
    'promo_banner_text': '',
    'promo_banner_color': '#0057FF',

    // Language control — empty string means all languages enabled.
    // Comma-separated list of AppLanguage enum names to show.
    // e.g. "english,hindi,bengali,tamil,telugu,marathi,gujarati"
    'enabled_languages': '',
  };

  // ── Force Update / Maintenance ────────────────────────────────────────

  bool get forceUpdateEnabled => _rc.getBool('force_update_enabled');
  String get minSupportedVersion => _rc.getString('min_supported_version');
  String get forceUpdateTitle => _rc.getString('force_update_title');
  String get forceUpdateMessage => _rc.getString('force_update_message');
  String get forceUpdateStoreUrl => _rc.getString('force_update_store_url');

  bool get maintenanceEnabled => _rc.getBool('maintenance_enabled');
  String get maintenanceTitle => _rc.getString('maintenance_title');
  String get maintenanceMessage => _rc.getString('maintenance_message');

  /// Returns true if the app's current version is below [minSupportedVersion].
  bool get needsForceUpdate {
    if (!forceUpdateEnabled) return false;
    return _isVersionBelow(_packageInfo.version, minSupportedVersion);
  }

  String get currentAppVersion => _packageInfo.version;

  // ── Plan Limits — Expired ─────────────────────────────────────────────

  int get expiredMaxInvoices => _rc.getInt('expired_max_invoices');
  int get expiredMaxCustomers => _rc.getInt('expired_max_customers');
  int get expiredMaxProducts => _rc.getInt('expired_max_products');
  int get expiredMaxPdfTemplates => _rc.getInt('expired_max_pdf_templates');
  int get expiredMaxWhatsAppShares => _rc.getInt('expired_max_whatsapp_shares');
  bool get expiredHasReports => _rc.getBool('expired_has_reports');
  bool get expiredHasEwayBill => _rc.getBool('expired_has_eway_bill');
  bool get expiredHasPurchaseOrders =>
      _rc.getBool('expired_has_purchase_orders');
  bool get expiredHasDataExport => _rc.getBool('expired_has_data_export');

  // ── Plan Limits — Pro ─────────────────────────────────────────────────

  int get proMaxInvoices => _rc.getInt('pro_max_invoices');
  int get proMaxCustomers => _rc.getInt('pro_max_customers');
  int get proMaxProducts => _rc.getInt('pro_max_products');
  int get proMaxPdfTemplates => _rc.getInt('pro_max_pdf_templates');
  int get proMaxWhatsAppShares => _rc.getInt('pro_max_whatsapp_shares');
  bool get proHasReports => _rc.getBool('pro_has_reports');
  bool get proHasEwayBill => _rc.getBool('pro_has_eway_bill');
  bool get proHasPurchaseOrders => _rc.getBool('pro_has_purchase_orders');
  bool get proHasDataExport => _rc.getBool('pro_has_data_export');

  // ── Pricing ───────────────────────────────────────────────────────────

  double get proPriceMonthly => _rc.getDouble('pro_price_monthly');
  double get proPriceAnnual => _rc.getDouble('pro_price_annual');

  // ── Review Triggers ───────────────────────────────────────────────────

  int get reviewSessionThreshold => _rc.getInt('review_session_threshold');
  int get reviewInvoiceThreshold => _rc.getInt('review_invoice_threshold');

  // ── Feature Flags ─────────────────────────────────────────────────────

  bool get featureEwayBill => _rc.getBool('feature_eway_bill');
  bool get featurePurchaseOrders => _rc.getBool('feature_purchase_orders');
  bool get featureReports => _rc.getBool('feature_reports');
  bool get featureDataExport => _rc.getBool('feature_data_export');
  bool get featureWhatsAppShare => _rc.getBool('feature_whatsapp_share');
  bool get featureMembership => _rc.getBool('feature_membership');
  bool get featureQrAttendance => _rc.getBool('feature_qr_attendance');

  // ── Upgrade Screen ────────────────────────────────────────────────────

  String get upgradeTitle => _rc.getString('upgrade_title');
  String get upgradeCtaText => _rc.getString('upgrade_cta_text');

  List<Map<String, String>> get upgradeFeatures {
    try {
      final raw = _rc.getString('upgrade_features_json');
      final list = jsonDecode(raw) as List;
      return list.map<Map<String, String>>((item) {
        final map = item as Map<String, dynamic>;
        return {
          'icon': map['icon']?.toString() ?? '',
          'label': map['label']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('[RemoteConfig] Failed to parse upgrade features: $e');
      return [];
    }
  }

  // ── Promo Banner ──────────────────────────────────────────────────────

  bool get promoBannerEnabled => _rc.getBool('promo_banner_enabled');
  String get promoBannerText => _rc.getString('promo_banner_text');
  String get promoBannerColor => _rc.getString('promo_banner_color');

  // ── Language Control ──────────────────────────────────────────────────

  /// Returns the list of enabled language names (AppLanguage enum names).
  /// Empty list means all languages are enabled.
  List<String> get enabledLanguages {
    final raw = _rc.getString('enabled_languages').trim();
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

  /// Force a re-fetch and activate. Useful for retry buttons.
  Future<void> refetch() async {
    try {
      await _rc.fetchAndActivate();
      _updateController.add(null);
    } catch (e) {
      debugPrint('[RemoteConfig] Refetch failed: $e');
    }
  }

  void dispose() {
    _updateController.close();
  }
}
