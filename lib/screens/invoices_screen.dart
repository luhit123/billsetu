import 'dart:async';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/widgets/empty_state_widget.dart';
import 'package:billeasy/widgets/error_retry_widget.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/create_invoice_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─── Shared brand colours (onboarding-inspired palette) ──────────────────────
const _kPrimary = Color(0xFF4361EE);
const _kBackground = Color(0xFFEFF6FF);
const _kTextPrimary = Color(0xFF1E3A8A);
const _kTextSecondary = Color(0xFF5B7A9A);
const _kCardBg = Colors.white;
const _kPaid = Color(0xFF22C55E);
const _kPaidBg = Color(0xFFDCFCE7);
const _kPending = Color(0xFFF59E0B);
const _kPendingBg = Color(0xFFFEF3C7);
const _kOverdue = Color(0xFFEF4444);
const _kOverdueBg = Color(0xFFFEE2E2);
const _kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1E3A8A), Color(0xFF4361EE), Color(0xFF6366F1)],
);

enum _Filter { all, paid, pending, overdue }

enum _Period { allTime, today, thisWeek, currentMonth, customRange }

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final _monthFmt = DateFormat('MMMM yyyy');
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _searchCtrl = TextEditingController();

  bool _searching = false;
  String _query = '';
  _Filter _filter = _Filter.all;
  _Period _period = _Period.allTime;
  DateTimeRange? _customRange;
  Timer? _searchDebounce;

  // ── Stream-based state (replaces Future pagination) ───────────────────────
  // All invoices from Firestore for the current period — unfiltered.
  List<Invoice> _allInvoices = [];
  bool _isLoading = true;
  Object? _loadError;
  StreamSubscription<List<Invoice>>? _invoiceSub;

  /// Status + search applied in-memory — zero network calls.
  List<Invoice> get _filtered {
    var list = _allInvoices;
    list = switch (_filter) {
      _Filter.all     => list,
      _Filter.paid    => list.where((i) => i.status == InvoiceStatus.paid).toList(),
      _Filter.pending => list.where((i) => i.status == InvoiceStatus.pending).toList(),
      _Filter.overdue => list.where((i) => i.status == InvoiceStatus.overdue).toList(),
    };
    final q = _query.toLowerCase();
    if (q.isEmpty) return list;
    return list.where((i) =>
      i.clientName.toLowerCase().contains(q) ||
      i.invoiceNumber.toLowerCase().contains(q),
    ).toList();
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _invoiceSub?.cancel();
    super.dispose();
  }

  /// Creates (or re-creates) the Firestore stream for the current period.
  /// Only called when the date period actually changes — not on filter/search.
  void _subscribe() {
    _invoiceSub?.cancel();
    final bounds = _periodBounds;
    setState(() { _isLoading = true; _loadError = null; });
    _invoiceSub = _firebaseService
        .getInvoicesStream(
          startDate: bounds?.$1,
          endDateExclusive: bounds?.$2,
          limit: 200, // generous cap; offline cache makes this instant after first load
        )
        .listen(
          (invoices) {
            if (!mounted) return;
            setState(() {
              _allInvoices = invoices;
              _isLoading = false;
              _loadError = null;
            });
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() { _loadError = e; _isLoading = false; });
          },
        );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final filtered = _filtered; // in-memory — zero network cost

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: _buildAppBar(s),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _subscribe(), // re-subscribe re-fetches
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _SummaryStrip(invoices: _allInvoices, currency: _currency),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _showPeriodSheet(s),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _kCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 15,
                              color: _kPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _periodLabel(s),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _kTextPrimary,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Row(
                        children: [
                          _chip(_Filter.all, s.homeFilterAll),
                          const SizedBox(width: 6),
                          _chip(_Filter.paid, s.homeFilterPaid),
                          const SizedBox(width: 6),
                          _chip(_Filter.pending, s.homeFilterPending),
                          const SizedBox(width: 6),
                          _chip(_Filter.overdue, s.homeFilterOverdue),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_loadError != null && _allInvoices.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorRetryWidget(
                    message: 'Could not load invoices.\nCheck your connection and try again.',
                    onRetry: _subscribe,
                  ),
                )
              else if (_isLoading && _allInvoices.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _allInvoices.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.receipt_long_outlined,
                          title: 'No invoices yet',
                          subtitle: 'Create your first invoice to get started',
                          actionLabel: 'Create Invoice',
                          iconColor: _kPrimary,
                          onAction: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateInvoiceScreen(),
                            ),
                          ),
                        )
                      : EmptyStateWidget(
                          icon: Icons.filter_list_off_rounded,
                          title: 'No matching invoices',
                          subtitle: s.homeNoInvoicesFilter,
                          iconColor: _kPrimary,
                        ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final inv = filtered[i];
                      return _InvoiceTile(
                        invoice: inv,
                        currency: _currency,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvoiceDetailsScreen(invoice: inv),
                          ),
                        ),
                        onStatusChange: (st) =>
                            _firebaseService.updateInvoiceStatus(inv.id, st),
                        onDelete: () => _firebaseService.deleteInvoice(inv.id),
                      );
                    }, childCount: filtered.length),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'invoices-fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
        ),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(AppStrings.of(context).homeCreateInvoice),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(AppStrings s) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: _kGradient),
      ),
      title: _searching
          ? TextField(
              controller: _searchCtrl,
              autofocus: true,
              cursorColor: Colors.white,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: s.homeSearchHint,
                hintStyle: const TextStyle(color: Colors.white60),
                border: InputBorder.none,
              ),
              onChanged: _handleSearchChanged,
            )
          : Text(
              s.invoicesScreenTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
      actions: [
        IconButton(
          onPressed: () {
            _searchDebounce?.cancel();
            setState(() {
              if (_searching) {
                _searchCtrl.clear();
                _query = '';
                _searching = false;
                // No reload — filter clears in-memory instantly.
              } else {
                _searching = true;
              }
            });
          },
          icon: Icon(
            _searching ? Icons.close_rounded : Icons.search_rounded,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ─── Filter chip ──────────────────────────────────────────────────────────

  Widget _chip(_Filter f, String label) {
    final active = _filter == f;
    return GestureDetector(
      onTap: () {
        // Status filter is applied in-memory on _allInvoices — no Firestore round-trip.
        setState(() => _filter = f);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _kPrimary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _kTextSecondary,
          ),
        ),
      ),
    );
  }

  // ─── Logic ────────────────────────────────────────────────────────────────

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      // Filter applied in-memory on _allInvoices — no Firestore round-trip.
      setState(() => _query = value.trim());
    });
  }

  (DateTime, DateTime)? get _periodBounds {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _Period.allTime:
        return null;
      case _Period.today:
        return (today, today.add(const Duration(days: 1)));
      case _Period.thisWeek:
        final start = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        return (start, start.add(const Duration(days: 7)));
      case _Period.currentMonth:
        return (
          DateTime(now.year, now.month),
          DateTime(now.year, now.month + 1),
        );
      case _Period.customRange:
        final r = _customRange;
        if (r == null) return null;
        return (
          DateTime(r.start.year, r.start.month, r.start.day),
          DateTime(r.end.year, r.end.month, r.end.day + 1),
        );
    }
  }

  String _periodLabel(AppStrings s) {
    switch (_period) {
      case _Period.allTime:
        return s.homePeriodAllInvoices;
      case _Period.today:
        return s.homePeriodToday;
      case _Period.thisWeek:
        return s.homePeriodThisWeek;
      case _Period.currentMonth:
        return _monthFmt.format(DateTime.now());
      case _Period.customRange:
        final r = _customRange;
        if (r == null) return s.homePeriodCustomRange;
        return s.homePeriodDateRange(
          _dateFmt.format(r.start),
          _dateFmt.format(r.end),
        );
    }
  }

  Future<void> _showPeriodSheet(AppStrings s) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _periodTile(s.homePeriodAllInvoices, _Period.allTime, ctx),
            _periodTile(s.homePeriodToday, _Period.today, ctx),
            _periodTile(s.homePeriodThisWeek, _Period.thisWeek, ctx),
            _periodTile(
              _monthFmt.format(DateTime.now()),
              _Period.currentMonth,
              ctx,
            ),
            _periodTile(
              _customRange == null
                  ? s.homePeriodCustomRange
                  : s.homePeriodCustomLabel(
                      _dateFmt.format(_customRange!.start),
                      _dateFmt.format(_customRange!.end),
                    ),
              _Period.customRange,
              ctx,
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodTile(String label, _Period p, BuildContext sheetCtx) {
    final sel = _period == p;
    return ListTile(
      leading: Icon(
        sel ? Icons.radio_button_checked : Icons.radio_button_off,
        color: sel ? _kPrimary : Colors.grey.shade500,
      ),
      title: Text(
        label,
        style: TextStyle(fontWeight: sel ? FontWeight.w700 : FontWeight.w500),
      ),
      onTap: () async {
        Navigator.of(sheetCtx).pop();
        _searchDebounce?.cancel();
        if (p == _Period.customRange) {
          await _pickRange();
        } else {
          setState(() => _period = p);
          _subscribe(); // re-subscribes with new date bounds
        }
      },
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial =
        _customRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initial,
      saveText: AppStrings.of(context).homeDateApply,
    );
    if (picked == null) return;
    _searchDebounce?.cancel();
    setState(() {
      _customRange = picked;
      _period = _Period.customRange;
    });
    _subscribe(); // re-subscribes with new date bounds
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

/// Three summary numbers at the top of the invoices page.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.invoices, required this.currency});
  final List<Invoice> invoices;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final paid = invoices
        .where((i) => i.status == InvoiceStatus.paid)
        .fold<double>(0, (s, i) => s + i.grandTotal);
    final pending = invoices
        .where((i) => i.status == InvoiceStatus.pending)
        .fold<double>(0, (s, i) => s + i.grandTotal);
    final overdue = invoices
        .where((i) => i.status == InvoiceStatus.overdue)
        .fold<double>(0, (s, i) => s + i.grandTotal);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _SummaryCell(
            label: 'Paid',
            value: currency.format(paid),
            color: _kPaid,
          ),
          _Divider(),
          _SummaryCell(
            label: 'Pending',
            value: currency.format(pending),
            color: _kPending,
          ),
          _Divider(),
          _SummaryCell(
            label: 'Overdue',
            value: currency.format(overdue),
            color: _kOverdue,
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFE5E7EB));
  }
}

/// Invoice row card matching the dashboard tile style.
class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
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
    final (badgeColor, badgeBg, statusLabel) = switch (invoice.status) {
      InvoiceStatus.paid => (_kPaid, _kPaidBg, 'PAID'),
      InvoiceStatus.pending => (_kPending, _kPendingBg, 'PENDING'),
      InvoiceStatus.overdue => (_kOverdue, _kOverdueBg, 'OVERDUE'),
    };

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _kPrimary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.description_rounded,
                size: 20,
                color: _kPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.clientName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${invoice.invoiceNumber} · ${_timeAgo(invoice.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(invoice.grandTotal),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                      letterSpacing: 0.5,
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

  void _showActions(BuildContext context) {
    final s = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (invoice.status != InvoiceStatus.paid)
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: _kPaid),
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
                  color: _kOverdue,
                ),
                title: Text(s.cardMarkOverdue),
                onTap: () {
                  Navigator.pop(context);
                  onStatusChange(InvoiceStatus.overdue);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: _kOverdue),
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

