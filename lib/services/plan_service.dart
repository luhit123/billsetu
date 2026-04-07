import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_config_service.dart';
import 'team_service.dart';

enum AppPlan { trial, expired, pro, enterprise }

class PlanLimits {
  final int maxInvoicesPerMonth;
  final int maxCustomers;
  final int maxProducts;
  final int maxPdfTemplates;
  final int maxWhatsAppSharesPerMonth; // 0 = disabled, -1 = unlimited
  final int maxTeamMembers; // -1 = unlimited, 0 = no teams
  final bool hasReports;
  final bool hasPurchaseOrders;
  final bool hasDataExport;
  final bool hasAttendance;
  final bool hasMembership;
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
    this.maxTeamMembers = 0,
    required this.hasReports,
    required this.hasPurchaseOrders,
    required this.hasDataExport,
    this.hasAttendance = false,
    this.hasMembership = false,
    required this.name,
    required this.displayName,
    required this.priceMonthly,
    required this.priceAnnual,
  });
}

class PlanService {
  PlanService._();
  static final PlanService instance = PlanService._();

  /// ALL plan limits are driven by Firebase Remote Config.
  /// Every single value can be changed remotely without an app update.
  static Map<AppPlan, PlanLimits> get limits {
    final rc = RemoteConfigService.instance;
    return {
      // Trial = full Enterprise experience so users see all features.
      // Uses Enterprise RC keys — not free keys.
      AppPlan.trial: PlanLimits(
        name: 'trial',
        displayName: 'BillRaja Enterprise',
        priceMonthly: 0,
        priceAnnual: 0,
        maxInvoicesPerMonth: rc.enterpriseMaxInvoices,
        maxCustomers: rc.enterpriseMaxCustomers,
        maxProducts: rc.enterpriseMaxProducts,
        maxPdfTemplates: rc.enterpriseMaxPdfTemplates,
        maxWhatsAppSharesPerMonth: rc.enterpriseMaxWhatsAppShares,
        maxTeamMembers: rc.enterpriseMaxTeamMembers,
        hasReports: rc.enterpriseHasReports,
        hasPurchaseOrders: rc.enterpriseHasPurchaseOrders,
        hasDataExport: rc.enterpriseHasDataExport,
        hasAttendance: rc.enterpriseHasAttendance,
        hasMembership: rc.enterpriseHasMembership,
      ),
      AppPlan.expired: PlanLimits(
        name: 'expired',
        displayName: 'Free',
        priceMonthly: 0,
        priceAnnual: 0,
        maxInvoicesPerMonth: rc.expiredMaxInvoices,
        maxCustomers: rc.expiredMaxCustomers,
        maxProducts: rc.expiredMaxProducts,
        maxPdfTemplates: rc.expiredMaxPdfTemplates,
        maxWhatsAppSharesPerMonth: rc.expiredMaxWhatsAppShares,
        maxTeamMembers: 0,
        hasReports: rc.expiredHasReports,
        hasPurchaseOrders: rc.expiredHasPurchaseOrders,
        hasDataExport: rc.expiredHasDataExport,
        hasAttendance: false,
        hasMembership: rc.expiredHasMembership,
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
        maxTeamMembers: rc.proMaxTeamMembers,
        hasReports: rc.proHasReports,
        hasPurchaseOrders: rc.proHasPurchaseOrders,
        hasDataExport: rc.proHasDataExport,
        hasAttendance: rc.proHasAttendance,
        hasMembership: rc.proHasMembership,
      ),
      AppPlan.enterprise: PlanLimits(
        name: 'enterprise',
        displayName: 'Enterprise',
        priceMonthly: rc.enterprisePriceMonthly,
        priceAnnual: rc.enterprisePriceAnnual,
        maxInvoicesPerMonth: rc.enterpriseMaxInvoices,
        maxCustomers: rc.enterpriseMaxCustomers,
        maxProducts: rc.enterpriseMaxProducts,
        maxPdfTemplates: rc.enterpriseMaxPdfTemplates,
        maxWhatsAppSharesPerMonth: rc.enterpriseMaxWhatsAppShares,
        maxTeamMembers: rc.enterpriseMaxTeamMembers,
        hasReports: rc.enterpriseHasReports,
        hasPurchaseOrders: rc.enterpriseHasPurchaseOrders,
        hasDataExport: rc.enterpriseHasDataExport,
        hasAttendance: rc.enterpriseHasAttendance,
        hasMembership: rc.enterpriseHasMembership,
      ),
    };
  }

  static String upgradeMessage = 'View Plans';

  AppPlan _currentPlan = AppPlan.trial;
  AppPlan get currentPlan => _currentPlan;
  PlanLimits get currentLimits => limits[_currentPlan]!;

  DateTime? _trialExpiresAt;
  DateTime? get trialExpiresAt => _trialExpiresAt;

  bool get isTrial => _currentPlan == AppPlan.trial;
  bool get isPro => _currentPlan == AppPlan.pro;
  bool get isEnterprise => _currentPlan == AppPlan.enterprise;
  bool get isExpired => _currentPlan == AppPlan.expired;
  bool get isFullAccess => isTrial || isPro || isEnterprise;
  bool get isPaidPlan => isPro || isEnterprise;

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
  StreamSubscription<void>? _rcListener;
  final _planController = StreamController<AppPlan>.broadcast();
  Stream<AppPlan> get planStream => _planController.stream;

  /// User's Firestore createdAt — cached so trial duration can be
  /// recalculated any time Remote Config changes trial_duration_months.
  DateTime? _userCreatedAt;

  /// One-shot load for startup — also sets up real-time listener
  Future<void> loadPlan() async {
    // Use effective owner so team members inherit the owner's subscription.
    String? uid;
    try {
      uid = TeamService.instance.getEffectiveOwnerId();
    } catch (e) {
      debugPrint(
        '[PlanService] getEffectiveOwnerId failed, falling back to currentUser: $e',
      );
      uid = FirebaseAuth.instance.currentUser?.uid;
    }
    if (uid == null) return;

    // Load cached plan first for instant UI
    await _loadCachedPlan();

    // Then start real-time listener
    _startPlanListener(uid);

    // Listen to Remote Config changes so feature flags and trial duration
    // apply immediately without requiring an app restart.
    _rcListener?.cancel();
    _rcListener = RemoteConfigService.instance.onConfigUpdated.listen((_) {
      // For non-pro users, recalculate trial expiry with the new RC duration.
      if (!isPro && _userCreatedAt != null) {
        _resolveTrialOrExpired(null);
      }
      // Always re-emit so UI rebuilds with updated limits/flags.
      _planController.add(_currentPlan);
    });
  }

  void _startPlanListener(String uid) {
    debugPrint('[PlanService] Listening on subscriptions/$uid');
    _planListener?.cancel();
    _planListener = FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(uid)
        .snapshots()
        .listen(
          (doc) async {
            debugPrint('[PlanService] Snapshot: exists=${doc.exists} fromCache=${doc.metadata.isFromCache} data=${doc.data()}');
            if (doc.exists) {
              // Ensure user's createdAt is cached for RC-based trial recalculation.
              if (_userCreatedAt == null) {
                await _fetchAndCacheUserCreatedAt(uid);
              }
              final data = doc.data()!;
              _applyPlanFromData(data);
            } else {
              // No subscription doc — determine trial status from user's createdAt.
              await _applyTrialFromUserDoc(uid);
            }
            debugPrint('[PlanService] Resolved plan: $_currentPlan status=$_subscriptionStatus');
            _planController.add(_currentPlan);
            _cachePlan();
          },
          onError: (e) {
            debugPrint('[PlanService] Listener error: $e');
            // Keep cached plan on error
          },
        );
  }

  /// Fetches the user document and caches createdAt for trial duration calculation.
  Future<void> _fetchAndCacheUserCreatedAt(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        _userCreatedAt = (userDoc.data()!['createdAt'] as Timestamp?)?.toDate();
      }
    } catch (e) {
      debugPrint('[PlanService] Failed to cache userCreatedAt: $e');
    }
  }

  Future<void> _applyTrialFromUserDoc(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        // Returning users (deleted account + re-signed up) never get a trial.
        final isReturningUser = data['returningUser'] as bool? ?? false;
        if (isReturningUser) {
          _currentPlan = AppPlan.expired;
          _trialExpiresAt = null;
          _userCreatedAt = null;
        } else {
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final storedTrialEnd =
              (data['trialExpiresAt'] as Timestamp?)?.toDate();
          if (createdAt != null) {
            _userCreatedAt = createdAt;
            _resolveTrialOrExpired(storedTrialEnd);
          } else {
            _currentPlan = AppPlan.expired;
          }
        }
      } else {
        _currentPlan = AppPlan.expired;
      }
    } catch (e) {
      debugPrint(
        '[PlanService] Failed to apply trial from user doc, keeping cached plan: $e',
      );
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

    // Active / halted paid subscriber (pro or enterprise)
    final isPaidPlan = planStr == 'pro' || planStr == 'enterprise';
    final resolvedPlan = planStr == 'enterprise' ? AppPlan.enterprise : AppPlan.pro;
    if ((status == 'active' || status == 'halted') &&
        isPaidPlan) {
      if (status == 'halted' &&
          graceAt != null &&
          graceAt.isAfter(DateTime.now())) {
        _currentPlan = resolvedPlan;
        _isInGracePeriod = true;
      } else if (status == 'halted') {
        // Grace period expired — fall through to trial check
        _resolveTrialOrExpired(trialEnd);
        _isInGracePeriod = false;
      } else {
        _currentPlan = resolvedPlan;
        _isInGracePeriod = false;
      }
    } else {
      // Not an active paid subscriber — check trial
      _resolveTrialOrExpired(trialEnd);
      _isInGracePeriod = false;
    }
  }

  /// Resolves whether user is on trial or expired.
  ///
  /// Prefers RC-based calculation (`_userCreatedAt + trial_duration_months`)
  /// so admins can change the trial duration in Firebase Remote Config and
  /// it takes effect immediately for all users without an app update.
  ///
  /// Falls back to [storedTrialEnd] only when createdAt is not yet cached.
  void _resolveTrialOrExpired(DateTime? storedTrialEnd) {
    // If the server explicitly set a trialExpiresAt (e.g. epoch 0 for
    // returning users), respect it over the RC-based calculation.
    if (storedTrialEnd != null &&
        storedTrialEnd.isBefore(DateTime(2000))) {
      // Server intentionally killed the trial (returning user).
      _currentPlan = AppPlan.expired;
      _trialExpiresAt = storedTrialEnd;
      return;
    }

    if (_userCreatedAt != null) {
      // RC-controlled: trial expiry = user's sign-up date + RC months.
      final rcMonths = RemoteConfigService.instance.trialDurationMonths;
      _trialExpiresAt = _addMonthsClamped(_userCreatedAt!, rcMonths);
      _currentPlan = _trialExpiresAt!.isAfter(DateTime.now())
          ? AppPlan.trial
          : AppPlan.expired;
      return;
    }
    // Fallback: use stored value (e.g. before user doc is fetched)
    if (storedTrialEnd != null && storedTrialEnd.isAfter(DateTime.now())) {
      _currentPlan = AppPlan.trial;
      _trialExpiresAt = storedTrialEnd;
    } else {
      _currentPlan = AppPlan.expired;
    }
  }

  /// Adds [months] to [base] with day-clamping to avoid overflow on short months
  /// (e.g. Oct 31 + 4 months → Feb 31 → Feb 28/29 instead of Mar 3).
  static DateTime _addMonthsClamped(DateTime base, int months) {
    final rawExpiry = DateTime(
      base.year,
      base.month + months,
      base.day,
      base.hour,
      base.minute,
      base.second,
    );
    // If Dart rolled the day into the next month, step back to last day of
    // the intended target month.
    final targetMonth = ((base.month - 1 + months) % 12) + 1;
    return rawExpiry.month == targetMonth
        ? rawExpiry
        : DateTime(
            rawExpiry.year,
            rawExpiry.month,
            0,
            base.hour,
            base.minute,
            base.second,
          );
  }

  Future<void> _loadCachedPlan() async {
    try {
      String? uid;
      try {
        uid = TeamService.instance.getEffectiveOwnerId();
      } catch (_) {
        uid = FirebaseAuth.instance.currentUser?.uid;
      }
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      // Validate cached data belongs to this user to prevent stale plan
      // showing after sign-out / sign-in as a different user.
      final cachedUid = prefs.getString('cached_plan_uid');
      if (cachedUid != uid) return;
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
    } catch (e) {
      debugPrint('[PlanService] Failed to load cached plan: $e');
    }
  }

  Future<void> _cachePlan() async {
    try {
      String? uid;
      try {
        uid = TeamService.instance.getEffectiveOwnerId();
      } catch (_) {
        uid = FirebaseAuth.instance.currentUser?.uid;
      }
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_plan_uid', uid);
      await prefs.setString('cached_plan', _currentPlan.name);
      if (_trialExpiresAt != null) {
        await prefs.setInt(
          'cached_trial_expires_at',
          _trialExpiresAt!.millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      debugPrint('[PlanService] Failed to cache plan: $e');
    }
  }

  /// Call on sign-out to stop listening to the old user's plan data
  /// and clear all cached state so the next sign-in starts clean.
  void reset() {
    _planListener?.cancel();
    _planListener = null;
    _rcListener?.cancel();
    _rcListener = null;
    _userCreatedAt = null;
    _currentPlan = AppPlan.expired;
    _trialExpiresAt = null;
    _subscriptionStatus = null;
    _billingCycle = null;
    _currentPeriodEnd = null;
    _graceExpiresAt = null;
    _isInGracePeriod = false;
    // Clear persisted cache so deleted/re-joined users don't see stale plan
    _clearCachedPlan();
  }

  Future<void> _clearCachedPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_plan');
      await prefs.remove('cached_plan_uid');
      await prefs.remove('cached_trial_expires_at');
    } catch (_) {}
  }

  void dispose() {
    _planListener?.cancel();
    _rcListener?.cancel();
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
    if (!RemoteConfigService.instance.featureWhatsAppShare) return false;
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
  /// from Remote Config — so a feature can be killed even for Pro/Trial users.
  bool get hasReports =>
      currentLimits.hasReports && RemoteConfigService.instance.featureReports;

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

  bool get hasAttendance => currentLimits.hasAttendance;

  bool get hasMembership =>
      currentLimits.hasMembership &&
      RemoteConfigService.instance.featureMembership;

  /// Whether the current plan allows any team members at all.
  /// 0 = no team access, -1 = unlimited, >0 = that many members.
  bool get hasTeamAccess => currentLimits.maxTeamMembers != 0;

  bool canAddTeamMember(int currentCount) {
    final max = currentLimits.maxTeamMembers;
    return max == -1 || currentCount < max;
  }
}
