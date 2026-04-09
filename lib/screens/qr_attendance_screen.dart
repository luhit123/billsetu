import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:billeasy/modals/member.dart';
import 'package:billeasy/services/membership_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/permission_denied_dialog.dart';

class QrAttendanceScreen extends StatefulWidget {
  const QrAttendanceScreen({super.key});

  @override
  State<QrAttendanceScreen> createState() => _QrAttendanceScreenState();
}

class _QrAttendanceScreenState extends State<QrAttendanceScreen>
    with TickerProviderStateMixin {
  final _membershipService = MembershipService();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  StreamSubscription<List<Member>>? _membersSub;
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  List<AttendanceLog> _todayLogs = [];
  Set<String> _todayCheckedInMemberIds = {};

  bool _isLoadingMembers = true;
  bool _isLoadingAttendance = true;

  // Track which member card is animating a check-in flash
  String? _flashingMemberId;

  @override
  void initState() {
    super.initState();
    _membersSub = _membershipService.watchMembers().listen((members) {
      if (!mounted) return;
      setState(() {
        _allMembers = members;
        _isLoadingMembers = false;
        _applyFilter();
      });
    });
    _loadTodayAttendance();
  }

  @override
  void dispose() {
    _membersSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredMembers = _allMembers.where((m) => m.isActive).toList();
    } else {
      _filteredMembers = _allMembers.where((m) {
        final nameMatch = m.name.toLowerCase().contains(query);
        final phoneMatch = m.phone.toLowerCase().contains(query);
        return (nameMatch || phoneMatch) && m.isActive;
      }).toList();
    }
  }

  Future<void> _loadTodayAttendance() async {
    try {
      final logs = await _membershipService.getTodayAttendance();
      if (!mounted) return;
      setState(() {
        _todayLogs = logs;
        _todayCheckedInMemberIds = logs.map((log) => log.memberId).toSet();
        _isLoadingAttendance = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingAttendance = false);
    }
  }

  Future<void> _checkIn(Member member) async {
    if (!PermissionDenied.check(
      context,
      TeamService.instance.can.canManageSubscription,
      'mark attendance',
    )) {
      return;
    }
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Flash animation
    setState(() => _flashingMemberId = member.id);

    try {
      await _membershipService.markAttendance(member.id, member.name, 'qr');

      // Reload today's attendance
      await _loadTodayAttendance();

      if (!mounted) return;

      // Show snackbar
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${member.name} checked in!',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: kPaid,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check in: $e'),
          backgroundColor: kOverdue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } finally {
      // End flash after a brief moment
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() => _flashingMemberId = null);
      }
    }
  }

  bool _isCheckedInToday(String memberId) {
    return _todayCheckedInMemberIds.contains(memberId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: kBuildGradientAppBar(titleText: 'Check-in'),
      body: Column(
        children: [
          // Quick stats bar
          _buildStatsBar(),
          // Search field
          _buildSearchField(),
          // Content
          Expanded(
            child: _isLoadingMembers
                ? const Center(
                    child: CircularProgressIndicator(color: kPrimary),
                  )
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  // ── Stats Bar ───────────────────────────────────────────────────────────────

  Widget _buildStatsBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: context.cs.primaryContainer),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: kPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Today: ${_todayLogs.length} check-in${_todayLogs.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: context.cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Text(
            DateFormat('EEEE, d MMM').format(DateTime.now()),
            style: TextStyle(
              color: context.cs.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Field ────────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [kWhisperShadow],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          style: TextStyle(
            fontSize: 16,
            color: context.cs.onSurface,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search by name or phone number',
            hintStyle: TextStyle(
              color: context.cs.onSurfaceVariant.withAlpha(153),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 10),
              child: Icon(Icons.search_rounded, color: kPrimary, size: 24),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.cs.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _applyFilter());
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onChanged: (_) => setState(() => _applyFilter()),
        ),
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        // Member results
        if (_searchController.text.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${_filteredMembers.length} member${_filteredMembers.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  color: context.cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        if (_filteredMembers.isNotEmpty && _searchController.text.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final member = _filteredMembers[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildMemberCard(member),
                );
              }, childCount: _filteredMembers.length),
            ),
          ),
        if (_filteredMembers.isEmpty && _searchController.text.isNotEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _buildEmptySearch()),

        // Today's check-ins section
        if (_searchController.text.isEmpty) ...[
          SliverToBoxAdapter(child: _buildTodayHeader()),
          if (_isLoadingAttendance)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: kPrimary),
                ),
              ),
            )
          else if (_todayLogs.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyToday())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final log = _todayLogs[index];
                  final isLast = index == _todayLogs.length - 1;
                  return _buildTimelineEntry(log, isLast);
                }, childCount: _todayLogs.length),
              ),
            ),
        ],
      ],
    );
  }

  // ── Member Card ─────────────────────────────────────────────────────────────

  Widget _buildMemberCard(Member member) {
    final checkedIn = _isCheckedInToday(member.id);
    final isFlashing = _flashingMemberId == member.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isFlashing ? kPaidBg : context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [kWhisperShadow],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: checkedIn
                  ? const LinearGradient(
                      colors: [kPaid, Color(0xFF16A34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : kSignatureGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                member.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    color: context.cs.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (member.planName.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.cs.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          member.planName,
                          style: const TextStyle(
                            color: kPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      member.daysLeftLabel,
                      style: TextStyle(
                        color: member.daysLeft <= 7
                            ? kOverdue
                            : context.cs.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Check-in button
          checkedIn ? _buildCheckedInBadge() : _buildCheckInButton(member),
        ],
      ),
    );
  }

  Widget _buildCheckInButton(Member member) {
    return GestureDetector(
      onTap: () => _checkIn(member),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: kSignatureGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          'CHECK IN',
          style: TextStyle(
            color: context.cs.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckedInBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kPaidBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle_rounded, color: kPaid, size: 16),
          SizedBox(width: 6),
          Text(
            'Checked In',
            style: TextStyle(
              color: kPaid,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty States ────────────────────────────────────────────────────────────

  Widget _buildEmptySearch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.person_search_rounded,
                color: context.cs.onSurfaceVariant.withAlpha(153),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No active members found',
              style: TextStyle(
                color: context.cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different name or phone number',
              style: TextStyle(
                color: context.cs.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyToday() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.how_to_reg_rounded,
                color: context.cs.onSurfaceVariant.withAlpha(153),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No check-ins yet today',
              style: TextStyle(
                color: context.cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for a member above to start checking in',
              style: TextStyle(
                color: context.cs.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Today's Check-ins ───────────────────────────────────────────────────────

  Widget _buildTodayHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Text(
            "TODAY'S CHECK-INS",
            style: TextStyle(
              color: context.cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: context.cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_todayLogs.length}',
              style: const TextStyle(
                color: kPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() => _isLoadingAttendance = true);
              _loadTodayAttendance();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: context.cs.onSurfaceVariant,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(AttendanceLog log, bool isLast) {
    final timeStr = DateFormat('h:mm a').format(log.checkInTime);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: kPrimary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: context.cs.primaryContainer,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Entry card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [kSubtleShadow],
              ),
              child: Row(
                children: [
                  // Member initials
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _initialsFromName(log.memberName),
                        style: const TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
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
                          log.memberName.isNotEmpty
                              ? log.memberName
                              : 'Unknown',
                          style: TextStyle(
                            color: context.cs.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: context.cs.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: context.cs.onSurfaceVariant.withAlpha(
                                  153,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _methodLabel(log.method),
                              style: TextStyle(
                                color: context.cs.onSurfaceVariant.withAlpha(
                                  153,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: kPaid,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'qr':
        return 'QR Scan';
      case 'code':
        return 'Code Entry';
      case 'manual':
      default:
        return 'Manual';
    }
  }
}
