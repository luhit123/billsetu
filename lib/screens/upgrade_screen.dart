import 'package:flutter/material.dart';
import '../services/plan_service.dart';
import '../services/payment_service.dart';

class UpgradeScreen extends StatefulWidget {
  final String? featureName;
  const UpgradeScreen({super.key, this.featureName});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen>
    with TickerProviderStateMixin {
  bool _isAnnual = true;

  // Brand colors
  static const _navy = Color(0xFF1E3A8A);
  static const _primary = Color(0xFF4361EE);
  static const _teal = Color(0xFF6366F1);
  static const _background = Color(0xFFF8FAFC);
  static const _border = Color(0xFFCBD5E1);
  static const _gold = Color(0xFFD4A017);
  static const _purple = Color(0xFF7B1FA2);

  AppPlan get _currentPlan => PlanService.instance.currentPlan;

  String _formatLimit(int value) => value == -1 ? 'Unlimited' : '$value';

  String _priceLabel(AppPlan plan) {
    final limits = PlanService.limits[plan]!;
    if (limits.priceMonthly == 0) return 'Free Forever';
    if (_isAnnual) {
      return '\u20B9${limits.priceAnnual.toStringAsFixed(0)}/yr';
    }
    return '\u20B9${limits.priceMonthly.toStringAsFixed(0)}/mo';
  }

  String _ctaPriceLabel(AppPlan plan) {
    final limits = PlanService.limits[plan]!;
    if (_isAnnual) {
      return '\u20B9${limits.priceAnnual.toStringAsFixed(0)}/yr';
    }
    return '\u20B9${limits.priceMonthly.toStringAsFixed(0)}/mo';
  }

  Future<void> _handlePurchase(AppPlan plan) async {
    if (_currentPlan == plan) return;

    final planId = plan == AppPlan.raja ? 'raja' : 'maharaja';
    final billingCycle = _isAnnual ? 'annual' : 'monthly';

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: plan == AppPlan.raja ? _gold : _purple,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Processing payment...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we set up your plan',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
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
      billingCycle: billingCycle,
    );

    if (!mounted) return;

    // Dismiss loading dialog
    Navigator.of(context).pop();

    if (result.success) {
      _showSuccessDialog(plan);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(result.message)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showSuccessDialog(AppPlan plan) {
    final limits = PlanService.limits[plan]!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  gradient: LinearGradient(
                    colors: plan == AppPlan.raja
                        ? [_gold, const Color(0xFFF5D060)]
                        : [_purple, const Color(0xFFAB47BC)],
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to ${limits.displayName}!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your ${limits.displayName} plan is now active. Enjoy all the premium features!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        plan == AppPlan.raja ? _gold : _purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // dialog
                    Navigator.of(context).pop(); // screen
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  _buildBillingToggle(),
                  const SizedBox(height: 20),
                  _buildPlanCard(
                    plan: AppPlan.free,
                    accentColor: const Color(0xFF78909C),
                    icon: Icons.account_circle_outlined,
                    badgeText: null,
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    plan: AppPlan.raja,
                    accentColor: _gold,
                    icon: Icons.emoji_events_rounded,
                    badgeText: 'Most Popular',
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    plan: AppPlan.maharaja,
                    accentColor: _purple,
                    icon: Icons.diamond_rounded,
                    badgeText: null,
                  ),
                  const SizedBox(height: 24),
                  _buildLaunchOfferBanner(),
                  const SizedBox(height: 24),
                  _buildCtaButtons(),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Continue with Free',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'All prices include 18% GST',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
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

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: _navy,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_navy, _teal],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 28),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(30),
                    border: Border.all(
                      color: Colors.white.withAlpha(40),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.amber,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                if (widget.featureName != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Unlock ${widget.featureName}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAnnual = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isAnnual ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Monthly',
                    style: TextStyle(
                      color: !_isAnnual ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isAnnual ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Annual',
                        style: TextStyle(
                          color:
                              _isAnnual ? Colors.white : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (_isAnnual) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SAVE',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
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

  Widget _buildPlanCard({
    required AppPlan plan,
    required Color accentColor,
    required IconData icon,
    required String? badgeText,
  }) {
    final limits = PlanService.limits[plan]!;
    final isCurrentPlan = _currentPlan == plan;
    final features = _buildFeatureList(plan, limits, accentColor);

    // Savings badge for paid plans when annual is selected
    String? savingsBadge;
    if (_isAnnual && limits.priceMonthly > 0) {
      final monthlyTotal = limits.priceMonthly * 12;
      final savings =
          ((monthlyTotal - limits.priceAnnual) / monthlyTotal * 100).round();
      savingsBadge = 'Save $savings%';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentPlan ? accentColor : _border,
          width: isCurrentPlan ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentPlan
                ? accentColor.withAlpha(30)
                : Colors.black.withAlpha(10),
            blurRadius: isCurrentPlan ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor,
                  accentColor.withAlpha(200),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      limits.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(25),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isCurrentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Current Plan',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _priceLabel(plan),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (savingsBadge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          savingsBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Feature list
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(children: features),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeatureList(
      AppPlan plan, PlanLimits limits, Color accentColor) {
    final items = <_FeatureRow>[
      _FeatureRow(
        icon: Icons.receipt_long,
        label: 'Invoices / month',
        value: _formatLimit(limits.maxInvoicesPerMonth),
        enabled: true,
      ),
      _FeatureRow(
        icon: Icons.people,
        label: 'Customers',
        value: _formatLimit(limits.maxCustomers),
        enabled: true,
      ),
      _FeatureRow(
        icon: Icons.inventory_2,
        label: 'Products',
        value: _formatLimit(limits.maxProducts),
        enabled: true,
      ),
      _FeatureRow(
        icon: Icons.picture_as_pdf,
        label: 'PDF Templates',
        value: '${limits.maxPdfTemplates}',
        enabled: true,
      ),
      _FeatureRow(
        icon: Icons.chat,
        label: 'WhatsApp Sharing',
        value: limits.maxWhatsAppSharesPerMonth == 0
            ? null
            : _formatLimit(limits.maxWhatsAppSharesPerMonth),
        enabled: limits.maxWhatsAppSharesPerMonth != 0,
      ),
      _FeatureRow(
        icon: Icons.shopping_cart,
        label: 'Purchase Orders',
        value: null,
        enabled: limits.hasPurchaseOrders,
      ),
      _FeatureRow(
        icon: Icons.bar_chart,
        label: 'Reports & Analytics',
        value: null,
        enabled: limits.hasReports,
      ),
      _FeatureRow(
        icon: Icons.local_shipping,
        label: 'E-Way Bill',
        value: null,
        enabled: limits.hasEwayBill,
      ),
      _FeatureRow(
        icon: Icons.download,
        label: 'Data Export',
        value: null,
        enabled: limits.hasDataExport,
      ),
    ];

    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 18,
              color: item.enabled ? accentColor : Colors.grey.shade400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      item.enabled ? Colors.grey.shade800 : Colors.grey.shade400,
                  fontWeight: item.enabled ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (item.value != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: item.enabled
                      ? accentColor.withAlpha(20)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.value!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: item.enabled ? accentColor : Colors.grey.shade400,
                  ),
                ),
              )
            else
              Icon(
                item.enabled
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 20,
                color: item.enabled ? Colors.green.shade500 : Colors.grey.shade300,
              ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildLaunchOfferBanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
        ),
        border: Border.all(color: _gold.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: _gold.withAlpha(25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_gold, _gold.withAlpha(180)],
              ),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Save up to 33% with Annual Billing',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Raja \u20B9799/yr  \u2022  Maharaja \u20B91,499/yr',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.brown.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'vs \u20B999/mo and \u20B9199/mo billed monthly',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.brown.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaButtons() {
    final isOnRaja = _currentPlan == AppPlan.raja;
    final isOnMaharaja = _currentPlan == AppPlan.maharaja;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Raja CTA
        _CtaButton(
          label: isOnRaja
              ? 'Current Plan \u2014 Raja'
              : 'Start Raja \u2014 ${_ctaPriceLabel(AppPlan.raja)}',
          gradient: const LinearGradient(
            colors: [_gold, Color(0xFFE8B830)],
          ),
          shadowColor: _gold,
          icon: Icons.emoji_events_rounded,
          enabled: !isOnRaja,
          onPressed: isOnRaja ? null : () => _handlePurchase(AppPlan.raja),
        ),
        const SizedBox(height: 12),
        // Maharaja CTA
        _CtaButton(
          label: isOnMaharaja
              ? 'Current Plan \u2014 Maharaja'
              : 'Go Maharaja \u2014 ${_ctaPriceLabel(AppPlan.maharaja)}',
          gradient: const LinearGradient(
            colors: [_purple, Color(0xFF9C27B0)],
          ),
          shadowColor: _purple,
          icon: Icons.diamond_rounded,
          enabled: !isOnMaharaja,
          onPressed:
              isOnMaharaja ? null : () => _handlePurchase(AppPlan.maharaja),
        ),
      ],
    );
  }
}

class _FeatureRow {
  final IconData icon;
  final String label;
  final String? value;
  final bool enabled;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
  });
}

class _CtaButton extends StatelessWidget {
  final String label;
  final Gradient gradient;
  final Color shadowColor;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  const _CtaButton({
    required this.label,
    required this.gradient,
    required this.shadowColor,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: gradient,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: shadowColor.withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
