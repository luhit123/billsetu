import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/member.dart';
import 'package:billeasy/modals/team_member.dart';
import 'package:billeasy/modals/team_role.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/membership_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Detailed view of a single team member's attendance + invoice performance.
class MemberPerformanceDetailScreen extends StatefulWidget {
  const MemberPerformanceDetailScreen({super.key, required this.member});
  final TeamMember member;

  @override
  State<MemberPerformanceDetailScreen> createState() =>
      _MemberPerformanceDetailScreenState();
}

class _MemberPerformanceDetailScreenState
    extends State<MemberPerformanceDetailScreen> {
  final _svc = MembershipService();
  bool _loading = true;

  // Attendance
  List<AttendanceLog> _allLogs = [];
  int _daysPresent = 0;
  double _totalHours = 0;
  double _avgHoursPerDay = 0;
  int _onTimeDays = 0;

  // Invoices
  List<Invoice> _invoices = [];
  int _totalInvoices = 0;
  double _totalBilled = 0;
  double _totalCollected = 0;
  double _totalPending = 0;
  double _collectionRate = 0;

  // Period
  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final uid = widget.member.uid;

      // Attendance logs
      _allLogs = await _svc.watchTeamAttendance(uid, limit: 500).first;
      final rangeLogs = _allLogs
          .where(
            (l) =>
                !l.checkInTime.isBefore(_range.start) &&
                l.checkInTime.isBefore(_range.end.add(const Duration(days: 1))),
          )
          .toList();

      final dayMap = <String, List<AttendanceLog>>{};
      _totalHours = 0;
      _onTimeDays = 0;
      for (final l in rangeLogs) {
        final key = DateFormat('yyyy-MM-dd').format(l.checkInTime);
        dayMap.putIfAbsent(key, () => []).add(l);
        _totalHours += l.totalHours ?? 0;
      }
      _daysPresent = dayMap.length;
      _avgHoursPerDay = _daysPresent > 0 ? _totalHours / _daysPresent : 0;

      // Count on-time days (first check-in before 10 AM)
      for (final dayLogs in dayMap.values) {
        final firstCheckIn = dayLogs.reduce((a, b) =>
            a.checkInTime.isBefore(b.checkInTime) ? a : b);
        if (firstCheckIn.checkInTime.hour < 10) _onTimeDays++;
      }

      // Invoices by this member
      final ownerId = TeamService.instance.getEffectiveOwnerId();
      final endBefore = DateTime(
        _range.end.year,
        _range.end.month,
        _range.end.day,
      ).add(const Duration(days: 1));
      _invoices = await FirebaseService().getInvoicesForOwner(
        ownerId: ownerId,
        createdByUid: uid,
        startAt: _range.start,
        endBefore: endBefore,
      );

      _totalInvoices = _invoices.length;
      _totalBilled = _invoices.fold(0, (s, i) => s + i.grandTotal);
      _totalCollected = _invoices
          .where((i) => i.effectiveStatus == InvoiceStatus.paid)
          .fold(0, (s, i) => s + i.grandTotal);
      _totalPending = _invoices
          .where((i) => i.effectiveStatus != InvoiceStatus.paid)
          .fold(0, (s, i) => s + i.balanceDue);
      _collectionRate = _totalBilled > 0
          ? (_totalCollected / _totalBilled * 100)
          : 0;
    } catch (e) {
      debugPrint('[MemberDetail] Load failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      _range = picked;
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.member.displayName.isNotEmpty
        ? widget.member.displayName
        : widget.member.phone;
    final fmt = DateFormat('dd MMM');

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          TextButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_rounded, size: 18),
            label: Text(
              '${fmt.format(_range.start)} – ${fmt.format(_range.end)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Member header
                  _buildHeader(name),
                  const SizedBox(height: 20),

                  // Attendance metrics
                  _sectionTitle('Attendance'),
                  const SizedBox(height: 8),
                  _buildAttendanceCard(),
                  const SizedBox(height: 20),

                  // Invoice performance
                  _sectionTitle('Invoice Performance'),
                  const SizedBox(height: 8),
                  _buildInvoiceCard(),
                  const SizedBox(height: 20),

                  // Recent attendance log
                  _sectionTitle('Recent Check-ins'),
                  const SizedBox(height: 8),
                  ..._allLogs.take(15).map(_buildLogTile),
                  if (_allLogs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No attendance records',
                        style: TextStyle(color: context.cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(String name) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: _roleColor(widget.member.role).withAlpha(30),
          child: Text(
            _initials(name),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _roleColor(widget.member.role),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _roleColor(widget.member.role).withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.member.role.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _roleColor(widget.member.role),
                      ),
                    ),
                  ),
                  if (widget.member.phone.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.member.phone,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: context.cs.onSurface,
      ),
    );
  }

  Widget _buildAttendanceCard() {
    final totalDays = _range.end.difference(_range.start).inDays + 1;
    final attendanceRate = totalDays > 0
        ? (_daysPresent / totalDays * 100)
        : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Attendance rate bar
            Row(
              children: [
                Text(
                  'Attendance Rate',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${attendanceRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: attendanceRate >= 80
                        ? kPaid
                        : (attendanceRate >= 50 ? Colors.orange : kOverdue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (attendanceRate / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: context.cs.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation(
                  attendanceRate >= 80
                      ? kPaid
                      : (attendanceRate >= 50 ? Colors.orange : kOverdue),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _metricTile('Days Present', '$_daysPresent/$totalDays', kPaid),
                const SizedBox(width: 8),
                _metricTile(
                  'Total Hours',
                  _totalHours.toStringAsFixed(1),
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _metricTile(
                  'Avg/Day',
                  '${_avgHoursPerDay.toStringAsFixed(1)}h',
                  kPrimary,
                ),
                const SizedBox(width: 8),
                _metricTile(
                  'On Time',
                  '$_onTimeDays',
                  _onTimeDays > 0 ? kPaid : context.cs.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Collection rate bar
            if (_totalBilled > 0) ...[
              Row(
                children: [
                  Text(
                    'Collection Rate',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_collectionRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _collectionRate >= 80
                          ? kPaid
                          : (_collectionRate >= 50 ? Colors.orange : kOverdue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_collectionRate / 100).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: context.cs.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(
                    _collectionRate >= 80
                        ? kPaid
                        : (_collectionRate >= 50 ? Colors.orange : kOverdue),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                _metricTile('Invoices', '$_totalInvoices', kPrimary),
                const SizedBox(width: 8),
                _metricTile(
                  'Billed',
                  kCurrencyFormat.format(_totalBilled),
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _metricTile(
                  'Collected',
                  kCurrencyFormat.format(_totalCollected),
                  kPaid,
                ),
                const SizedBox(width: 8),
                _metricTile(
                  'Pending',
                  kCurrencyFormat.format(_totalPending),
                  kOverdue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
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

  Widget _buildLogTile(AttendanceLog log) {
    final date = DateFormat('dd MMM').format(log.checkInTime);
    final inTime = DateFormat.jm().format(log.checkInTime);
    final outTime = log.checkOutTime != null
        ? DateFormat.jm().format(log.checkOutTime!)
        : null;
    final hours = log.totalHours;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Icon(
              log.isCheckedIn ? Icons.login_rounded : Icons.schedule_rounded,
              size: 16,
              color: log.isCheckedIn ? kPaid : Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              '$inTime — ${outTime ?? "Active"}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: hours != null
            ? Text(
                '${hours.toStringAsFixed(1)}h',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
              )
            : Text(
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
