import 'dart:async';
import 'package:billeasy/modals/member.dart';
import 'package:billeasy/modals/team.dart';
import 'package:billeasy/services/membership_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:intl/intl.dart';

/// Member screen for geo-fenced check-in / check-out + personal attendance stats.
class GeoAttendanceScreen extends StatefulWidget {
  const GeoAttendanceScreen({super.key});

  @override
  State<GeoAttendanceScreen> createState() => _GeoAttendanceScreenState();
}

class _GeoAttendanceScreenState extends State<GeoAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final _svc = MembershipService();
  late TabController _tabController;
  Team? _team;
  Position? _position;
  double? _distance;
  bool _insideFence = false;
  bool _loading = true;
  bool _processing = false;
  AttendanceLog? _activeCheckIn;
  String? _error;

  // Today's logs
  List<AttendanceLog> _todayLogs = [];

  // My Stats
  bool _statsLoading = true;
  List<AttendanceLog> _allLogs = [];
  int _daysPresent = 0;
  double _totalHours = 0;
  double _avgHoursPerDay = 0;
  int _onTimeDays = 0;
  DateTimeRange _statsRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _statsLoading) _loadStats();
    });
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Get team with office location
      _team = TeamService.instance.cachedTeam;
      if (_team == null || !_team!.hasOfficeLocation) {
        setState(() { _error = 'Office location not set. Ask your team owner.'; _loading = false; });
        return;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() { _error = 'Please enable Location Services in your device settings.'; _loading = false; });
        return;
      }

      // Check permission
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _error = kIsWeb
              ? 'Location permission denied. Please allow location access in your browser settings and reload.'
              : 'Location permission required for attendance.';
          _loading = false;
        });
        if (!kIsWeb) {
          await Geolocator.openAppSettings();
        }
        return;
      }

      // Get current position
      _position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Calculate distance
      _distance = _svc.distanceToOffice(
        _position!.latitude, _position!.longitude, _team!,
      );
      _insideFence = _distance! <= _team!.officeRadius;

      // Check if already checked in today
      final memberId = TeamService.instance.getActualUserId();
      _activeCheckIn = await _svc.getActiveCheckIn(memberId);

      // Load today's logs
      await _loadTodayLogs();
    } catch (e) {
      _error = 'Failed to load: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTodayLogs() async {
    final memberId = TeamService.instance.getActualUserId();
    final logs = await _svc.watchTeamAttendance(memberId, limit: 10).first;
    final today = DateTime.now();
    _todayLogs = logs.where((l) =>
      l.checkInTime.year == today.year &&
      l.checkInTime.month == today.month &&
      l.checkInTime.day == today.day
    ).toList();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final memberId = TeamService.instance.getActualUserId();
      _allLogs = await _svc.watchTeamAttendance(memberId, limit: 500).first;

      final rangeLogs = _allLogs.where((l) =>
        !l.checkInTime.isBefore(_statsRange.start) &&
        l.checkInTime.isBefore(_statsRange.end.add(const Duration(days: 1)))
      ).toList();

      // Group by date to compute daily stats
      final dayMap = <String, List<AttendanceLog>>{};
      for (final l in rangeLogs) {
        final key = DateFormat('yyyy-MM-dd').format(l.checkInTime);
        dayMap.putIfAbsent(key, () => []).add(l);
      }

      _daysPresent = dayMap.length;
      _totalHours = 0;
      _onTimeDays = 0;

      for (final entry in dayMap.entries) {
        final dayLogs = entry.value;
        double dayHours = 0;
        bool onTime = true;

        for (final l in dayLogs) {
          dayHours += l.totalHours ?? 0;
          if (l.checkInTime.hour >= 10) onTime = false;
        }

        _totalHours += dayHours;
        if (onTime) _onTimeDays++;
      }

      _avgHoursPerDay = _daysPresent > 0 ? _totalHours / _daysPresent : 0;
    } catch (e) {
      debugPrint('[GeoAttendance] Stats load failed: $e');
    }
    if (mounted) setState(() => _statsLoading = false);
  }

  Future<void> _pickStatsRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _statsRange,
    );
    if (picked != null) {
      _statsRange = picked;
      _loadStats();
    }
  }

  Future<void> _checkIn() async {
    if (!_insideFence || _processing) return;
    setState(() => _processing = true);
    try {
      final memberId = TeamService.instance.getActualUserId();
      // Get member name from team member doc
      final members = await TeamService.instance.watchMembers().first;
      final me = members.where((m) => m.uid == memberId).firstOrNull;
      final name = me?.displayName ?? '';

      final logId = await _svc.geoCheckIn(
        memberId: memberId,
        memberName: name,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
      );
      HapticFeedback.heavyImpact();
      _activeCheckIn = AttendanceLog(
        id: logId,
        memberId: memberId,
        memberName: name,
        checkInTime: DateTime.now(),
        method: 'geo',
        latitude: _position!.latitude,
        longitude: _position!.longitude,
      );
      await _loadTodayLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyError(e, fallback: 'Check-in failed. Please try again.'))),
        );
      }
    }
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _checkOut() async {
    if (_activeCheckIn == null || _processing) return;
    setState(() => _processing = true);
    try {
      final memberId = TeamService.instance.getActualUserId();
      await _svc.geoCheckOut(
        memberId: memberId,
        logId: _activeCheckIn!.id,
        latitude: _position?.latitude ?? 0,
        longitude: _position?.longitude ?? 0,
      );
      HapticFeedback.heavyImpact();
      _activeCheckIn = null;
      await _loadTodayLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked out successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyError(e, fallback: 'Check-out failed. Please try again.'))),
        );
      }
    }
    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _init();
              if (_tabController.index == 1) _loadStats();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary,
          unselectedLabelColor: context.cs.onSurfaceVariant,
          indicatorColor: kPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Check In'),
            Tab(text: 'My Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Check-in / Check-out
          _buildCheckInTab(),
          // Tab 2: My attendance stats
          _buildStatsTab(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ─── Tab 1: Check In / Out ─────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildCheckInTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded, size: 48, color: kOverdue),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: TextStyle(color: context.cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(),
        const SizedBox(height: 16),
        _buildActionButton(),
        const SizedBox(height: 24),
        if (_todayLogs.isNotEmpty) ...[
          Text("Today's Log", style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: context.cs.onSurface,
          )),
          const SizedBox(height: 8),
          ..._todayLogs.map(_buildLogTile),
        ],
      ],
    );
  }

  Widget _buildStatusCard() {
    final distText = _distance != null
        ? _distance! < 1000
            ? '${_distance!.toInt()}m away'
            : '${(_distance! / 1000).toStringAsFixed(1)}km away'
        : 'Unknown';

    return Card(
      color: _insideFence ? kPaid.withAlpha(15) : kOverdue.withAlpha(15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _insideFence ? Icons.location_on_rounded : Icons.location_off_rounded,
              size: 48,
              color: _insideFence ? kPaid : kOverdue,
            ),
            const SizedBox(height: 12),
            Text(
              _insideFence ? 'You are at the office' : 'You are outside the geofence',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _insideFence ? kPaid : kOverdue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              distText,
              style: TextStyle(fontSize: 14, color: context.cs.onSurfaceVariant),
            ),
            if (_team?.officeAddress.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                _team!.officeAddress,
                style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Radius: ${_team?.officeRadius.toInt() ?? 200}m',
              style: TextStyle(fontSize: 11, color: context.cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_activeCheckIn != null) {
      // Checked in — show check-out button + duration
      final duration = DateTime.now().difference(_activeCheckIn!.checkInTime);
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      return Column(
        children: [
          Text(
            'Checked in ${DateFormat.jm().format(_activeCheckIn!.checkInTime)}',
            style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant),
          ),
          Text(
            '${hours}h ${mins}m elapsed',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _processing ? null : _checkOut,
              style: FilledButton.styleFrom(
                backgroundColor: kOverdue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _processing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.logout_rounded),
              label: const Text('Check Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
    }

    // Not checked in — show check-in button
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: (_insideFence && !_processing) ? _checkIn : null,
        style: FilledButton.styleFrom(
          backgroundColor: kPaid,
          disabledBackgroundColor: context.cs.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _processing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.login_rounded),
        label: Text(
          _insideFence ? 'Check In' : 'Move closer to check in',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildLogTile(AttendanceLog log) {
    final inTime = DateFormat.jm().format(log.checkInTime);
    final outTime = log.checkOutTime != null ? DateFormat.jm().format(log.checkOutTime!) : 'Active';
    final hours = log.totalHours;
    final hoursText = hours != null ? '${hours.toStringAsFixed(1)}h' : 'In progress';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: log.isCheckedIn ? kPaid.withAlpha(30) : context.cs.surfaceContainerHigh,
          child: Icon(
            log.isCheckedIn ? Icons.login_rounded : Icons.logout_rounded,
            color: log.isCheckedIn ? kPaid : context.cs.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text('$inTime — $outTime', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(hoursText, style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
        trailing: log.isCheckedIn
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: kPaid.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                child: Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPaid)),
              )
            : null,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ─── Tab 2: My Stats ───────────────────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildStatsTab() {
    if (_statsLoading) return const Center(child: CircularProgressIndicator());

    final totalDaysInRange = _statsRange.end.difference(_statsRange.start).inDays + 1;
    final absentDays = totalDaysInRange - _daysPresent;
    final attendanceRate = totalDaysInRange > 0
        ? (_daysPresent / totalDaysInRange * 100)
        : 0.0;
    final fmt = DateFormat('dd MMM');

    // Recent logs for the stats range
    final rangeLogs = _allLogs.where((l) =>
      !l.checkInTime.isBefore(_statsRange.start) &&
      l.checkInTime.isBefore(_statsRange.end.add(const Duration(days: 1)))
    ).toList();

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date range picker
          GestureDetector(
            onTap: _pickStatsRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kPrimary.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withAlpha(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.date_range_rounded, size: 18, color: kPrimary),
                  const SizedBox(width: 8),
                  Text(
                    '${fmt.format(_statsRange.start)} – ${fmt.format(_statsRange.end)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kPrimary),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_rounded, size: 14, color: kPrimary.withAlpha(150)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Attendance rate card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Attendance Rate', style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant)),
                      const Spacer(),
                      Text(
                        '${attendanceRate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: attendanceRate >= 80 ? kPaid : (attendanceRate >= 50 ? Colors.orange : kOverdue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (attendanceRate / 100).clamp(0, 1),
                      minHeight: 10,
                      backgroundColor: context.cs.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(
                        attendanceRate >= 80 ? kPaid : (attendanceRate >= 50 ? Colors.orange : kOverdue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Stats grid
          Row(
            children: [
              _statCard('Present', '$_daysPresent', kPaid, Icons.check_circle_rounded),
              const SizedBox(width: 8),
              _statCard('Absent', '$absentDays', kOverdue, Icons.cancel_rounded),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statCard('On Time', '$_onTimeDays', Colors.blue, Icons.wb_sunny_rounded),
              const SizedBox(width: 8),
              _statCard('Avg/Day', '${_avgHoursPerDay.toStringAsFixed(1)}h', kPrimary, Icons.timer_rounded),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statCard('Total Hours', _totalHours.toStringAsFixed(1), Colors.blue, Icons.access_time_rounded),
              const SizedBox(width: 8),
              _statCard('Days in Range', '$totalDaysInRange', context.cs.onSurfaceVariant, Icons.calendar_month_rounded),
            ],
          ),

          const SizedBox(height: 20),

          // Recent logs
          Text('Recent Check-ins', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: context.cs.onSurface,
          )),
          const SizedBox(height: 8),
          if (rangeLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No attendance records in this period',
                  style: TextStyle(color: context.cs.onSurfaceVariant)),
            ),
          ...rangeLogs.take(20).map(_buildStatsLogTile),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                    Text(label, style: TextStyle(fontSize: 10, color: context.cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsLogTile(AttendanceLog log) {
    final date = DateFormat('dd MMM').format(log.checkInTime);
    final inTime = DateFormat.jm().format(log.checkInTime);
    final outTime = log.checkOutTime != null ? DateFormat.jm().format(log.checkOutTime!) : null;
    final hours = log.totalHours;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(date, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.cs.onSurfaceVariant)),
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
            Expanded(
              child: Text(
                '$inTime — ${outTime ?? "Active"}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        trailing: hours != null
            ? Text('${hours.toStringAsFixed(1)}h',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary))
            : Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPaid)),
      ),
    );
  }
}
