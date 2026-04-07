import 'package:flutter/material.dart';
import 'package:billeasy/theme/app_colors.dart';

import '../services/plan_service.dart';
import '../services/usage_tracking_service.dart';
import '../screens/subscription_screen.dart';
import '../screens/upgrade_screen.dart';

/// Compact subscription usage card for embedding in the home screen.
///
/// Shows the current plan name, 2-3 key usage metrics inline, and a
/// contextual action button (Upgrade on free, Manage on paid).
class UsageDashboard extends StatefulWidget {
  const UsageDashboard({super.key});

  @override
  State<UsageDashboard> createState() => _UsageDashboardState();
}

class _UsageDashboardState extends State<UsageDashboard> {
  Map<String, int>? _usage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    try {
      final usage = await UsageTrackingService.instance.getUsageSummary();
      if (mounted) setState(() => _usage = usage);
    } catch (e) {
      debugPrint('[UsageDashboard] Failed to load usage: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final limits = PlanService.instance.currentLimits;
    final isFree = !PlanService.instance.isFullAccess;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [kWhisperShadow],
        ),
        child: Column(
          children: [
            // ── Header row: plan badge + action button ───────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: kSignatureGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFree
                            ? Icons.star_border_rounded
                            : Icons.diamond_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${limits.displayName} Plan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _CompactButton(
                  label: isFree ? 'Upgrade' : 'Manage',
                  icon: isFree ? Icons.rocket_launch_rounded : Icons.settings_rounded,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => isFree
                            ? const UpgradeScreen()
                            : const SubscriptionScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Usage metrics row ────────────────────────────
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              _buildMetricsRow(limits),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(PlanLimits limits) {
    final usage = _usage ?? {};
    final invoices = usage['invoices'] ?? 0;
    final customers = usage['customers'] ?? 0;
    final products = usage['products'] ?? 0;

    return Row(
      children: [
        _MetricPill(
          icon: Icons.receipt_long_rounded,
          label: _formatUsage(invoices, limits.maxInvoicesPerMonth, 'invoices'),
          ratio: _ratio(invoices, limits.maxInvoicesPerMonth),
        ),
        const SizedBox(width: 8),
        _MetricPill(
          icon: Icons.people_rounded,
          label: _formatUsage(customers, limits.maxCustomers, 'customers'),
          ratio: _ratio(customers, limits.maxCustomers),
        ),
        const SizedBox(width: 8),
        _MetricPill(
          icon: Icons.inventory_2_rounded,
          label: _formatUsage(products, limits.maxProducts, 'products'),
          ratio: _ratio(products, limits.maxProducts),
        ),
      ],
    );
  }

  String _formatUsage(int current, int max, String noun) {
    if (max == -1) return '$current $noun';
    if (max == 0) return '0 $noun';
    return '$current/$max $noun';
  }

  double _ratio(int current, int max) {
    if (max <= 0) return 0.0;
    return (current / max).clamp(0.0, 1.0);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Compact Button ──────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: context.cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: kPrimary),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ─── Metric Pill ─────────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.ratio,
  });

  final IconData icon;
  final String label;
  final double ratio;

  Color get _color {
    if (ratio > 0.9) return kOverdue;
    if (ratio > 0.7) return kPending;
    return kPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
