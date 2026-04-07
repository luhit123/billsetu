import 'package:billeasy/modals/team_role.dart';

/// Merges a [TeamRole]'s default permissions with Firestore-stored overrides.
///
/// For solo users (no team), all overrides are empty → falls through to
/// [TeamRole.owner] defaults, producing identical behaviour to the pre-team era.
class EffectivePermissions {
  EffectivePermissions(this._role, [this._overrides = const {}]);

  final TeamRole _role;

  /// Overrides for the current role, keyed by permission name.
  /// Values present here take precedence over the role default.
  final Map<String, bool> _overrides;

  /// Returns the effective value for a permission key.
  bool check(String key) => _overrides[key] ?? _role.defaultFor(key);

  // ── Invoice ───────────────────────────────────────────────────────────────
  bool get canCreateInvoice => check('canCreateInvoice');
  bool get canEditInvoice => check('canEditInvoice');
  bool get canDeleteInvoice => check('canDeleteInvoice');
  bool get canRecordPayment => check('canRecordPayment');

  // ── Customer ──────────────────────────────────────────────────────────────
  bool get canAddCustomer => check('canAddCustomer');
  bool get canEditCustomer => check('canEditCustomer');
  bool get canDeleteCustomer => check('canDeleteCustomer');

  // ── Product ───────────────────────────────────────────────────────────────
  bool get canAddProduct => check('canAddProduct');
  bool get canEditProduct => check('canEditProduct');
  bool get canDeleteProduct => check('canDeleteProduct');
  bool get canAdjustStock => check('canAdjustStock');

  // ── Operations ────────────────────────────────────────────────────────────
  bool get canManagePurchaseOrders => check('canManagePurchaseOrders');
  bool get canViewReports => check('canViewReports');
  bool get canViewRevenue => check('canViewRevenue');
  bool get canExportData => check('canExportData');

  // ── Profile & subscription (owner-only, not overridable) ──────────────────
  bool get canEditProfile => _role.canEditProfile;
  bool get canManageSubscription => _role.canManageSubscription;

  // ── Team management ───────────────────────────────────────────────────────
  bool get canInviteMembers => check('canInviteMembers');
  bool get canRemoveMembers => _role.canRemoveMembers; // owner-only
  bool get canChangeRoles => _role.canChangeRoles; // owner-only
  bool get canAddMembers => check('canAddMembers');
  bool get canMarkAttendance => check('canMarkAttendance');
  bool get canViewOthersInvoices => check('canViewOthersInvoices');
}
