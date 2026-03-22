import 'dart:async';

import 'package:billeasy/modals/member.dart';
import 'package:billeasy/modals/subscription_plan.dart';
import 'package:billeasy/screens/member_detail_screen.dart';
import 'package:billeasy/screens/member_form_screen.dart';
import 'package:billeasy/screens/members_screen.dart';
import 'package:billeasy/screens/plan_builder_screen.dart';
import 'package:billeasy/screens/qr_attendance_screen.dart';
import 'package:billeasy/services/membership_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final MembershipService _service = MembershipService();
  final NumberFormat _currencyFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);

  StreamSubscription<List<SubscriptionPlan>>? _plansSub;
  StreamSubscription<List<Member>>? _membersSub;

  List<SubscriptionPlan> _plans = [];
  List<Member> _members = [];
  List<AttendanceLog> _todayAttendance = [];
  bool _isLoadingAttendance = true;

  // Computed stats
  int _totalMembers = 0;
  int _activeCount = 0;
  int _expiringSoonCount = 0;
  int _expiredCount = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _plansSub = _service.watchPlans().listen(
      (plans) {
        if (mounted) setState(() => _plans = plans);
      },
      onError: (_) {},
    );
    _membersSub = _service.watchMembers().listen(
      (members) {
        if (mounted) {
          setState(() {
            _members = members;
            _recomputeStats();
          });
        }
      },
      onError: (_) {},
    );
    _loadTodayAttendance();
  }

  void _recomputeStats() {
    final now = DateTime.now();
    int active = 0;
    int expiringSoon = 0;
    int expired = 0;
    double revenue = 0;

    for (final m in _members) {
      revenue += m.amountPaid + m.joiningFeePaid;
      if (m.status == MemberStatus.frozen) {
        // Frozen members count towards total but not active/expired
      } else if (m.endDate.isBefore(now)) {
        expired++;
      } else {
        active++;
        if (m.endDate.difference(now).inDays <= 7) {
          expiringSoon++;
        }
      }
    }

    _totalMembers = _members.length;
    _activeCount = active;
    _expiringSoonCount = expiringSoon;
    _expiredCount = expired;
    _totalRevenue = revenue;
  }

  Future<void> _loadTodayAttendance() async {
    try {
      final logs = await _service.getTodayAttendance();
      if (mounted) {
        setState(() {
          _todayAttendance = logs;
          _isLoadingAttendance = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAttendance = false);
    }
  }

  @override
  void dispose() {
    _plansSub?.cancel();
    _membersSub?.cancel();
    super.dispose();
  }

  List<Member> get _expiringMembers {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    return _members
        .where((m) =>
            m.status == MemberStatus.active &&
            m.endDate.isAfter(now) &&
            m.endDate.isBefore(weekFromNow))
        .toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: kBuildGradientAppBar(
        titleText: 'Subscriptions',
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Check-in',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrAttendanceScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: _loadTodayAttendance,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildRevenueCard(),
            const SizedBox(height: 24),
            _buildQuickActionsGrid(),
            const SizedBox(height: 28),
            _buildPlansSection(),
            const SizedBox(height: 28),
            _buildExpiringSoonSection(),
            const SizedBox(height: 28),
            _buildRecentCheckInsSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: _buildGradientFAB(),
    );
  }

  // ── Stats Row ───────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return SizedBox(
      height: 116,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _StatCard(
            icon: Icons.people_rounded,
            iconColor: kPrimary,
            iconBg: kPrimaryContainer,
            value: _totalMembers.toString(),
            label: 'Total Members',
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.check_circle_rounded,
            iconColor: kPaid,
            iconBg: kPaidBg,
            value: _activeCount.toString(),
            label: 'Active',
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.warning_rounded,
            iconColor: kPending,
            iconBg: kPendingBg,
            value: _expiringSoonCount.toString(),
            label: 'Expiring Soon',
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.cancel_rounded,
            iconColor: kOverdue,
            iconBg: kOverdueBg,
            value: _expiredCount.toString(),
            label: 'Expired',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Revenue Card ────────────────────────────────────────────────────────────

  Widget _buildRevenueCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0057FF), Color(0xFF004CE1)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Revenue',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currencyFmt.format(_totalRevenue),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'from $_totalMembers members',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white.withOpacity(0.9),
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions ───────────────────────────────────────────────────────────

  Widget _buildQuickActionsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK ACTIONS',
            style: TextStyle(
              color: kOnSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.person_add_rounded,
                  label: 'Add Member',
                  iconColor: kPrimary,
                  iconBg: kPrimaryContainer,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MemberFormScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.add_card_rounded,
                  label: 'Create Plan',
                  iconColor: kPaid,
                  iconBg: kPaidBg,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlanBuilderScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.groups_rounded,
                  label: 'View Members',
                  iconColor: const Color(0xFF7C3AED),
                  iconBg: const Color(0xFFEDE9FE),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MembersScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Check-in',
                  iconColor: const Color(0xFFEA580C),
                  iconBg: const Color(0xFFFFF7ED),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrAttendanceScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Plans Section ───────────────────────────────────────────────────────────

  Widget _buildPlansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'YOUR PLANS',
                  style: TextStyle(
                    color: kOnSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (_plans.isNotEmpty)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlanBuilderScreen()),
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(
                      color: kPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_plans.isEmpty)
          _buildEmptyPlans()
        else
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _plans.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                return _PlanCard(
                  plan: plan,
                  currencyFmt: _currencyFmt,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanBuilderScreen(plan: plan),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyPlans() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlanBuilderScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: kSurfaceLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kPrimary.withOpacity(0.15),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kPrimaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add_card_rounded, color: kPrimary, size: 24),
              ),
              const SizedBox(height: 12),
              const Text(
                'Create your first plan',
                style: TextStyle(
                  color: kOnSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set up membership plans for your business',
                style: TextStyle(
                  color: kOnSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Expiring Soon Section ───────────────────────────────────────────────────

  Widget _buildExpiringSoonSection() {
    final expiring = _expiringMembers;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXPIRING THIS WEEK',
            style: TextStyle(
              color: kOnSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (expiring.isEmpty)
            _buildExpiringSoonEmpty()
          else
            ...expiring.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ExpiringMemberCard(
                    member: m,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemberDetailScreen(member: m),
                      ),
                    ),
                    onRenew: () => _showRenewDialog(m),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildExpiringSoonEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: kPaidBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kPaidBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_rounded, color: kPaid, size: 24),
          ),
          const SizedBox(height: 10),
          const Text(
            'All members are in good standing',
            style: TextStyle(
              color: kOnSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenewDialog(Member member) async {
    final plan = _plans.where((p) => p.id == member.planId).firstOrNull;
    if (plan == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Renew Membership', style: TextStyle(color: kOnSurface)),
        content: Text(
          'Renew ${member.name}\'s ${plan.name} plan for ${plan.durationLabel}?\n\n'
          'Amount: ${_currencyFmt.format(plan.effectivePrice)}',
          style: const TextStyle(color: kOnSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kOnSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kPrimary),
            child: const Text('Renew'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newEnd = DateTime.now().add(Duration(days: plan.durationDays));
      await _service.renewMember(member.id, newEnd, plan.effectivePrice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name} renewed successfully'),
            backgroundColor: kPaid,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ── Recent Check-ins ────────────────────────────────────────────────────────

  Widget _buildRecentCheckInsSection() {
    final timeFmt = DateFormat('h:mm a');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TODAY\'S CHECK-INS',
            style: TextStyle(
              color: kOnSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingAttendance)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: kPrimary),
                ),
              ),
            )
          else if (_todayAttendance.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_available_rounded,
                      color: kTextTertiary.withOpacity(0.6), size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'No check-ins today',
                    style: TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: kSurfaceLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [kWhisperShadow],
              ),
              child: Column(
                children: List.generate(_todayAttendance.length, (i) {
                  final log = _todayAttendance[i];
                  final isLast = i == _todayAttendance.length - 1;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: kPrimaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.login_rounded,
                                color: kPrimary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.memberName.isNotEmpty
                                        ? log.memberName
                                        : 'Member',
                                    style: const TextStyle(
                                      color: kOnSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _methodLabel(log.method),
                                    style: const TextStyle(
                                      color: kOnSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              timeFmt.format(log.checkInTime),
                              style: const TextStyle(
                                color: kOnSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 64,
                          color: kSurfaceContainerLow.withOpacity(0.8),
                        ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'qr':
        return 'QR Code Scan';
      case 'code':
        return 'Member Code';
      case 'manual':
        return 'Manual Check-in';
      default:
        return method;
    }
  }

  // ── Gradient FAB ────────────────────────────────────────────────────────────

  Widget _buildGradientFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: kSignatureGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: 'subscriptions-fab',
        onPressed: _showFABSheet,
        backgroundColor: Colors.transparent,
        elevation: 0,
        hoverElevation: 0,
        focusElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  void _showFABSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: kSurfaceContainer,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _SheetOption(
              icon: Icons.person_add_rounded,
              iconColor: kPrimary,
              iconBg: kPrimaryContainer,
              label: 'Add Member',
              subtitle: 'Register a new member',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MemberFormScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            _SheetOption(
              icon: Icons.add_card_rounded,
              iconColor: kPaid,
              iconBg: kPaidBg,
              label: 'Create Plan',
              subtitle: 'Design a subscription plan',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanBuilderScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [kWhisperShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: kOnSurface,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: kOnSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [kSubtleShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: kOnSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.currencyFmt,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final NumberFormat currencyFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = _parseHexColor(plan.colorHex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cardColor, cardColor.withOpacity(0.75)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: plan.isActive ? const Color(0xFF4ADE80) : Colors.white38,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    plan.durationLabel,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    plan.planType == PlanType.package ? '📦' : '🔄',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              currencyFmt.format(plan.effectivePrice),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            if (plan.discountPercent > 0)
              Text(
                '${plan.discountPercent.toStringAsFixed(0)}% off \u2022 MRP ${currencyFmt.format(plan.price)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.people_outline_rounded,
                    color: Colors.white.withOpacity(0.7), size: 14),
                const SizedBox(width: 4),
                Text(
                  '${plan.memberCount} member${plan.memberCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _parseHexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return const Color(0xFF1E3A8A);
  }
}

class _ExpiringMemberCard extends StatelessWidget {
  const _ExpiringMemberCard({
    required this.member,
    required this.onTap,
    required this.onRenew,
  });

  final Member member;
  final VoidCallback onTap;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final daysLeft = member.daysLeft;
    final isUrgent = daysLeft <= 2;
    final statusColor = isUrgent ? kOverdue : kPending;
    final statusBg = isUrgent ? kOverdueBg : kPendingBg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [kSubtleShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kPrimaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  member.initials,
                  style: const TextStyle(
                    color: kPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      color: kOnSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.planName.isNotEmpty ? member.planName : 'No plan',
                    style: const TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                daysLeft <= 0 ? 'Today' : '${daysLeft}d left',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRenew,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kPrimaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.refresh_rounded, color: kPrimary, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: kOnSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kTextTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
