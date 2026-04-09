import 'dart:async';

import 'package:billeasy/modals/member.dart';
import 'package:billeasy/modals/team_member.dart';
import 'package:billeasy/modals/team_role.dart';
import 'package:billeasy/screens/member_performance_detail_screen.dart';
import 'package:billeasy/services/membership_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _ViewPeriod { today, thisWeek, thisMonth, custom }

/// Owner/Manager dashboard showing all team members' attendance.
class AttendanceDashboardScreen extends StatefulWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  State<AttendanceDashboardScreen> createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends State<AttendanceDashboardScreen> {
  final _svc = MembershipService();
  _ViewPeriod _period = _ViewPeriod.today;
  DateTimeRange? _customRange;
  bool _loading = true;
  List<TeamMember> _members = [];
  int _loadRequestId = 0;
  Timer? _refreshTimer;

  // memberId → list of all logs in the selected range
  Map<String, List<AttendanceLog>> _logsByMember = {};

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh every 30 seconds so checkout times appear promptly.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  DateTimeRange _getRange() {
    final now = DateTime.now();
    switch (_period) {
      case _ViewPeriod.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );
      case _ViewPeriod.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(weekStart.year, weekStart.month, weekStart.day),
          end: now,
        );
      case _ViewPeriod.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case _ViewPeriod.custom:
        return _customRange ?? DateTimeRange(start: now, end: now);
    }
  }

  int get _totalDaysInRange {
    final range = _getRange();
    return range.end.difference(range.start).inDays + 1;
  }

  Future<void> _load() async {
    final requestId = ++_loadRequestId;
    setState(() => _loading = true);

    try {
      final members = await TeamService.instance.watchMembers().first;
      final ownerId = TeamService.instance.getEffectiveOwnerId();
      final range = _getRange();
      final teamMembers = members
          .where((member) => member.uid != ownerId)
          .toList();
      final endExclusive = range.end.add(const Duration(days: 1));
      final logsByMemberEntries = await Future.wait(
        teamMembers.map((member) async {
          final allLogs = await _svc.getTeamAttendance(member.uid, limit: 500);
          final filtered = allLogs
              .where(
                (log) =>
                    !log.checkInTime.isBefore(range.start) &&
                    log.checkInTime.isBefore(endExclusive),
              )
              .toList();
          return MapEntry(member.uid, filtered);
        }),
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _members = members;
        _logsByMember = {
          for (final entry in logsByMemberEntries) entry.key: entry.value,
        };
      });
    } catch (e) {
      debugPrint('[AttendanceDashboard] Load failed: $e');
    }
    if (!mounted || requestId != _loadRequestId) return;
    setState(() => _loading = false);
  }

  void _onPeriodChanged(_ViewPeriod period) {
    if (period == _ViewPeriod.custom) {
      _pickCustomRange();
      return;
    }
    setState(() => _period = period);
    _load();
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
        _period = _ViewPeriod.custom;
      });
      _load();
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _ViewPeriod.today:
        return 'Today';
      case _ViewPeriod.thisWeek:
        return 'This Week';
      case _ViewPeriod.thisMonth:
        return DateFormat('MMMM yyyy').format(DateTime.now());
      case _ViewPeriod.custom:
        if (_customRange != null) {
          final fmt = DateFormat('dd MMM');
          return '${fmt.format(_customRange!.start)} – ${fmt.format(_customRange!.end)}';
        }
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = TeamService.instance.getEffectiveOwnerId();
    final teamMembers = _members.where((m) => m.uid != ownerId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            tooltip: 'Custom range',
            onPressed: _pickCustomRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // Period chips
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('Today', _ViewPeriod.today),
                _chip('This Week', _ViewPeriod.thisWeek),
                _chip('This Month', _ViewPeriod.thisMonth),
                if (_customRange != null)
                  _chip(_periodLabel(), _ViewPeriod.custom),
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
                : teamMembers.isEmpty
                ? const Center(child: Text('No team members'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        _buildSummaryCard(teamMembers),
                        const SizedBox(height: 16),
                        ...teamMembers.map(_buildMemberCard),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _ViewPeriod period) {
    final selected = _period == period;
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

  Widget _buildSummaryCard(List<TeamMember> teamMembers) {
    final isToday = _period == _ViewPeriod.today;

    // For multi-day: count unique days present per member, then average
    int totalPresent = 0;
    int totalAbsent = 0;
    double totalHours = 0;

    if (isToday) {
      totalPresent = teamMembers
          .where((m) => (_logsByMember[m.uid] ?? []).isNotEmpty)
          .length;
      totalAbsent = teamMembers.length - totalPresent;
      totalHours = teamMembers.fold(0.0, (sum, m) {
        final logs = _logsByMember[m.uid] ?? [];
        return sum + logs.fold(0.0, (s, l) => s + (l.totalHours ?? 0));
      });
    } else {
      // Multi-day summary
      for (final m in teamMembers) {
        final logs = _logsByMember[m.uid] ?? [];
        if (logs.isNotEmpty) totalPresent++;
        totalHours += logs.fold(0.0, (s, l) => s + (l.totalHours ?? 0));
      }
      totalAbsent = teamMembers.length - totalPresent;
    }

    final active = isToday
        ? teamMembers.where((m) {
            final logs = _logsByMember[m.uid] ?? [];
            return logs.any((l) => l.isCheckedIn);
          }).length
        : 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _summaryChip('Total', '${teamMembers.length}', kPrimary),
                const SizedBox(width: 10),
                _summaryChip('Present', '$totalPresent', kPaid),
                const SizedBox(width: 10),
                _summaryChip('Absent', '$totalAbsent', kOverdue),
                const SizedBox(width: 10),
                _summaryChip(
                  'Hours',
                  totalHours.toStringAsFixed(1),
                  Colors.blue,
                ),
              ],
            ),
            if (isToday && active > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: kPaid.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$active currently at office',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kPaid,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
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

  Widget _buildMemberCard(TeamMember member) {
    final logs = _logsByMember[member.uid] ?? [];
    final isPresent = logs.isNotEmpty;
    final isActive = logs.any((l) => l.isCheckedIn);
    final totalHours = logs.fold<double>(
      0,
      (sum, l) => sum + (l.totalHours ?? 0),
    );

    // Days present (unique dates)
    final uniqueDays = <String>{};
    for (final l in logs) {
      uniqueDays.add(DateFormat('yyyy-MM-dd').format(l.checkInTime));
    }
    final daysPresent = uniqueDays.length;
    final isMultiDay = _period != _ViewPeriod.today;

    // Attendance rate for multi-day
    final attendanceRate = isMultiDay && _totalDaysInRange > 0
        ? (daysPresent / _totalDaysInRange * 100)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: isPresent
              ? (isActive ? kPaid.withAlpha(30) : Colors.orange.withAlpha(30))
              : kOverdue.withAlpha(20),
          child: Text(
            _initials(
              member.displayName.isNotEmpty ? member.displayName : member.phone,
            ),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isPresent ? (isActive ? kPaid : Colors.orange) : kOverdue,
            ),
          ),
        ),
        title: Text(
          member.displayName.isNotEmpty ? member.displayName : member.phone,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    (isActive
                            ? kPaid
                            : isPresent
                            ? Colors.orange
                            : kOverdue)
                        .withAlpha(15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _period == _ViewPeriod.today
                    ? (isActive
                          ? 'At Office'
                          : isPresent
                          ? 'Checked Out'
                          : 'Absent')
                    : isPresent
                    ? '$daysPresent days'
                    : 'No attendance',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? kPaid
                      : isPresent
                      ? Colors.orange
                      : kOverdue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (totalHours > 0)
              Text(
                '${totalHours.toStringAsFixed(1)}h',
                style: TextStyle(
                  fontSize: 11,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            if (attendanceRate != null) ...[
              const SizedBox(width: 6),
              Text(
                '· ${attendanceRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: attendanceRate >= 80
                      ? kPaid
                      : (attendanceRate >= 50 ? Colors.orange : kOverdue),
                ),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _roleColor(member.role).withAlpha(15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            member.role.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _roleColor(member.role),
            ),
          ),
        ),
        children: [
          // View full details button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberPerformanceDetailScreen(member: member),
                ),
              ),
              icon: const Icon(Icons.analytics_outlined, size: 16),
              label: const Text(
                'View Full Report',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No check-ins in this period',
                style: TextStyle(
                  fontSize: 13,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ),

          // Group logs by date for multi-day view
          if (logs.isNotEmpty && isMultiDay) ...[
            for (final date in _groupedDates(logs)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  DateFormat('EEE, dd MMM').format(date),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ),
              ..._logsForDate(logs, date).map((log) => _buildLogTile(log)),
            ],
          ],

          // Today view: flat list
          if (logs.isNotEmpty && !isMultiDay)
            ...logs.map((log) => _buildLogTile(log)),
        ],
      ),
    );
  }

  List<DateTime> _groupedDates(List<AttendanceLog> logs) {
    final dates = <String, DateTime>{};
    for (final l in logs) {
      final key = DateFormat('yyyy-MM-dd').format(l.checkInTime);
      dates.putIfAbsent(
        key,
        () => DateTime(
          l.checkInTime.year,
          l.checkInTime.month,
          l.checkInTime.day,
        ),
      );
    }
    final sorted = dates.values.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  List<AttendanceLog> _logsForDate(List<AttendanceLog> logs, DateTime date) {
    return logs
        .where(
          (l) =>
              l.checkInTime.year == date.year &&
              l.checkInTime.month == date.month &&
              l.checkInTime.day == date.day,
        )
        .toList();
  }

  Widget _buildLogTile(AttendanceLog log) {
    final inTime = DateFormat.jm().format(log.checkInTime);
    final outTime = log.checkOutTime != null
        ? DateFormat.jm().format(log.checkOutTime!)
        : null;
    final hours = log.totalHours;

    return ListTile(
      dense: true,
      leading: Icon(
        log.isCheckedIn ? Icons.login_rounded : Icons.schedule_rounded,
        size: 18,
        color: log.isCheckedIn ? kPaid : Colors.orange,
      ),
      title: Row(
        children: [
          Text(
            inTime,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            ' — ',
            style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant),
          ),
          Text(
            outTime ?? 'At office',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: outTime != null ? context.cs.onSurface : kPaid,
            ),
          ),
        ],
      ),
      trailing: hours != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kPrimary.withAlpha(15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${hours.toStringAsFixed(1)}h',
                style: TextStyle(
                  fontSize: 12,
                  color: kPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kPaid.withAlpha(15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Active',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kPaid,
                ),
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
