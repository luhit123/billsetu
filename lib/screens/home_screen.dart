import 'dart:async';
import 'dart:math' as math;

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/analytics_models.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/create_invoice_screen.dart';
import 'package:billeasy/modals/team_role.dart';
import 'package:billeasy/screens/attendance_dashboard_screen.dart';
import 'package:billeasy/screens/geo_attendance_screen.dart';
import 'package:billeasy/screens/office_location_screen.dart';
import 'package:billeasy/screens/member_performance_detail_screen.dart';
import 'package:billeasy/screens/team_management_screen.dart';
import 'package:billeasy/screens/team_settings_screen.dart';
import 'package:billeasy/screens/customers_screen.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/screens/gst_report_screen.dart';
import 'package:billeasy/screens/invoices_screen.dart';
import 'package:billeasy/screens/reports_screen.dart';
import 'package:billeasy/screens/products_screen.dart';
import 'package:billeasy/screens/create_purchase_order_screen.dart';
import 'package:billeasy/screens/settings_screen.dart';
import 'package:billeasy/screens/subscriptions_screen.dart';
import 'package:billeasy/modals/product.dart';
import 'package:billeasy/services/analytics_service.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/sync_status_service.dart';
import 'package:billeasy/screens/upgrade_screen.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/review_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/aurora_app_backdrop.dart';
import 'package:billeasy/widgets/connectivity_banner.dart';
import 'package:billeasy/widgets/error_retry_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billeasy/utils/responsive.dart';

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
  StreamSubscription<AppPlan>? _planSub;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _DashboardPage(invoicesStream: widget.invoicesStream),
      const InvoicesScreen(embeddedInHomeShell: true),
      const CustomersScreen(embeddedInHomeShell: true),
      const ProductsScreen(embeddedInHomeShell: true),
    ];
    ReviewService.instance.onAppOpen();
    _planSub = PlanService.instance.planStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _planSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return windowSizeOf(context) == WindowSize.expanded
        ? _buildWideLayout(s)
        : _buildCompactLayout(s);
  }

  /// Phone layout — bottom nav + draggable FAB.
  Widget _buildCompactLayout(AppStrings s) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraAppBackdrop()),
          Column(
            children: [
              Expanded(
                child: IndexedStack(index: _selectedTab, children: _tabs),
              ),
            ],
          ),
          if (TeamService.instance.can.canCreateInvoice)
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

  /// Tablet / Desktop layout — NavigationRail on the left.
  Widget _buildWideLayout(AppStrings s) {
    final currentPlan = PlanService.instance.currentLimits.displayName;
    final planStatus = switch (PlanService.instance.currentPlan) {
      AppPlan.trial => '${PlanService.instance.trialDaysLeft}d trial left',
      AppPlan.pro || AppPlan.enterprise => 'Workspace active',
      AppPlan.expired => 'Free workspace',
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraAppBackdrop()),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints.tightFor(width: 272),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: context.cs.surfaceContainerLowest.withValues(
                        alpha: 0.9,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [kWhisperShadow],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipOval(
                              child: Image.asset(
                                'assets/icon/logo.png',
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BillRaja',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 19,
                                      color: context.cs.onSurface,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Web workspace',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: context.cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.cs.primaryContainer.withValues(
                                  alpha: 0.95,
                                ),
                                context.cs.surfaceContainerLowest,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentPlan,
                                style: const TextStyle(
                                  color: kPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                planStatus,
                                style: TextStyle(
                                  color: context.cs.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _HomeDesktopNavItem(
                          icon: Icons.home_rounded,
                          label: s.homeBottomHome,
                          subtitle: 'Overview, KPIs, and alerts',
                          isActive: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                        const SizedBox(height: 8),
                        _HomeDesktopNavItem(
                          icon: Icons.receipt_long_rounded,
                          label: s.homeBottomInvoices,
                          subtitle: 'Billing, status, and follow-ups',
                          isActive: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                        const SizedBox(height: 8),
                        _HomeDesktopNavItem(
                          icon: Icons.people_alt_rounded,
                          label: s.homeBottomClients,
                          subtitle: 'Customer relationships and groups',
                          isActive: _selectedTab == 2,
                          onTap: () => setState(() => _selectedTab = 2),
                        ),
                        const SizedBox(height: 8),
                        _HomeDesktopNavItem(
                          icon: Icons.inventory_2_rounded,
                          label: s.homeBottomProducts,
                          subtitle: 'Catalog, pricing, and stock',
                          isActive: _selectedTab == 3,
                          onTap: () => setState(() => _selectedTab = 3),
                        ),
                        const Spacer(),
                        Text(
                          'Keep invoices, customers, products, and plan controls in one place.',
                          style: TextStyle(
                            color: context.cs.onSurfaceVariant,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                        if (TeamService.instance.can.canCreateInvoice) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: _WaveHomeInvoiceButton(
                              label: 'New Invoice',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateInvoiceScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.cs.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [kWhisperShadow],
                    ),
                    child: IndexedStack(index: _selectedTab, children: _tabs),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(AppStrings s) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
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
  StreamSubscription<AppPlan>? _planSub;

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
    _planSub = PlanService.instance.planStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _planSub?.cancel();
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
    // If team member can't view others' invoices, show only their own
    final onlyMyInvoices =
        TeamService.instance.isTeamMember &&
        !TeamService.instance.can.canViewOthersInvoices;
    final filterUid = onlyMyInvoices
        ? TeamService.instance.getActualUserId()
        : null;
    final stream =
        widget.invoicesStream ??
        _firebaseService.getInvoicesStream(limit: 50, createdByUid: filterUid);
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
    _analyticsSub = _analyticsService!.watchDashboardSummary().listen((data) {
      if (!mounted) return;
      setState(() => _analytics = data);
    }, onError: (_) {});
  }

  Future<void> _loadLowStockProducts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _lowStockLoading = false);
      return;
    }
    try {
      // Use cache-only when offline to avoid a network timeout hanging the UI
      final getOpts = ConnectivityService.instance.isOffline
          ? const GetOptions(source: Source.cache)
          : const GetOptions(source: Source.serverAndCache);
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('products')
          .where('trackInventory', isEqualTo: true)
          .limit(200)
          .get(getOpts);
      if (!mounted) return;
      final products =
          snap.docs
              .map((d) => Product.fromMap(d.data(), docId: d.id))
              .where(
                (p) => p.currentStock <= p.minStockAlert && p.minStockAlert > 0,
              )
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
        .where(
          (inv) =>
              inv.status == InvoiceStatus.paid &&
              inv.createdAt.year == now.year &&
              inv.createdAt.month == now.month,
        )
        .fold<double>(0, (s, inv) => s + inv.grandTotal);

    final prevMonth = DateTime(now.year, now.month - 1);
    _previousMonthRevenue = _allInvoices
        .where(
          (inv) =>
              inv.status == InvoiceStatus.paid &&
              inv.createdAt.year == prevMonth.year &&
              inv.createdAt.month == prevMonth.month,
        )
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
    final raw = a != null
        ? a.totalOutstanding
        : _allInvoices
            .where((inv) => inv.status != InvoiceStatus.paid)
            .fold<double>(0, (s, inv) => s + inv.balanceDue);
    return raw < 0 ? 0 : raw;
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

  String _avatarLabel(User? user) {
    final source = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.trim();
    if (source == null || source.isEmpty) return 'G';
    return source.characters.first.toUpperCase();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Only show the hard error screen when there is no cached data to display.
    // If we already have invoices (from Firestore cache), keep showing them
    // even if a subsequent stream error occurs — the offline banner handles UX.
    if (_invoicesError != null && _allInvoices.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: ErrorRetryWidget(
          message: _s.homeLoadError,
          onRetry: _subscribeToInvoices,
        ),
      );
    }

    if (_invoicesLoading && _allInvoices.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: _handleRefresh,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kWebContentMaxWidth),
            child: CustomScrollView(
              slivers: [
                // 1. SliverAppBar
                _buildSliverAppBar(),

                // 1b. Sync warning banner
                SliverToBoxAdapter(child: _SyncWarningBanner()),

                // 2. Hero Card (revenue — owner/manager only)
                if (TeamService.instance.can.canViewRevenue)
                  SliverToBoxAdapter(child: _buildHeroCard()),

                // 3. Status Strip (paid/pending/overdue — owner/manager only)
                if (TeamService.instance.can.canViewRevenue)
                  SliverToBoxAdapter(child: _buildStatusStrip()),

                // 4. Overdue Alert (conditional — owner/manager only)
                if (TeamService.instance.can.canViewRevenue &&
                    _overdueCount > 0)
                  SliverToBoxAdapter(child: _buildOverdueAlert()),

                // 4b. Team member cards (attendance + my performance)
                if (TeamService.instance.isTeamMember)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        children: [
                          if (TeamService.instance.can.canMarkAttendance)
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: kPrimary.withAlpha(20),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    color: kPrimary,
                                  ),
                                ),
                                title: const Text(
                                  'Attendance',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  PlanService.instance.hasAttendance
                                      ? 'Check in / out at office'
                                      : 'Upgrade to Pro to use attendance',
                                ),
                                trailing: PlanService.instance.hasAttendance
                                    ? const Icon(Icons.chevron_right_rounded)
                                    : Icon(
                                        Icons.lock_rounded,
                                        size: 18,
                                        color: Colors.amber.shade700,
                                      ),
                                onTap: () {
                                  if (!PlanService.instance.hasAttendance) {
                                    _showFeatureUpgradePrompt('Attendance');
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const GeoAttendanceScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.withAlpha(20),
                                child: const Icon(
                                  Icons.analytics_outlined,
                                  color: Colors.blue,
                                ),
                              ),
                              title: const Text(
                                'My Performance',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: const Text(
                                'Attendance & invoice stats',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () async {
                                final uid = TeamService.instance
                                    .getActualUserId();
                                final members = await TeamService.instance
                                    .watchMembers()
                                    .first;
                                final me = members
                                    .where((m) => m.uid == uid)
                                    .firstOrNull;
                                if (me != null && context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MemberPerformanceDetailScreen(
                                            member: me,
                                          ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. Quick Actions
                SliverToBoxAdapter(child: _buildQuickActions()),

                // 6. Revenue Card (owner/manager only)
                if (TeamService.instance.can.canViewRevenue)
                  SliverToBoxAdapter(child: _buildRevenueCard()),

                // 7. Low Stock Banner (conditional)
                if (!_lowStockLoading && _lowStockProducts.isNotEmpty)
                  SliverToBoxAdapter(child: _buildLowStockBanner()),

                // Bottom spacing
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Section Builders ─────────────────────────────────────────────────────

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      foregroundColor: context.cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: Text(
        'BillRaja',
        style: TextStyle(
          color: context.cs.onSurface,
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
          icon: Icon(
            Icons.settings_outlined,
            color: context.cs.onSurfaceVariant,
          ),
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
    final ts = TeamService.instance;
    final isTeam = ts.isOnTeam;
    final teamName = ts.teamBusinessName;
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isTeam ? 'Team Outstanding' : 'Total Outstanding',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        if (isTeam && teamName.isNotEmpty)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.groups_rounded,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      teamName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: _heroStatPill(
                            Icons.schedule_rounded,
                            '$_pendingCount pending',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _heroStatPill(
                            Icons.warning_amber_rounded,
                            '$_overdueCount overdue',
                          ),
                        ),
                      ],
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

  Widget _heroStatPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
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
            count: _pendingCount,
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
            count: _overdueCount,
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
    int? count,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: context.cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [kSubtleShadow],
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    if (count != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currencyFormat.format(amount),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
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
      child: Column(
        children: [
          Row(
            children: [
              _buildQuickAction(
                icon: Icons.add_circle_outline_rounded,
                label: _s.homeCreateInvoice,
                highlighted: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateInvoiceScreen(),
                  ),
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
                onTap: () {
                  if (!PlanService.instance.hasPurchaseOrders) {
                    if (TeamService.instance.isTeamMember) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This feature is not available. Contact your team owner to upgrade.',
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UpgradeScreen(),
                        ),
                      );
                    }
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreatePurchaseOrderScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildQuickAction(
                icon: Icons.receipt_long_outlined,
                label: 'GST Report',
                onTap: () {
                  if (!TeamService.instance.can.canViewReports) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'You do not have permission to view reports',
                        ),
                      ),
                    );
                    return;
                  }
                  if (!PlanService.instance.hasReports) {
                    if (TeamService.instance.isTeamMember) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This feature is not available. Contact your team owner to upgrade.',
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UpgradeScreen(),
                        ),
                      );
                    }
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GstReportScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildQuickAction(
                icon: Icons.fingerprint_rounded,
                label: 'Attendance',
                onTap: () {
                  if (!PlanService.instance.hasAttendance) {
                    _showFeatureUpgradePrompt('Attendance');
                    return;
                  }
                  _showAttendanceHowItWorks();
                },
              ),
              const SizedBox(width: 8),
              _buildQuickAction(
                icon: Icons.bar_chart_rounded,
                label: 'Reports',
                onTap: () {
                  if (!TeamService.instance.can.canViewReports) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'You do not have permission to view reports',
                        ),
                      ),
                    );
                    return;
                  }
                  if (!PlanService.instance.hasReports) {
                    if (TeamService.instance.isTeamMember) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This feature is not available. Contact your team owner to upgrade.',
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UpgradeScreen(),
                        ),
                      );
                    }
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildQuickAction(
                icon: Icons.workspace_premium_rounded,
                label: 'Manage Sub',
                onTap: () {
                  if (!PlanService.instance.hasMembership) {
                    _showFeatureUpgradePrompt('Membership Management');
                    return;
                  }
                  if (!TeamService.instance.can.canManageSubscription) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'You do not have permission to manage memberships',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildQuickAction(
                icon: Icons.groups_rounded,
                label: 'Team',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamService.instance.isTeamMember
                        ? const TeamSettingsScreen()
                        : const TeamManagementScreen(),
                  ),
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
        ],
      ),
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
              color: context.cs.surfaceContainerLowest,
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? kPrimary
                        : context.cs.surfaceContainerLow,
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.cs.onSurface,
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

  void _showFeatureUpgradePrompt(String featureName) {
    // Attendance & GSTR-3B are Enterprise-only; everything else is Pro+.
    final isEnterpriseOnly = featureName.toLowerCase().contains('attendance') ||
        featureName.toLowerCase().contains('gstr');
    final planLabel = isEnterpriseOnly ? 'Enterprise' : 'Pro';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$featureName — $planLabel Feature'),
        content: Text(
          'Upgrade to $planLabel to unlock $featureName and other premium features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpgradeScreen()),
              );
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  void _showAttendanceHowItWorks() {
    final isOwnerOrManager =
        TeamService.instance.isOnTeam &&
        (TeamService.instance.isTeamOwner ||
            TeamService.instance.currentRole == TeamRole.coOwner ||
            TeamService.instance.currentRole == TeamRole.manager);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AttendanceHowItWorksSheet(
        isOwnerOrManager: isOwnerOrManager,
        isOnTeam: TeamService.instance.isOnTeam,
      ),
    );
  }

  Widget _buildRevenueCard() {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM').format(now);
    final prevMonthName = DateFormat(
      'MMM',
    ).format(DateTime(now.year, now.month - 1));

    double? percentChange;
    if (_previousMonthRevenue > 0) {
      percentChange =
          ((_currentMonthRevenue - _previousMonthRevenue) /
              _previousMonthRevenue) *
          100;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currencyFormat.format(_currentMonthRevenue),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.cs.onSurface,
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface,
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

class _DraggableFabState extends State<_DraggableFab>
    with SingleTickerProviderStateMixin {
  static const _fabW = 160.0;
  static const _fabH = 52.0;

  Offset? _position;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _position ??= Offset((screen.width - _fabW) / 2, screen.height - 170);
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
              child: _WaveInvoiceVisual(
                progress: animationsDisabled ? 0.18 : _controller.value,
                width: _fabW,
                height: _fabH,
                borderRadius: const BorderRadius.all(Radius.circular(30)),
                label: 'New Invoice',
                iconSize: 22,
                iconTextSpacing: 8,
                fontSize: 15,
                letterSpacing: 0.3,
                shadowAlpha: 0.45,
                shadowBlur: 20,
                shadowOffset: const Offset(0, 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveHomeInvoiceButton extends StatefulWidget {
  const _WaveHomeInvoiceButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_WaveHomeInvoiceButton> createState() => _WaveHomeInvoiceButtonState();
}

class _WaveHomeInvoiceButtonState extends State<_WaveHomeInvoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final borderRadius = const BorderRadius.all(Radius.circular(14));

    return Tooltip(
      message: widget.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: borderRadius,
          child: _WaveInvoiceVisual(
            progress: animationsDisabled ? 0.18 : _controller.value,
            width: null,
            height: 52,
            borderRadius: borderRadius,
            label: widget.label,
            showLabel: true,
            iconSize: 20,
            iconTextSpacing: 8,
            fontSize: 15,
            shadowAlpha: 0.34,
            shadowBlur: 16,
            shadowOffset: const Offset(0, 6),
          ),
        ),
      ),
    );
  }
}

class _WaveInvoiceVisual extends StatelessWidget {
  const _WaveInvoiceVisual({
    required this.progress,
    required this.height,
    required this.borderRadius,
    required this.label,
    this.width,
    this.showLabel = true,
    this.iconSize = 20,
    this.iconTextSpacing = 8,
    this.fontSize = 15,
    this.letterSpacing = 0,
    this.shadowAlpha = 0.34,
    this.shadowBlur = 16,
    this.shadowOffset = const Offset(0, 6),
  });

  final double progress;
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final String label;
  final bool showLabel;
  final double iconSize;
  final double iconTextSpacing;
  final double fontSize;
  final double letterSpacing;
  final double shadowAlpha;
  final double shadowBlur;
  final Offset shadowOffset;

  static const _waveStart = Color(0xFF7C3AED);
  static const _waveEnd = Color(0xFF5B21B6);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_waveStart, _waveEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: _waveStart.withValues(alpha: shadowAlpha),
            blurRadius: shadowBlur,
            offset: shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _WaveActionPainter(
                  progress: progress,
                  backWaveColor: Colors.white.withValues(alpha: 0.10),
                  frontWaveColor: Colors.white.withValues(alpha: 0.16),
                  highlightColor: Colors.white.withValues(alpha: 0.28),
                ),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: iconSize),
                  if (showLabel) ...[
                    SizedBox(width: iconTextSpacing),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: fontSize,
                        letterSpacing: letterSpacing,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveActionPainter extends CustomPainter {
  const _WaveActionPainter({
    required this.progress,
    required this.backWaveColor,
    required this.frontWaveColor,
    required this.highlightColor,
  });

  final double progress;
  final Color backWaveColor;
  final Color frontWaveColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    _paintWave(
      canvas,
      size,
      baseline: size.height * 0.78,
      amplitude: 5,
      wavelength: size.width * 0.92,
      phase: progress * math.pi * 2,
      color: backWaveColor,
    );
    _paintWave(
      canvas,
      size,
      baseline: size.height * 0.66,
      amplitude: 7,
      wavelength: size.width * 0.72,
      phase: -progress * math.pi * 3.2,
      color: frontWaveColor,
    );
    _paintHighlight(
      canvas,
      size,
      baseline: size.height * 0.51,
      amplitude: 3,
      wavelength: size.width * 0.84,
      phase: progress * math.pi * 4.6,
    );
  }

  void _paintWave(
    Canvas canvas,
    Size size, {
    required double baseline,
    required double amplitude,
    required double wavelength,
    required double phase,
    required Color color,
  }) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y =
          baseline +
          math.sin((x / wavelength) * math.pi * 2 + phase) * amplitude;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintHighlight(
    Canvas canvas,
    Size size, {
    required double baseline,
    required double amplitude,
    required double wavelength,
    required double phase,
  }) {
    final path = Path();
    for (double x = 0; x <= size.width; x++) {
      final y =
          baseline +
          math.sin((x / wavelength) * math.pi * 2 + phase) * amplitude;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = highlightColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveActionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backWaveColor != backWaveColor ||
        oldDelegate.frontWaveColor != frontWaveColor ||
        oldDelegate.highlightColor != highlightColor;
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
                  color: isActive
                      ? activeColor
                      : context.cs.onSurfaceVariant.withAlpha(153),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? activeColor
                      : context.cs.onSurfaceVariant.withAlpha(153),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeDesktopNavItem extends StatelessWidget {
  const _HomeDesktopNavItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? context.cs.primaryContainer.withValues(alpha: 0.96)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.88)
                      : context.cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isActive ? kPrimary : context.cs.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isActive ? kPrimary : context.cs.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.cs.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.3,
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
}

// ═════════════════════════════════════════════════════════════════════════════
// Attendance "How It Works" Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════

class _AttendanceHowItWorksSheet extends StatelessWidget {
  const _AttendanceHowItWorksSheet({
    required this.isOwnerOrManager,
    required this.isOnTeam,
  });

  final bool isOwnerOrManager;
  final bool isOnTeam;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.cs.onSurface.withAlpha(40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6C63FF), Color(0xFF4A42E8)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withAlpha(50),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: Text(
                      'GPS Attendance System',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.cs.onSurface,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Center(
                    child: Text(
                      'Track team attendance with GPS geofencing',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // How it works steps
                  _buildSectionTitle(context, 'How It Works'),
                  const SizedBox(height: 14),

                  _buildStep(
                    context,
                    step: '1',
                    icon: Icons.location_on_rounded,
                    color: const Color(0xFF4CAF50),
                    title: 'Owner sets office location',
                    description:
                        'The team owner marks the office on a map and sets a geofence radius (e.g., 100m). Only check-ins within this boundary are accepted.',
                  ),

                  _buildStepConnector(context),

                  _buildStep(
                    context,
                    step: '2',
                    icon: Icons.groups_rounded,
                    color: const Color(0xFF2196F3),
                    title: 'Invite team members',
                    description:
                        'Add your sales reps, managers, and staff to the team. Each member gets the attendance feature on their app.',
                  ),

                  _buildStepConnector(context),

                  _buildStep(
                    context,
                    step: '3',
                    icon: Icons.login_rounded,
                    color: const Color(0xFFFF9800),
                    title: 'Members check in & out',
                    description:
                        'Team members tap "Check In" when they arrive at office. GPS verifies they\'re within the geofence. Tap "Check Out" when leaving.',
                  ),

                  _buildStepConnector(context),

                  _buildStep(
                    context,
                    step: '4',
                    icon: Icons.analytics_rounded,
                    color: const Color(0xFF9C27B0),
                    title: 'Owner tracks everything',
                    description:
                        'View daily attendance logs, total hours worked, late arrivals, and team performance — all from the dashboard.',
                  ),

                  const SizedBox(height: 28),

                  // Features grid
                  _buildSectionTitle(context, 'Features Included'),
                  const SizedBox(height: 14),

                  _buildFeatureRow(
                    context,
                    icon: Icons.gps_fixed_rounded,
                    color: const Color(0xFF4CAF50),
                    title: 'GPS Geofencing',
                    subtitle: 'Check-in only works within office radius',
                  ),

                  _buildFeatureRow(
                    context,
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFF2196F3),
                    title: 'Work Hours Tracking',
                    subtitle: 'Automatic calculation of daily hours worked',
                  ),

                  _buildFeatureRow(
                    context,
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFFFF9800),
                    title: 'Attendance Dashboard',
                    subtitle: 'Owner sees all members\' daily/monthly logs',
                  ),

                  _buildFeatureRow(
                    context,
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF9C27B0),
                    title: 'Performance Reports',
                    subtitle: 'Track individual member attendance & invoices',
                  ),

                  _buildFeatureRow(
                    context,
                    icon: Icons.shield_rounded,
                    color: const Color(0xFF607D8B),
                    title: 'Anti-Fraud Protection',
                    subtitle: 'GPS coordinates logged with every check-in',
                  ),

                  _buildFeatureRow(
                    context,
                    icon: Icons.people_rounded,
                    color: const Color(0xFFE91E63),
                    title: 'Unlimited Team Members',
                    subtitle: 'No limit on how many people can use attendance',
                  ),

                  const SizedBox(height: 28),

                  // CTA section
                  if (!isOnTeam) ...[
                    // User has no team — prompt to create one
                    _buildInfoCard(
                      context,
                      icon: Icons.info_outline_rounded,
                      color: const Color(0xFF2196F3),
                      text:
                          'Create a team first to start using GPS attendance. Go to Team from the quick actions below.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TeamManagementScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.groups_rounded),
                        label: const Text(
                          'Create Your Team',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ] else if (isOwnerOrManager) ...[
                    // Owner/manager — show setup + dashboard options
                    _buildInfoCard(
                      context,
                      icon: Icons.lightbulb_outline_rounded,
                      color: const Color(0xFFFF9800),
                      text:
                          'Set your office location first, then invite team members. They\'ll be able to check in when near your office.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const OfficeLocationScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.location_on_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'Set Location',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AttendanceDashboardScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.dashboard_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'Dashboard',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Team member — show check-in button
                    _buildInfoCard(
                      context,
                      icon: Icons.info_outline_rounded,
                      color: const Color(0xFF4CAF50),
                      text:
                          'You can check in when you\'re at the office location set by your team owner.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GeoAttendanceScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text(
                          'Go to Check In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: context.cs.onSurface,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required String step,
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step number circle
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(60), width: 1.5),
          ),
          child: Center(
            child: Text(
              step,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: context.cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 17, top: 4, bottom: 4),
      child: Container(
        width: 2,
        height: 20,
        decoration: BoxDecoration(
          color: context.cs.onSurface.withAlpha(25),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.cs.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: color.withAlpha(180),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: context.cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sync Warning Banner ─────────────────────────────────────────────────────

/// Shows a persistent warning when offline writes haven't synced to the server.
/// Listens to [SyncStatusService] and auto-hides when sync completes.
class _SyncWarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: SyncStatusService.instance.lastSyncError,
      builder: (context, error, _) {
        if (error == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Material(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.sync_problem_rounded,
                    size: 18,
                    color: Color(0xFFB45309),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
