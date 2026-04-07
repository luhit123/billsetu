import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Shows a graceful "Permission Denied" bottom sheet when a team member
/// attempts an action they don't have access to.
///
/// Usage:
/// ```dart
/// if (!TeamService.instance.can.canDeleteInvoice) {
///   PermissionDenied.show(context, action: 'delete invoices');
///   return;
/// }
/// ```
class PermissionDenied {
  PermissionDenied._();

  /// Returns true if the permission is granted, false if denied (and shows feedback).
  /// Convenience wrapper for inline checks:
  /// ```dart
  /// if (!PermissionDenied.check(context, TeamService.instance.can.canEditInvoice, 'edit invoices')) return;
  /// ```
  static bool check(BuildContext context, bool allowed, String action) {
    if (allowed) return true;
    show(context, action: action);
    return false;
  }

  /// Shows a permission denied bottom sheet.
  static void show(BuildContext context, {required String action}) {
    final role = TeamService.instance.currentRole.displayName;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kOverdue.withAlpha(24),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded, color: kOverdue, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                'Permission Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your role ($role) does not have permission to $action. '
                'Contact your team owner to update your permissions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
