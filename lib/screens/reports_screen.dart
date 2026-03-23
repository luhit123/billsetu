import 'dart:async';
import 'dart:math' as math;

import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/purchase_order.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/screens/upgrade_screen.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/purchase_order_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Status colours (kept as semantic)
const _kPaid = Color(0xFF22C55E);
const _kPaidBg = Color(0xFFDCFCE7);
const _kAmber = Color(0xFFF59E0B);
const _kAmberBg = Color(0xFFFEF3C7);
const _kRed = Color(0xFFEF4444);
const _kRedBg = Color(0xFFFEE2E2);

// ── Period enum ───────────────────────────────────────────────────────────────
enum _ReportPeriod { thisMonth, last3Months, thisYear, allTime }

// ── Product aggregation model ─────────────────────────────────────────────────
class _ProductStat {
  _ProductStat(this.name);
  final String name;
  int timesInvoiced = 0;
  double totalQty = 0;
  double totalRevenue = 0;
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firebaseService = FirebaseService();
  final _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  // ── Revenue tab state ──────────────────────────────────────────────────────
  _ReportPeriod _period = _ReportPeriod.thisMonth;
  StreamSubscription<List<Invoice>>? _revenueSub;
  List<Invoice> _revenueInvoices = [];
  bool _revenueLoading = true;
  Object? _revenueError;

  // ── Receivables tab state ──────────────────────────────────────────────────
  StreamSubscription<List<Invoice>>? _receivablesSub;
  List<Invoice> _receivablesInvoices = [];
  bool _receivablesLoading = true;
  Object? _receivablesError;

  // ── Products tab state ─────────────────────────────────────────────────────
  StreamSubscription<List<Invoice>>? _productsSub;
  List<Invoice> _productsInvoices = [];
  bool _productsLoading = true;
  Object? _productsError;

  // ── Profit & Loss tab state ───────────────────────────────────────────────
  List<PurchaseOrder> _purchaseOrders = [];
  bool _purchaseOrdersLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _subscribeRevenue();
    _subscribeReceivables();
    _subscribeProducts();
    _loadPurchaseOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _revenueSub?.cancel();
    _receivablesSub?.cancel();
    _productsSub?.cancel();
    super.dispose();
  }

  // ── Date range helpers ─────────────────────────────────────────────────────

  (DateTime?, DateTime?) get _dateRange {
    final now = DateTime.now();
    switch (_period) {
      case _ReportPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return (start, end);
      case _ReportPeriod.last3Months:
        final end = DateTime(now.year, now.month + 1, 1);
        final start = DateTime(now.year, now.month - 2, 1);
        return (start, end);
      case _ReportPeriod.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1);
        return (start, end);
      case _ReportPeriod.allTime:
        return (null, null);
    }
  }

  // ── Subscriptions ──────────────────────────────────────────────────────────

  void _subscribeRevenue() {
    _revenueSub?.cancel();
    final (start, end) = _dateRange;
    setState(() {
      _revenueLoading = true;
      _revenueError = null;
    });
    _revenueSub = _firebaseService
        .getInvoicesStream(
          startDate: start,
          endDateExclusive: end,
          limit: 500,
        )
        .listen(
          (invoices) {
            if (!mounted) return;
            setState(() {
              _revenueInvoices = invoices;
              _revenueLoading = false;
            });
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _revenueError = e;
              _revenueLoading = false;
            });
          },
        );
  }

  void _subscribeReceivables() {
    _receivablesSub?.cancel();
    setState(() {
      _receivablesLoading = true;
      _receivablesError = null;
    });
    _receivablesSub = _firebaseService
        .getInvoicesStream(limit: 500)
        .listen(
          (invoices) {
            if (!mounted) return;
            setState(() {
              _receivablesInvoices = invoices
                  .where(
                    (inv) =>
                        inv.status == InvoiceStatus.pending ||
                        inv.status == InvoiceStatus.overdue,
                  )
                  .toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              _receivablesLoading = false;
            });
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _receivablesError = e;
              _receivablesLoading = false;
            });
          },
        );
  }

  void _subscribeProducts() {
    _productsSub?.cancel();
    setState(() {
      _productsLoading = true;
      _productsError = null;
    });
    _productsSub = _firebaseService
        .getInvoicesStream(limit: 500)
        .listen(
          (invoices) {
            if (!mounted) return;
            setState(() {
              _productsInvoices = invoices;
              _productsLoading = false;
            });
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _productsError = e;
              _productsLoading = false;
            });
          },
        );
  }

  // ── Purchase orders for Profit & Loss ──────────────────────────────────────

  Future<void> _loadPurchaseOrders() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final (start, end) = _dateRange;
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('purchaseOrders')
          .orderBy('createdAt', descending: true);
      if (start != null) {
        q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      }
      if (end != null) {
        q = q.where('createdAt', isLessThan: Timestamp.fromDate(end));
      }
      final snap = await q.limit(500).get();
      if (!mounted) return;
      setState(() {
        _purchaseOrders = snap.docs
            .map((d) => PurchaseOrder.fromMap(d.data(), docId: d.id))
            .where((po) => po.status == PurchaseOrderStatus.received)
            .toList();
        _purchaseOrdersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _purchaseOrdersLoading = false);
    }
  }

  // ── Product aggregation ────────────────────────────────────────────────────

  List<_ProductStat> _aggregateProducts() {
    final map = <String, _ProductStat>{};
    for (final inv in _productsInvoices) {
      for (final item in inv.items) {
        final key = item.description.trim().toLowerCase();
        final stat = map.putIfAbsent(key, () => _ProductStat(item.description));
        stat.timesInvoiced += 1;
        stat.totalQty += item.quantity;
        stat.totalRevenue += item.total;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return list;
  }

  // ── Age bucket helper ──────────────────────────────────────────────────────

  int _daysOld(Invoice inv) {
    return DateTime.now().difference(inv.createdAt).inDays;
  }

  String _ageBucketLabel(int days) {
    if (days <= 30) return '0–30 days';
    if (days <= 60) return '31–60 days';
    if (days <= 90) return '61–90 days';
    return '90+ days';
  }

  Color _ageBucketColor(int days) {
    if (days <= 30) return kPrimary;
    if (days <= 60) return _kAmber;
    if (days <= 90) return const Color(0xFFEA580C);
    return _kRed;
  }

  // ── Top customers ─────────────────────────────────────────────────────────

  List<MapEntry<String, double>> _top5Customers() {
    final map = <String, double>{};
    for (final inv in _revenueInvoices) {
      map.update(
        inv.clientName,
        (v) => v + inv.grandTotal,
        ifAbsent: () => inv.grandTotal,
      );
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!PlanService.instance.hasReports) {
      return Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          title: const Text('Reports'),
          backgroundColor: kSurface,
          foregroundColor: kOnSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: kSurfaceDim),
                const SizedBox(height: 16),
                const Text('Reports & Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kOnSurface)),
                const SizedBox(height: 8),
                const Text('Upgrade to Maharaja plan to access detailed reports.', textAlign: TextAlign.center, style: TextStyle(color: kOnSurfaceVariant)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen(featureName: 'Reports'))),
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Upgrade Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: kOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Financial Reports',
          style: TextStyle(
            color: kOnSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kPrimary,
          indicatorWeight: 3,
          labelColor: kOnSurface,
          unselectedLabelColor: kOnSurfaceVariant,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Revenue'),
            Tab(text: 'Receivables'),
            Tab(text: 'Party-wise'),
            Tab(text: 'Products'),
            Tab(text: 'Profit & Loss'),
            Tab(text: 'Sales Trend'),
            Tab(text: 'Top Sellers'),
            Tab(text: 'Cash Flow'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRevenueTab(),
          _buildReceivablesTab(),
          _buildPartyWiseTab(),
          _buildProductsTab(),
          _buildProfitLossTab(),
          _buildSalesTrendTab(),
          _buildTopSellersTab(),
          _buildCashFlowTab(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 — Revenue Summary
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRevenueTab() {
    if (_revenueLoading) return _loadingWidget();
    if (_revenueError != null) {
      return _errorWidget('$_revenueError', _subscribeRevenue);
    }

    final invoices = _revenueInvoices;
    final totalRevenue =
        invoices.fold<double>(0, (acc, inv) => acc + inv.grandTotal);
    final collected = invoices
        .where((inv) => inv.status == InvoiceStatus.paid)
        .fold<double>(0, (acc, inv) => acc + inv.grandTotal);
    final outstanding = totalRevenue - collected;
    final top5 = _top5Customers();
    final maxTop5 =
        top5.isEmpty ? 1.0 : top5.first.value.clamp(1.0, double.infinity);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Period picker
        _buildPeriodPicker(),
        const SizedBox(height: 16),

        // Total revenue hero card
        _heroCard(
          label: 'Total Revenue',
          value: totalRevenue,
          icon: Icons.trending_up_rounded,
          subtitle:
              '${invoices.length} invoice${invoices.length == 1 ? '' : 's'}',
        ),
        const SizedBox(height: 12),

        // Collected vs Outstanding
        Row(
          children: [
            Expanded(
              child: _miniStatCard(
                label: 'Collected',
                value: collected,
                color: _kPaid,
                bgColor: _kPaidBg,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _miniStatCard(
                label: 'Outstanding',
                value: outstanding,
                color: _kAmber,
                bgColor: _kAmberBg,
                icon: Icons.hourglass_empty_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Payment Status Visual ──
        if (invoices.isNotEmpty) ...[
          _sectionLabel('Payment Status'),
          _buildPaymentStatusChart(invoices),
          const SizedBox(height: 16),

          // ── Monthly Revenue Bars ──
          _sectionLabel('Monthly Breakdown'),
          _buildMonthlyRevenueChart(invoices),
          const SizedBox(height: 16),

          // ── Collection Rate ──
          _sectionLabel('Collection Rate'),
          _buildCollectionRateCard(collected, totalRevenue),
          const SizedBox(height: 16),
        ],

        // Top 5 Customers
        if (top5.isNotEmpty) ...[
          _sectionLabel('Top Customers'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Column(
              children: top5.asMap().entries.map((e) {
                final rank = e.key + 1;
                final entry = e.value;
                final barFraction = entry.value / maxTop5;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: rank < top5.length ? 14 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: rank == 1
                                  ? kPrimary
                                  : kSurfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '$rank',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: rank == 1
                                      ? Colors.white
                                      : kOnSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kOnSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _currencyFmt.format(entry.value),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: barFraction,
                          minHeight: 5,
                          backgroundColor: kSurfaceContainerLow,
                          valueColor:
                              const AlwaysStoppedAnimation(kPrimary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        if (invoices.isEmpty) ...[
          const SizedBox(height: 20),
          _emptyState(
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF5856D6),
            title: 'No revenue data',
            subtitle: 'No invoices found for this period.',
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Period picker widget ────────────────────────────────────────────────────

  Widget _buildPeriodPicker() {
    const periods = [
      (_ReportPeriod.thisMonth, 'This Month'),
      (_ReportPeriod.last3Months, 'Last 3 Months'),
      (_ReportPeriod.thisYear, 'This Year'),
      (_ReportPeriod.allTime, 'All Time'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((entry) {
          final (period, label) = entry;
          final selected = _period == period;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (_period == period) return;
                setState(() => _period = period);
                _subscribeRevenue();
                _loadPurchaseOrders();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? kPrimary : kSurfaceLowest,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : kOnSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — Outstanding Receivables
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildReceivablesTab() {
    if (_receivablesLoading) return _loadingWidget();
    if (_receivablesError != null) {
      return _errorWidget('$_receivablesError', _subscribeReceivables);
    }

    final invoices = _receivablesInvoices;
    final total =
        invoices.fold<double>(0, (acc, inv) => acc + inv.grandTotal);

    // Age buckets
    final buckets = <String, double>{
      '0–30 days': 0,
      '31–60 days': 0,
      '61–90 days': 0,
      '90+ days': 0,
    };
    for (final inv in invoices) {
      final days = _daysOld(inv);
      final key = _ageBucketLabel(days);
      buckets[key] = (buckets[key] ?? 0) + inv.grandTotal;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Summary
        _heroCard(
          label: 'Total Outstanding',
          value: total,
          icon: Icons.account_balance_wallet_outlined,
          subtitle:
              '${invoices.length} invoice${invoices.length == 1 ? '' : 's'} unpaid',
          color: _kAmber,
        ),
        const SizedBox(height: 16),

        // Age buckets
        if (invoices.isNotEmpty) ...[
          _sectionLabel('Age Analysis'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Column(
              children: buckets.entries.toList().asMap().entries.map((e) {
                final i = e.key;
                final bucket = e.value;
                final color = _ageBucketColor(
                  switch (bucket.key) {
                    '0–30 days' => 15,
                    '31–60 days' => 45,
                    '61–90 days' => 75,
                    _ => 100,
                  },
                );
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i < buckets.length - 1 ? 14 : 0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bucket.key,
                          style: const TextStyle(
                            fontSize: 13,
                            color: kOnSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        _currencyFmt.format(bucket.value),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              bucket.value > 0 ? color : kOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Unpaid Invoices (Oldest First)'),
          ...invoices.map((inv) => _receivableInvoiceTile(inv)),
        ],

        if (invoices.isEmpty)
          _emptyState(
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF34C759),
            title: 'All caught up!',
            subtitle: 'No outstanding receivables at the moment.',
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _receivableInvoiceTile(Invoice inv) {
    final days = _daysOld(inv);
    final isOverdue = inv.status == InvoiceStatus.overdue;
    final color = isOverdue ? _kRed : _kAmber;
    final bgColor = isOverdue ? _kRedBg : _kAmberBg;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailsScreen(invoice: inv),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [kSubtleShadow],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inv.clientName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kOnSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    inv.invoiceNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kOnSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOverdue
                          ? '$days day${days == 1 ? '' : 's'} overdue'
                          : '$days day${days == 1 ? '' : 's'} old',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFmt.format(inv.grandTotal),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: kOnSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 — Product Performance
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildProductsTab() {
    if (_productsLoading) return _loadingWidget();
    if (_productsError != null) {
      return _errorWidget('$_productsError', _subscribeProducts);
    }

    final stats = _aggregateProducts();

    if (stats.isEmpty) {
      return _emptyState(
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFFFF9500),
        title: 'No product data yet',
        subtitle: 'Create invoices with line items to see product performance.',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _sectionLabel('Products by Revenue'),
        Container(
          decoration: _cardDeco(),
          child: Column(
            children: stats.asMap().entries.map((e) {
              final i = e.key;
              final stat = e.value;
              final isLast = i == stats.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? kPrimary
                                : kSurfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: i == 0
                                    ? Colors.white
                                    : kOnSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kOnSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _statPill(
                                    '${stat.timesInvoiced}x invoiced',
                                  ),
                                  const SizedBox(width: 6),
                                  _statPill(
                                    'Qty: ${_formatQty(stat.totalQty)}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _currencyFmt.format(stat.totalRevenue),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(
                      height: 1,
                      color: kSurfaceContainerLow,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 — Party-wise Outstanding
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPartyWiseTab() {
    if (_receivablesLoading) return _loadingWidget();
    if (_receivablesError != null) {
      return _errorWidget('$_receivablesError', _subscribeReceivables);
    }

    // Aggregate outstanding by customer
    final partyMap = <String, _PartyOutstanding>{};
    for (final inv in _receivablesInvoices) {
      final name = inv.clientName.isEmpty ? 'Unknown' : inv.clientName;
      final party = partyMap.putIfAbsent(name, () => _PartyOutstanding(name));
      party.totalOutstanding += inv.grandTotal;
      party.invoiceCount += 1;
      final days = DateTime.now().difference(inv.createdAt).inDays;
      if (days > party.oldestDays) party.oldestDays = days;
      party.invoices.add(inv);
    }

    final parties = partyMap.values.toList()
      ..sort((a, b) => b.totalOutstanding.compareTo(a.totalOutstanding));

    if (parties.isEmpty) {
      return _emptyState(
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF34C759),
        title: 'No outstanding dues!',
        subtitle: 'All your customers have paid up.',
      );
    }

    final grandTotal = parties.fold<double>(0, (s, p) => s + p.totalOutstanding);
    final maxParty = parties.first.totalOutstanding.clamp(1.0, double.infinity);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _heroCard(
          label: 'Total Receivables',
          value: grandTotal,
          icon: Icons.people_outline_rounded,
          subtitle: '${parties.length} customer${parties.length == 1 ? '' : 's'} with dues',
          color: _kAmber,
        ),
        const SizedBox(height: 16),
        _sectionLabel('Customer-wise Breakdown'),
        ...parties.map((party) {
          final barFraction = party.totalOutstanding / maxParty;
          final urgencyColor = party.oldestDays > 90
              ? _kRed
              : party.oldestDays > 30
                  ? _kAmber
                  : kPrimary;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurfaceLowest,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        party.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kOnSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _currencyFmt.format(party.totalOutstanding),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: urgencyColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barFraction,
                    minHeight: 5,
                    backgroundColor: kSurfaceContainerLow,
                    valueColor: AlwaysStoppedAnimation(urgencyColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statPill('${party.invoiceCount} invoice${party.invoiceCount == 1 ? '' : 's'}'),
                    const SizedBox(width: 6),
                    _statPill('Oldest: ${party.oldestDays}d'),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 5 — Profit & Loss
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildProfitLossTab() {
    if (_revenueLoading || _purchaseOrdersLoading) return _loadingWidget();

    final totalSales = _revenueInvoices.fold<double>(0, (s, inv) => s + inv.grandTotal);
    final totalPurchases = _purchaseOrders.fold<double>(0, (s, po) => s + po.grandTotal);
    final grossProfit = totalSales - totalPurchases;
    final margin = totalSales > 0 ? (grossProfit / totalSales * 100) : 0.0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _buildPeriodPicker(),
        const SizedBox(height: 16),

        // Gross Profit Hero
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: grossProfit >= 0 ? kSignatureGradient : const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [kWhisperShadow],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grossProfit >= 0 ? 'Gross Profit' : 'Net Loss',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currencyFmt.format(grossProfit.abs()),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${margin.toStringAsFixed(1)}% margin',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  grossProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 30, color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Sales vs Purchases visual bar
        _sectionLabel('Breakdown'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Column(
            children: [
              _plRow('Total Sales (Revenue)', totalSales, kPrimary, Icons.arrow_upward_rounded),
              const SizedBox(height: 14),
              _plRow('Total Purchases (Cost)', totalPurchases, const Color(0xFFEF4444), Icons.arrow_downward_rounded),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(height: 1, color: kSurfaceContainerLow),
              ),
              _plRow(
                grossProfit >= 0 ? 'Gross Profit' : 'Net Loss',
                grossProfit.abs(),
                grossProfit >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                grossProfit >= 0 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Visual comparison bar
        if (totalSales > 0 || totalPurchases > 0) ...[
          _sectionLabel('Visual Comparison'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Column(
              children: [
                _visualBar('Sales', totalSales, kPrimary, totalSales, totalPurchases),
                const SizedBox(height: 12),
                _visualBar('Purchases', totalPurchases, const Color(0xFFEF4444), totalSales, totalPurchases),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Summary stats
        Row(
          children: [
            Expanded(
              child: _miniStatCard(
                label: 'Invoices',
                value: _revenueInvoices.length.toDouble(),
                color: kPrimary,
                bgColor: kPrimaryContainer,
                icon: Icons.receipt_long_rounded,
                isCount: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _miniStatCard(
                label: 'Purchase Orders',
                value: _purchaseOrders.length.toDouble(),
                color: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFEDE9FE),
                icon: Icons.inventory_2_outlined,
                isCount: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _plRow(String label, double value, Color color, IconData icon, {bool bold = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: kOnSurface,
            ),
          ),
        ),
        Text(
          _currencyFmt.format(value),
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _visualBar(String label, double value, Color color, double sales, double purchases) {
    final maxVal = math.max(sales, purchases).clamp(1.0, double.infinity);
    final fraction = value / maxVal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
            const Spacer(),
            Text(_currencyFmt.format(value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 12,
            backgroundColor: kSurfaceContainerLow,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VISUAL CHARTS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPaymentStatusChart(List<Invoice> invoices) {
    final paid = invoices.where((i) => i.status == InvoiceStatus.paid).length;
    final pending = invoices.where((i) => i.status == InvoiceStatus.pending).length;
    final overdue = invoices.where((i) => i.status == InvoiceStatus.overdue).length;
    final total = invoices.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _DonutChartPainter(
                segments: [
                  _DonutSegment(paid / total, _kPaid),
                  _DonutSegment(pending / total, _kAmber),
                  _DonutSegment(overdue / total, _kRed),
                ],
              ),
              child: Center(
                child: Text(
                  '$total',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kOnSurface),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendRow('Paid', paid, _kPaid),
                const SizedBox(height: 10),
                _legendRow('Pending', pending, _kAmber),
                const SizedBox(height: 10),
                _legendRow('Overdue', overdue, _kRed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kOnSurfaceVariant)),
        const Spacer(),
        Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildMonthlyRevenueChart(List<Invoice> invoices) {
    // Group invoices by month
    final monthMap = <String, double>{};
    for (final inv in invoices) {
      final key = '${inv.createdAt.year}-${inv.createdAt.month.toString().padLeft(2, '0')}';
      monthMap[key] = (monthMap[key] ?? 0) + inv.grandTotal;
    }

    if (monthMap.isEmpty) return const SizedBox.shrink();

    final sortedKeys = monthMap.keys.toList()..sort();
    final maxVal = monthMap.values.fold<double>(0, (a, b) => math.max(a, b)).clamp(1.0, double.infinity);
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: sortedKeys.map((key) {
          final parts = key.split('-');
          final monthIdx = int.parse(parts[1]) - 1;
          final label = '${monthNames[monthIdx]} ${parts[0].substring(2)}';
          final value = monthMap[key]!;
          final fraction = value / maxVal;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 16,
                          backgroundColor: kSurfaceContainerLow,
                          valueColor: const AlwaysStoppedAnimation(kPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 65,
                      child: Text(
                        _currencyFmt.format(value),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOnSurface),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCollectionRateCard(double collected, double total) {
    final rate = total > 0 ? (collected / total * 100) : 0.0;
    final rateColor = rate >= 80 ? _kPaid : rate >= 50 ? _kAmber : _kRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: _RingChartPainter(
                fraction: rate / 100,
                color: rateColor,
                bgColor: rateColor.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  '${rate.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: rateColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Collection Rate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kOnSurface)),
                const SizedBox(height: 4),
                Text(
                  '${_currencyFmt.format(collected)} of ${_currencyFmt.format(total)} collected',
                  style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  rate >= 80 ? 'Excellent collection!' : rate >= 50 ? 'Follow up on pending invoices' : 'Needs attention — many unpaid invoices',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: rateColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: kOnSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toStringAsFixed(0);
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  Widget _heroCard({
    required String label,
    required double value,
    required IconData icon,
    required String subtitle,
    Color color = kPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: kSignatureGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [kWhisperShadow],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currencyFmt.format(value),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _miniStatCard({
    required String label,
    required double value,
    required Color color,
    required Color bgColor,
    required IconData icon,
    bool isCount = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            isCount ? value.toInt().toString() : _currencyFmt.format(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kPrimary,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingWidget() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(kPrimary),
      ),
    );
  }

  Widget _errorWidget(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: _kRed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kOnSurfaceVariant),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 6 — Sales Trend
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSalesTrendTab() {
    if (_revenueLoading) return _loadingWidget();
    if (_revenueError != null) {
      return _errorWidget('$_revenueError', _subscribeRevenue);
    }

    final invoices = _revenueInvoices;
    if (invoices.isEmpty) {
      return _emptyState(
        icon: Icons.show_chart_rounded,
        iconColor: const Color(0xFF3B82F6),
        title: 'No sales data',
        subtitle: 'Create invoices to see your sales trend.',
      );
    }

    // Group by day
    final dayFormat = DateFormat('dd MMM');
    final dayMap = <String, double>{};
    final dayKeys = <String, DateTime>{};
    for (final inv in invoices) {
      final key = DateFormat('yyyy-MM-dd').format(inv.createdAt);
      dayMap[key] = (dayMap[key] ?? 0) + inv.grandTotal;
      dayKeys.putIfAbsent(key, () => inv.createdAt);
    }
    final sortedDays = dayMap.keys.toList()..sort();

    // Group by week
    final weekMap = <String, double>{};
    for (final inv in invoices) {
      final weekStart = inv.createdAt.subtract(Duration(days: inv.createdAt.weekday - 1));
      final key = DateFormat('dd MMM').format(weekStart);
      weekMap[key] = (weekMap[key] ?? 0) + inv.grandTotal;
    }
    final sortedWeeks = weekMap.keys.toList();

    // Group by month
    final monthMap = <String, double>{};
    for (final inv in invoices) {
      final key = DateFormat('MMM yy').format(inv.createdAt);
      monthMap[key] = (monthMap[key] ?? 0) + inv.grandTotal;
    }

    // Calculate growth
    final totalRevenue = invoices.fold<double>(0, (s, i) => s + i.grandTotal);
    final avgDaily = sortedDays.isNotEmpty ? totalRevenue / sortedDays.length : 0.0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _buildPeriodPicker(),
        const SizedBox(height: 16),

        // Summary cards
        Row(
          children: [
            Expanded(
              child: _miniStatCard(
                label: 'Total Revenue',
                value: totalRevenue,
                color: kPrimary,
                bgColor: kPrimaryContainer,
                icon: Icons.trending_up_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _miniStatCard(
                label: 'Avg / Day',
                value: avgDaily,
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFDBEAFE),
                icon: Icons.calendar_today_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Daily trend line chart (visual bars)
        _sectionLabel('Daily Revenue'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Column(
            children: () {
              final maxVal = dayMap.values.fold<double>(0, (a, b) => a > b ? a : b).clamp(1.0, double.infinity);
              final recentDays = sortedDays.length > 14 ? sortedDays.sublist(sortedDays.length - 14) : sortedDays;
              return recentDays.map((key) {
                final value = dayMap[key]!;
                final fraction = value / maxVal;
                final label = dayFormat.format(dayKeys[key]!);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 14,
                            backgroundColor: kSurfaceContainerLow,
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: Text(
                          _currencyFmt.format(value),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kOnSurface),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            }(),
          ),
        ),
        const SizedBox(height: 16),

        // Monthly breakdown
        if (monthMap.length > 1) ...[
          _sectionLabel('Monthly Trend'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Column(
              children: () {
                final maxVal = monthMap.values.fold<double>(0, (a, b) => a > b ? a : b).clamp(1.0, double.infinity);
                return monthMap.entries.map((e) {
                  final fraction = e.value / maxVal;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 16,
                              backgroundColor: kSurfaceContainerLow,
                              valueColor: const AlwaysStoppedAnimation(kPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 65,
                          child: Text(
                            _currencyFmt.format(e.value),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOnSurface),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              }(),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 7 — Top Sellers (Best/Slow Movers)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTopSellersTab() {
    if (_productsLoading) return _loadingWidget();
    if (_productsError != null) {
      return _errorWidget('$_productsError', _subscribeProducts);
    }

    final stats = _aggregateProducts();
    if (stats.isEmpty) {
      return _emptyState(
        icon: Icons.star_outline_rounded,
        iconColor: const Color(0xFFFF9500),
        title: 'No product data',
        subtitle: 'Create invoices to see your best and slow sellers.',
      );
    }

    final topSellers = stats.take(10).toList();
    final slowMovers = stats.length > 5 ? stats.reversed.take(5).toList() : <_ProductStat>[];
    final totalRevenue = stats.fold<double>(0, (s, p) => s + p.totalRevenue);
    final maxRev = topSellers.isNotEmpty ? topSellers.first.totalRevenue.clamp(1.0, double.infinity) : 1.0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Top sellers header
        _heroCard(
          label: 'Product Revenue',
          value: totalRevenue,
          icon: Icons.star_rounded,
          subtitle: '${stats.length} product${stats.length == 1 ? '' : 's'} sold',
        ),
        const SizedBox(height: 16),

        // Best sellers
        _sectionLabel('Best Sellers'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDeco(),
          child: Column(
            children: topSellers.asMap().entries.map((e) {
              final rank = e.key + 1;
              final p = e.value;
              final barFraction = p.totalRevenue / maxRev;
              final share = totalRevenue > 0 ? (p.totalRevenue / totalRevenue * 100) : 0.0;

              return Padding(
                padding: EdgeInsets.only(bottom: rank < topSellers.length ? 12 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: rank <= 3 ? kPrimary : kSurfaceContainerLow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '$rank',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: rank <= 3 ? Colors.white : kOnSurfaceVariant),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurface), overflow: TextOverflow.ellipsis),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_currencyFmt.format(p.totalRevenue), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
                            Text('${share.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: barFraction,
                        minHeight: 4,
                        backgroundColor: kSurfaceContainerLow,
                        valueColor: const AlwaysStoppedAnimation(kPrimary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _statPill('${p.timesInvoiced}x sold'),
                        const SizedBox(width: 6),
                        _statPill('Qty: ${_formatQty(p.totalQty)}'),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Slow movers
        if (slowMovers.isNotEmpty) ...[
          _sectionLabel('Slow Movers'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kRedBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              children: slowMovers.asMap().entries.map((e) {
                final p = e.value;
                final isLast = e.key == slowMovers.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_down_rounded, size: 16, color: _kRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurface), overflow: TextOverflow.ellipsis),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_currencyFmt.format(p.totalRevenue), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kRed)),
                          Text('${p.timesInvoiced}x sold', style: const TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // WhatsApp share button
        _buildWhatsAppShareButton('Top Sellers Report', () {
          final buf = StringBuffer('*Top Sellers Report*\n\n');
          for (var i = 0; i < topSellers.length; i++) {
            final p = topSellers[i];
            buf.writeln('${i + 1}. ${p.name}');
            buf.writeln('   Revenue: ${_currencyFmt.format(p.totalRevenue)}  |  Qty: ${_formatQty(p.totalQty)}');
          }
          if (slowMovers.isNotEmpty) {
            buf.writeln('\n*Slow Movers:*');
            for (final p in slowMovers) {
              buf.writeln('- ${p.name}: ${_currencyFmt.format(p.totalRevenue)}');
            }
          }
          return buf.toString();
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 8 — Cash Flow Statement
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCashFlowTab() {
    if (_revenueLoading || _purchaseOrdersLoading) return _loadingWidget();

    final invoices = _revenueInvoices;
    final pos = _purchaseOrders;

    final totalInflow = invoices
        .where((i) => i.status == InvoiceStatus.paid)
        .fold<double>(0, (s, i) => s + i.grandTotal);
    final totalPending = invoices
        .where((i) => i.status != InvoiceStatus.paid)
        .fold<double>(0, (s, i) => s + i.grandTotal);
    final totalOutflow = pos.fold<double>(0, (s, po) => s + po.grandTotal);
    final netCashFlow = totalInflow - totalOutflow;

    // Monthly cash flow
    final monthlyIn = <String, double>{};
    final monthlyOut = <String, double>{};
    for (final inv in invoices.where((i) => i.status == InvoiceStatus.paid)) {
      final key = DateFormat('MMM yy').format(inv.createdAt);
      monthlyIn[key] = (monthlyIn[key] ?? 0) + inv.grandTotal;
    }
    for (final po in pos) {
      final key = DateFormat('MMM yy').format(po.createdAt);
      monthlyOut[key] = (monthlyOut[key] ?? 0) + po.grandTotal;
    }
    final allMonths = {...monthlyIn.keys, ...monthlyOut.keys}.toList()..sort();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _buildPeriodPicker(),
        const SizedBox(height: 16),

        // Net Cash Flow hero
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: netCashFlow >= 0
                ? kSignatureGradient
                : const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [kWhisperShadow],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Net Cash Flow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      _currencyFmt.format(netCashFlow.abs()),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        netCashFlow >= 0 ? 'Positive Cash Flow' : 'Negative Cash Flow',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  netCashFlow >= 0 ? Icons.account_balance_wallet_rounded : Icons.warning_rounded,
                  size: 30,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Inflow / Outflow / Pending cards
        Row(
          children: [
            Expanded(
              child: _miniStatCard(
                label: 'Inflow (Paid)',
                value: totalInflow,
                color: _kPaid,
                bgColor: _kPaidBg,
                icon: Icons.arrow_downward_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _miniStatCard(
                label: 'Outflow (Cost)',
                value: totalOutflow,
                color: _kRed,
                bgColor: _kRedBg,
                icon: Icons.arrow_upward_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _miniStatCard(
          label: 'Pending Receivables',
          value: totalPending,
          color: _kAmber,
          bgColor: _kAmberBg,
          icon: Icons.hourglass_empty_rounded,
        ),
        const SizedBox(height: 16),

        // Monthly cash flow breakdown
        if (allMonths.isNotEmpty) ...[
          _sectionLabel('Monthly Cash Flow'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _cardDeco(),
            child: Column(
              children: allMonths.map((month) {
                final inVal = monthlyIn[month] ?? 0;
                final outVal = monthlyOut[month] ?? 0;
                final net = inVal - outVal;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(month, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kOnSurface)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: net >= 0 ? _kPaidBg : _kRedBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${net >= 0 ? '+' : ''}${_currencyFmt.format(net)}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: net >= 0 ? _kPaid : _kRed),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('In', style: TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                                Text(_currencyFmt.format(inVal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kPaid)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Out', style: TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                                Text(_currencyFmt.format(outVal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kRed)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // WhatsApp share
        _buildWhatsAppShareButton('Cash Flow Report', () {
          final buf = StringBuffer('*Cash Flow Report*\n\n');
          buf.writeln('Net Cash Flow: ${_currencyFmt.format(netCashFlow)}');
          buf.writeln('Inflow (Paid): ${_currencyFmt.format(totalInflow)}');
          buf.writeln('Outflow (Cost): ${_currencyFmt.format(totalOutflow)}');
          buf.writeln('Pending: ${_currencyFmt.format(totalPending)}');
          if (allMonths.isNotEmpty) {
            buf.writeln('\n*Monthly Breakdown:*');
            for (final month in allMonths) {
              final inVal = monthlyIn[month] ?? 0;
              final outVal = monthlyOut[month] ?? 0;
              buf.writeln('$month: In ${_currencyFmt.format(inVal)} | Out ${_currencyFmt.format(outVal)}');
            }
          }
          return buf.toString();
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── WhatsApp Share Button ──────────────────────────────────────────────────

  Widget _buildWhatsAppShareButton(String reportName, String Function() contentBuilder) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              final text = contentBuilder();
              final encoded = Uri.encodeComponent(text);
              final whatsappUrl = Uri.parse('https://wa.me/?text=$encoded');
              launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Share via WhatsApp', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            final text = contentBuilder();
            SharePlus.instance.share(ShareParams(text: text, subject: reportName));
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.share_rounded, size: 18, color: kOnSurfaceVariant),
          ),
        ),
      ],
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
  }) {
    final effectiveColor = iconColor ?? kOnSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: effectiveColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kOnSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Party outstanding model ────────────────────────────────────────────────────
class _PartyOutstanding {
  _PartyOutstanding(this.name);
  final String name;
  double totalOutstanding = 0;
  int invoiceCount = 0;
  int oldestDays = 0;
  final List<Invoice> invoices = [];
}

BoxDecoration _cardDeco() => BoxDecoration(
      color: kSurfaceLowest,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [kSubtleShadow],
    );

// ── Donut Chart Painter ─────────────────────────────────────────────────────

class _DonutSegment {
  _DonutSegment(this.fraction, this.color);
  final double fraction;
  final Color color;
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.segments});
  final List<_DonutSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Background ring
    paint.color = kSurfaceContainerLow;
    canvas.drawArc(rect.deflate(7), 0, 2 * math.pi, false, paint);

    // Segments
    double startAngle = -math.pi / 2;
    for (final seg in segments) {
      if (seg.fraction <= 0) continue;
      final sweepAngle = seg.fraction * 2 * math.pi;
      paint.color = seg.color;
      canvas.drawArc(rect.deflate(7), startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Ring Chart Painter ──────────────────────────────────────────────────────

class _RingChartPainter extends CustomPainter {
  _RingChartPainter({required this.fraction, required this.color, required this.bgColor});
  final double fraction;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    paint.color = bgColor;
    canvas.drawArc(rect.deflate(4), 0, 2 * math.pi, false, paint);

    paint.color = color;
    canvas.drawArc(rect.deflate(4), -math.pi / 2, fraction.clamp(0, 1) * 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
