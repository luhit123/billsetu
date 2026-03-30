import 'dart:async';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/create_invoice_screen.dart';
import 'package:billeasy/screens/customer_form_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/widgets/balance_reminder_sheet.dart';
import 'package:billeasy/widgets/customer_groups_sheet.dart';
import 'package:billeasy/widgets/error_retry_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({super.key, required this.client});
  final Client client;

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final ClientService _clientService = ClientService();
  final FirebaseService _firebaseService = FirebaseService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );
  final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  static const int _invoicePageSize = 12;

  // Stream subscriptions replacing nested StreamBuilders
  StreamSubscription<Client?>? _clientSub;
  StreamSubscription<List<Invoice>>? _statsSub;

  // State driven by subscriptions
  Client? _client;
  String? _clientError;
  List<Invoice> _statsInvoices = const [];

  List<Invoice> _invoices = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _invoiceCursor;
  bool _hasMoreInvoices = true;
  bool _isLoadingInvoices = true;
  bool _isLoadingMoreInvoices = false;
  Object? _invoiceLoadError;

  @override
  void initState() {
    super.initState();
    _subscribeToStreams(widget.client.id);
    _loadInvoicePage(reset: true);
  }

  @override
  void didUpdateWidget(covariant CustomerDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client.id != widget.client.id) {
      _cancelSubscriptions();
      _subscribeToStreams(widget.client.id);
      _resetInvoices();
      _loadInvoicePage(reset: true);
    }
  }

  void _subscribeToStreams(String clientId) {
    _clientSub = _clientService.watchClient(clientId).listen(
      (client) {
        if (mounted) setState(() { _client = client; _clientError = null; });
      },
      onError: (e) {
        if (mounted) setState(() => _clientError = e.toString());
      },
    );
    _statsSub = _firebaseService
        .getInvoicesForClientStream(clientId)
        .listen(
      (invoices) {
        if (mounted) setState(() => _statsInvoices = invoices);
      },
      onError: (e) {
        // Stats stream errors are non-fatal; log via debugPrint so the UI
        // keeps showing the last known values rather than clearing them.
        debugPrint('[CustomerDetailsScreen] Stats stream error: $e');
      },
    );
  }

  void _cancelSubscriptions() {
    _clientSub?.cancel();
    _clientSub = null;
    _statsSub?.cancel();
    _statsSub = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = _client ?? widget.client;
    final s = AppStrings.of(context);
    final historyInvoices = _invoices;
    final isLoadingInvoices = _isLoadingInvoices && historyInvoices.isEmpty;

    final totalBilled = _statsInvoices.fold<double>(
      0,
      (total, invoice) => total + invoice.grandTotal,
    );
    final outstanding = _statsInvoices
        .where((invoice) => invoice.status != InvoiceStatus.paid)
        .fold<double>(0, (total, invoice) => total + invoice.grandTotal);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: _buildAppBar(s, client),
      bottomNavigationBar: _buildBottomBar(s, client),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_clientError != null && _client == null)
              ErrorRetryWidget(
                message: 'Could not load customer details.',
                onRetry: () {
                  _cancelSubscriptions();
                  _subscribeToStreams(widget.client.id);
                },
              ),
            _HeroCard(client: client),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStatCard(
                    label: s.customerDetailsStatInvoices,
                    value: _statsInvoices.length.toString(),
                    icon: Icons.receipt_long_rounded,
                    color: kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStatCard(
                    label: s.customerDetailsStatTotalBilled,
                    value: _currency.format(totalBilled),
                    icon: Icons.payments_rounded,
                    color: kPaid,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStatCard(
                    label: s.customerDetailsStatOutstanding,
                    value: _currency.format(outstanding),
                    icon: Icons.account_balance_wallet_rounded,
                    color: outstanding > 0 ? kOverdue : kPrimary,
                  ),
                ),
              ],
            ),
            // Outstanding balance reminder CTA
            if (outstanding > 0) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  final unpaid = _statsInvoices
                      .where((inv) => inv.status != InvoiceStatus.paid)
                      .toList();
                  _sendBalanceReminder(client, unpaid);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x30EF4444),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Send Payment Reminder',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_currency.format(outstanding)} outstanding',
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              title: s.customerDetailsContact,
              children: [
                _ContactRow(
                  icon: Icons.folder_rounded,
                  iconColor: const Color(0xFFFF9500),
                  label: s.customerDetailsGroup,
                  value: _valueOrFallback(client.groupName, s),
                ),
                _ContactRow(
                  icon: Icons.phone_rounded,
                  iconColor: const Color(0xFF34C759),
                  label: s.customerDetailsPhone,
                  value: _valueOrFallback(client.phone, s),
                ),
                if (client.email.trim().isNotEmpty)
                  _ContactRow(
                    icon: Icons.email_rounded,
                    iconColor: const Color(0xFF007AFF),
                    label: s.customerDetailsEmail,
                    value: client.email.trim(),
                  ),
                _ContactRow(
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFFFF2D55),
                  label: s.customerDetailsAddress,
                  value: _valueOrFallback(client.address, s),
                ),
              ],
            ),
            if (client.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: s.customerDetailsNotes,
                children: [
                  Text(
                    client.notes.trim(),
                    style: const TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ],
            if (client.updatedAt != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  s.customerDetailsLastUpdated(
                    _dateFmt.format(client.updatedAt!),
                  ),
                  style: const TextStyle(
                    color: kTextTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SectionCard(
              title: s.customerDetailsHistory,
              children: [
                if (_invoiceLoadError != null && historyInvoices.isEmpty)
                  ErrorRetryWidget(
                    message: s.customerDetailsHistoryError,
                    onRetry: () => _loadInvoicePage(reset: true),
                  )
                else if (isLoadingInvoices)
                  const Center(child: CircularProgressIndicator())
                else if (historyInvoices.isEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        color: kTextTertiary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.customerDetailsHistoryEmpty,
                          style: const TextStyle(
                            color: kOnSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  ...historyInvoices.map(
                    (invoice) => _HistoryInvoiceTile(
                      invoice: invoice,
                      currency: _currency,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              InvoiceDetailsScreen(invoice: invoice),
                        ),
                      ),
                      onStatusChange: (status) =>
                          _firebaseService.updateInvoiceStatus(invoice.id, status),
                      onDelete: () =>
                          _firebaseService.deleteInvoice(invoice.id),
                    ),
                  ),
                  if (_hasMoreInvoices || _isLoadingMoreInvoices) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed:
                            _isLoadingMoreInvoices || !_hasMoreInvoices
                            ? null
                            : () => _loadInvoicePage(reset: false),
                        child: Text(
                          _isLoadingMoreInvoices
                              ? 'Loading more...'
                              : 'Load more invoices',
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- AppBar ---

  void _resetInvoices() {
    _invoices = [];
    _invoiceCursor = null;
    _hasMoreInvoices = true;
    _isLoadingInvoices = true;
    _isLoadingMoreInvoices = false;
    _invoiceLoadError = null;
  }

  Future<void> _loadInvoicePage({required bool reset}) async {
    if (_isLoadingMoreInvoices) {
      return;
    }

    if (!reset && !_hasMoreInvoices) {
      return;
    }

    final clientId = widget.client.id;
    if (clientId.trim().isEmpty) {
      return;
    }

    if (reset) {
      setState(() {
        _resetInvoices();
      });
    } else {
      setState(() {
        _isLoadingMoreInvoices = true;
      });
    }

    try {
      final page = await _firebaseService.getInvoicesForClientPage(
        clientId,
        limit: _invoicePageSize,
        startAfterDocument: reset ? null : _invoiceCursor,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (reset) {
          _invoices = page.items;
        } else {
          _invoices = [..._invoices, ...page.items];
        }
        _invoiceCursor = page.cursor;
        _hasMoreInvoices = page.hasMore;
        _invoiceLoadError = null;
        _isLoadingInvoices = false;
        _isLoadingMoreInvoices = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _invoiceLoadError = error;
        _isLoadingInvoices = false;
        _isLoadingMoreInvoices = false;
      });
    }
  }

  PreferredSizeWidget _buildAppBar(AppStrings s, Client client) {
    final unpaidInvoices = _statsInvoices
        .where((inv) => inv.status != InvoiceStatus.paid)
        .toList();
    final hasOutstanding = unpaidInvoices.isNotEmpty;

    return AppBar(
      backgroundColor: kSurface,
      foregroundColor: kOnSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Text(
        s.customerDetailsTitle,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: kOnSurface,
        ),
      ),
      actions: [
        if (hasOutstanding)
          IconButton(
            onPressed: () => _sendBalanceReminder(client, unpaidInvoices),
            tooltip: 'Send balance reminder',
            icon: const Icon(Icons.notifications_active_outlined, color: kOverdue),
          ),
        IconButton(
          onPressed: () => _editCustomer(client),
          tooltip: s.customerDetailsEditTooltip,
          icon: const Icon(Icons.edit_outlined, color: kOnSurfaceVariant),
        ),
        IconButton(
          onPressed: () => _moveCustomerToGroup(client),
          tooltip: client.groupId.isEmpty
              ? s.customerDetailsMoveGroup
              : s.customerDetailsChangeGroup,
          icon: const Icon(Icons.folder_open_rounded, color: kOnSurfaceVariant),
        ),
      ],
    );
  }

  // --- Bottom CTA ---

  Widget _buildBottomBar(AppStrings s, Client client) {
    return Container(
      color: kSurfaceLowest,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _createInvoiceForCustomer(client),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: Text(s.customerDetailsCreateInvoice),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Actions (logic unchanged) ---

  Future<void> _editCustomer(Client client) async {
    await Navigator.push<Client>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(initialClient: client),
      ),
    );
  }

  Future<void> _createInvoiceForCustomer(Client client) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateInvoiceScreen(initialClient: client),
      ),
    );
  }

  Future<void> _moveCustomerToGroup(Client client) async {
    final selection = await showCustomerGroupPickerSheet(
      context,
      initialGroupId: client.groupId,
    );
    if (!mounted || selection == null) {
      return;
    }
    if (selection.groupId == client.groupId &&
        selection.groupName == client.groupName) {
      return;
    }

    try {
      final updated = await _clientService.updateClientGroup(
        client: client,
        groupId: selection.groupId,
        groupName: selection.groupName,
      );
      if (!mounted) return;
      final s = AppStrings.of(context);
      final msg = updated.groupName.trim().isEmpty
          ? s.customerDetailsNowUngrouped(updated.name)
          : s.customerDetailsMovedToGroup(updated.name, updated.groupName);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(
              context,
            ).customerDetailsFailedUpdateGroup(error.toString()),
          ),
        ),
      );
    }
  }

  void _sendBalanceReminder(Client client, List<Invoice> unpaidInvoices) {
    final outstanding = unpaidInvoices.fold<double>(
      0,
      (total, inv) => total + inv.grandTotal,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FutureBuilder(
        future: ProfileService().getCurrentProfile(),
        builder: (ctx, snap) => BalanceReminderSheet(
          client: client,
          unpaidInvoices: unpaidInvoices,
          totalOutstanding: outstanding,
          upiId: snap.data?.upiId,
          businessName: snap.data?.storeName,
        ),
      ),
    );
  }

  String _valueOrFallback(String value, AppStrings s) {
    final t = value.trim();
    return t.isEmpty ? s.customerDetailsNotAdded : t;
  }
}

// =========================================================================
// Widgets
// =========================================================================

/// Large avatar + name + subtitle on a clean white card.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [kWhisperShadow],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            child: Text(
              client.initials,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: const TextStyle(
                    color: kOnSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (client.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    client.subtitle,
                    style: const TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (client.groupName.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      client.groupName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact stat card used in the 3-column row.
class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: kOnSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kOnSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// White card with a section title and arbitrary children.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [kWhisperShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kOnSurface,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: kOutlineVariant.withAlpha(51)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// A single contact info row with icon + label + value.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = kPrimary,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: kOnSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kOnSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Invoice tile inside the history section.
class _HistoryInvoiceTile extends StatelessWidget {
  const _HistoryInvoiceTile({
    required this.invoice,
    required this.currency,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
  });
  final Invoice invoice;
  final NumberFormat currency;
  final VoidCallback onTap;
  final void Function(InvoiceStatus) onStatusChange;
  final VoidCallback onDelete;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 7) {
      final w = (diff.inDays / 7).floor();
      return '$w week${w > 1 ? 's' : ''} ago';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final (badgeColor, badgeBg, label) = switch (invoice.effectiveStatus) {
      InvoiceStatus.paid => (kPaid, kPaidBg, 'PAID'),
      InvoiceStatus.pending => (const Color(0xFFEF4444), const Color(0xFFFEE2E2), 'UNPAID'),
      InvoiceStatus.overdue => (kOverdue, kOverdueBg, 'OVERDUE'),
      InvoiceStatus.partiallyPaid => (const Color(0xFFEAB308), const Color(0xFFFEF3C7), 'PARTIAL'),
    };
    final s = AppStrings.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context, s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kPrimaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_rounded,
                size: 16,
                color: kPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kOnSurface,
                    ),
                  ),
                  Text(
                    _timeAgo(invoice.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: kTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(invoice.grandTotal),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kOnSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context, AppStrings s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (invoice.status != InvoiceStatus.paid)
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: kPaid),
                title: Text(s.cardMarkPaid),
                onTap: () {
                  Navigator.pop(context);
                  onStatusChange(InvoiceStatus.paid);
                },
              ),
            if (invoice.status != InvoiceStatus.overdue)
              ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: kOverdue,
                ),
                title: Text(s.cardMarkOverdue),
                onTap: () {
                  Navigator.pop(context);
                  onStatusChange(InvoiceStatus.overdue);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: kOverdue),
              title: Text(s.cardDelete),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
