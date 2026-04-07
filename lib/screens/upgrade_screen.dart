import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/plan_service.dart';
import '../services/payment_service.dart';
import '../services/remote_config_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_helpers.dart';
import '../utils/responsive.dart';
import '../widgets/aurora_app_backdrop.dart';

class UpgradeScreen extends StatefulWidget {
  final String? featureName;
  const UpgradeScreen({super.key, this.featureName});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _isAnnual = true;

  PlanLimits get _proLimits => PlanService.limits[AppPlan.pro]!;
  PlanLimits get _enterpriseLimits => PlanService.limits[AppPlan.enterprise]!;
  bool get _isPro => PlanService.instance.isPro;
  bool get _isEnterprise => PlanService.instance.isEnterprise;
  bool get _isTrial => PlanService.instance.isTrial;
  bool get _isPaidPlan => PlanService.instance.isPaidPlan;

  double _proPrice() =>
      _isAnnual ? _proLimits.priceAnnual : _proLimits.priceMonthly;
  double _enterprisePrice() => _isAnnual
      ? _enterpriseLimits.priceAnnual
      : _enterpriseLimits.priceMonthly;
  String _period() => _isAnnual ? '/year' : '/month';

  double _proMonthlyEquiv() {
    if (_isAnnual) return _proLimits.priceAnnual / 12;
    return _proLimits.priceMonthly;
  }

  double _enterpriseMonthlyEquiv() {
    if (_isAnnual) return _enterpriseLimits.priceAnnual / 12;
    return _enterpriseLimits.priceMonthly;
  }

  /// True if switching from a higher plan to a lower one.
  bool _isDowngrade(String targetPlanId) {
    const planRank = {'pro': 1, 'enterprise': 2};
    final currentPlan = PlanService.instance.currentLimits.name;
    return _isPaidPlan &&
        (planRank[targetPlanId] ?? 0) < (planRank[currentPlan] ?? 0);
  }

  /// True if switching from a lower plan to a higher one.
  bool _isUpgrade(String targetPlanId) {
    const planRank = {'pro': 1, 'enterprise': 2};
    final currentPlan = PlanService.instance.currentLimits.name;
    return _isPaidPlan &&
        (planRank[targetPlanId] ?? 0) > (planRank[currentPlan] ?? 0);
  }

  Future<void> _handlePurchase(String planId) async {
    if (_isPaidPlan && PlanService.instance.currentLimits.name == planId &&
        PlanService.instance.billingCycle == (_isAnnual ? 'annual' : 'monthly')) {
      return;
    }

    // ── Downgrade: show confirmation first ──────────────────────────────
    if (_isDowngrade(planId)) {
      final confirmed = await _showDowngradeConfirmation(planId);
      if (!confirmed || !mounted) return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: kPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isDowngrade(planId)
                      ? 'Scheduling plan change...'
                      : 'Processing payment...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await PaymentService.instance.purchasePlan(
      planId: planId,
      billingCycle: _isAnnual ? 'annual' : 'monthly',
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (result.downgradeScheduled) {
      _showDowngradeScheduledDialog(planId, result.currentPeriodEnd);
    } else if (result.success && !result.activationPending) {
      _showSuccessDialog(planId);
    } else if (result.activationPending) {
      _showPendingDialog(result.message);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFriendlyError(
              result.message,
              fallback: 'Payment failed. Please try again.',
            ),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<bool> _showDowngradeConfirmation(String targetPlanId) async {
    final currentName = _isEnterprise ? 'Enterprise' : 'Pro';
    final targetName = targetPlanId == 'pro' ? 'Pro' : 'Enterprise';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.swap_vert_rounded, color: Colors.orange.shade600, size: 24),
            const SizedBox(width: 10),
            const Text('Change Plan?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'re switching from $currentName to $targetName.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your $currentName plan will continue until the end of your current billing period. After that, you can subscribe to $targetName.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep $currentName',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Switch to $targetName'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showDowngradeScheduledDialog(
      String targetPlanId, String? periodEndIso) {
    final currentName = _isEnterprise ? 'Enterprise' : 'Pro';
    final targetName = targetPlanId == 'pro' ? 'Pro' : 'Enterprise';

    String periodEndText = '';
    if (periodEndIso != null) {
      try {
        final date = DateTime.parse(periodEndIso);
        periodEndText =
            '${date.day}/${date.month}/${date.year}';
      } catch (_) {}
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.shade50,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 36,
                  color: Colors.orange.shade600,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Plan Change Scheduled',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your $currentName plan will remain active'
                '${periodEndText.isNotEmpty ? ' until $periodEndText' : ' until the end of your billing period'}.'
                '\n\nAfter that, you can subscribe to the $targetName plan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: context.cs.onSurface.withAlpha(170),
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Got it',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String planId) {
    final displayName = planId == 'enterprise' ? 'Enterprise' : 'Pro';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: planId == 'enterprise'
                      ? const LinearGradient(
                          colors: [Color(0xFF7B2FF7), Color(0xFFC471F5)],
                        )
                      : kSignatureGradient,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to $displayName!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your $displayName plan is now active. Enjoy all features!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Start Using',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPendingDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.cs.primaryContainer,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: context.cs.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Payment Processing',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Okay',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trialDays = PlanService.instance.trialDaysLeft;
    final rc = RemoteConfigService.instance;

    if (kIsWeb && windowSizeOf(context) == WindowSize.expanded) {
      return _buildWebLayout(rc: rc, trialDays: trialDays);
    }

    return Scaffold(
      backgroundColor: context.cs.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero Header ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: context.cs.primary,
            leading: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: kSignatureGradient),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -40,
                      right: -30,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(8),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -40,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(6),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 16),
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withAlpha(15),
                                border: Border.all(
                                  color: Colors.white.withAlpha(25),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.rocket_launch_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Choose Your Plan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Grow your business with the right tools',
                              style: TextStyle(
                                color: Colors.white.withAlpha(180),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (widget.featureName != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(18),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_open_rounded,
                                      color: Colors.white.withAlpha(220),
                                      size: 13,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Unlock ${widget.featureName}',
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(220),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // ── Promo banner ───────────────────────────────
                  if (rc.promoBannerEnabled && rc.promoBannerText.isNotEmpty)
                    _buildPromoBanner(rc),

                  // ── Trial countdown ────────────────────────────
                  if (_isTrial && trialDays > 0) _buildTrialBanner(trialDays),

                  // ── Billing toggle ─────────────────────────────
                  _buildBillingToggle(),
                  const SizedBox(height: 24),

                  // ── Plan Cards ─────────────────────────────────

                  // Pro Plan Card
                  _buildPlanCard(
                    planName: 'Pro',
                    tagline: 'For growing businesses',
                    price: _proPrice(),
                    monthlyEquiv: _isAnnual ? _proMonthlyEquiv() : null,
                    period: _period(),
                    gradient: kSignatureGradient,
                    accentColor: kPrimary,
                    icon: Icons.workspace_premium_rounded,
                    isCurrentPlan: _isPro,
                    isPopular: true,
                    onUpgrade: () => _handlePurchase('pro'),
                    features: _buildProFeatures(),
                  ),

                  const SizedBox(height: 16),

                  // Enterprise Plan Card
                  _buildPlanCard(
                    planName: 'Enterprise',
                    tagline: 'For teams that need everything',
                    price: _enterprisePrice(),
                    monthlyEquiv: _isAnnual ? _enterpriseMonthlyEquiv() : null,
                    period: _period(),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7B2FF7), Color(0xFFC471F5)],
                    ),
                    accentColor: const Color(0xFF7B2FF7),
                    icon: Icons.diamond_rounded,
                    isCurrentPlan: _isEnterprise,
                    isPopular: false,
                    onUpgrade: () => _handlePurchase('enterprise'),
                    features: _buildEnterpriseFeatures(),
                  ),

                  const SizedBox(height: 24),

                  // ── Free Plan Section ──────────────────────────
                  if (!_isPaidPlan) _buildFreePlanSection(),

                  // ── Why upgrade section ────────────────────────
                  const SizedBox(height: 8),
                  _buildWhyUpgradeSection(),

                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'All prices include 18% GST \u2022 Cancel anytime',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebLayout({
    required RemoteConfigService rc,
    required int trialDays,
  }) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: context.cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.cs.surface.withValues(
                alpha: context.isDark ? 0.4 : 0.8,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: context.cs.outlineVariant),
            ),
            child: const Icon(Icons.close_rounded, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Plans & Pricing',
          style: TextStyle(
            color: context.cs.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraAppBackdrop()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: context.isDark
                      ? [const Color(0x10000000), const Color(0x52050A12)]
                      : [
                          Colors.white.withValues(alpha: 0.28),
                          const Color(0x1AFFFFFF),
                        ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWebHero(rc: rc, trialDays: trialDays),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildPlanCard(
                              planName: 'Pro',
                              tagline: 'For growing businesses',
                              price: _proPrice(),
                              monthlyEquiv: _isAnnual
                                  ? _proMonthlyEquiv()
                                  : null,
                              period: _period(),
                              gradient: kSignatureGradient,
                              accentColor: kPrimary,
                              icon: Icons.workspace_premium_rounded,
                              isCurrentPlan: _isPro,
                              isPopular: true,
                              onUpgrade: () => _handlePurchase('pro'),
                              features: _buildProFeatures(),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildPlanCard(
                              planName: 'Enterprise',
                              tagline: 'For teams that need everything',
                              price: _enterprisePrice(),
                              monthlyEquiv: _isAnnual
                                  ? _enterpriseMonthlyEquiv()
                                  : null,
                              period: _period(),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF7B2FF7), Color(0xFFC471F5)],
                              ),
                              accentColor: const Color(0xFF7B2FF7),
                              icon: Icons.diamond_rounded,
                              isCurrentPlan: _isEnterprise,
                              isPopular: false,
                              onUpgrade: () => _handlePurchase('enterprise'),
                              features: _buildEnterpriseFeatures(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildWebComparisonCard(rc)),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                if (rc.promoBannerEnabled &&
                                    rc.promoBannerText.isNotEmpty)
                                  _buildPromoBanner(rc),
                                if (_isTrial && trialDays > 0)
                                  _buildTrialBanner(trialDays),
                                if (!_isPaidPlan) _buildFreePlanSection(),
                                _buildWhyUpgradeSection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'All prices include 18% GST • Cancel anytime',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebHero({
    required RemoteConfigService rc,
    required int trialDays,
  }) {
    final currentPlanName = PlanService.instance.currentLimits.displayName;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: kPrimary.withValues(alpha: context.isDark ? 0.28 : 0.14),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDark
              ? [const Color(0xE6101726), const Color(0xE20D1F33)]
              : [Colors.white.withValues(alpha: 0.88), const Color(0xFFF6FAFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: context.isDark
                ? Colors.black.withValues(alpha: 0.26)
                : const Color(0x181C3A54),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kPrimary.withValues(alpha: 0.14)),
                  ),
                  child: Text(
                    widget.featureName != null
                        ? 'Unlock ${widget.featureName}'
                        : '${rc.upgradeTitle} • compare every plan',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: kPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A cleaner pricing experience for web, with faster comparison and a clearer buying decision.',
                  style: TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    letterSpacing: -0.9,
                    color: context.cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Compare limits, team access, billing options, and premium tools without digging through stacked mobile cards.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _WebHeroChip(
                      icon: Icons.receipt_long_rounded,
                      label: 'GST billing',
                    ),
                    _WebHeroChip(
                      icon: Icons.groups_rounded,
                      label: 'Team & attendance',
                    ),
                    _WebHeroChip(
                      icon: Icons.qr_code_rounded,
                      label: 'UPI links & QR',
                    ),
                    _WebHeroChip(
                      icon: Icons.download_rounded,
                      label: 'Reports & export',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.cs.surface.withValues(
                  alpha: context.isDark ? 0.42 : 0.72,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: context.cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: kPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current plan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentPlanName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: context.cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildBillingToggle(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _WebMetricTile(
                          label: 'Pro annual',
                          value:
                              '₹${_proLimits.priceAnnual.toStringAsFixed(0)}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WebMetricTile(
                          label: 'Enterprise annual',
                          value:
                              '₹${_enterpriseLimits.priceAnnual.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                  if (_isTrial && trialDays > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? Colors.amber.withValues(alpha: 0.12)
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.isDark
                              ? Colors.amber.withValues(alpha: 0.24)
                              : Colors.amber.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$trialDays days left in your trial. You still have full premium access.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: context.isDark
                                    ? Colors.amber.shade300
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebComparisonCard(RemoteConfigService rc) {
    final features = rc.planComparisonFeatures;
    final freeLimits = PlanService.limits[AppPlan.expired]!;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      decoration: BoxDecoration(
        color: context.cs.surface.withValues(
          alpha: context.isDark ? 0.92 : 0.96,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.cs.outlineVariant),
        boxShadow: const [kWhisperShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.table_chart_rounded, color: kPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan comparison',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Desktop-friendly comparison of your free, Pro, and Enterprise limits.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cs.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Feature',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.cs.onSurfaceVariant,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Expanded(child: _buildComparisonPlanHeader('Free')),
                Expanded(
                  child: _buildComparisonPlanHeader('Pro', accent: kPrimary),
                ),
                Expanded(
                  child: _buildComparisonPlanHeader(
                    'Enterprise',
                    accent: const Color(0xFF7B2FF7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final feature in features)
            _buildComparisonRow(
              icon: _comparisonIconFor(feature['icon']?.toString() ?? ''),
              label: feature['label']?.toString() ?? '',
              freeValue: _comparisonValueForPlan(
                feature['label']?.toString() ?? '',
                AppPlan.expired,
                feature['free'],
                limits: freeLimits,
              ),
              proValue: _comparisonValueForPlan(
                feature['label']?.toString() ?? '',
                AppPlan.pro,
                feature['pro'],
                limits: _proLimits,
              ),
              enterpriseValue: _comparisonValueForPlan(
                feature['label']?.toString() ?? '',
                AppPlan.enterprise,
                feature['pro'],
                limits: _enterpriseLimits,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonPlanHeader(String label, {Color? accent}) {
    final color = accent ?? context.cs.onSurfaceVariant;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: accent == null ? 0.08 : 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonRow({
    required IconData icon,
    required String label,
    required dynamic freeValue,
    required dynamic proValue,
    required dynamic enterpriseValue,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: kPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildComparisonValueCell(freeValue)),
          Expanded(
            child: _buildComparisonValueCell(
              proValue,
              accent: kPrimary,
              emphasize: true,
            ),
          ),
          Expanded(
            child: _buildComparisonValueCell(
              enterpriseValue,
              accent: const Color(0xFF7B2FF7),
              emphasize: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonValueCell(
    dynamic value, {
    Color? accent,
    bool emphasize = false,
  }) {
    if (value is bool) {
      final enabled = value;
      final color = enabled
          ? (accent ?? const Color(0xFF16A34A))
          : context.cs.onSurfaceVariant.withValues(alpha: 0.55);
      return Center(
        child: Icon(
          enabled ? Icons.check_circle_rounded : Icons.remove_rounded,
          size: enabled ? 20 : 18,
          color: color,
        ),
      );
    }

    final text = value?.toString() ?? '-';
    final color = accent ?? context.cs.onSurface;
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          color: color,
          height: 1.35,
        ),
      ),
    );
  }

  IconData _comparisonIconFor(String key) {
    switch (key) {
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'people':
        return Icons.people_rounded;
      case 'inventory_2':
        return Icons.inventory_2_rounded;
      case 'picture_as_pdf':
        return Icons.picture_as_pdf_rounded;
      case 'currency_rupee':
        return Icons.currency_rupee_rounded;
      case 'qr_code':
        return Icons.qr_code_rounded;
      case 'language':
        return Icons.language_rounded;
      case 'cloud_off':
        return Icons.cloud_off_rounded;
      case 'badge':
        return Icons.badge_rounded;
      case 'chat':
        return Icons.chat_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'bar_chart':
        return Icons.bar_chart_rounded;
      case 'assessment':
        return Icons.assessment_rounded;
      case 'card_membership':
        return Icons.card_membership_rounded;
      case 'qr_code_scanner':
        return Icons.qr_code_scanner_rounded;
      case 'download':
        return Icons.download_rounded;
      case 'palette':
        return Icons.palette_rounded;
      default:
        return Icons.checklist_rounded;
    }
  }

  dynamic _comparisonValueForPlan(
    String label,
    AppPlan plan,
    dynamic fallback, {
    required PlanLimits limits,
  }) {
    final lower = label.toLowerCase();
    if (lower.contains('invoice')) {
      return limits.maxInvoicesPerMonth == -1
          ? 'Unlimited'
          : '${limits.maxInvoicesPerMonth}/month';
    }
    if (lower.contains('customer')) {
      return limits.maxCustomers == -1 ? 'Unlimited' : '${limits.maxCustomers}';
    }
    if (lower.contains('product')) {
      return limits.maxProducts == -1 ? 'Unlimited' : '${limits.maxProducts}';
    }
    if (lower.contains('pdf template')) {
      return limits.maxPdfTemplates == -1
          ? 'Unlimited'
          : '${limits.maxPdfTemplates}';
    }
    if (lower.contains('whatsapp')) {
      if (limits.maxWhatsAppSharesPerMonth == 0) return false;
      return limits.maxWhatsAppSharesPerMonth == -1
          ? 'Unlimited'
          : '${limits.maxWhatsAppSharesPerMonth}/mo';
    }
    if (lower.contains('team member')) {
      if (limits.maxTeamMembers == 0) return false;
      return limits.maxTeamMembers == -1
          ? 'Unlimited'
          : '${limits.maxTeamMembers}';
    }
    if (lower.contains('purchase order')) return limits.hasPurchaseOrders;
    if (lower.contains('report') || lower.contains('gstr')) {
      return limits.hasReports;
    }
    if (lower.contains('data export') || lower.contains('csv')) {
      return limits.hasDataExport;
    }
    if (lower.contains('attendance')) return limits.hasAttendance;
    if (lower.contains('membership')) return limits.hasMembership;
    if (lower.contains('custom branding')) {
      return plan == AppPlan.expired ? fallback : true;
    }
    if (lower.contains('gst') ||
        lower.contains('upi') ||
        lower.contains('multi-language') ||
        lower.contains('offline') ||
        lower.contains('business card')) {
      return true;
    }
    return fallback;
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ─── Plan Card ─────────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildPlanCard({
    required String planName,
    required String tagline,
    required double price,
    double? monthlyEquiv,
    required String period,
    required Gradient gradient,
    required Color accentColor,
    required IconData icon,
    required bool isCurrentPlan,
    required bool isPopular,
    required VoidCallback onUpgrade,
    required List<_PlanFeature> features,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(isPopular ? 30 : 12),
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: isPopular ? 2 : 0,
          ),
        ],
        border: isPopular
            ? Border.all(color: accentColor.withAlpha(60), width: 1.5)
            : Border.all(color: context.cs.outlineVariant.withAlpha(40)),
      ),
      child: Column(
        children: [
          // ── Card Header ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(gradient: gradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(15)),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                planName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (isPopular) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade300,
                                        Colors.orange.shade300,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'POPULAR',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tagline,
                            style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Price + CTA button inline
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Price
                    Text(
                      '\u20B9',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    Text(
                      price.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        period,
                        style: TextStyle(
                          color: Colors.white.withAlpha(160),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (monthlyEquiv != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(\u20B9${monthlyEquiv.toStringAsFixed(0)}/mo)',
                        style: TextStyle(
                          color: Colors.white.withAlpha(180),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const Spacer(),
                    // CTA button in header
                    if (isCurrentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withAlpha(30)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Current Plan',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onUpgrade,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Text(
                              _isUpgrade(planName.toLowerCase())
                                  ? 'Upgrade'
                                  : _isDowngrade(planName.toLowerCase())
                                      ? 'Switch'
                                      : 'Get $planName',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Compact Features List (max 5 visible) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              children: [
                ...features.take(5).map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: accentColor.withAlpha(180),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                f.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: context.cs.onSurface,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (features.length > 5)
                  Text(
                    '+${features.length - 5} more features',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor.withAlpha(180),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ─── Free Plan Section ─────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildFreePlanSection() {
    return Column(
      children: [
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue with current plan',
              style: TextStyle(
                color: context.cs.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'You can keep using your current limits and upgrade later whenever your business needs more capacity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: context.cs.onSurfaceVariant.withAlpha(180),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ─── Why Upgrade Section ───────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildWhyUpgradeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.cs.outlineVariant.withAlpha(40)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: kSignatureGradient,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Why BillRaja?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.cs.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTrustItem(
            Icons.cloud_off_rounded,
            'Works offline',
            'Create invoices even without internet',
          ),
          _buildTrustItem(
            Icons.security_rounded,
            'Bank-grade security',
            'Your data is encrypted and protected',
          ),
          _buildTrustItem(
            Icons.support_agent_rounded,
            'Indian SME focused',
            'GST compliant, UPI ready, multi-language',
          ),
          _buildTrustItem(
            Icons.cancel_outlined,
            'Cancel anytime',
            'No lock-in, no hidden charges',
          ),
        ],
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kPrimary.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: kPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ─── Billing Toggle ────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildBillingToggle() {
    final monthlyTotal = _proLimits.priceMonthly * 12;
    final savings = monthlyTotal > 0
        ? ((monthlyTotal - _proLimits.priceAnnual) / monthlyTotal * 100)
              .round()
              .clamp(0, 99)
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [kSubtleShadow],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAnnual = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !_isAnnual ? kPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Monthly',
                    style: TextStyle(
                      color: !_isAnnual
                          ? Colors.white
                          : context.cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAnnual = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _isAnnual ? kPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Annual',
                        style: TextStyle(
                          color: _isAnnual
                              ? Colors.white
                              : context.cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (_isAnnual && savings > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'SAVE $savings%',
                            style: const TextStyle(
                              color: Color(0xFF1B5E20),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ─── Promo & Trial Banners ─────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════════

  Widget _buildPromoBanner(RemoteConfigService rc) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _parseColor(rc.promoBannerColor).withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _parseColor(rc.promoBannerColor).withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_rounded,
            color: _parseColor(rc.promoBannerColor),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rc.promoBannerText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _parseColor(rc.promoBannerColor),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBanner(int trialDays) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.amber.withAlpha(25)
            : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark
              ? Colors.amber.withAlpha(60)
              : Colors.amber.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$trialDays days left in your free trial',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.isDark
                        ? Colors.amber.shade300
                        : Colors.amber.shade900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You have full Pro access during your trial',
                  style: TextStyle(
                    color: context.isDark
                        ? Colors.amber.shade400
                        : Colors.amber.shade800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // ─── Dynamic Feature Lists (RC-driven) ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════════

  String _formatLimit(int value, String singular, {String? plural}) {
    if (value == -1) return 'Unlimited ${plural ?? '${singular}s'}';
    if (value == 0) return 'No ${plural ?? '${singular}s'}';
    if (value == 1) return '1 $singular';
    return '$value ${plural ?? '${singular}s'}';
  }

  List<_PlanFeature> _buildProFeatures() {
    final l = _proLimits;
    return [
      _PlanFeature(
        Icons.receipt_long_rounded,
        l.maxInvoicesPerMonth == -1
            ? 'Unlimited invoices'
            : '${l.maxInvoicesPerMonth} invoices/month',
      ),
      _PlanFeature(
        Icons.people_rounded,
        _formatLimit(l.maxCustomers, 'customer'),
      ),
      _PlanFeature(
        Icons.inventory_2_rounded,
        _formatLimit(l.maxProducts, 'product'),
      ),
      _PlanFeature(
        Icons.palette_rounded,
        _formatLimit(l.maxPdfTemplates, 'PDF template'),
      ),
      _PlanFeature(
        Icons.groups_rounded,
        _formatLimit(l.maxTeamMembers, 'team member'),
      ),
      if (l.maxWhatsAppSharesPerMonth != 0)
        _PlanFeature(
          Icons.share_rounded,
          l.maxWhatsAppSharesPerMonth == -1
              ? 'Unlimited WhatsApp shares'
              : '${l.maxWhatsAppSharesPerMonth} WhatsApp shares/mo',
        ),
      if (l.hasReports)
        const _PlanFeature(
          Icons.bar_chart_rounded,
          'Business reports & analytics',
        ),
      if (l.hasPurchaseOrders)
        const _PlanFeature(Icons.shopping_cart_rounded, 'Purchase orders'),
      if (l.hasDataExport)
        const _PlanFeature(Icons.download_rounded, 'Data export (CSV/Excel)'),
      if (l.hasAttendance)
        const _PlanFeature(
          Icons.fingerprint_rounded,
          'Team attendance tracking',
        ),
    ];
  }

  List<_PlanFeature> _buildEnterpriseFeatures() {
    final l = _enterpriseLimits;
    return [
      _PlanFeature(
        Icons.receipt_long_rounded,
        l.maxInvoicesPerMonth == -1
            ? 'Unlimited invoices'
            : '${l.maxInvoicesPerMonth} invoices/month',
      ),
      _PlanFeature(
        Icons.people_rounded,
        _formatLimit(l.maxCustomers, 'customer'),
      ),
      _PlanFeature(
        Icons.inventory_2_rounded,
        _formatLimit(l.maxProducts, 'product'),
      ),
      _PlanFeature(
        Icons.palette_rounded,
        _formatLimit(l.maxPdfTemplates, 'PDF template'),
      ),
      _PlanFeature(
        Icons.groups_rounded,
        _formatLimit(l.maxTeamMembers, 'team member'),
      ),
      if (l.maxWhatsAppSharesPerMonth != 0)
        _PlanFeature(
          Icons.share_rounded,
          l.maxWhatsAppSharesPerMonth == -1
              ? 'Unlimited WhatsApp shares'
              : '${l.maxWhatsAppSharesPerMonth} WhatsApp shares/mo',
        ),
      if (l.hasReports)
        const _PlanFeature(
          Icons.bar_chart_rounded,
          'Advanced reports & analytics',
        ),
      if (l.hasPurchaseOrders)
        const _PlanFeature(Icons.shopping_cart_rounded, 'Purchase orders'),
      if (l.hasDataExport)
        const _PlanFeature(Icons.download_rounded, 'Data export (CSV/Excel)'),
      if (l.hasAttendance)
        const _PlanFeature(
          Icons.fingerprint_rounded,
          'Team attendance tracking',
        ),
      const _PlanFeature(Icons.support_agent_rounded, 'Priority support'),
    ];
  }
}

/// Internal model for plan feature items.
class _PlanFeature {
  final IconData icon;
  final String label;
  const _PlanFeature(this.icon, this.label);
}

class _WebHeroChip extends StatelessWidget {
  const _WebHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.cs.surface.withValues(
          alpha: context.isDark ? 0.45 : 0.7,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.cs.outlineVariant.withValues(
            alpha: context.isDark ? 0.6 : 1,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: kPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebMetricTile extends StatelessWidget {
  const _WebMetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
