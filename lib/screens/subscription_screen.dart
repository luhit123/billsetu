import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../modals/payment.dart';
import '../services/plan_service.dart';
import '../services/payment_service.dart';
import '../services/usage_tracking_service.dart';
import '../theme/app_colors.dart';
import 'upgrade_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, int>? _usage;
  bool _isLoadingUsage = true;
  bool _isCancelling = false;
  bool _isReactivating = false;
  bool _cancelAtPeriodEnd = false;

  StreamSubscription<AppPlan>? _planSub;
  StreamSubscription<DocumentSnapshot>? _subDocSub;

  @override
  void initState() {
    super.initState();
    _loadUsage();
    _listenPlanChanges();
    _listenSubscriptionDoc();
  }

  @override
  void dispose() {
    _planSub?.cancel();
    _subDocSub?.cancel();
    super.dispose();
  }

  void _listenPlanChanges() {
    _planSub = PlanService.instance.planStream.listen((_) {
      if (mounted) {
        _loadUsage();
        setState(() {});
      }
    });
  }

  void _listenSubscriptionDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _subDocSub = FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _cancelAtPeriodEnd = data['cancelAtPeriodEnd'] as bool? ?? false;
        });
      }
    });
  }

  Future<void> _loadUsage() async {
    setState(() => _isLoadingUsage = true);
    try {
      final usage = await UsageTrackingService.instance.getUsageSummary();
      if (mounted) setState(() => _usage = usage);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingUsage = false);
  }

  @override
  Widget build(BuildContext context) {
    final plan = PlanService.instance.currentPlan;
    final limits = PlanService.instance.currentLimits;
    final status = PlanService.instance.subscriptionStatus;
    final billingCycle = PlanService.instance.billingCycle;
    final periodEnd = PlanService.instance.currentPeriodEnd;
    final isGrace = PlanService.instance.isInGracePeriod;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: kSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: kOnSurface,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsage,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Grace-period warning ─────────────────────────
            if (isGrace) _buildGraceWarning(),

            // ── Plan header card ─────────────────────────────
            _PlanHeaderCard(
              plan: plan,
              limits: limits,
              status: status,
              billingCycle: billingCycle,
              periodEnd: periodEnd,
              cancelAtPeriodEnd: _cancelAtPeriodEnd,
              isGrace: isGrace,
            ),
            const SizedBox(height: 20),

            // ── Usage dashboard ──────────────────────────────
            _buildSectionHeader('Usage This Month', 'Track your current plan usage'),
            const SizedBox(height: 12),
            _isLoadingUsage
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ))
                : _buildUsageGrid(limits),
            const SizedBox(height: 20),

            // ── Subscription actions ─────────────────────────
            _buildSectionHeader('Manage Subscription', 'Upgrade, change, or cancel your plan'),
            const SizedBox(height: 12),
            _buildActions(plan),
            const SizedBox(height: 20),

            // ── Payment history ──────────────────────────────
            _buildSectionHeader('Payment History', 'Your recent transactions'),
            const SizedBox(height: 12),
            _buildPaymentHistory(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Grace-period warning banner ────────────────────────────────────────────

  Widget _buildGraceWarning() {
    final graceEnd = PlanService.instance.graceExpiresAt;
    final daysLeft = graceEnd != null
        ? graceEnd.difference(DateTime.now()).inDays
        : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grace Period Active',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your payment is overdue. You have $daysLeft day${daysLeft == 1 ? '' : 's'} to renew before losing access.',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kOnSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: kOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Usage grid ─────────────────────────────────────────────────────────────

  Widget _buildUsageGrid(PlanLimits limits) {
    final usage = _usage ?? {};
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _UsageCard(
          label: 'Invoices',
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFF007AFF),
          current: usage['invoices'] ?? 0,
          max: limits.maxInvoicesPerMonth,
        ),
        _UsageCard(
          label: 'Customers',
          icon: Icons.people_rounded,
          iconColor: const Color(0xFF34C759),
          current: usage['customers'] ?? 0,
          max: limits.maxCustomers,
        ),
        _UsageCard(
          label: 'Products',
          icon: Icons.inventory_2_rounded,
          iconColor: const Color(0xFFFF9500),
          current: usage['products'] ?? 0,
          max: limits.maxProducts,
        ),
        _UsageCard(
          label: 'WhatsApp',
          icon: Icons.chat_rounded,
          iconColor: const Color(0xFF25D366),
          current: usage['whatsappShares'] ?? 0,
          max: limits.maxWhatsAppSharesPerMonth,
        ),
      ],
    );
  }

  // ── Subscription actions ───────────────────────────────────────────────────

  Widget _buildActions(AppPlan plan) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        children: [
          // Upgrade / Change plan
          _ActionTile(
            icon: Icons.rocket_launch_rounded,
            title: plan == AppPlan.free ? 'Upgrade Plan' : 'Change Plan',
            subtitle: plan == AppPlan.free
                ? 'Unlock more features with Raja or Maharaja'
                : 'Switch to a different plan',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpgradeScreen()),
              );
            },
          ),

          // Cancel / Reactivate (paid plans only)
          if (plan != AppPlan.free) ...[
            const Divider(height: 1, thickness: 1, indent: 18, endIndent: 18),
            if (_cancelAtPeriodEnd)
              _ActionTile(
                icon: Icons.replay_rounded,
                title: 'Reactivate Subscription',
                subtitle: 'Resume your plan before it expires',
                isLoading: _isReactivating,
                onTap: _reactivate,
              )
            else
              _ActionTile(
                icon: Icons.cancel_outlined,
                title: 'Cancel Subscription',
                subtitle: 'You will retain access until the billing period ends',
                isLoading: _isCancelling,
                titleColor: const Color(0xFFB3261E),
                onTap: () => _showCancelDialog(),
              ),
          ],

          // Cancellation notice
          if (_cancelAtPeriodEnd && PlanService.instance.currentPeriodEnd != null) ...[
            const Divider(height: 1, thickness: 1, indent: 18, endIndent: 18),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your plan will end on ${DateFormat('dd MMM yyyy').format(PlanService.instance.currentPeriodEnd!)}',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCancelDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'You will keep access to your current plan until the end of the billing period. After that, your account will revert to the Free plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Plan'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFB3261E)),
            child: const Text('Cancel Plan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelSubscription();
    }
  }

  Future<void> _cancelSubscription() async {
    setState(() => _isCancelling = true);
    try {
      final success = await PaymentService.instance.cancelSubscription();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Subscription cancelled. You will retain access until the end of this billing period.'
                : 'Failed to cancel subscription. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _reactivate() async {
    setState(() => _isReactivating = true);
    try {
      final success = await PaymentService.instance.reactivateSubscription();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Subscription reactivated!'
                : 'Failed to reactivate. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReactivating = false);
    }
  }

  // ── Payment history ────────────────────────────────────────────────────────

  Widget _buildPaymentHistory() {
    return StreamBuilder<List<Payment>>(
      stream: PaymentService.instance.watchPayments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final payments = snapshot.data ?? [];
        if (payments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kSurfaceLowest,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [kSubtleShadow],
            ),
            child: const Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 40, color: kOnSurfaceVariant),
                SizedBox(height: 12),
                Text(
                  'No payments yet',
                  style: TextStyle(
                    color: kOnSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: kSurfaceLowest,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [kSubtleShadow],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payments.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1, thickness: 1, indent: 18, endIndent: 18,
            ),
            itemBuilder: (context, index) {
              final payment = payments[index];
              return _PaymentTile(payment: payment);
            },
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Plan Header Card ────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _PlanHeaderCard extends StatelessWidget {
  const _PlanHeaderCard({
    required this.plan,
    required this.limits,
    required this.status,
    required this.billingCycle,
    required this.periodEnd,
    required this.cancelAtPeriodEnd,
    required this.isGrace,
  });

  final AppPlan plan;
  final PlanLimits limits;
  final String? status;
  final String? billingCycle;
  final DateTime? periodEnd;
  final bool cancelAtPeriodEnd;
  final bool isGrace;

  IconData get _planIcon => switch (plan) {
    AppPlan.free => Icons.star_border_rounded,
    AppPlan.raja => Icons.star_rounded,
    AppPlan.maharaja => Icons.diamond_rounded,
    AppPlan.king => Icons.workspace_premium_rounded,
  };

  String get _statusLabel {
    if (cancelAtPeriodEnd) return 'Cancelling';
    if (isGrace) return 'Grace Period';
    if (status == 'active') return 'Active';
    return 'Inactive';
  }

  Color get _statusColor {
    if (cancelAtPeriodEnd) return Colors.amber;
    if (isGrace) return Colors.orange;
    if (status == 'active') return Colors.greenAccent;
    return Colors.red.shade200;
  }

  @override
  Widget build(BuildContext context) {
    final cycleName = billingCycle == 'annual' ? 'Annual' : 'Monthly';
    final price = billingCycle == 'annual' ? limits.priceAnnual : limits.priceMonthly;
    final periodLabel = billingCycle == 'annual' ? '/year' : '/month';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: kSignatureGradient,
        boxShadow: const [kWhisperShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_planIcon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${limits.displayName} Plan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusChip(label: _statusLabel, color: _statusColor),
                        if (plan != AppPlan.free) ...[
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: cycleName,
                            color: Colors.white.withValues(alpha: 0.25),
                            textColor: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (plan != AppPlan.free) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCurrency(price)}$periodLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (periodEnd != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        cancelAtPeriodEnd ? 'Ends on' : 'Next billing',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(periodEnd!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              'Upgrade to unlock more invoices, customers, WhatsApp sharing, and more.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return 'Free';
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
    return fmt.format(amount);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Status Chip ─────────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.textColor,
  });

  final String label;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Usage Card ──────────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.label,
    required this.icon,
    required this.current,
    required this.max,
    this.iconColor = kPrimary,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final int current;
  final int max; // -1 = unlimited, 0 = disabled

  @override
  Widget build(BuildContext context) {
    final isUnlimited = max == -1;
    final isDisabled = max == 0;
    final ratio = isUnlimited || isDisabled ? 0.0 : (max > 0 ? current / max : 0.0);
    final progressColor = isUnlimited
        ? kPrimary
        : ratio > 0.9
            ? Colors.red
            : ratio > 0.7
                ? Colors.amber.shade700
                : kPrimary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kOnSurface,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (isUnlimited) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: kPrimary),
                const SizedBox(width: 6),
                Text(
                  '$current used',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kOnSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Unlimited',
              style: TextStyle(
                fontSize: 12,
                color: kPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (isDisabled) ...[
            const Text(
              'Not available',
              style: TextStyle(
                fontSize: 13,
                color: kOnSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Upgrade to unlock',
              style: TextStyle(fontSize: 11, color: kOnSurfaceVariant),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: CircularProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            strokeWidth: 4,
                            backgroundColor: kSurfaceDim,
                            valueColor: AlwaysStoppedAnimation(progressColor),
                          ),
                        ),
                        Text(
                          '$current',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text(
                    '$current / $max',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kOnSurface,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Action Tile ─────────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLoading = false,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLoading;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kPrimaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(icon, color: titleColor ?? kPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor ?? kOnSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: kOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, color: kOnSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Payment Tile ────────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final Payment payment;

  Color get _statusColor => switch (payment.status) {
    'captured' => kPrimary,
    'refunded' => Colors.amber.shade700,
    _ => Colors.red,
  };

  String get _statusLabel => switch (payment.status) {
    'captured' => 'Paid',
    'refunded' => 'Refunded',
    'failed' => 'Failed',
    _ => payment.status,
  };

  @override
  Widget build(BuildContext context) {
    final amountInRupees = payment.amount / 100;
    final baseInRupees = payment.baseAmount / 100;
    final gstInRupees = payment.gstAmount / 100;
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              payment.status == 'captured'
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: _statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmt.format(amountInRupees),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kOnSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Base ${fmt.format(baseInRupees)} + GST ${fmt.format(gstInRupees)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: kOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('dd MMM yy').format(payment.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (payment.method != null) ...[
                    Text(
                      payment.method!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
