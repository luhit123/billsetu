import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/team_member.dart';
import 'package:billeasy/modals/team_role.dart';
import 'package:billeasy/screens/member_performance_detail_screen.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _FilterPeriod { thisMonth, last3Months, thisYear, allTime, custom }

/// Shows per-member invoice performance for the team owner.
class TeamPerformanceScreen extends StatefulWidget {
  const TeamPerformanceScreen({super.key});

  @override
  State<TeamPerformanceScreen> createState() => _TeamPerformanceScreenState();
}

class _TeamPerformanceScreenState extends State<TeamPerformanceScreen> {
  bool _loading = true;
  List<_MemberStats> _stats = [];
  List<Invoice> _allInvoices = [];
  List<TeamMember> _members = [];

  _FilterPeriod _selectedPeriod = _FilterPeriod.thisMonth;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final ownerId = TeamService.instance.getEffectiveOwnerId();
      final range = _getDateRange(DateTime.now());
      final endBefore = range == null
          ? null
          : DateTime(
              range.end.year,
              range.end.month,
              range.end.day,
            ).add(const Duration(days: 1));
      final membersFuture = TeamService.instance.watchMembers().first;
      final invoicesFuture = FirebaseService().getInvoicesForOwner(
        ownerId: ownerId,
        startAt: range?.start,
        endBefore: endBefore,
      );

      final results = await Future.wait([membersFuture, invoicesFuture]);
      _members = results[0] as List<TeamMember>;
      _allInvoices = results[1] as List<Invoice>;

      _computeStats();
    } catch (e) {
      debugPrint('[TeamPerformance] Load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _computeStats() {
    final ownerId = TeamService.instance.getEffectiveOwnerId();

    // Group by creator
    final byCreator = <String, List<Invoice>>{};
    for (final inv in _allInvoices) {
      final uid = inv.createdByUid.isNotEmpty ? inv.createdByUid : inv.ownerId;
      byCreator.putIfAbsent(uid, () => []).add(inv);
    }

    final statsList = <_MemberStats>[];

    // Owner stats
    final ownerInvoices = byCreator[ownerId] ?? [];
    statsList.add(
      _buildStats(ownerId, 'You (Owner)', TeamRole.owner, ownerInvoices),
    );

    // Member stats
    for (final member in _members) {
      if (member.uid == ownerId) continue;
      final memberInvoices = byCreator[member.uid] ?? [];
      statsList.add(
        _buildStats(
          member.uid,
          member.displayName.isNotEmpty ? member.displayName : member.phone,
          member.role,
          memberInvoices,
          teamMember: member,
        ),
      );
    }

    statsList.sort((a, b) => b.totalInvoices.compareTo(a.totalInvoices));
    if (mounted) {
      setState(() {
        _stats = statsList;
        _loading = false;
      });
    }
  }

  _MemberStats _buildStats(
    String uid,
    String name,
    TeamRole role,
    List<Invoice> invoices, {
    TeamMember? teamMember,
  }) {
    return _MemberStats(
      uid: uid,
      name: name,
      role: role,
      teamMember: teamMember,
      totalInvoices: invoices.length,
      totalBilled: invoices.fold(0, (s, i) => s + i.grandTotal),
      totalCollected: invoices
          .where((i) => i.effectiveStatus == InvoiceStatus.paid)
          .fold(0, (s, i) => s + i.grandTotal),
      totalPending: invoices
          .where((i) => i.effectiveStatus != InvoiceStatus.paid)
          .fold(0, (s, i) => s + i.balanceDue),
    );
  }

  DateTimeRange? _getDateRange(DateTime now) {
    switch (_selectedPeriod) {
      case _FilterPeriod.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case _FilterPeriod.last3Months:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: now,
        );
      case _FilterPeriod.thisYear:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case _FilterPeriod.allTime:
        return null;
      case _FilterPeriod.custom:
        return _customRange;
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange:
          _customRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedPeriod = _FilterPeriod.custom;
      });
      _loadData();
    }
  }

  void _onPeriodChanged(_FilterPeriod period) {
    if (period == _FilterPeriod.custom) {
      _pickCustomRange();
      return;
    }
    setState(() => _selectedPeriod = period);
    _loadData();
  }

  String _periodLabel() {
    switch (_selectedPeriod) {
      case _FilterPeriod.thisMonth:
        return DateFormat('MMMM yyyy').format(DateTime.now());
      case _FilterPeriod.last3Months:
        return 'Last 3 Months';
      case _FilterPeriod.thisYear:
        return 'Year ${DateTime.now().year}';
      case _FilterPeriod.allTime:
        return 'All Time';
      case _FilterPeriod.custom:
        if (_customRange != null) {
          final fmt = DateFormat('dd MMM');
          return '${fmt.format(_customRange!.start)} - ${fmt.format(_customRange!.end)}';
        }
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Custom date range',
            onPressed: _pickCustomRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filterChip('This Month', _FilterPeriod.thisMonth),
                _filterChip('3 Months', _FilterPeriod.last3Months),
                _filterChip('This Year', _FilterPeriod.thisYear),
                _filterChip('All Time', _FilterPeriod.allTime),
                if (_customRange != null)
                  _filterChip(_periodLabel(), _FilterPeriod.custom),
              ],
            ),
          ),

          // Period label
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _periodLabel(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _stats.isEmpty
                ? const Center(child: Text('No data yet'))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _stats.length,
                      itemBuilder: (context, index) =>
                          _buildMemberCard(_stats[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _FilterPeriod period) {
    final selected = _selectedPeriod == period;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => _onPeriodChanged(period),
        selectedColor: kPrimary.withAlpha(30),
        labelStyle: TextStyle(
          color: selected ? kPrimary : context.cs.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildMemberCard(_MemberStats stats) {
    final collectionRate = stats.totalBilled > 0
        ? (stats.totalCollected / stats.totalBilled * 100)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: stats.teamMember != null
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MemberPerformanceDetailScreen(member: stats.teamMember!),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: avatar + name + role
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _roleColor(stats.role).withAlpha(30),
                    child: Text(
                      _initials(stats.name),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _roleColor(stats.role),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stats.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _roleColor(stats.role).withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            stats.role.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _roleColor(stats.role),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimary.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${stats.totalInvoices}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: kPrimary,
                          ),
                        ),
                        Text(
                          'Bills',
                          style: TextStyle(
                            fontSize: 10,
                            color: kPrimary.withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Collection rate bar
              if (stats.totalBilled > 0) ...[
                Row(
                  children: [
                    Text(
                      'Collection Rate',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${collectionRate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: collectionRate >= 80
                            ? kPaid
                            : (collectionRate >= 50 ? Colors.orange : kOverdue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (collectionRate / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: context.cs.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation(
                      collectionRate >= 80
                          ? kPaid
                          : (collectionRate >= 50 ? Colors.orange : kOverdue),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Stats grid
              Row(
                children: [
                  _statChip(
                    'Billed',
                    kCurrencyFormat.format(stats.totalBilled),
                    kPrimary,
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    'Collected',
                    kCurrencyFormat.format(stats.totalCollected),
                    kPaid,
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    'Pending',
                    kCurrencyFormat.format(stats.totalPending),
                    kOverdue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withAlpha(180)),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  Color _roleColor(TeamRole role) {
    switch (role) {
      case TeamRole.owner:
      case TeamRole.coOwner:
        return kPrimary;
      case TeamRole.manager:
        return Colors.blue;
      case TeamRole.sales:
        return Colors.orange;
      case TeamRole.viewer:
        return kTextSecondary;
    }
  }
}

class _MemberStats {
  final String uid;
  final String name;
  final TeamRole role;
  final TeamMember? teamMember;
  final int totalInvoices;
  final double totalBilled;
  final double totalCollected;
  final double totalPending;

  const _MemberStats({
    required this.uid,
    required this.name,
    required this.role,
    this.teamMember,
    required this.totalInvoices,
    required this.totalBilled,
    required this.totalCollected,
    required this.totalPending,
  });
}
