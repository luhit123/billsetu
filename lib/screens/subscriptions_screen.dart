import 'dart:async';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/member.dart';
import 'package:billeasy/modals/subscription_plan.dart';
import 'package:billeasy/screens/member_detail_screen.dart';
import 'package:billeasy/screens/member_form_screen.dart';
import 'package:billeasy/screens/members_screen.dart';
import 'package:billeasy/screens/plan_builder_screen.dart';
import 'package:billeasy/screens/qr_attendance_screen.dart';
import 'package:billeasy/services/membership_service.dart';
import 'package:billeasy/services/remote_config_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/responsive.dart';
import 'package:billeasy/widgets/aurora_app_backdrop.dart';
import 'package:billeasy/widgets/permission_denied_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final MembershipService _service = MembershipService();
  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );

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

  // Date range filter for revenue
  late DateTimeRange _filterRange;
  double _rangeRevenue = 0;
  int _rangeMemberCount = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0), // last day of current month
    );
    _plansSub = _service.watchPlans().listen((plans) {
      if (mounted) setState(() => _plans = plans);
    }, onError: (_) {});
    _membersSub = _service.watchMembers().listen((members) {
      if (mounted) {
        setState(() {
          _members = members;
          _recomputeStats();
        });
      }
    }, onError: (_) {});
    _loadTodayAttendance();
  }

  void _recomputeStats() {
    final now = DateTime.now();
    int active = 0;
    int expiringSoon = 0;
    int expired = 0;
    double revenue = 0;
    double rangeRevenue = 0;
    int rangeCount = 0;

    // Include end day fully by checking before start of next day
    final rangeEnd = DateTime(
      _filterRange.end.year,
      _filterRange.end.month,
      _filterRange.end.day + 1,
    );

    for (final m in _members) {
      revenue += m.amountPaid + m.joiningFeePaid;
      if (!m.startDate.isBefore(_filterRange.start) &&
          m.startDate.isBefore(rangeEnd)) {
        rangeRevenue += m.amountPaid + m.joiningFeePaid;
        rangeCount++;
      }
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
    _rangeRevenue = rangeRevenue;
    _rangeMemberCount = rangeCount;
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
        .where(
          (m) =>
              m.status == MemberStatus.active &&
              m.endDate.isAfter(now) &&
              m.endDate.isBefore(weekFromNow),
        )
        .toList()
      ..sort((a, b) => a.endDate.compareTo(b.endDate));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final expanded = windowSizeOf(context) == WindowSize.expanded;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: kBuildGradientAppBar(
        titleText: s.subscriptionsTitle,
        actions: [
          if (RemoteConfigService.instance.featureQrAttendance)
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
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraAppBackdrop()),
          RefreshIndicator(
            color: kPrimary,
            onRefresh: _loadTodayAttendance,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      const SizedBox(height: 16),
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _buildStatsRow(),
                                    const SizedBox(height: 20),
                                    _buildQuickActionsGrid(),
                                    const SizedBox(height: 28),
                                    _buildExpiringSoonSection(),
                                    const SizedBox(height: 28),
                                    _buildRecentCheckInsSection(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildRevenueCard(),
                                    const SizedBox(height: 28),
                                    _buildPlansSection(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
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
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildGradientFAB(),
    );
  }

  void _changeMonth(int delta) {
    final s = _filterRange.start;
    final newStart = DateTime(s.year, s.month + delta, 1);
    final newEnd = DateTime(newStart.year, newStart.month + 1, 0);
    setState(() {
      _filterRange = DateTimeRange(start: newStart, end: newEnd);
      _recomputeStats();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _filterRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kPrimary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _filterRange = picked;
        _recomputeStats();
      });
    }
  }

  // ── Stats Row ───────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final cards = [
      _StatCard(
        icon: Icons.people_rounded,
        iconColor: kPrimary,
        iconBg: context.cs.primaryContainer,
        value: _totalMembers.toString(),
        label: 'Total Members',
      ),
      _StatCard(
        icon: Icons.check_circle_rounded,
        iconColor: kPaid,
        iconBg: kPaidBg,
        value: _activeCount.toString(),
        label: 'Active',
      ),
      _StatCard(
        icon: Icons.warning_rounded,
        iconColor: kPending,
        iconBg: kPendingBg,
        value: _expiringSoonCount.toString(),
        label: 'Expiring Soon',
      ),
      _StatCard(
        icon: Icons.cancel_rounded,
        iconColor: kOverdue,
        iconBg: kOverdueBg,
        value: _expiredCount.toString(),
        label: 'Expired',
      ),
    ];

    if (windowSizeOf(context) == WindowSize.expanded) {
      return GridView.count(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards,
      );
    }

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => cards[index],
      ),
    );
  }

  // ── Revenue Card ────────────────────────────────────────────────────────────

  Widget _buildRevenueCard() {
    final now = DateTime.now();
    final fmt = DateFormat('d MMM');
    final fmtFull = DateFormat('d MMM yyyy');
    final s = _filterRange.start;
    final e = _filterRange.end;
    // Single month: show "Mar 2026", else show "1 Mar – 15 Apr 2026"
    final sameMonth = s.year == e.year && s.month == e.month;
    final sameYear = s.year == e.year;
    final rangeLabel = sameMonth
        ? DateFormat('MMM yyyy').format(s)
        : sameYear
        ? '${fmt.format(s)} – ${fmtFull.format(e)}'
        : '${fmtFull.format(s)} – ${fmtFull.format(e)}';

    // Is this the current month (default range)?
    final isCurrentMonth =
        s.year == now.year &&
        s.month == now.month &&
        e.year == now.year &&
        e.month == now.month;

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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Range navigator row
            Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 22,
                  ),
                  onPressed: () => _changeMonth(-1),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDateRange,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            rangeLabel,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: isCurrentMonth
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.8),
                    size: 22,
                  ),
                  onPressed: isCurrentMonth ? null : () => _changeMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.of(context).subscriptionsRevenue,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currencyFmt.format(_rangeRevenue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$_rangeMemberCount ${AppStrings.of(context).subscriptionsMembersJoined}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppStrings.of(context).subscriptionsAllTime,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFmt.format(_totalRevenue),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_totalMembers total',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions ───────────────────────────────────────────────────────────

  Widget _buildQuickActionsGrid() {
    final cards = <Widget>[
      _QuickActionCard(
        icon: Icons.person_add_rounded,
        label: 'Add Member',
        iconColor: kPrimary,
        iconBg: context.cs.primaryContainer,
        onTap: () {
          if (!PermissionDenied.check(
            context,
            TeamService.instance.can.canManageSubscription,
            'add members',
          )) {
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MemberFormScreen()),
          );
        },
      ),
      _QuickActionCard(
        icon: Icons.add_card_rounded,
        label: 'Create Plan',
        iconColor: kPaid,
        iconBg: kPaidBg,
        onTap: () {
          if (!PermissionDenied.check(
            context,
            TeamService.instance.can.canManageSubscription,
            'create membership plans',
          )) {
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlanBuilderScreen()),
          );
        },
      ),
      _QuickActionCard(
        icon: Icons.groups_rounded,
        label: 'View Members',
        iconColor: const Color(0xFF7C3AED),
        iconBg: const Color(0xFFEDE9FE),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MembersScreen()),
        ),
      ),
    ];

    if (RemoteConfigService.instance.featureQrAttendance) {
      cards.add(
        _QuickActionCard(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Check-in',
          iconColor: const Color(0xFFEA580C),
          iconBg: const Color(0xFFFFF7ED),
          onTap: () {
            if (!PermissionDenied.check(
              context,
              TeamService.instance.can.canManageSubscription,
              'mark attendance',
            )) {
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrAttendanceScreen()),
            );
          },
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: windowSizeOf(context) == WindowSize.expanded ? 0 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK ACTIONS',
            style: TextStyle(
              color: context.cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (windowSizeOf(context) == WindowSize.expanded)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 76,
              ),
              itemBuilder: (context, index) => cards[index],
            )
          else ...[
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: cards[2]),
                if (cards.length > 3) ...[
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ],
            ),
          ],
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
              Expanded(
                child: Text(
                  'YOUR PLANS',
                  style: TextStyle(
                    color: context.cs.onSurfaceVariant,
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
                    MaterialPageRoute(
                      builder: (_) => const PlanBuilderScreen(),
                    ),
                  ),
                  child: Text(
                    AppStrings.of(context).subscriptionsCreatePlan,
                    style: const TextStyle(
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
        else if (windowSizeOf(context) == WindowSize.expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _plans.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 170,
              ),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                return _PlanCard(
                  plan: plan,
                  currencyFmt: _currencyFmt,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MembersScreen(planId: plan.id, planName: plan.name),
                    ),
                  ),
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanBuilderScreen(plan: plan),
                    ),
                  ),
                  onDelete: () => _confirmDeletePlan(plan),
                );
              },
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _plans.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                return _PlanCard(
                  plan: plan,
                  currencyFmt: _currencyFmt,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MembersScreen(planId: plan.id, planName: plan.name),
                    ),
                  ),
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanBuilderScreen(plan: plan),
                    ),
                  ),
                  onDelete: () => _confirmDeletePlan(plan),
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
            color: context.cs.surfaceContainerLowest,
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
                  color: context.cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_card_rounded,
                  color: kPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create your first plan',
                style: TextStyle(
                  color: context.cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Set up membership plans for your business',
                style: TextStyle(
                  color: context.cs.onSurfaceVariant,
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
          Text(
            'EXPIRING THIS WEEK',
            style: TextStyle(
              color: context.cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (expiring.isEmpty)
            _buildExpiringSoonEmpty()
          else
            ...expiring.map(
              (m) => Padding(
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
              ),
            ),
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
            child: const Icon(
              Icons.check_circle_rounded,
              color: kPaid,
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'All members are in good standing',
            style: TextStyle(
              color: context.cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePlan(SubscriptionPlan plan) async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          s.subscriptionsDeletePlan,
          style: TextStyle(color: context.cs.onSurface),
        ),
        content: Text(
          s.subscriptionsDeletePlanBody,
          style: TextStyle(color: context.cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kOverdue),
            child: Text(s.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    if (!PermissionDenied.check(
      context,
      TeamService.instance.can.canManageSubscription,
      'delete membership plans',
    )) {
      return;
    }
    try {
      await _service.deletePlan(plan.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${plan.name}" deleted'),
            backgroundColor: kOverdue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showRenewDialog(Member member) async {
    if (!PermissionDenied.check(
      context,
      TeamService.instance.can.canManageSubscription,
      'renew memberships',
    )) {
      return;
    }

    final plan = _plans.where((p) => p.id == member.planId).firstOrNull;
    final durationDays = plan?.durationDays ?? member.planDurationDays;
    final planName = plan?.name ?? member.planName;
    final renewalAmount =
        plan?.effectivePrice ??
        (member.planEffectivePrice > 0
            ? member.planEffectivePrice
            : member.amountPaid);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Renew Membership',
          style: TextStyle(color: context.cs.onSurface),
        ),
        content: Text(
          'Renew ${member.name}\'s $planName membership for $durationDays day${durationDays == 1 ? '' : 's'}?\n\n'
          'Amount: ${_currencyFmt.format(renewalAmount)}',
          style: TextStyle(color: context.cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.cs.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: context.cs.primary),
            child: const Text('Renew'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.renewMember(member.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name} renewed successfully'),
            backgroundColor: kPaid,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
          Text(
            'TODAY\'S CHECK-INS',
            style: TextStyle(
              color: context.cs.onSurfaceVariant,
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: kPrimary,
                  ),
                ),
              ),
            )
          else if (_todayAttendance.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    color: context.cs.onSurfaceVariant
                        .withAlpha(153)
                        .withOpacity(0.6),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No check-ins today',
                    style: TextStyle(
                      color: context.cs.onSurfaceVariant,
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
                color: context.cs.surfaceContainerLowest,
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
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: context.cs.primaryContainer,
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
                                    style: TextStyle(
                                      color: context.cs.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _methodLabel(log.method),
                                    style: TextStyle(
                                      color: context.cs.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              timeFmt.format(log.checkInTime),
                              style: TextStyle(
                                color: context.cs.onSurfaceVariant,
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
                          color: context.cs.surfaceContainerLow.withOpacity(
                            0.8,
                          ),
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
        decoration: BoxDecoration(
          color: context.cs.surfaceContainerLowest,
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
                color: context.cs.surfaceContainer,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _SheetOption(
              icon: Icons.person_add_rounded,
              iconColor: kPrimary,
              iconBg: context.cs.primaryContainer,
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
        color: context.cs.surfaceContainerLowest,
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
            style: TextStyle(
              color: context.cs.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.cs.onSurfaceVariant,
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
          color: context.cs.surfaceContainerLowest,
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
                style: TextStyle(
                  color: context.cs.onSurface,
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
    required this.onEdit,
    required this.onDelete,
  });

  final SubscriptionPlan plan;
  final NumberFormat currencyFmt;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cardColor = _parseHexColor(plan.colorHex);
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context, cardColor),
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
                    color: plan.isActive
                        ? const Color(0xFF4ADE80)
                        : Colors.white38,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
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
                Icon(
                  Icons.people_outline_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: 14,
                ),
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

  void _showContextMenu(BuildContext context, Color cardColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    plan.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: kPrimary),
              title: Text(
                AppStrings.of(context).subscriptionsModifyPlan,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Edit name, price, duration'),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: kOverdue,
              ),
              title: Text(
                AppStrings.of(context).subscriptionsDeletePlan,
                style: const TextStyle(
                  color: kOverdue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Permanently remove this plan'),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
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
          color: context.cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [kSubtleShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.cs.primaryContainer,
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
                    style: TextStyle(
                      color: context.cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.planName.isNotEmpty ? member.planName : 'No plan',
                    style: TextStyle(
                      color: context.cs.onSurfaceVariant,
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
                  color: context.cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: kPrimary,
                  size: 18,
                ),
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
          color: context.cs.surfaceContainerLow,
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
                    style: TextStyle(
                      color: context.cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.cs.onSurfaceVariant.withAlpha(153),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
