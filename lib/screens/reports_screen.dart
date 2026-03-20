import 'dart:async';

import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/screens/upgrade_screen.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF4361EE);
const _kNavy = Color(0xFF1E3A8A);
const _kTeal = Color(0xFF6366F1);
const _kBackground = Color(0xFFEFF6FF);
const _kBorder = Color(0xFFBDD5F0);
const _kLabel = Color(0xFF5B7A9A);
const _kTitle = Color(0xFF1E3A8A);
const _kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1E3A8A), Color(0xFF4361EE), Color(0xFF6366F1)],
);

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _subscribeRevenue();
    _subscribeReceivables();
    _subscribeProducts();
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
    if (days <= 30) return _kTeal;
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
        appBar: AppBar(title: const Text('Reports')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Color(0xFFBDD5F0)),
                const SizedBox(height: 16),
                const Text('Reports & Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                const SizedBox(height: 8),
                const Text('Upgrade to Maharaja plan to access detailed reports.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF5B7A9A))),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen(featureName: 'Reports'))),
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Upgrade Now'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _kGradient),
        ),
        title: const Text(
          'Financial Reports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Revenue'),
            Tab(text: 'Receivables'),
            Tab(text: 'Products'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRevenueTab(),
          _buildReceivablesTab(),
          _buildProductsTab(),
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
                                  ? _kNavy
                                  : _kBackground,
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
                                      : _kLabel,
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
                                color: _kTitle,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _currencyFmt.format(entry.value),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kPrimary,
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
                          backgroundColor: _kBackground,
                          valueColor:
                              const AlwaysStoppedAnimation(_kTeal),
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
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: selected ? _kGradient : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: selected ? Colors.transparent : _kBorder,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _kNavy.withValues(alpha: 0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _kLabel,
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
                            color: _kLabel,
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
                              bucket.value > 0 ? color : _kLabel,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: _kNavy.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
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
                      color: _kTitle,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    inv.invoiceNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kLabel,
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
                  color: _kLabel,
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
                                ? _kNavy
                                : _kBackground,
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
                                    : _kLabel,
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
                                  color: _kTitle,
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
                            color: _kPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(
                      height: 1,
                      color: _kBackground,
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

  Widget _statPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: _kLabel,
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
    Color color = _kPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _kGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _kNavy.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
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
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            _currencyFmt.format(value),
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
              color: _kTeal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kTeal,
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
        valueColor: AlwaysStoppedAnimation(_kTeal),
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
                color: _kTitle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _kLabel),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
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

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
                color: _kBackground,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder, width: 1.5),
              ),
              child: Icon(icon, size: 36, color: _kLabel),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kTitle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _kLabel),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDeco() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder, width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0E0F4A75),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    );
