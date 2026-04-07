/// Defines team member roles and their associated permissions.
///
/// Permission matrix:
///   Owner    — full access (default for solo users)
///   Co-Owner — same as owner, can do everything owner does
///   Manager  — everything except profile, subscription, and member removal
///   Sales    — create invoices, record payments, manage customers, add/edit products
///   Viewer   — read-only access to all data
enum TeamRole {
  owner,
  coOwner,
  manager,
  sales,
  viewer;

  // ── Parsing ──────────────────────────────────────────────────────────────

  static TeamRole fromString(String? value) {
    switch (value) {
      case 'owner':
        return TeamRole.owner;
      case 'coOwner':
      case 'co_owner':
        return TeamRole.coOwner;
      case 'manager':
        return TeamRole.manager;
      case 'sales':
        return TeamRole.sales;
      case 'viewer':
        return TeamRole.viewer;
      default:
        return TeamRole.viewer;
    }
  }

  String toStringValue() {
    if (this == coOwner) return 'coOwner';
    return name;
  }

  // ── Display ──────────────────────────────────────────────────────────────

  String get displayName {
    switch (this) {
      case TeamRole.owner:
        return 'Owner';
      case TeamRole.coOwner:
        return 'Co-Owner';
      case TeamRole.manager:
        return 'Manager';
      case TeamRole.sales:
        return 'Sales';
      case TeamRole.viewer:
        return 'Viewer';
    }
  }

  String get description {
    switch (this) {
      case TeamRole.owner:
        return 'Full access to all features and settings';
      case TeamRole.coOwner:
        return 'Full access — same as owner, manages everything';
      case TeamRole.manager:
        return 'Manage invoices, customers, products, and reports';
      case TeamRole.sales:
        return 'Create invoices, record payments, manage customers and products';
      case TeamRole.viewer:
        return 'View-only access to all data';
    }
  }

  // ── Default permission getters (used as fallback) ───────────────────────

  bool get _isOwnerLevel => this == owner || this == coOwner;

  bool get canCreateInvoice =>
      _isOwnerLevel || this == manager || this == sales;

  bool get canEditInvoice => _isOwnerLevel || this == manager;

  bool get canDeleteInvoice => _isOwnerLevel || this == manager;

  bool get canRecordPayment =>
      _isOwnerLevel || this == manager || this == sales;

  bool get canAddCustomer =>
      _isOwnerLevel || this == manager || this == sales;

  bool get canEditCustomer =>
      _isOwnerLevel || this == manager || this == sales;

  bool get canDeleteCustomer => _isOwnerLevel || this == manager;

  bool get canAddProduct =>
      _isOwnerLevel || this == manager || this == sales;

  bool get canEditProduct =>
      _isOwnerLevel || this == manager || this == sales;

  bool get canDeleteProduct => _isOwnerLevel || this == manager;

  bool get canAdjustStock => _isOwnerLevel || this == manager;

  bool get canManagePurchaseOrders => _isOwnerLevel || this == manager;

  bool get canViewReports => _isOwnerLevel || this == manager;

  bool get canViewRevenue => _isOwnerLevel || this == manager;

  bool get canExportData => _isOwnerLevel || this == manager;

  bool get canEditProfile => _isOwnerLevel;

  bool get canManageSubscription => _isOwnerLevel;

  bool get canInviteMembers => _isOwnerLevel || this == manager;

  bool get canRemoveMembers => _isOwnerLevel;

  bool get canChangeRoles => _isOwnerLevel;

  bool get canAddMembers => _isOwnerLevel || this == manager;

  bool get canMarkAttendance =>
      _isOwnerLevel || this == manager || this == sales;

  bool get canViewOthersInvoices => _isOwnerLevel || this == manager;

  // ── Permission registry ─────────────────────────────────────────────────

  /// All configurable permissions with display labels, grouped by category.
  /// Owner-only permissions (editProfile, manageSubscription, removeMembers,
  /// changeRoles) are excluded — they cannot be delegated.
  static const List<PermissionEntry> configurablePermissions = [
    // Invoices
    PermissionEntry('canCreateInvoice', 'Create invoices', 'Invoices'),
    PermissionEntry('canEditInvoice', 'Edit invoices', 'Invoices'),
    PermissionEntry('canDeleteInvoice', 'Delete invoices', 'Invoices'),
    PermissionEntry('canRecordPayment', 'Record payments', 'Invoices'),
    // Customers
    PermissionEntry('canAddCustomer', 'Add customers', 'Customers'),
    PermissionEntry('canEditCustomer', 'Edit customers', 'Customers'),
    PermissionEntry('canDeleteCustomer', 'Delete customers', 'Customers'),
    // Products
    PermissionEntry('canAddProduct', 'Add products', 'Products'),
    PermissionEntry('canEditProduct', 'Edit products', 'Products'),
    PermissionEntry('canDeleteProduct', 'Delete products', 'Products'),
    PermissionEntry('canAdjustStock', 'Adjust stock', 'Products'),
    // Operations
    PermissionEntry('canManagePurchaseOrders', 'Purchase orders', 'Operations'),
    PermissionEntry('canViewReports', 'View reports', 'Operations'),
    PermissionEntry('canViewRevenue', 'View revenue & financials', 'Operations'),
    PermissionEntry('canExportData', 'Export data', 'Operations'),
    // Team
    PermissionEntry('canInviteMembers', 'Invite members', 'Team'),
    PermissionEntry('canAddMembers', 'Add members', 'Team'),
    PermissionEntry('canMarkAttendance', 'Mark attendance', 'Team'),
    PermissionEntry('canViewOthersInvoices', 'View other members\' invoices', 'Invoices'),
  ];

  /// Returns the default value for a permission key on this role.
  bool defaultFor(String key) {
    switch (key) {
      case 'canCreateInvoice':
        return canCreateInvoice;
      case 'canEditInvoice':
        return canEditInvoice;
      case 'canDeleteInvoice':
        return canDeleteInvoice;
      case 'canRecordPayment':
        return canRecordPayment;
      case 'canAddCustomer':
        return canAddCustomer;
      case 'canEditCustomer':
        return canEditCustomer;
      case 'canDeleteCustomer':
        return canDeleteCustomer;
      case 'canAddProduct':
        return canAddProduct;
      case 'canEditProduct':
        return canEditProduct;
      case 'canDeleteProduct':
        return canDeleteProduct;
      case 'canAdjustStock':
        return canAdjustStock;
      case 'canManagePurchaseOrders':
        return canManagePurchaseOrders;
      case 'canViewReports':
        return canViewReports;
      case 'canViewRevenue':
        return canViewRevenue;
      case 'canExportData':
        return canExportData;
      case 'canEditProfile':
        return canEditProfile;
      case 'canManageSubscription':
        return canManageSubscription;
      case 'canInviteMembers':
        return canInviteMembers;
      case 'canRemoveMembers':
        return canRemoveMembers;
      case 'canChangeRoles':
        return canChangeRoles;
      case 'canAddMembers':
        return canAddMembers;
      case 'canMarkAttendance':
        return canMarkAttendance;
      case 'canViewOthersInvoices':
        return canViewOthersInvoices;
      default:
        return false;
    }
  }
}

/// A permission entry for the configurable permissions registry.
class PermissionEntry {
  const PermissionEntry(this.key, this.label, this.category);

  /// The permission key (e.g. 'canCreateInvoice').
  final String key;

  /// Human-readable label for the UI.
  final String label;

  /// Category for grouping in the settings UI.
  final String category;
}
