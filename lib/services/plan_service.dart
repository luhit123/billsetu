import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppPlan { free, raja, maharaja, king }

class PlanLimits {
  final int maxInvoicesPerMonth;
  final int maxCustomers;
  final int maxProducts;
  final int maxPdfTemplates;
  final int maxWhatsAppSharesPerMonth; // 0 = disabled, -1 = unlimited
  final bool hasReports;
  final bool hasEwayBill;
  final bool hasPurchaseOrders;
  final bool hasDataExport;
  final String name;
  final String displayName;
  final double priceMonthly; // incl GST
  final double priceAnnual; // incl GST
  final double launchPriceAnnual; // first 500 users

  const PlanLimits({
    required this.maxInvoicesPerMonth,
    required this.maxCustomers,
    required this.maxProducts,
    required this.maxPdfTemplates,
    required this.maxWhatsAppSharesPerMonth,
    required this.hasReports,
    required this.hasEwayBill,
    required this.hasPurchaseOrders,
    required this.hasDataExport,
    required this.name,
    required this.displayName,
    required this.priceMonthly,
    required this.priceAnnual,
    this.launchPriceAnnual = 0,
  });
}

class PlanService {
  PlanService._();
  static final PlanService instance = PlanService._();

  static const Map<AppPlan, PlanLimits> limits = {
    AppPlan.free: PlanLimits(
      name: 'free',
      displayName: 'Free',
      priceMonthly: 0,
      priceAnnual: 0,
      maxInvoicesPerMonth: 20,
      maxCustomers: 10,
      maxProducts: 20,
      maxPdfTemplates: 1,
      maxWhatsAppSharesPerMonth: 0,
      hasReports: false,
      hasEwayBill: false,
      hasPurchaseOrders: false,
      hasDataExport: false,
    ),
    AppPlan.raja: PlanLimits(
      name: 'raja',
      displayName: 'Raja',
      priceMonthly: 120,
      priceAnnual: 999,
      maxInvoicesPerMonth: -1,    // unlimited
      maxCustomers: -1,           // unlimited
      maxProducts: -1,            // unlimited
      maxPdfTemplates: 2,
      maxWhatsAppSharesPerMonth: 50,
      hasReports: false,
      hasEwayBill: false,
      hasPurchaseOrders: true,
      hasDataExport: true,
    ),
    AppPlan.maharaja: PlanLimits(
      name: 'maharaja',
      displayName: 'Maharaja',
      priceMonthly: 239,
      priceAnnual: 1999,
      maxInvoicesPerMonth: -1,    // unlimited
      maxCustomers: -1,           // unlimited
      maxProducts: -1,            // unlimited
      maxPdfTemplates: 5,
      maxWhatsAppSharesPerMonth: 100,
      hasReports: true,
      hasEwayBill: true,
      hasPurchaseOrders: true,
      hasDataExport: true,
    ),
    AppPlan.king: PlanLimits(
      name: 'king',
      displayName: 'King',
      priceMonthly: 499,
      priceAnnual: 3999,
      maxInvoicesPerMonth: -1,    // unlimited
      maxCustomers: -1,           // unlimited
      maxProducts: -1,            // unlimited
      maxPdfTemplates: -1,        // unlimited
      maxWhatsAppSharesPerMonth: -1, // unlimited
      hasReports: true,
      hasEwayBill: true,
      hasPurchaseOrders: true,
      hasDataExport: true,
    ),
  };

  AppPlan _currentPlan = AppPlan.free;
  AppPlan get currentPlan => _currentPlan;
  PlanLimits get currentLimits => limits[_currentPlan]!;

  bool _isInGracePeriod = false;
  bool get isInGracePeriod => _isInGracePeriod;
  DateTime? _graceExpiresAt;
  DateTime? get graceExpiresAt => _graceExpiresAt;

  String? _subscriptionStatus;
  String? get subscriptionStatus => _subscriptionStatus;
  String? _billingCycle;
  String? get billingCycle => _billingCycle;
  DateTime? _currentPeriodEnd;
  DateTime? get currentPeriodEnd => _currentPeriodEnd;

  StreamSubscription<DocumentSnapshot>? _planListener;
  final _planController = StreamController<AppPlan>.broadcast();
  Stream<AppPlan> get planStream => _planController.stream;

  /// One-shot load for startup — also sets up real-time listener
  Future<void> loadPlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Load cached plan first for instant UI
    await _loadCachedPlan();

    // Then start real-time listener
    _startPlanListener(uid);
  }

  void _startPlanListener(String uid) {
    _planListener?.cancel();
    _planListener = FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        _applyPlanFromData(data);
      } else {
        _currentPlan = AppPlan.free;
        _isInGracePeriod = false;
        _subscriptionStatus = null;
      }
      _planController.add(_currentPlan);
      _cachePlan();
    }, onError: (_) {
      // Keep cached plan on error
    });
  }

  void _applyPlanFromData(Map<String, dynamic> data) {
    final planStr = data['plan'] as String? ?? 'free';
    final status = data['status'] as String? ?? 'expired';
    final expiresAt = (data['currentPeriodEnd'] as Timestamp?)?.toDate();
    final graceAt = (data['graceExpiresAt'] as Timestamp?)?.toDate();

    _subscriptionStatus = status;
    _billingCycle = data['billingCycle'] as String?;
    _currentPeriodEnd = expiresAt;
    _graceExpiresAt = graceAt;

    // Parse plan
    final plan = AppPlan.values.firstWhere(
      (p) => p.name == planStr,
      orElse: () => AppPlan.free,
    );

    if (status == 'active') {
      _currentPlan = plan;
      _isInGracePeriod = false;
    } else if (status == 'halted' && graceAt != null && graceAt.isAfter(DateTime.now())) {
      // Grace period — still give access
      _currentPlan = plan;
      _isInGracePeriod = true;
    } else if (status == 'pending') {
      // Payment retry — keep access
      _currentPlan = plan;
      _isInGracePeriod = false;
    } else {
      _currentPlan = AppPlan.free;
      _isInGracePeriod = false;
    }
  }

  Future<void> _loadCachedPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_plan');
      if (cached != null) {
        _currentPlan = AppPlan.values.firstWhere(
          (p) => p.name == cached,
          orElse: () => AppPlan.free,
        );
      }
    } catch (_) {}
  }

  Future<void> _cachePlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_plan', _currentPlan.name);
    } catch (_) {}
  }

  void dispose() {
    _planListener?.cancel();
    _planController.close();
  }

  // ── Feature gates ─────────────────────────────────────────────────────

  bool canCreateInvoice(int thisMonthCount) {
    final max = currentLimits.maxInvoicesPerMonth;
    return max == -1 || thisMonthCount < max;
  }

  bool canAddCustomer(int currentCount) {
    final max = currentLimits.maxCustomers;
    return max == -1 || currentCount < max;
  }

  bool canAddProduct(int currentCount) {
    final max = currentLimits.maxProducts;
    return max == -1 || currentCount < max;
  }

  bool canShareWhatsApp(int thisMonthCount) {
    final max = currentLimits.maxWhatsAppSharesPerMonth;
    if (max == 0) return false;
    if (max == -1) return true;
    return thisMonthCount < max;
  }

  bool canUseTemplate(int templateIndex) {
    return templateIndex < currentLimits.maxPdfTemplates;
  }

  bool get hasReports => currentLimits.hasReports;
  bool get hasEwayBill => currentLimits.hasEwayBill;
  bool get hasPurchaseOrders => currentLimits.hasPurchaseOrders;
  bool get hasDataExport => currentLimits.hasDataExport;
  bool get hasPdfTemplates => currentLimits.maxPdfTemplates > 1;
  bool get hasWhatsAppShare => currentLimits.maxWhatsAppSharesPerMonth != 0;

  /// For upgrade screen — which plan unlocks a feature
  static AppPlan cheapestPlanFor(String feature) {
    switch (feature) {
      case 'purchase_orders':
      case 'data_export':
      case 'more_invoices':
      case 'more_customers':
      case 'more_products':
        return AppPlan.raja;
      case 'reports':
      case 'eway_bill':
      case 'e_way_bill':
      case 'pdf_templates':
        return AppPlan.maharaja;
      case 'whatsapp':
      case 'whatsapp_sharing':
        return AppPlan.king; // unlimited WhatsApp is King-only
      default:
        return AppPlan.raja;
    }
  }
}
