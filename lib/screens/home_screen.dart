import 'dart:async';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/analytics_models.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/create_invoice_screen.dart';
import 'package:billeasy/screens/customers_screen.dart';
import 'package:billeasy/screens/gst_report_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/screens/invoices_screen.dart';
import 'package:billeasy/screens/reports_screen.dart';
import 'package:billeasy/screens/products_screen.dart';
import 'package:billeasy/screens/purchase_orders_screen.dart';
import 'package:billeasy/screens/create_purchase_order_screen.dart';
import 'package:billeasy/screens/login_screen.dart';
import 'package:billeasy/screens/profile_setup_screen.dart';
import 'package:billeasy/screens/settings_screen.dart';
import 'package:billeasy/screens/subscriptions_screen.dart';
import 'package:billeasy/modals/product.dart';
import 'package:billeasy/services/analytics_service.dart';
import 'package:billeasy/services/auth_service.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/remote_config_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/connectivity_banner.dart';
import 'package:billeasy/widgets/error_retry_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget homescreen() => const HomeScreen();

enum InvoiceFilter { all, paid, pending, overdue }

enum InvoicePeriodFilter { allTime, today, thisWeek, currentMonth, customRange }

// ─── Shell: manages tab index + bottom nav ────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.invoicesStream});
  final Stream<List<Invoice>>? invoicesStream;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _DashboardPage(invoicesStream: widget.invoicesStream),
      const InvoicesScreen(),
      const CustomersScreen(),
      const ProductsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const ConnectivityBanner(),
              Expanded(
                child: IndexedStack(index: _selectedTab, children: _tabs),
              ),
            ],
          ),
          _DraggableFab(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(s),
    );
  }

  Widget _buildBottomNav(AppStrings s) {
    return Container(
      decoration: const BoxDecoration(
        color: kSurfaceLowest,
        boxShadow: [kWhisperShadow],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _BottomNavItem(
              icon: Icons.home_rounded,
              label: s.homeBottomHome,
              isActive: _selectedTab == 0,
              activeColor: const Color(0xFF007AFF),
              onTap: () => setState(() => _selectedTab = 0),
            ),
            _BottomNavItem(
              icon: Icons.receipt_long_rounded,
              label: s.homeBottomInvoices,
              isActive: _selectedTab == 1,
              activeColor: const Color(0xFF5856D6),
              onTap: () => setState(() => _selectedTab = 1),
            ),
            _BottomNavItem(
              icon: Icons.people_alt_rounded,
              label: s.homeBottomClients,
              isActive: _selectedTab == 2,
              activeColor: const Color(0xFF34C759),
              onTap: () => setState(() => _selectedTab = 2),
            ),
            _BottomNavItem(
              icon: Icons.inventory_2_rounded,
              label: s.homeBottomProducts,
              isActive: _selectedTab == 3,
              activeColor: const Color(0xFFFF9500),
              onTap: () => setState(() => _selectedTab = 3),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard page (tab 0) ────────────────────────────────────────────────────

class _DashboardPage extends StatefulWidget {
  const _DashboardPage({this.invoicesStream});
  final Stream<List<Invoice>>? invoicesStream;

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  final FirebaseService _firebaseService = FirebaseService();
  AnalyticsService? _analyticsService;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
    decimalDigits: 0,
  );

  // Streams & subscriptions
  StreamSubscription<List<Invoice>>? _invoicesSub;
  StreamSubscription<DashboardAnalytics?>? _analyticsSub;

  // State
  List<Invoice> _allInvoices = [];
  bool _invoicesLoading = true;
  Object? _invoicesError;
  DashboardAnalytics? _analytics;

  List<Product> _lowStockProducts = [];
  bool _lowStockLoading = true;

  // Revenue helpers
  double _currentMonthRevenue = 0;
  double _previousMonthRevenue = 0;

  late AppStrings _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = AppStrings.of(context);
  }

  @override
  void initState() {
    super.initState();
    _subscribeToInvoices();
    _subscribeToAnalytics();
    _loadLowStockProducts();
  }

  @override
  void dispose() {
    _invoicesSub?.cancel();
    _analyticsSub?.cancel();
    super.dispose();
  }

  // ─── Data ──────────────────────────────────────────────────────────────────

  void _subscribeToInvoices() {
    if (Firebase.apps.isEmpty) {
      _invoicesLoading = false;
      return;
    }
    _invoicesSub?.cancel();
    final stream = widget.invoicesStream ??
        _firebaseService.getInvoicesStream(limit: 50);
    _invoicesSub = stream.listen(
      (invoices) {
        if (!mounted) return;
        setState(() {
          _allInvoices = invoices;
          _invoicesLoading = false;
          _invoicesError = null;
          _computeMonthlyRevenue();
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _invoicesError = e;
          _invoicesLoading = false;
        });
      },
    );
  }

  void _subscribeToAnalytics() {
    if (Firebase.apps.isEmpty) return;
    _analyticsService ??= AnalyticsService();
    _analyticsSub?.cancel();
    _analyticsSub = _analyticsService!.watchDashboardSummary().listen(
      (data) {
        if (!mounted) return;
        setState(() => _analytics = data);
      },
      onError: (_) {},
    );
  }

  Future<void> _loadLowStockProducts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _lowStockLoading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('products')
          .where('trackInventory', isEqualTo: true)
          .limit(200)
          .get();
      if (!mounted) return;
      final products = snap.docs
          .map((d) => Product.fromMap(d.data(), docId: d.id))
          .where((p) => p.currentStock <= p.minStockAlert && p.minStockAlert > 0)
          .toList()
        ..sort((a, b) => a.currentStock.compareTo(b.currentStock));
      setState(() {
        _lowStockProducts = products;
        _lowStockLoading = false;
      });
    } catch (e) {
      debugPrint('[HomeScreen] Low stock load error: $e');
      if (!mounted) return;
      setState(() => _lowStockLoading = false);
    }
  }

  void _computeMonthlyRevenue() {
    final now = DateTime.now();
    _currentMonthRevenue = _allInvoices
        .where((inv) =>
            inv.status == InvoiceStatus.paid &&
            inv.createdAt.year == now.year &&
            inv.createdAt.month == now.month)
        .fold<double>(0, (s, inv) => s + inv.grandTotal);

    final prevMonth = DateTime(now.year, now.month - 1);
    _previousMonthRevenue = _allInvoices
        .where((inv) =>
            inv.status == InvoiceStatus.paid &&
            inv.createdAt.year == prevMonth.year &&
            inv.createdAt.month == prevMonth.month)
        .fold<double>(0, (s, inv) => s + inv.grandTotal);
  }

  Future<void> _handleRefresh() async {
    _subscribeToInvoices();
    _subscribeToAnalytics();
    _loadLowStockProducts();
    // Allow streams to emit at least one value
    await Future.delayed(const Duration(milliseconds: 600));
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  double get _totalOutstanding {
    final a = _analytics;
    if (a != null) return a.totalOutstanding;
    return _allInvoices
        .where((inv) => inv.status != InvoiceStatus.paid)
        .fold<double>(0, (s, inv) => s + inv.balanceDue);
  }

  double get _totalPaid {
    final a = _analytics;
    if (a != null) return a.totalCollected;
    return _allInvoices
        .where((inv) => inv.status == InvoiceStatus.paid)
        .fold<double>(0, (s, inv) => s + inv.grandTotal);
  }

  double get _totalPending {
    final a = _analytics;
    if (a != null) {
      // totalOutstanding includes both pending + overdue;
      // pending-only = totalOutstanding - overdue portion
      final overdueAmt = _allInvoices
          .where((inv) => inv.status == InvoiceStatus.overdue)
          .fold<double>(0, (s, inv) => s + inv.grandTotal);
      return a.totalOutstanding - overdueAmt;
    }
    return _allInvoices
        .where((inv) => inv.status == InvoiceStatus.pending)
        .fold<double>(0, (s, inv) => s + inv.grandTotal);
  }

  double get _totalOverdue {
    return _allInvoices
        .where((inv) => inv.status == InvoiceStatus.overdue)
        .fold<double>(0, (s, inv) => s + inv.grandTotal);
  }

  int get _pendingCount {
    final a = _analytics;
    if (a != null) return a.pendingInvoices;
    return _allInvoices.where((i) => i.status == InvoiceStatus.pending).length;
  }

  int get _overdueCount {
    final a = _analytics;
    if (a != null) return a.overdueInvoices;
    return _allInvoices.where((i) => i.status == InvoiceStatus.overdue).length;
  }

  List<Invoice> get _overdueInvoices =>
      _allInvoices.where((i) => i.status == InvoiceStatus.overdue).toList();

  List<Invoice> get _recentInvoices {
    final sorted = _allInvoices.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(3).toList();
  }

  String _avatarLabel(User? user) {
    final source = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.trim();
    if (source == null || source.isEmpty) return 'G';
    return source.characters.first.toUpperCase();
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 7) {
      final w = (diff.inDays / 7).floor();
      return '$w week${w > 1 ? 's' : ''} ago';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h ago';
    } else {
      return 'Just now';
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_invoicesError != null) {
      return Scaffold(
        backgroundColor: kSurface,
        body: ErrorRetryWidget(
          message: _s.homeLoadError,
          onRetry: _subscribeToInvoices,
        ),
      );
    }

    if (_invoicesLoading && _allInvoices.isEmpty) {
      return const Scaffold(
        backgroundColor: kSurface,
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: kSurface,
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          slivers: [
            // 1. SliverAppBar
            _buildSliverAppBar(),

            // 2. Hero Card
            SliverToBoxAdapter(child: _buildHeroCard()),

            // 3. Status Strip
            SliverToBoxAdapter(child: _buildStatusStrip()),

            // 4. Overdue Alert (conditional)
            if (_overdueCount > 0)
              SliverToBoxAdapter(child: _buildOverdueAlert()),

            // 5. Quick Actions
            SliverToBoxAdapter(child: _buildQuickActions()),

            // 6. Revenue Card
            SliverToBoxAdapter(child: _buildRevenueCard()),

            // 7. Low Stock Banner (conditional)
            if (!_lowStockLoading && _lowStockProducts.isNotEmpty)
              SliverToBoxAdapter(child: _buildLowStockBanner()),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ─── Section Builders ─────────────────────────────────────────────────────

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: kSurface,
      foregroundColor: kOnSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: const Text(
        'BillRaja',
        style: TextStyle(
          color: kOnSurface,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.4,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.settings_outlined, color: kOnSurfaceVariant),
          tooltip: 'Settings',
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Firebase.apps.isEmpty
              ? const _AvatarWidget(label: 'G')
              : StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  initialData: FirebaseAuth.instance.currentUser,
                  builder: (context, snap) =>
                      _AvatarWidget(label: _avatarLabel(snap.data)),
                ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InvoicesScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: BoxDecoration(
          gradient: kSignatureGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Decorative circles for depth
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                right: 30,
                bottom: -40,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Outstanding',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(_totalOutstanding),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_pendingCount pending  \u00B7  $_overdueCount overdue',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _buildStatusChip(
            color: kPaid,
            label: _s.homeFilterPaid,
            amount: _totalPaid,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoicesScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusChip(
            color: kPending,
            label: _s.homeFilterPending,
            amount: _totalPending,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoicesScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusChip(
            color: kOverdue,
            label: _s.homeFilterOverdue,
            amount: _totalOverdue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoicesScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required Color color,
    required String label,
    required double amount,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: kSurfaceLowest,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [kSubtleShadow],
            border: Border(
              left: BorderSide(color: color, width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: kOnSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currencyFormat.format(amount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kOnSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverdueAlert() {
    final overdue = _overdueInvoices;
    final topClients = overdue
        .map((i) => i.clientName)
        .toSet()
        .take(2)
        .join(', ');
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InvoicesScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kOverdueBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kOverdue.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: kOverdue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${overdue.length} invoice${overdue.length > 1 ? 's' : ''} overdue \u2014 ${_currencyFormat.format(_totalOverdue)} at risk',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kOverdue,
                    ),
                  ),
                  if (topClients.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      topClients,
                      style: TextStyle(
                        fontSize: 11,
                        color: kOverdue.withValues(alpha: 0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: kOverdue),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(children: [Row(
        children: [
          _buildQuickAction(
            icon: Icons.add_circle_outline_rounded,
            label: _s.homeCreateInvoice,
            highlighted: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickAction(
            icon: Icons.person_add_alt_1_rounded,
            label: _s.homeAddClient,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomersScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickAction(
            icon: Icons.shopping_cart_outlined,
            label: 'New PO',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreatePurchaseOrderScreen(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickAction(
            icon: Icons.receipt_long_outlined,
            label: 'GST Report',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GstReportScreen()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          _buildQuickAction(
            icon: Icons.bar_chart_rounded,
            label: 'Reports',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildGradientAction(
            icon: Icons.workspace_premium_rounded,
            label: 'Manage Sub',
            gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3CAC), Color(0xFF784BA0)]),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickAction(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickAction(
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductsScreen()),
            ),
          ),
        ],
      ),
    ]),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    bool highlighted = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: kSurfaceLowest,
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: highlighted ? kPrimary : kSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: highlighted ? Colors.white : kPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kOnSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientAction({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: gradient,
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueCard() {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);
    final prevMonthName = DateFormat('MMM').format(DateTime(now.year, now.month - 1));

    double? percentChange;
    if (_previousMonthRevenue > 0) {
      percentChange =
          ((_currentMonthRevenue - _previousMonthRevenue) / _previousMonthRevenue) * 100;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kSubtleShadow],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$monthName Revenue',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kOnSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currencyFormat.format(_currentMonthRevenue),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kOnSurface,
                  ),
                ),
              ],
            ),
          ),
          if (percentChange != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: percentChange >= 0 ? kPaidBg : kOverdueBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(0)}% vs $prevMonthName',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: percentChange >= 0 ? kPaid : kOverdue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLowStockBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProductsScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kPendingBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kPending.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 18, color: kPending),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_lowStockProducts.length} product${_lowStockProducts.length > 1 ? 's' : ''} low on stock',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kOnSurface,
                ),
              ),
            ),
            const Text(
              'View',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kPending,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: kPending),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentInvoicesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Text(
            _s.homeRecentInvoices,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kOnSurface,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoicesScreen()),
            ),
            child: Row(
              children: [
                Text(
                  _s.homeViewAll,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kPrimary,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 16, color: kPrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInvoiceTile(Invoice invoice) {
    final (badgeColor, badgeBg, statusLabel) = switch (invoice.effectiveStatus) {
      InvoiceStatus.paid => (kPaid, kPaidBg, 'PAID'),
      InvoiceStatus.pending => (const Color(0xFFEF4444), const Color(0xFFFEE2E2), 'UNPAID'),
      InvoiceStatus.overdue => (kOverdue, kOverdueBg, 'OVERDUE'),
      InvoiceStatus.partiallyPaid => (const Color(0xFFEAB308), const Color(0xFFFEF3C7), 'PARTIAL'),
    };

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailsScreen(invoice: invoice),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [kSubtleShadow],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.clientName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kOnSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeAgo(invoice.createdAt),
                    style: const TextStyle(fontSize: 11, color: kTextTertiary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFormat.format(invoice.grandTotal),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kOnSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 9,
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

// ═══════════════════════════════════════════════════════════════════════════════
// Draggable FAB — isolated StatefulWidget so drag rebuilds never touch the
// parent HomeScreen or its IndexedStack, keeping scroll perfectly smooth.
// ═══════════════════════════════════════════════════════════════════════════════

class _DraggableFab extends StatefulWidget {
  const _DraggableFab({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_DraggableFab> createState() => _DraggableFabState();
}

class _DraggableFabState extends State<_DraggableFab> {
  static const _fabW = 160.0;
  static const _fabH = 52.0;

  Offset? _position;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    _position ??= Offset(
      (screen.width - _fabW) / 2,
      screen.height - 170,
    );
    final pos = _position!;

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: pos.dx,
            top: pos.dy,
            child: GestureDetector(
              onPanUpdate: (d) {
                setState(() {
                  _position = Offset(
                    (pos.dx + d.delta.dx).clamp(0.0, screen.width - _fabW),
                    (pos.dy + d.delta.dy).clamp(0.0, screen.height - _fabH),
                  );
                });
              },
              onTap: widget.onTap,
              child: Container(
                width: _fabW,
                height: _fabH,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'New Invoice',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ═══════════════════════════════════════════════════════════════════════════════

/// Small user avatar circle.
class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: kSignatureGradient,
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: kPrimary,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-nav item widget.
class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
    this.activeColor = kPrimary,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 18 : 0,
                  vertical: isActive ? 6 : 0,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isActive ? activeColor : kTextTertiary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeColor : kTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
