import 'package:flutter/material.dart';
import '../services/plan_service.dart';
import '../services/payment_service.dart';
import '../services/remote_config_service.dart';
import '../theme/app_colors.dart';

class UpgradeScreen extends StatefulWidget {
  final String? featureName;
  const UpgradeScreen({super.key, this.featureName});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _isAnnual = true;

  PlanLimits get _proLimits => PlanService.limits[AppPlan.pro]!;
  bool get _isPro => PlanService.instance.isPro;
  bool get _isTrial => PlanService.instance.isTrial;

  String _priceLabel() {
    if (_isAnnual) {
      return '\u20B9${_proLimits.priceAnnual.toStringAsFixed(0)}/yr';
    }
    return '\u20B9${_proLimits.priceMonthly.toStringAsFixed(0)}/mo';
  }

  Future<void> _handlePurchase() async {
    if (_isPro) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48, height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3, color: kPrimary),
                ),
                SizedBox(height: 20),
                Text('Processing payment...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kOnSurface)),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await PaymentService.instance.purchasePlan(
      planId: 'pro',
      billingCycle: _isAnnual ? 'annual' : 'monthly',
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (result.success) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showSuccessDialog() {
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
                width: 72, height: 72,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: kSignatureGradient),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Welcome to Pro!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kOnSurface)),
              const SizedBox(height: 8),
              Text(
                'Your Pro plan is now active. Enjoy all features!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Start Using', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
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

    return Scaffold(
      backgroundColor: kSurface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: kPrimary,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: kSignatureGradient),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 28),
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(30),
                          border: Border.all(color: Colors.white.withAlpha(40), width: 2),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        rc.upgradeTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      if (widget.featureName != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Unlock ${widget.featureName}',
                            style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
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

                  // Promo banner (remote config driven)
                  if (rc.promoBannerEnabled && rc.promoBannerText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _parseColor(rc.promoBannerColor).withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _parseColor(rc.promoBannerColor).withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_offer_rounded, color: _parseColor(rc.promoBannerColor), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rc.promoBannerText,
                              style: TextStyle(fontWeight: FontWeight.w600, color: _parseColor(rc.promoBannerColor), fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Trial countdown
                  if (_isTrial && trialDays > 0)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, color: Colors.amber.shade800, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            '$trialDays days left in your free trial',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.amber.shade900, fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                  // Billing toggle
                  _buildBillingToggle(),
                  const SizedBox(height: 20),

                  // Single Pro plan card
                  _buildProCard(),
                  const SizedBox(height: 20),

                  // CTA
                  if (!_isPro)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: kSignatureGradient,
                        boxShadow: [
                          BoxShadow(color: kPrimary.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _handlePurchase,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  '${rc.upgradeCtaText} \u2014 ${_priceLabel()}',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_isPro)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 22),
                          SizedBox(width: 8),
                          Text('You\'re on Pro!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.green)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  if (!_isPro)
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          _isTrial ? 'Continue with Free Trial' : 'Maybe Later',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'All prices include 18% GST',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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

  Widget _buildBillingToggle() {
    final monthlyTotal = _proLimits.priceMonthly * 12;
    final savings = ((monthlyTotal - _proLimits.priceAnnual) / monthlyTotal * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(14),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isAnnual ? kPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Monthly',
                    style: TextStyle(
                      color: !_isAnnual ? Colors.white : kOnSurfaceVariant,
                      fontWeight: FontWeight.w600, fontSize: 14,
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
                  color: _isAnnual ? kPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Annual',
                        style: TextStyle(
                          color: _isAnnual ? Colors.white : kOnSurfaceVariant,
                          fontWeight: FontWeight.w600, fontSize: 14,
                        ),
                      ),
                      if (_isAnnual) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'SAVE $savings%',
                            style: const TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.bold),
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

  Widget _buildProCard() {
    final rc = RemoteConfigService.instance;
    final features = rc.upgradeFeatures;

    return Container(
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: const BoxDecoration(
              gradient: kSignatureGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Pro',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  _priceLabel(),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: features.map((f) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(_resolveIcon(f['icon'] ?? ''), size: 18, color: kPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f['label'] ?? '',
                          style: const TextStyle(fontSize: 13, color: kOnSurface, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(Icons.check_circle_rounded, size: 20, color: Colors.green.shade500),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Maps icon name strings from Remote Config to Material Icons.
  static IconData _resolveIcon(String name) {
    const map = <String, IconData>{
      'receipt_long': Icons.receipt_long,
      'people': Icons.people,
      'inventory_2': Icons.inventory_2,
      'picture_as_pdf': Icons.picture_as_pdf,
      'chat': Icons.chat,
      'shopping_cart': Icons.shopping_cart,
      'bar_chart': Icons.bar_chart,
      'local_shipping': Icons.local_shipping,
      'download': Icons.download,
      'palette': Icons.palette,
      'workspace_premium': Icons.workspace_premium_rounded,
      'star': Icons.star,
      'bolt': Icons.bolt,
      'diamond': Icons.diamond,
      'support': Icons.support_agent,
      'cloud': Icons.cloud,
      'security': Icons.security,
      'speed': Icons.speed,
    };
    return map[name] ?? Icons.check_circle_outline;
  }

  /// Parses a hex color string like "#0057FF" into a Color.
  static Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
