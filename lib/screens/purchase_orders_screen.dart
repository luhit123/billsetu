import 'dart:async';

import 'package:billeasy/modals/purchase_order.dart';
import 'package:billeasy/screens/create_purchase_order_screen.dart';
import 'package:billeasy/screens/purchase_order_details_screen.dart';
import 'package:billeasy/services/purchase_order_service.dart';
import 'package:billeasy/widgets/error_retry_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── Brand tokens ─────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF4361EE);
const _kBackground = Color(0xFFEFF6FF);
const _kTextPrimary = Color(0xFF1E3A8A);
const _kTextSecondary = Color(0xFF5B7A9A);

const _kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1E3A8A), Color(0xFF4361EE), Color(0xFF6366F1)],
);

// Status colours
const _kDraft = Color(0xFF6B7280);
const _kDraftBg = Color(0xFFF3F4F6);
const _kConfirmed = Color(0xFFF59E0B);
const _kConfirmedBg = Color(0xFFFEF3C7);
const _kReceived = Color(0xFF22C55E);
const _kReceivedBg = Color(0xFFDCFCE7);
const _kCancelled = Color(0xFFEF4444);
const _kCancelledBg = Color(0xFFFEE2E2);

enum _Filter { all, draft, sent, received, cancelled }

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _svc = PurchaseOrderService();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _searchCtrl = TextEditingController();

  bool _searching = false;
  String _query = '';
  _Filter _filter = _Filter.all;
  Timer? _searchDebounce;

  // ── Stream-based state ───────────────────────────────────────────────────
  List<PurchaseOrder> _allOrders = [];
  bool _isLoading = true;
  Object? _loadError;
  StreamSubscription<List<PurchaseOrder>>? _orderSub;

  List<PurchaseOrder> get _filtered {
    var list = _allOrders;
    list = switch (_filter) {
      _Filter.all => list,
      _Filter.draft =>
        list.where((o) => o.status == PurchaseOrderStatus.draft).toList(),
      _Filter.sent =>
        list.where((o) => o.status == PurchaseOrderStatus.confirmed).toList(),
      _Filter.received =>
        list.where((o) => o.status == PurchaseOrderStatus.received).toList(),
      _Filter.cancelled =>
        list.where((o) => o.status == PurchaseOrderStatus.cancelled).toList(),
    };
    final q = _query.toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (o) =>
              o.supplierName.toLowerCase().contains(q) ||
              o.orderNumber.toLowerCase().contains(q),
        )
        .toList();
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
    _orderSub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _orderSub?.cancel();
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _orderSub = _svc.getPurchaseOrdersStream(limit: 200).listen(
      (orders) {
        if (!mounted) return;
        setState(() {
          _allOrders = orders;
          _isLoading = false;
          _loadError = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _loadError = e;
          _isLoading = false;
        });
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _subscribe(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Summary strip
              SliverToBoxAdapter(
                child: _SummaryStrip(orders: _allOrders, currency: _currency),
              ),
              // Filter chips
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _chip(_Filter.all, 'All'),
                      const SizedBox(width: 6),
                      _chip(_Filter.draft, 'Draft'),
                      const SizedBox(width: 6),
                      _chip(_Filter.sent, 'Sent'),
                      const SizedBox(width: 6),
                      _chip(_Filter.received, 'Received'),
                      const SizedBox(width: 6),
                      _chip(_Filter.cancelled, 'Cancelled'),
                    ],
                  ),
                ),
              ),
              // Content
              if (_loadError != null && _allOrders.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorRetryWidget(
                    message:
                        'Could not load purchase orders.\nCheck your connection and try again.',
                    onRetry: _subscribe,
                  ),
                )
              else if (_isLoading && _allOrders.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.shopping_cart_outlined,
                              color: _kPrimary,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _allOrders.isEmpty
                                ? 'No purchase orders yet'
                                : 'No orders match this filter',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (_allOrders.isEmpty)
                            const Text(
                              'Create your first PO',
                              style: TextStyle(
                                color: _kTextSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final order = filtered[i];
                        return _POTile(
                          order: order,
                          currency: _currency,
                          dateFmt: _dateFmt,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PurchaseOrderDetailsScreen(order: order),
                              ),
                            );
                          },
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'po-fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatePurchaseOrderScreen()),
        ),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New PO'),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
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
              decoration: const InputDecoration(
                hintText: 'Search orders…',
                hintStyle: TextStyle(color: Colors.white60),
                border: InputBorder.none,
              ),
              onChanged: _handleSearchChanged,
            )
          : const Text(
              'Purchase Orders',
              style: TextStyle(
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

  // ── Filter chip ───────────────────────────────────────────────────────────

  Widget _chip(_Filter f, String label) {
    final active = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
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

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.orders, required this.currency});
  final List<PurchaseOrder> orders;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final draft = orders
        .where((o) => o.status == PurchaseOrderStatus.draft)
        .length;
    final sent = orders
        .where((o) => o.status == PurchaseOrderStatus.confirmed)
        .length;
    final receivedValue = orders
        .where((o) => o.status == PurchaseOrderStatus.received)
        .fold<double>(0, (s, o) => s + o.subtotal);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
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
          _SummaryCell(label: 'Draft', value: '$draft POs', color: _kDraft),
          _VertDivider(),
          _SummaryCell(
            label: 'Sent',
            value: '$sent POs',
            color: _kConfirmed,
          ),
          _VertDivider(),
          _SummaryCell(
            label: 'Received',
            value: currency.format(receivedValue),
            color: _kReceived,
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

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFE5E7EB));
  }
}

// PO list tile
class _POTile extends StatelessWidget {
  const _POTile({
    required this.order,
    required this.currency,
    required this.dateFmt,
    required this.onTap,
  });

  final PurchaseOrder order;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (badgeColor, badgeBg, statusLabel) = switch (order.status) {
      PurchaseOrderStatus.draft => (_kDraft, _kDraftBg, 'DRAFT'),
      PurchaseOrderStatus.confirmed => (_kConfirmed, _kConfirmedBg, 'SENT'),
      PurchaseOrderStatus.received => (_kReceived, _kReceivedBg, 'RECEIVED'),
      PurchaseOrderStatus.cancelled => (
          _kCancelled,
          _kCancelledBg,
          'CANCELLED'
        ),
    };

    final itemCount = order.items.length;
    final itemLabel = '$itemCount ${itemCount == 1 ? 'item' : 'items'}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
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
                Icons.shopping_cart_outlined,
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
                    order.supplierName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${order.orderNumber} · ${dateFmt.format(order.createdAt)} · $itemLabel',
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
                  currency.format(order.subtotal),
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
}
