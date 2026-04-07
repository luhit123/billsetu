import 'package:billeasy/modals/team_role.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:flutter/material.dart';

/// Conditionally shows [child] based on the current user's team role.
///
/// Usage:
/// ```dart
/// RoleGated(
///   permission: (role) => role.canCreateInvoice,
///   child: FloatingActionButton(...),
/// )
/// ```
///
/// For solo users, [TeamService.currentRole] is [TeamRole.owner], so the
/// permission function always returns true — no UI change.
class RoleGated extends StatelessWidget {
  const RoleGated({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  /// A function that receives the current role and returns whether the
  /// child should be visible.
  final bool Function(TeamRole role) permission;

  /// The widget to show when permission is granted.
  final Widget child;

  /// Optional widget to show when permission is denied.
  /// Defaults to [SizedBox.shrink] (invisible).
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final role = TeamService.instance.currentRole;
    if (permission(role)) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

/// Variant that disables the child instead of hiding it.
class RoleGatedEnabled extends StatelessWidget {
  const RoleGatedEnabled({
    super.key,
    required this.permission,
    required this.child,
  });

  final bool Function(TeamRole role) permission;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final role = TeamService.instance.currentRole;
    final allowed = permission(role);
    return IgnorePointer(
      ignoring: !allowed,
      child: Opacity(
        opacity: allowed ? 1.0 : 0.4,
        child: child,
      ),
    );
  }
}
