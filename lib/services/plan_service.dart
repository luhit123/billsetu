import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_config_service.dart';

enum AppPlan { trial, expired, pro }

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
  });
}

class PlanService {
  PlanService._();
  static final PlanService instance = PlanService._();

  /// Plan limits are now driven by Firebase Remote Config.
  /// Trial gets the same limits as Pro (full access during trial).
  static Map<AppPlan, PlanLimits> get limits {
    final rc = RemoteConfigService.instance;
    return {
      AppPlan.trial: PlanLimits(
        name: 'trial',
        displayName: 'Trial',
        priceMonthly: 0,
        priceAnnual: 0,
        maxInvoicesPerMonth: -1,
        maxCustomers: -1,
        maxProducts: -1,
        maxPdfTemplates: -1,
        maxWhatsAppSharesPerMonth: -1,
        hasReports: true,
        hasEwayBill: true,
        hasPurchaseOrders: true,
        hasDataExport: true,
      ),
      AppPlan.expired: PlanLimits(
        name: 'expired',
        displayName: 'Expired',
        priceMonthly: 0,
        priceAnnual: 0,
        maxInvoicesPerMonth: rc.expiredMaxInvoices,
        maxCustomers: rc.expiredMaxCustomers,
        maxProducts: rc.expiredMaxProducts,
        maxPdfTemplates: rc.expiredMaxPdfTemplates,
        maxWhatsAppSharesPerMonth: rc.expiredMaxWhatsAppShares,
        hasReports: rc.expiredHasReports,
        hasEwayBill: rc.expiredHasEwayBill,
        hasPurchaseOrders: rc.expiredHasPurchaseOrders,
        hasDataExport: rc.expiredHasDataExport,
      ),
      AppPlan.pro: PlanLimits(
        name: 'pro',
        displayName: 'Pro',
        priceMonthly: rc.proPriceMonthly,
        priceAnnual: rc.proPriceAnnual,
        maxInvoicesPerMonth: rc.proMaxInvoices,
        maxCustomers: rc.proMaxCustomers,
        maxProducts: rc.proMaxProducts,
        maxPdfTemplates: rc.proMaxPdfTemplates,
        maxWhatsAppSharesPerMonth: rc.proMaxWhatsAppShares,
        hasReports: rc.proHasReports,
        hasEwayBill: rc.proHasEwayBill,
        hasPurchaseOrders: rc.proHasPurchaseOrders,
        hasDataExport: rc.proHasDataExport,
      ),
    };
  }

  static String upgradeMessage = 'Upgrade to Pro';

  AppPlan _currentPlan = AppPlan.trial;
  AppPlan get currentPlan => _currentPlan;
  PlanLimits get currentLimits => limits[_currentPlan]!;

  DateTime? _trialExpiresAt;
  DateTime? get trialExpiresAt => _trialExpiresAt;

  bool get isTrial => _currentPlan == AppPlan.trial;
  bool get isPro => _currentPlan == AppPlan.pro;
  bool get isExpired => _currentPlan == AppPlan.expired;
  bool get isFullAccess => isTrial || isPro;

  int get trialDaysLeft {
    if (_trialExpiresAt == null) return 0;
    final diff = _trialExpiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

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
        .listen((doc) async {
      if (doc.exists) {
        final data = doc.data()!;
        _applyPlanFromData(data);
      } else {
        // No subscription doc — determine trial status from user's createdAt
        await _applyTrialFromUserDoc(uid);
      }
      _planController.add(_currentPlan);
      _cachePlan();
    }, onError: (_) {
      // Keep cached plan on error
    });
  }

  Future<void> _applyTrialFromUserDoc(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          _trialExpiresAt = DateTime(
            createdAt.year,
            createdAt.month + 6,
            createdAt.day,
            createdAt.hour,
            createdAt.minute,
            createdAt.second,
          );
          if (_trialExpiresAt!.isAfter(DateTime.now())) {
            _currentPlan = AppPlan.trial;
          } else {
            _currentPlan = AppPlan.expired;
          }
        } else {
          _currentPlan = AppPlan.expired;
        }
      } else {
        _currentPlan = AppPlan.expired;
      }
    } catch (_) {
      // Keep cached plan on error
    }

    _isInGracePeriod = false;
    _subscriptionStatus = null;
    _billingCycle = null;
    _currentPeriodEnd = null;
    _graceExpiresAt = null;
  }

  void _applyPlanFromData(Map<String, dynamic> data) {
    final planStr = data['plan'] as String? ?? 'expired';
    final status = data['status'] as String? ?? 'expired';
    final expiresAt = (data['currentPeriodEnd'] as Timestamp?)?.toDate();
    final graceAt = (data['graceExpiresAt'] as Timestamp?)?.toDate();
    final trialEnd = (data['trialExpiresAt'] as Timestamp?)?.toDate();

    _subscriptionStatus = status;
    _billingCycle = data['billingCycle'] as String?;
    _currentPeriodEnd = expiresAt;
    _graceExpiresAt = graceAt;
    _trialExpiresAt = trialEnd;

    // Active / halted / pending pro subscriber
    if ((status == 'active' || status == 'halted' || status == 'pending') &&
        planStr == 'pro') {
      if (status == 'halted' && graceAt != null && graceAt.isAfter(DateTime.now())) {
        _currentPlan = AppPlan.pro;
        _isInGracePeriod = true;
      } else if (status == 'halted') {
        // Grace period expired — fall through to trial check
        _resolveTrialOrExpired(trialEnd);
        _isInGracePeriod = false;
      } else {
        _currentPlan = AppPlan.pro;
        _isInGracePeriod = false;
      }
    } else {
      // Not an active pro subscriber — check trial
      _resolveTrialOrExpired(trialEnd);
      _isInGracePeriod = false;
    }
  }

  void _resolveTrialOrExpired(DateTime? trialEnd) {
    if (trialEnd != null && trialEnd.isAfter(DateTime.now())) {
      _currentPlan = AppPlan.trial;
      _trialExpiresAt = trialEnd;
    } else {
      _currentPlan = AppPlan.expired;
    }
  }

  Future<void> _loadCachedPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_plan');
      if (cached != null) {
        _currentPlan = AppPlan.values.firstWhere(
          (p) => p.name == cached,
          orElse: () => AppPlan.trial,
        );
      }
      final cachedTrialMs = prefs.getInt('cached_trial_expires_at');
      if (cachedTrialMs != null) {
        _trialExpiresAt = DateTime.fromMillisecondsSinceEpoch(cachedTrialMs);
      }
    } catch (_) {}
  }

  Future<void> _cachePlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_plan', _currentPlan.name);
      if (_trialExpiresAt != null) {
        await prefs.setInt(
            'cached_trial_expires_at', _trialExpiresAt!.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  /// Call on sign-out to stop listening to the old user's plan data.
  void reset() {
    _planListener?.cancel();
    _planListener = null;
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
    final max = currentLimits.maxPdfTemplates;
    return max == -1 || templateIndex < max;
  }

  /// Feature access checks combine plan-level gating with global feature flags
  /// from Remote Config — so a feature can be killed even for Pro users.
  bool get hasReports =>
      currentLimits.hasReports &&
      RemoteConfigService.instance.featureReports;

  bool get hasEwayBill =>
      currentLimits.hasEwayBill &&
      RemoteConfigService.instance.featureEwayBill;

  bool get hasPurchaseOrders =>
      currentLimits.hasPurchaseOrders &&
      RemoteConfigService.instance.featurePurchaseOrders;

  bool get hasDataExport =>
      currentLimits.hasDataExport &&
      RemoteConfigService.instance.featureDataExport;

  bool get hasPdfTemplates =>
      currentLimits.maxPdfTemplates == -1 || currentLimits.maxPdfTemplates > 1;

  bool get hasWhatsAppShare =>
      currentLimits.maxWhatsAppSharesPerMonth != 0 &&
      RemoteConfigService.instance.featureWhatsAppShare;
}
