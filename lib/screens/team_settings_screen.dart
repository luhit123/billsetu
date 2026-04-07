import 'package:billeasy/modals/team_role.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:flutter/material.dart';

/// For **owners**: configure per-role permissions with toggles.
/// For **members**: view current effective permissions (read-only) + leave team.
class TeamSettingsScreen extends StatefulWidget {
  const TeamSettingsScreen({super.key});

  @override
  State<TeamSettingsScreen> createState() => _TeamSettingsScreenState();
}

class _TeamSettingsScreenState extends State<TeamSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = TeamService.instance;
  late final bool _isOwner;
  TabController? _tabController;

  // Local state: role → { permKey → bool }
  // Seeded from cached team doc, updated on toggle, saved to Firestore.
  final Map<TeamRole, Map<String, bool>> _roleOverrides = {};

  static const _configurableRoles = [
    TeamRole.coOwner,
    TeamRole.manager,
    TeamRole.sales,
    TeamRole.viewer,
  ];

  @override
  void initState() {
    super.initState();
    _isOwner = _service.currentRole == TeamRole.owner ||
                _service.currentRole == TeamRole.coOwner;
    if (_isOwner) {
      _tabController = TabController(length: _configurableRoles.length, vsync: this);
      _seedOverrides();
    }
  }

  void _seedOverrides() {
    final team = _service.cachedTeam;
    for (final role in _configurableRoles) {
      final saved = team?.rolePermissions[role.toStringValue()] ?? {};
      // Build full permission map: default merged with saved overrides
      final perms = <String, bool>{};
      for (final entry in TeamRole.configurablePermissions) {
        perms[entry.key] = saved[entry.key] ?? role.defaultFor(entry.key);
      }
      _roleOverrides[role] = perms;
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOwner) return _buildOwnerView(context);
    return _buildMemberView(context);
  }

  // ── Owner view: tabbed permission toggles ─────────────────────────────────

  Widget _buildOwnerView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Permissions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _configurableRoles
              .map((r) => Tab(text: r.displayName))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _configurableRoles
            .map((role) => _buildPermissionList(role))
            .toList(),
      ),
    );
  }

  Widget _buildPermissionList(TeamRole role) {
    final perms = _roleOverrides[role]!;
    // Group by category
    final grouped = <String, List<PermissionEntry>>{};
    for (final entry in TeamRole.configurablePermissions) {
      grouped.putIfAbsent(entry.category, () => []).add(entry);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            role.description,
            style: TextStyle(color: kTextSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
        for (final category in grouped.keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              category,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: kTextSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          for (final entry in grouped[category]!)
            SwitchListTile(
              title: Text(entry.label, style: const TextStyle(fontSize: 14)),
              value: perms[entry.key] ?? false,
              dense: true,
              onChanged: (value) => _togglePermission(role, entry.key, value),
            ),
        ],
      ],
    );
  }

  Future<void> _togglePermission(TeamRole role, String key, bool value) async {
    setState(() => _roleOverrides[role]![key] = value);
    try {
      await _service.updateRolePermissions(role, _roleOverrides[role]!);
    } catch (e) {
      // Revert on failure
      setState(() => _roleOverrides[role]![key] = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyError(e, fallback: 'Failed to save permissions. Please try again.'))),
        );
      }
    }
  }

  // ── Member view: read-only permissions + leave ────────────────────────────

  Widget _buildMemberView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: kPrimary.withOpacity(0.12),
                          child: Icon(Icons.groups_rounded, color: kPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _service.teamBusinessName.isNotEmpty
                                    ? _service.teamBusinessName
                                    : 'Team',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your role: ${_service.currentRole.displayName}',
                                style: TextStyle(color: kTextSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _service.currentRole.description,
                      style: TextStyle(color: kTextSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Permissions', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    for (final entry in TeamRole.configurablePermissions)
                      _permRow(entry.label, _service.can.check(entry.key)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _leaveTeam(context),
              icon: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
              label: const Text('Leave Team', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permRow(String label, bool allowed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: allowed ? Colors.green : Colors.red.shade300,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _leaveTeam(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Team'),
        content: const Text(
          'You will lose access to this team\'s data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.leaveTeam();
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userFriendlyError(e, fallback: 'Failed to update. Please try again.'))),
          );
        }
      }
    }
  }
}
