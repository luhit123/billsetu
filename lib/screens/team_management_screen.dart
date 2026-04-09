import 'dart:async';

import 'package:billeasy/modals/team_invite.dart';
import 'package:billeasy/modals/team_member.dart';
import 'package:billeasy/modals/team_role.dart';
import 'package:billeasy/screens/attendance_dashboard_screen.dart';
import 'package:billeasy/screens/member_performance_detail_screen.dart';
import 'package:billeasy/screens/office_location_screen.dart';
import 'package:billeasy/screens/team_invite_screen.dart';
import 'package:billeasy/screens/team_performance_screen.dart';
import 'package:billeasy/screens/upgrade_screen.dart';
import 'package:billeasy/screens/team_settings_screen.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:flutter/material.dart';

/// Owner/Manager view for managing team members and invites.
class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _teamService = TeamService.instance;
  bool _isCreatingTeam = false;
  StreamSubscription<AppPlan>? _planSub;

  @override
  void initState() {
    super.initState();
    _planSub = PlanService.instance.planStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _planSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          if (_teamService.isOnTeam &&
              (_teamService.currentRole == TeamRole.owner ||
                  _teamService.currentRole == TeamRole.coOwner)) ...[
            IconButton(
              icon: const Icon(Icons.schedule_rounded),
              tooltip: 'Attendance',
              onPressed: () {
                if (!PlanService.instance.hasAttendance) {
                  _showUpgradeDialog('use attendance tracking');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AttendanceDashboardScreen(),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                switch (value) {
                  case 'performance':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeamPerformanceScreen(),
                      ),
                    );
                  case 'permissions':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeamSettingsScreen(),
                      ),
                    );
                  case 'office_location':
                    if (!PlanService.instance.hasAttendance) {
                      _showUpgradeDialog('use attendance & office location');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OfficeLocationScreen(),
                      ),
                    );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'performance',
                  child: ListTile(
                    leading: Icon(Icons.bar_chart_rounded),
                    title: Text('Performance'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'permissions',
                  child: ListTile(
                    leading: Icon(Icons.tune_rounded),
                    title: Text('Permissions'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'office_location',
                  child: ListTile(
                    leading: Icon(Icons.location_on_rounded),
                    title: Text('Office Location'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton:
          _teamService.can.canInviteMembers && _teamService.isOnTeam
          ? FloatingActionButton.extended(
              onPressed: () {
                if (!PlanService.instance.hasTeamAccess) {
                  _showUpgradeDialog('invite team members');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeamInviteScreen()),
                );
              },
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Invite'),
            )
          : null,
      body: _teamService.isSolo || (!_teamService.isOnTeam)
          ? _buildCreateTeamView()
          : _buildTeamView(),
    );
  }

  Widget _buildCreateTeamView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_rounded, size: 64, color: kTextTertiary),
            const SizedBox(height: 16),
            Text(
              'Create Your Team',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Invite sales reps, managers, and viewers to collaborate on invoices and customers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isCreatingTeam ? null : () {
                if (!PlanService.instance.hasTeamAccess) {
                  _showUpgradeDialog('create a team');
                  return;
                }
                _createTeam();
              },
              child: _isCreatingTeam
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Team'),
            ),
            if (!PlanService.instance.hasTeamAccess) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Upgrade to Pro to use Team features',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createTeam() async {
    setState(() => _isCreatingTeam = true);
    try {
      final profile = ProfileService.instance.cachedProfile;
      final user = FirebaseAuth.instance.currentUser;
      await _teamService.createTeam(
        businessName: profile?.storeName ?? 'My Business',
        ownerName: user?.displayName ?? profile?.phoneNumber ?? '',
        ownerPhone: profile?.phoneNumber ?? user?.phoneNumber ?? '',
        ownerEmail: user?.email ?? '',
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e, fallback: 'Failed to create team. Please try again.'))));
      }
    } finally {
      if (mounted) setState(() => _isCreatingTeam = false);
    }
  }

  Widget _buildTeamView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Team info header
        _buildTeamHeader(),
        const SizedBox(height: 24),
        // Active members
        Text('Members', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _buildMembersList(),
        if (_teamService.can.canInviteMembers) ...[
          const SizedBox(height: 24),
          Text(
            'Pending Invites',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildPendingInvites(),
        ],
      ],
    );
  }

  Widget _buildTeamHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: kPrimary.withValues(alpha: 0.12),
              child: Icon(Icons.groups_rounded, color: kPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _teamService.teamBusinessName.isNotEmpty
                        ? _teamService.teamBusinessName
                        : 'My Team',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _teamService.isTeamOwner
                        ? 'Owner'
                        : _teamService.currentRole.displayName,
                    style: TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    return StreamBuilder<List<TeamMember>>(
      stream: _teamService.watchMembers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No members yet. Invite someone to get started!'),
            ),
          );
        }

        return Column(
          children: members.map((m) => _buildMemberTile(m)).toList(),
        );
      },
    );
  }

  Widget _buildMemberTile(TeamMember member) {
    final isCurrentUser = member.uid == _teamService.getActualUserId();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _roleColor(member.role).withValues(alpha: 0.12),
          child: Text(
            member.displayName.isNotEmpty
                ? member.displayName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: _roleColor(member.role),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${member.displayName}${isCurrentUser ? ' (You)' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(member.phone.isNotEmpty ? member.phone : member.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _roleColor(member.role).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                member.role.displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _roleColor(member.role),
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _onMemberAction(value, member),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'view_report',
                  child: ListTile(
                    leading: Icon(Icons.analytics_outlined, size: 20),
                    title: Text('View Report'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_teamService.can.canRemoveMembers &&
                    member.role != TeamRole.owner &&
                    !isCurrentUser) ...[
                  const PopupMenuItem(
                    value: 'change_role',
                    child: ListTile(
                      leading: Icon(Icons.swap_horiz_rounded, size: 20),
                      title: Text('Change Role'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(
                        Icons.person_remove_rounded,
                        size: 20,
                        color: Colors.red,
                      ),
                      title: Text(
                        'Remove',
                        style: TextStyle(color: Colors.red),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMemberAction(String action, TeamMember member) async {
    if (action == 'view_report') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberPerformanceDetailScreen(member: member),
        ),
      );
      return;
    }
    if (action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Remove Member'),
          content: Text('Remove ${member.displayName} from the team?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        try {
          await _teamService.removeMember(member.uid);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(userFriendlyError(e, fallback: 'Failed to remove member. Please try again.'))));
          }
        }
      }
    } else if (action == 'change_role') {
      final newRole = await showDialog<TeamRole>(
        context: context,
        builder: (_) => _RolePickerDialog(currentRole: member.role),
      );
      if (newRole != null && newRole != member.role) {
        try {
          await _teamService.changeRole(member.uid, newRole);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(userFriendlyError(e, fallback: 'Failed to change role. Please try again.'))),
            );
          }
        }
      }
    }
  }

  Widget _buildPendingInvites() {
    return StreamBuilder<List<TeamInvite>>(
      stream: _teamService.watchPendingInvites(),
      builder: (context, snapshot) {
        final invites = snapshot.data ?? [];
        if (invites.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No pending invites',
                style: TextStyle(color: kTextSecondary),
              ),
            ),
          );
        }

        return Column(
          children: invites
              .map(
                (inv) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: Text(
                      inv.invitedPhone.isNotEmpty
                          ? inv.invitedPhone
                          : inv.invitedEmail,
                    ),
                    subtitle: Text('Role: ${inv.role.displayName}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () async {
                        try {
                          await _teamService.cancelInvite(inv.id);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to cancel invite: $e'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  void _showUpgradeDialog(String feature) {
    final isEnterpriseOnly = feature.toLowerCase().contains('attendance') ||
        feature.toLowerCase().contains('office location');
    final planLabel = isEnterpriseOnly ? 'Enterprise' : 'Pro';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$planLabel Plan Required'),
        content: Text(
          'You need ${isEnterpriseOnly ? 'an' : 'a'} $planLabel plan to $feature. Upgrade now to unlock this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpgradeScreen()),
              );
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  Color _roleColor(TeamRole role) {
    switch (role) {
      case TeamRole.owner:
        return kPrimary;
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

class _RolePickerDialog extends StatelessWidget {
  const _RolePickerDialog({required this.currentRole});
  final TeamRole currentRole;

  @override
  Widget build(BuildContext context) {
    final roles = [TeamRole.manager, TeamRole.sales, TeamRole.viewer];
    return SimpleDialog(
      title: const Text('Change Role'),
      children: roles
          .map(
            (role) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, role),
              child: Row(
                children: [
                  if (role == currentRole)
                    const Icon(Icons.check, size: 18, color: Colors.green)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          role.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
