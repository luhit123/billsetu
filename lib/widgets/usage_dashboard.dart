import 'package:flutter/material.dart';

import '../services/plan_service.dart';
import '../services/usage_tracking_service.dart';
import '../screens/subscription_screen.dart';
import '../screens/upgrade_screen.dart';

// ─── Brand colours ───────────────────────────────────────────────────────────
const _kNavy = Color(0xFF1E3A8A);
const _kPrimary = Color(0xFF4361EE);
const _kTeal = Color(0xFF6366F1);

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
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final plan = PlanService.instance.currentPlan;
    final limits = PlanService.instance.currentLimits;
    final isFree = plan == AppPlan.free;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            width: 1.5,
            color: Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: GradientBorder(
            gradient: const LinearGradient(
              colors: [_kNavy, _kTeal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // ── Header row: plan badge + action button ───────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kNavy, _kTeal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFree
                            ? Icons.star_border_rounded
                            : plan == AppPlan.raja
                                ? Icons.star_rounded
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
            color: const Color(0xFFEAF8FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: _kPrimary),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kPrimary,
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
    if (ratio > 0.9) return Colors.red;
    if (ratio > 0.7) return Colors.amber.shade700;
    return _kTeal;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withValues(alpha: 0.2)),
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

// ═════════════════════════════════════════════════════════════════════════════
// ─── Gradient Border Decoration ──────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class GradientBorder extends BoxBorder {
  const GradientBorder({
    required this.gradient,
    required this.width,
  });

  final Gradient gradient;
  final double width;

  @override
  BorderSide get top => BorderSide.none;
  @override
  BorderSide get bottom => BorderSide.none;
  @override
  bool get isUniform => true;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    final rRect = borderRadius != null
        ? borderRadius.toRRect(rect).deflate(width / 2)
        : RRect.fromRectAndRadius(
            rect.deflate(width / 2),
            Radius.circular(22 - width / 2),
          );
    canvas.drawRRect(rRect, paint);
  }

  @override
  ShapeBorder scale(double t) => GradientBorder(
        gradient: gradient,
        width: width * t,
      );
}
