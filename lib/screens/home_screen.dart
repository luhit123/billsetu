import 'dart:async';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/analytics_models.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/create_invoice_screen.dart';
import 'package:billeasy/screens/customers_screen.dart';
import 'package:billeasy/screens/gst_report_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/screens/invoices_screen.dart';
import 'package:billeasy/screens/referral_screen.dart';
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
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(child: IndexedStack(index: _selectedTab, children: _tabs)),
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
  AnalyticsService? _analyticsService;
  final FirebaseService _firebaseService = FirebaseService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final DateFormat _monthLabelFormat = DateFormat('MMMM yyyy');
  final DateFormat _periodDateFormat = DateFormat('dd MMM yyyy');
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _isSearching = false;
  String _searchQuery = '';
  InvoicePeriodFilter _selectedPeriodFilter = InvoicePeriodFilter.currentMonth;
  DateTimeRange? _customDateRange;
  late AppStrings _s;

  // --- Stable invoice state (replaces _visibleInvoicesStream) ---
  List<Invoice> _allInvoices = [];
  bool _invoicesLoading = true;
  Object? _invoicesError;
  StreamSubscription<List<Invoice>>? _invoiceSubscription;

  Stream<DashboardAnalytics?>? _dashboardSummaryStream;
  List<Invoice>? _injectedInvoices;
  Object? _injectedInvoicesError;

  // Low stock alerts
  List<Product> _lowStockProducts = [];
  bool _lowStockLoading = true;

  /// Client-side filtered view: search applied on top of _allInvoices.
  List<Invoice> get _filteredInvoices {
    if (_searchQuery.isEmpty) return _allInvoices;
    final q = _searchQuery.toLowerCase();
    return _allInvoices.where((inv) {
      return inv.clientName.toLowerCase().contains(q) ||
          inv.invoiceNumber.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = AppStrings.of(context);
  }

  @override
  void initState() {
    super.initState();
    if (widget.invoicesStream != null) {
      _primeInjectedInvoices();
    } else {
      _subscribeToInvoices();
    }
    _refreshDashboardStream();
    _loadLowStockProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _invoiceSubscription?.cancel();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  Future<void> _primeInjectedInvoices() async {
    try {
      final invoices = await widget.invoicesStream!.first;
      if (!mounted) {
        return;
      }
      setState(() {
        _injectedInvoices = invoices;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _injectedInvoicesError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      drawer: _buildDrawer(),
      drawerScrimColor: Colors.black45,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Injected-stream path (used in tests / previews)
    if (widget.invoicesStream != null) {
      if (_injectedInvoicesError != null) {
        return ErrorRetryWidget(
          message: _s.homeLoadError,
          onRetry: _primeInjectedInvoices,
        );
      }
      if (_injectedInvoices == null) {
        return const Center(
          child: CircularProgressIndicator(color: kPrimary),
        );
      }
      return _buildScrollContent(_injectedInvoices!);
    }

    // Normal Firestore path
    if (_invoicesError != null) {
      return ErrorRetryWidget(
        message: _s.homeLoadError,
        onRetry: _subscribeToInvoices,
      );
    }

    if (_invoicesLoading && _allInvoices.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimary),
      );
    }

    return _buildScrollContent(_filteredInvoices);
  }

  Widget _buildScrollContent(List<Invoice> invoices) {
    // Dashboard shows only the 5 most recent — no status filter
    final recentInvoices =
        (invoices.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
            .take(5)
            .toList();

    final totalPaid = invoices
        .where((inv) => inv.status == InvoiceStatus.paid)
        .fold<double>(0, (s, inv) => s + inv.grandTotal);
    final outstanding = invoices
        .where((inv) => inv.status != InvoiceStatus.paid)
        .fold<double>(0, (s, inv) => s + inv.grandTotal);
    final discountsGiven = invoices.fold<double>(
      0,
      (s, inv) => s + inv.discountAmount,
    );

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ── Period banner ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _PeriodBanner(
              label: _periodLabel,
              onTap: _showPeriodPicker,
            ),
          ),

          // ── Stat cards (Outstanding · Collected · Discounts) ──────
          SliverToBoxAdapter(
            child: _buildDashboardStats(
              fallbackOutstanding: outstanding,
              fallbackCollected: totalPaid,
              fallbackDiscounts: discountsGiven,
            ),
          ),

          // ── Monthly Revenue chart ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _MonthlyRevenueCard(
                currencyFormat: _currencyFormat,
              ),
            ),
          ),

          // ── Quick Actions ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _QuickActionsSection(
                onCreateInvoice: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateInvoiceScreen(),
                  ),
                ),
                onAddClient: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomersScreen(),
                  ),
                ),
                onNewPurchase: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreatePurchaseOrderScreen(),
                  ),
                ),
                onReferral: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReferralScreen(),
                  ),
                ),
              ),
            ),
          ),

          // ── Low Stock Alerts ──────────────────────────────────────
          if (!_lowStockLoading && _lowStockProducts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFFB45309)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Low Stock Alert (${_lowStockProducts.length})',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
                            child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...(_lowStockProducts.take(5).map((p) {
                        final isOutOfStock = p.currentStock <= 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF78350F)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isOutOfStock ? const Color(0xFFFEE2E2) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isOutOfStock
                                      ? 'Out of Stock'
                                      : '${p.currentStock.toStringAsFixed(p.currentStock == p.currentStock.truncateToDouble() ? 0 : 1)} ${p.unit}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isOutOfStock ? const Color(0xFFEF4444) : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      })),
                    ],
                  ),
                ),
              ),
            ),

          // ── Membership & Subscriptions Card ────────────────────────
          if (RemoteConfigService.instance.featureMembership)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionsScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x307C3AED),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.card_membership_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Memberships & Subscriptions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Manage plans, members & attendance',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
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
            ),
          ),

          // ── Referral Banner ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _ReferralBanner(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReferralScreen(),
                  ),
                ),
              ),
            ),
          ),

          // ── Recent Invoices header ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Text(
                    _s.homeRecentInvoices,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kOnSurface,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InvoicesScreen(),
                      ),
                    ),
                    child: Text(
                      _s.homeViewAll,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 5 most-recent invoices (no status filter on dashboard) ─
          if (recentInvoices.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Center(
                  child: Text(
                    _s.homeNoInvoicesYet,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final invoice = recentInvoices[index];
                  return _RecentInvoiceTile(
                    invoice: invoice,
                    currencyFormat: _currencyFormat,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceDetailsScreen(invoice: invoice),
                      ),
                    ),
                    onStatusChange: (status) =>
                        _firebaseService.updateInvoiceStatus(invoice.id, status),
                    onDelete: () =>
                        _firebaseService.deleteInvoice(invoice.id),
                  );
                }, childCount: recentInvoices.length),
              ),
            ),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kSurface,
      foregroundColor: kOnSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      leading: Builder(
        builder: (context) => IconButton(
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: kOnSurface),
          tooltip: 'Open menu',
        ),
      ),
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: kPrimary,
              style: const TextStyle(
                color: kOnSurface,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: _s.homeSearchHint,
                hintStyle: const TextStyle(color: kTextTertiary),
                border: InputBorder.none,
              ),
              onChanged: _handleSearchChanged,
            )
          : const Text(
              'BillEasy',
              style: TextStyle(
                color: kOnSurface,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
            ),
      actions: [
        IconButton(
          onPressed: _toggleSearch,
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.search_rounded,
            color: kOnSurface,
          ),
          tooltip: _isSearching ? _s.homeCloseSearch : _s.homeSearchTooltip,
        ),
        IconButton(
          onPressed: _showPeriodPicker,
          icon: const Icon(Icons.calendar_today_rounded, color: kOnSurfaceVariant),
          tooltip: _s.homeFilterPeriodTooltip,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Firebase.apps.isEmpty
              ? _AvatarWidget(label: 'G')
              : StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  initialData: FirebaseAuth.instance.currentUser,
                  builder: (context, snapshot) {
                    return _AvatarWidget(
                      label: _avatarLabelForUser(snapshot.data),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── Logic ────────────────────────────────────────────────────────────────

  /// Subscribe (or re-subscribe) to Firestore for the current date period.
  /// Only call this when the DATE PERIOD changes — not on search/filter taps.
  void _subscribeToInvoices() {
    if (widget.invoicesStream != null) return;

    if (Firebase.apps.isEmpty) {
      _allInvoices = [];
      _invoicesLoading = false;
      return;
    }

    // Cancel any existing subscription before creating a new one
    _invoiceSubscription?.cancel();

    final periodBounds = _selectedPeriodBounds;
    final isAllTimeDashboard =
        _selectedPeriodFilter == InvoicePeriodFilter.allTime;
    final allTimeWindowStart = isAllTimeDashboard
        ? DateTime(DateTime.now().year - 1, DateTime.now().month, 1)
        : null;

    // Fetch without search query — search is applied client-side via _filteredInvoices
    final stream = _firebaseService.getInvoicesStream(
      startDate: periodBounds?.$1 ?? allTimeWindowStart,
      endDateExclusive: periodBounds?.$2,
      limit: 200,
    );

    // Direct assignment is safe during initState; use setState after first build
    if (mounted) {
      setState(() {
        _invoicesLoading = true;
        _invoicesError = null;
      });
    } else {
      _invoicesLoading = true;
      _invoicesError = null;
    }

    _invoiceSubscription = stream.listen(
      (invoices) {
        if (!mounted) return;
        setState(() {
          _allInvoices = invoices;
          _invoicesLoading = false;
          _invoicesError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _invoicesError = error;
          _invoicesLoading = false;
        });
      },
    );
  }

  void _refreshDashboardStream() {
    final shouldUseDashboardSummary =
        widget.invoicesStream == null &&
        _selectedPeriodFilter == InvoicePeriodFilter.allTime &&
        _searchQuery.isEmpty;

    if (!shouldUseDashboardSummary) {
      // Use setState only if the widget is already built; direct assignment is
      // safe during initState (before the first build).
      if (mounted) {
        setState(() => _dashboardSummaryStream = null);
      } else {
        _dashboardSummaryStream = null;
      }
      return;
    }

    _analyticsService ??= Firebase.apps.isEmpty ? null : AnalyticsService();
    final newStream = _analyticsService?.watchDashboardSummary();
    if (mounted) {
      setState(() => _dashboardSummaryStream = newStream);
    } else {
      _dashboardSummaryStream = newStream;
    }
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _lowStockLoading = false);
    }
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      // Client-side filter only — no Firestore round-trip needed
      setState(() {
        _searchQuery = value.trim();
      });
    });
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _searchDebounce?.cancel();
        _searchController.clear();
        _searchQuery = '';
        _isSearching = false;
      } else {
        _isSearching = true;
      }
      // No stream refresh — search is client-side
    });
  }

  Future<void> _showPeriodPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PeriodOptionTile(
                title: _s.homePeriodAllInvoices,
                isSelected:
                    _selectedPeriodFilter == InvoicePeriodFilter.allTime,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _selectedPeriodFilter = InvoicePeriodFilter.allTime;
                  });
                  _subscribeToInvoices();
                  _refreshDashboardStream();
                },
              ),
              _PeriodOptionTile(
                title: _s.homePeriodToday,
                isSelected: _selectedPeriodFilter == InvoicePeriodFilter.today,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _selectedPeriodFilter = InvoicePeriodFilter.today;
                  });
                  _subscribeToInvoices();
                  _refreshDashboardStream();
                },
              ),
              _PeriodOptionTile(
                title: _s.homePeriodThisWeek,
                isSelected:
                    _selectedPeriodFilter == InvoicePeriodFilter.thisWeek,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _selectedPeriodFilter = InvoicePeriodFilter.thisWeek;
                  });
                  _subscribeToInvoices();
                  _refreshDashboardStream();
                },
              ),
              _PeriodOptionTile(
                title: _monthLabelFormat.format(DateTime.now()),
                isSelected:
                    _selectedPeriodFilter == InvoicePeriodFilter.currentMonth,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _selectedPeriodFilter = InvoicePeriodFilter.currentMonth;
                  });
                  _subscribeToInvoices();
                  _refreshDashboardStream();
                },
              ),
              _PeriodOptionTile(
                title: _customPeriodSheetLabel,
                isSelected:
                    _selectedPeriodFilter == InvoicePeriodFilter.customRange,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickCustomDateRange();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardStats({
    required double fallbackOutstanding,
    required double fallbackCollected,
    required double fallbackDiscounts,
  }) {
    final dashboardStream = _dashboardSummaryStream;
    if (dashboardStream == null) {
      return _dashboardStatsRow(
        outstanding: fallbackOutstanding,
        collected: fallbackCollected,
        discounts: fallbackDiscounts,
      );
    }

    return StreamBuilder<DashboardAnalytics?>(
      stream: dashboardStream,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        return _dashboardStatsRow(
          outstanding: summary?.totalOutstanding ?? fallbackOutstanding,
          collected: summary?.totalCollected ?? fallbackCollected,
          discounts: summary?.totalDiscounts ?? fallbackDiscounts,
        );
      },
    );
  }

  Widget _dashboardStatsRow({
    required double outstanding,
    required double collected,
    required double discounts,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _DashboardStatCard(
              label: _s.homeStatOutstanding,
              value: _currencyFormat.format(outstanding),
              accentColor: kPrimary,
              icon: Icons.account_balance_wallet_rounded,
              fullWidth: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DashboardStatCard(
              label: _s.homeStatCollected,
              value: _currencyFormat.format(collected),
              accentColor: kPaid,
              icon: Icons.check_circle_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DashboardStatCard(
              label: _s.homeStatDiscounts,
              value: _currencyFormat.format(discounts),
              accentColor: kPending,
              icon: Icons.local_offer_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initialRange =
        _customDateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );

    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      saveText: _s.homeDateApply,
    );

    if (pickedRange == null) return;
    setState(() {
      _customDateRange = pickedRange;
      _selectedPeriodFilter = InvoicePeriodFilter.customRange;
    });
    _subscribeToInvoices();
    _refreshDashboardStream();
  }

  String get _periodLabel {
    switch (_selectedPeriodFilter) {
      case InvoicePeriodFilter.allTime:
        return _s.homePeriodAllInvoices;
      case InvoicePeriodFilter.today:
        return _s.homePeriodToday;
      case InvoicePeriodFilter.thisWeek:
        return _s.homePeriodThisWeek;
      case InvoicePeriodFilter.currentMonth:
        return _monthLabelFormat.format(DateTime.now());
      case InvoicePeriodFilter.customRange:
        final r = _customDateRange;
        if (r == null) return _s.homePeriodCustomRange;
        return _s.homePeriodDateRange(
          _periodDateFormat.format(r.start),
          _periodDateFormat.format(r.end),
        );
    }
  }

  String get _customPeriodSheetLabel {
    final r = _customDateRange;
    if (r == null) return _s.homePeriodCustomRange;
    return _s.homePeriodCustomLabel(
      _periodDateFormat.format(r.start),
      _periodDateFormat.format(r.end),
    );
  }

  (DateTime, DateTime)? get _selectedPeriodBounds {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_selectedPeriodFilter) {
      case InvoicePeriodFilter.allTime:
        return null;
      case InvoicePeriodFilter.today:
        return (today, today.add(const Duration(days: 1)));
      case InvoicePeriodFilter.thisWeek:
        final startOfWeek = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        return (startOfWeek, startOfWeek.add(const Duration(days: 7)));
      case InvoicePeriodFilter.currentMonth:
        return (
          DateTime(now.year, now.month),
          DateTime(now.year, now.month + 1),
        );
      case InvoicePeriodFilter.customRange:
        final r = _customDateRange;
        if (r == null) return null;
        return (
          DateTime(r.start.year, r.start.month, r.start.day),
          DateTime(r.end.year, r.end.month, r.end.day + 1),
        );
    }
  }

  // ─── Drawer ───────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      width: 296,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kPrimaryDark,
              kPrimary,
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0, 0.35, 0.35],
          ),
        ),
        child: SafeArea(
          child: Firebase.apps.isEmpty
              ? _buildDrawerBody(null)
              : StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  initialData: FirebaseAuth.instance.currentUser,
                  builder: (context, snapshot) =>
                      _buildDrawerBody(snapshot.data),
                ),
        ),
      ),
    );
  }

  Widget _buildDrawerBody(User? user) {
    final displayName = _displayNameForUser(user);
    final subtitle = user?.email ?? _s.drawerNotSignedIn;
    final authActionLabel = user == null ? _s.drawerLogIn : _s.drawerLogOut;
    final authActionIcon = user == null
        ? Icons.login_rounded
        : Icons.logout_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withAlpha(30)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  child: Text(
                    _avatarLabelForUser(user),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DrawerSectionLabel(title: _s.drawerWorkspace),
                  _DrawerMenuTile(
                    icon: Icons.badge_outlined,
                    title: _s.drawerMyProfile,
                    iconBgColor: const Color(0xFF007AFF),
                    onTap: () => _openDrawerScreen(const ProfileSetupScreen()),
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.inventory_2_outlined,
                    title: _s.drawerProducts,
                    iconBgColor: const Color(0xFFFF9500),
                    onTap: () => _openDrawerScreen(const ProductsScreen()),
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.groups_2_outlined,
                    title: _s.drawerCustomers,
                    iconBgColor: const Color(0xFF34C759),
                    onTap: () => _openDrawerScreen(const CustomersScreen()),
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.shopping_cart_outlined,
                    title: _s.drawerPurchases,
                    iconBgColor: const Color(0xFFFF2D55),
                    onTap: () => _openDrawerScreen(const PurchaseOrdersScreen()),
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.assessment_outlined,
                    title: _s.drawerReports,
                    iconBgColor: const Color(0xFF00C7BE),
                    onTap: () => _openDrawerScreen(const ReportsScreen()),
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.receipt_long_outlined,
                    title: _s.drawerGst,
                    iconBgColor: const Color(0xFFAF52DE),
                    onTap: () => _openDrawerScreen(const GstReportScreen()),
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.settings_outlined,
                    title: _s.drawerSettings,
                    iconBgColor: const Color(0xFF8E8E93),
                    onTap: () => _openDrawerScreen(const SettingsScreen()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DrawerMenuTile(
            icon: authActionIcon,
            title: authActionLabel,
            backgroundColor: user == null
                ? kPrimaryContainer
                : const Color(0xFFFFECEC),
            borderColor: user == null
                ? kPrimaryContainer
                : const Color(0xFFFFD1D1),
            iconColor: user == null
                ? kPrimary
                : const Color(0xFFB3261E),
            textColor: user == null
                ? kPrimary
                : const Color(0xFFB3261E),
            onTap: () => _handleDrawerAuthAction(user),
          ),
        ],
      ),
    );
  }

  void _openDrawerScreen(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _handleDrawerAuthAction(User? user) async {
    Navigator.pop(context);
    if (!mounted) return;
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    try {
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_s.drawerFailedLogOut(error.toString()))),
      );
    }
  }

  String _displayNameForUser(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return _s.drawerMyProfileFallback;
  }

  String _avatarLabelForUser(User? user) {
    final source = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.trim();
    if (source == null || source.isEmpty) return 'G';
    return source.characters.first.toUpperCase();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════════════

/// Thin coloured banner showing the active period.
class _PeriodBanner extends StatelessWidget {
  const _PeriodBanner({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [kSubtleShadow],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: kPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kOnSurface,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: kTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat card with icon accent strip on the left.
class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.icon,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final Color accentColor;
  final IconData icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    // fullWidth cards show icon + text side-by-side for a wider layout
    final inner = fullWidth
        ? Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 12),
              Column(
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
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: kOnSurface,
                    ),
                  ),
                ],
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: kOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kOnSurface,
                ),
              ),
            ],
          );

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kSubtleShadow],
      ),
      child: inner,
    );
  }
}

/// Monthly revenue bar chart card (last 6 months).
// ── Monthly Revenue Card (dynamic all-months, horizontally scrollable) ────────

class _MonthlyRevenueCard extends StatefulWidget {
  const _MonthlyRevenueCard({required this.currencyFormat});

  final NumberFormat currencyFormat;

  @override
  State<_MonthlyRevenueCard> createState() => _MonthlyRevenueCardState();
}

class _MonthlyRevenueCardState extends State<_MonthlyRevenueCard> {
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription<List<Invoice>>? _revenueSub;
  List<Invoice> _invoices = [];

  final ScrollController _scrollCtrl = ScrollController();

  // Derived state
  List<DateTime> _months = [];
  List<double> _totals = [];
  int _selectedIdx = 0;

  // Layout constants
  static const double _barW = 36;
  static const double _barSpacing = 10;
  // _barSlot = _barW + _barSpacing = 46 (kept for reference)
  static const double _barH = 72;
  static const double _minH = 5;

  @override
  void initState() {
    super.initState();
    _subscribeToRevenue();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _subscribeToRevenue() {
    _revenueSub?.cancel();
    final now = DateTime.now();
    final startDate = DateTime(now.year - 1, now.month, 1);
    _revenueSub = _firebaseService
        .getInvoicesStream(startDate: startDate, limit: 500)
        .listen(
          (invoices) {
            if (!mounted) return;
            setState(() {
              _invoices = invoices;
              _rebuildData();
            });
          },
          onError: (_) {},
        );
  }

  void _rebuildData() {
    final now = DateTime.now();

    // Find the earliest month that has an invoice (floor to at least 12 months back)
    var earliest = DateTime(now.year, now.month - 11);
    for (final inv in _invoices) {
      final m = DateTime(inv.createdAt.year, inv.createdAt.month);
      if (m.isBefore(earliest)) earliest = m;
    }

    // Generate every month from earliest to now
    _months = [];
    var cursor = DateTime(earliest.year, earliest.month);
    final nowMonth = DateTime(now.year, now.month);
    while (!cursor.isAfter(nowMonth)) {
      _months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    // Aggregate grand-total revenue per month
    _totals = _months.map((m) {
      return _invoices
          .where(
            (inv) =>
                inv.createdAt.year == m.year && inv.createdAt.month == m.month,
          )
          .fold<double>(0, (acc, inv) => acc + inv.grandTotal);
    }).toList();

    // Keep the user's selected bar; only move to current month on first load
    // or when the old index falls out of range (e.g. months list shrank).
    if (_selectedIdx < 0 || _selectedIdx >= _months.length) {
      _selectedIdx = _months.length - 1;
    }
  }

  void _scrollToCurrent() {
    if (!_scrollCtrl.hasClients || _months.isEmpty) return;
    final maxExt = _scrollCtrl.position.maxScrollExtent;
    // Scroll to rightmost (current month is always last)
    _scrollCtrl.animateTo(
      maxExt,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _revenueSub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = _months.isNotEmpty
        ? _months[_selectedIdx]
        : DateTime.now();
    final selectedTotal = _totals.isNotEmpty ? _totals[_selectedIdx] : 0.0;
    final maxTotal = _totals.fold<double>(0, (m, t) => t > m ? t : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kWhisperShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.of(context).homeMonthlyRevenue,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kOnSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        widget.currencyFormat.format(selectedTotal),
                        key: ValueKey(selectedTotal),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: kOnSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(selectedMonth),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMM yyyy').format(selectedMonth),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Scroll hint
          const Row(
            children: [
              Icon(Icons.swipe_rounded, size: 13, color: kTextTertiary),
              SizedBox(width: 4),
              Text(
                'Scroll to see all months · Tap a bar',
                style: TextStyle(fontSize: 10, color: kTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Scrollable bar chart ─────────────────────────────────────────
          SizedBox(
            height: _barH + 22, // bars + label height
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(_months.length, (i) {
                    final isSelected = i == _selectedIdx;
                    final fraction = maxTotal > 0
                        ? (_totals[i] / maxTotal).clamp(0.0, 1.0)
                        : 0.0;
                    final barHeight = (fraction * _barH).clamp(_minH, _barH);

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedIdx = i),
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i < _months.length - 1 ? _barSpacing : 0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Bar container (fixed height so bars align at bottom)
                            SizedBox(
                              width: _barW,
                              height: _barH,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: _barW,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? kPrimary
                                        : _totals[i] > 0
                                        ? kSurfaceContainer
                                        : kSurfaceContainerLow,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('MMM').format(_months[i]),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? kPrimary
                                    : kTextTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick Actions: Create Invoice + Add Client + New Purchase Order + Reports.
class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({
    required this.onCreateInvoice,
    required this.onAddClient,
    required this.onNewPurchase,
    required this.onReferral,
  });

  final VoidCallback onCreateInvoice;
  final VoidCallback onAddClient;
  final VoidCallback onNewPurchase;
  final VoidCallback onReferral;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.homeQuickActions,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kOnSurface,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.add_circle_outline_rounded,
                label: s.homeCreateInvoice,
                filled: true,
                onTap: onCreateInvoice,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: s.homeAddClient,
                filled: false,
                onTap: onAddClient,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: filled ? kSignatureGradient : null,
            color: filled ? null : kSurfaceLowest,
            boxShadow: filled
                ? null
                : const [kSubtleShadow],
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: filled ? Colors.white : kPrimary),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : kPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Referral banner shown on the dashboard.
class _ReferralBanner extends StatelessWidget {
  const _ReferralBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6D00), Color(0xFFFFA000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite friends, get 1 month free',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Share your referral code and earn Pro rewards',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact invoice row for the dashboard list.
class _RecentInvoiceTile extends StatelessWidget {
  const _RecentInvoiceTile({
    required this.invoice,
    required this.currencyFormat,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
  });

  final Invoice invoice;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;
  final void Function(InvoiceStatus) onStatusChange;
  final VoidCallback onDelete;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final (badgeColor, badgeBg, statusLabel) = switch (invoice.status) {
      InvoiceStatus.paid => (kPaid, kPaidBg, 'PAID'),
      InvoiceStatus.pending => (kPending, kPendingBg, 'PENDING'),
      InvoiceStatus.overdue => (kOverdue, kOverdueBg, 'OVERDUE'),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [kSubtleShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kPrimaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.description_rounded,
                size: 18,
                color: kPrimary,
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
                      color: kOnSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${invoice.invoiceNumber} · ${_timeAgo(invoice.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
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
                  currencyFormat.format(invoice.grandTotal),
                  style: const TextStyle(
                    fontSize: 14,
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

/// Small user avatar circle for the AppBar leading.
class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
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
                  horizontal: isActive ? 16 : 0,
                  vertical: isActive ? 4 : 0,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
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

// ─── Unchanged drawer helpers ─────────────────────────────────────────────────

class _DrawerMenuTile extends StatelessWidget {
  const _DrawerMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.backgroundColor = kSurfaceContainerLow,
    this.borderColor = kSurfaceContainerLow,
    this.iconColor = kPrimary,
    this.textColor = kOnSurface,
    this.iconBgColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final Color? iconBgColor;

  @override
  Widget build(BuildContext context) {
    final iconWidget = iconBgColor != null
        ? Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: Colors.white, size: 17),
          )
        : Icon(icon, color: iconColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _PeriodOptionTile extends StatelessWidget {
  const _PeriodOptionTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? kPrimary : kTextTertiary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
