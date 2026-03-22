import 'dart:async';

import 'package:billeasy/modals/member.dart';
import 'package:billeasy/modals/subscription_plan.dart';
import 'package:billeasy/screens/member_form_screen.dart';
import 'package:billeasy/screens/membership_invoice_screen.dart';
import 'package:billeasy/services/membership_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

BoxDecoration _cardDeco() => const BoxDecoration(
      color: kSurfaceLowest,
      borderRadius: BorderRadius.all(Radius.circular(20)),
      boxShadow: [kWhisperShadow],
    );

class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key, required this.member});
  final Member member;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final MembershipService _service = MembershipService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );
  final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  final DateFormat _timeFmt = DateFormat('hh:mm a');

  late Member _member;
  StreamSubscription<List<AttendanceLog>>? _attendanceSub;
  List<AttendanceLog> _attendanceLogs = const [];
  bool _isLoadingAttendance = true;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _subscribeAttendance();
  }

  void _subscribeAttendance() {
    _attendanceSub?.cancel();
    _attendanceSub = _service.watchAttendance(_member.id).listen(
      (logs) {
        if (mounted) {
          setState(() {
            _attendanceLogs = logs;
            _isLoadingAttendance = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isLoadingAttendance = false);
      },
    );
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _handleCheckIn() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    try {
      await _service.markAttendance(_member.id, _member.name, 'manual');
      if (mounted) {
        setState(() => _member = _member.copyWith(
              attendanceCount: _member.attendanceCount + 1,
              lastCheckIn: DateTime.now(),
            ));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in recorded'),
            backgroundColor: kPaid,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in failed: $e'),
            backgroundColor: kOverdue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _handleFreeze() async {
    if (_member.isFrozen) {
      // Unfreeze — add remaining frozen days back to end date
      final frozenDaysLeft =
          _member.frozenUntil!.difference(DateTime.now()).inDays;
      final newEnd =
          _member.endDate.add(Duration(days: frozenDaysLeft.clamp(0, 9999)));
      try {
        await _service.unfreezeMember(_member.id, newEnd);
        if (mounted) {
          setState(() => _member = _member.copyWith(
                status: MemberStatus.active,
                endDate: newEnd,
              ));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Membership unfrozen'),
              backgroundColor: kPaid,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unfreeze: $e'),
              backgroundColor: kOverdue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return;
    }

    // Freeze — pick a date
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: _member.endDate.add(const Duration(days: 90)),
      helpText: 'Freeze until',
    );
    if (picked == null || !mounted) return;

    try {
      await _service.freezeMember(_member.id, picked);
      if (mounted) {
        setState(() => _member = _member.copyWith(
              status: MemberStatus.frozen,
              frozenUntil: picked,
            ));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Frozen until ${_dateFmt.format(picked)}'),
            backgroundColor: kPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to freeze: $e'),
            backgroundColor: kOverdue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleRenew() {
    final totalDays = _member.endDate.difference(_member.startDate).inDays;
    final newEnd = _member.endDate.add(Duration(days: totalDays));

    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kSurfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Renew Membership',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kOnSurface,
              ),
            ),
            const SizedBox(height: 20),
            _renewRow('Plan', _member.planName),
            const SizedBox(height: 10),
            _renewRow('Duration', '$totalDays days'),
            const SizedBox(height: 10),
            _renewRow('New End Date', _dateFmt.format(newEnd)),
            const SizedBox(height: 10),
            _renewRow('Amount', _currency.format(_member.amountPaid)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _service.renewMember(
                        _member.id, newEnd, _member.amountPaid);
                    if (mounted) {
                      setState(() => _member = _member.copyWith(
                            status: MemberStatus.active,
                            endDate: newEnd,
                          ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Membership renewed'),
                          backgroundColor: kPaid,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Renewal failed: $e'),
                          backgroundColor: kOverdue,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Confirm Renewal',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: kOnSurfaceVariant)),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kOnSurface)),
      ],
    );
  }

  Future<void> _handleInvoice() async {
    try {
      // Fetch the plan for this member
      SubscriptionPlan? plan = await _service.getPlanById(_member.planId);
      plan ??= SubscriptionPlan(
        id: _member.planId,
        ownerId: _member.ownerId,
        name: _member.planName,
        price: _member.amountPaid,
        createdAt: _member.createdAt,
        updatedAt: _member.updatedAt,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MembershipInvoiceScreen(
            member: _member,
            plan: plan!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plan: $e')),
      );
    }
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.push<Member>(
      context,
      MaterialPageRoute(
        builder: (_) => MemberFormScreen(member: _member),
      ),
    );
    if (result != null && mounted) {
      setState(() => _member = result);
      // Re-subscribe in case ID or attendance path changed
      _subscribeAttendance();
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Member',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: kOnSurface, fontSize: 17)),
        content: Text(
          'Are you sure you want to delete ${_member.name}? This action cannot be undone.',
          style: const TextStyle(color: kOnSurfaceVariant, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: kOnSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: kOverdue)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteMember(_member.id, _member.planId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: kOverdue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Status helpers ───────────────────────────────────────────────────────

  Color _statusColor(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:
        return kPaid;
      case MemberStatus.expired:
        return kOverdue;
      case MemberStatus.frozen:
        return kPrimary;
      case MemberStatus.cancelled:
        return kPending;
    }
  }

  Color _statusBg(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:
        return kPaidBg;
      case MemberStatus.expired:
        return kOverdueBg;
      case MemberStatus.frozen:
        return kPrimaryContainer;
      case MemberStatus.cancelled:
        return kPendingBg;
    }
  }

  String _statusLabel(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:
        return 'Active';
      case MemberStatus.expired:
        return 'Expired';
      case MemberStatus.frozen:
        return 'Frozen';
      case MemberStatus.cancelled:
        return 'Cancelled';
    }
  }

  double _planProgress() {
    final totalDays =
        _member.endDate.difference(_member.startDate).inDays.clamp(1, 99999);
    final elapsed =
        DateTime.now().difference(_member.startDate).inDays.clamp(0, totalDays);
    return elapsed / totalDays;
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'qr':
        return Icons.qr_code_2_rounded;
      case 'code':
        return Icons.pin_rounded;
      default:
        return Icons.touch_app_rounded;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: kBuildGradientAppBar(
        titleText: _member.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 22),
            tooltip: 'Edit',
            onPressed: _handleEdit,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: kSurfaceLowest,
            onSelected: (v) {
              if (v == 'delete') _handleDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Member',
                    style: TextStyle(color: kOverdue, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 12),
            _buildPlanInfoCard(),
            const SizedBox(height: 12),
            _buildQuickActions(),
            const SizedBox(height: 12),
            _buildAttendanceSection(),
            if (_member.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildNotesSection(),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Profile Header ───────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    final progress = _planProgress();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: kPrimaryContainer,
            child: Text(
              _member.initials,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: kPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _member.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kOnSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          if (_member.phone.isNotEmpty)
            Text(
              _member.phone,
              style: const TextStyle(fontSize: 14, color: kOnSurfaceVariant),
            ),
          if (_member.email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _member.email,
              style: const TextStyle(fontSize: 13, color: kTextTertiary),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusBg(_member.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(_member.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(_member.status),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _member.daysLeftLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _member.daysLeft <= 7 && _member.daysLeft > 0
                      ? kPending
                      : kOnSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: kSurfaceContainerLow,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 0.9
                    ? kOverdue
                    : progress >= 0.7
                        ? kPending
                        : kPaid,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dateFmt.format(_member.startDate),
                style: const TextStyle(fontSize: 11, color: kTextTertiary),
              ),
              Text(
                _dateFmt.format(_member.endDate),
                style: const TextStyle(fontSize: 11, color: kTextTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Plan Info ────────────────────────────────────────────────────────────

  Widget _buildPlanInfoCard() {
    final totalDays = _member.endDate.difference(_member.startDate).inDays;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PLAN DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: kTextTertiary,
            ),
          ),
          const SizedBox(height: 14),
          _planRow('Plan', _member.planName.isEmpty ? '-' : _member.planName),
          const SizedBox(height: 10),
          _planRow('Duration', '$totalDays days'),
          const SizedBox(height: 10),
          _planRow('Start Date', _dateFmt.format(_member.startDate)),
          const SizedBox(height: 10),
          _planRow('End Date', _dateFmt.format(_member.endDate)),
          const SizedBox(height: 10),
          _planRow('Amount Paid', _currency.format(_member.amountPaid)),
          if (_member.joiningFeePaid > 0) ...[
            const SizedBox(height: 10),
            _planRow(
                'Joining Fee', _currency.format(_member.joiningFeePaid)),
          ],
          const SizedBox(height: 10),
          _planRow('Auto-Renew', _member.autoRenew ? 'Yes' : 'No'),
          if (_member.isFrozen && _member.frozenUntil != null) ...[
            const SizedBox(height: 10),
            _planRow(
                'Frozen Until', _dateFmt.format(_member.frozenUntil!)),
          ],
        ],
      ),
    );
  }

  Widget _planRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: kOnSurfaceVariant)),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kOnSurface)),
      ],
    );
  }

  // ── Quick Actions ────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final isFrozen = _member.isFrozen;

    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.login_rounded,
            label: 'Check In',
            color: kPaid,
            bgColor: kPaidBg,
            isLoading: _checkingIn,
            onTap: _handleCheckIn,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: isFrozen ? Icons.play_arrow_rounded : Icons.ac_unit_rounded,
            label: isFrozen ? 'Unfreeze' : 'Freeze',
            color: kPrimary,
            bgColor: kPrimaryContainer,
            onTap: _handleFreeze,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.autorenew_rounded,
            label: 'Renew',
            color: kPending,
            bgColor: kPendingBg,
            onTap: _handleRenew,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.receipt_long_rounded,
            label: 'Invoice',
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFEDE9FE),
            onTap: _handleInvoice,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [kSubtleShadow],
        ),
        child: Column(
          children: [
            if (isLoading)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Attendance ───────────────────────────────────────────────────────────

  Widget _buildAttendanceSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'RECENT ATTENDANCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: kTextTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kPrimaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_member.attendanceCount}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingAttendance)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (_attendanceLogs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.event_busy_rounded,
                        size: 36, color: kTextTertiary),
                    SizedBox(height: 8),
                    Text(
                      'No check-ins yet',
                      style: TextStyle(fontSize: 14, color: kTextTertiary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attendanceLogs.length > 20
                  ? 20
                  : _attendanceLogs.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: kSurfaceContainerLow,
              ),
              itemBuilder: (_, i) {
                final log = _attendanceLogs[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: kSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _methodIcon(log.method),
                          size: 18,
                          color: kOnSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dateFmt.format(log.checkInTime),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: kOnSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _timeFmt.format(log.checkInTime),
                              style: const TextStyle(
                                  fontSize: 12, color: kTextTertiary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          log.method.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: kOnSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Notes ────────────────────────────────────────────────────────────────

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOTES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: kTextTertiary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _member.notes,
            style: const TextStyle(
              fontSize: 14,
              color: kOnSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
