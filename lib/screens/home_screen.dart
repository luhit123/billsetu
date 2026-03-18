import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/create_invoice_screen.dart';
import 'package:billeasy/screens/feature_placeholder_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/screens/login_screen.dart';
import 'package:billeasy/screens/profile_setup_screen.dart';
import 'package:billeasy/services/auth_service.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/widgets/invoice_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget homescreen() => const HomeScreen();

enum InvoiceFilter { all, paid, pending, overdue }

enum InvoicePeriodFilter { allTime, today, thisWeek, currentMonth, customRange }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.invoicesStream});

  final Stream<List<Invoice>>? invoicesStream;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final DateFormat _monthLabelFormat = DateFormat('MMMM yyyy');
  final DateFormat _periodDateFormat = DateFormat('dd MMM yyyy');
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  String _searchQuery = '';
  InvoiceFilter _selectedFilter = InvoiceFilter.all;
  InvoicePeriodFilter _selectedPeriodFilter = InvoicePeriodFilter.currentMonth;
  DateTimeRange? _customDateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      drawerScrimColor: Colors.black45,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                cursorColor: Colors.white,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search customer name',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(170)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
              )
            : const Text(
                'BillEasy',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
        backgroundColor: const Color(0xFF123C85),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x33000000),
        elevation: 10,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search),
            tooltip: _isSearching ? 'Close search' : 'Search customers',
          ),
          IconButton(
            onPressed: _showPeriodPicker,
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Filter by period',
          ),
        ],
      ),
      body: StreamBuilder<List<Invoice>>(
        stream: _buildInvoicesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load invoices right now.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final invoices = snapshot.data ?? const <Invoice>[];
          final filteredInvoices = _applyFilter(invoices);
          final hasSearchQuery = _searchQuery.isNotEmpty;

          final totalBilled = invoices.fold<double>(
            0,
            (runningTotal, invoice) => runningTotal + invoice.grandTotal,
          );
          final collected = invoices
              .where((invoice) => invoice.status == InvoiceStatus.paid)
              .fold<double>(
                0,
                (runningTotal, invoice) => runningTotal + invoice.grandTotal,
              );
          final outstanding = invoices
              .where((invoice) => invoice.status != InvoiceStatus.paid)
              .fold<double>(
                0,
                (runningTotal, invoice) => runningTotal + invoice.grandTotal,
              );
          final discountsGiven = invoices.fold<double>(
            0,
            (runningTotal, invoice) => runningTotal + invoice.discountAmount,
          );

          return SafeArea(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE4FFFB),
                    const Color(0xFFF5FFFD),
                    const Color(0xFFEAF2FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -30,
                    child: _BackgroundOrb(
                      size: 180,
                      colors: [
                        Colors.teal.shade200.withAlpha(140),
                        Colors.cyan.shade100.withAlpha(30),
                      ],
                    ),
                  ),
                  Positioned(
                    left: -50,
                    top: 210,
                    child: _BackgroundOrb(
                      size: 220,
                      colors: [
                        Colors.lightBlue.shade100.withAlpha(100),
                        Colors.white.withAlpha(20),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PeriodSummaryCard(
                          label: 'Period',
                          value: _periodLabel,
                          onTap: _showPeriodPicker,
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth - 12) / 2;

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _StatCard(
                                    label: 'Total Billed',
                                    value: _currencyFormat.format(totalBilled),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _StatCard(
                                    label: 'Collected',
                                    value: _currencyFormat.format(collected),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _StatCard(
                                    label: 'Outstanding',
                                    value: _currencyFormat.format(outstanding),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _StatCard(
                                    label: 'Discounts',
                                    value: _currencyFormat.format(
                                      discountsGiven,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(InvoiceFilter.all, 'All'),
                              const SizedBox(width: 8),
                              _buildFilterChip(InvoiceFilter.paid, 'Paid'),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                InvoiceFilter.pending,
                                'Pending',
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                InvoiceFilter.overdue,
                                'Overdue',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: filteredInvoices.isEmpty
                              ? Center(
                                  child: Text(
                                    hasSearchQuery && invoices.isEmpty
                                        ? 'No invoices found for "$_searchQuery".'
                                        : invoices.isEmpty
                                        ? 'No invoices available yet.'
                                        : 'No invoices match this filter.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredInvoices.length,
                                  itemBuilder: (context, index) {
                                    final invoice = filteredInvoices[index];

                                    return InvoiceCard(
                                      invoice: invoice,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                InvoiceDetailsScreen(
                                                  invoice: invoice,
                                                ),
                                          ),
                                        );
                                      },
                                      onStatusChange: (status) {
                                        FirebaseService().updateInvoiceStatus(
                                          invoice.id,
                                          status,
                                        );
                                      },
                                      onDelete: () {
                                        FirebaseService().deleteInvoice(
                                          invoice.id,
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-invoice-fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Invoice> _applyFilter(List<Invoice> invoices) {
    final statusFiltered = switch (_selectedFilter) {
      InvoiceFilter.all => invoices,
      InvoiceFilter.paid =>
        invoices
            .where((invoice) => invoice.status == InvoiceStatus.paid)
            .toList(),
      InvoiceFilter.pending =>
        invoices
            .where((invoice) => invoice.status == InvoiceStatus.pending)
            .toList(),
      InvoiceFilter.overdue =>
        invoices
            .where((invoice) => invoice.status == InvoiceStatus.overdue)
            .toList(),
    };

    final normalizedQuery = _searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return statusFiltered;
    }

    return statusFiltered.where((invoice) {
      return invoice.clientName.toLowerCase().contains(normalizedQuery) ||
          invoice.invoiceNumber.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  Widget _buildFilterChip(InvoiceFilter filter, String label) {
    return FilterChip(
      selected: _selectedFilter == filter,
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      selectedColor: Colors.teal.shade100,
      checkmarkColor: Colors.teal.shade900,
      labelStyle: TextStyle(
        color: _selectedFilter == filter ? Colors.teal.shade900 : null,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Stream<List<Invoice>> _buildInvoicesStream() {
    if (widget.invoicesStream != null) {
      return widget.invoicesStream!;
    }

    final periodBounds = _selectedPeriodBounds;
    final shouldUseFirebaseSearch = periodBounds == null;

    return FirebaseService().getInvoicesStream(
      searchQuery: shouldUseFirebaseSearch ? _searchQuery : '',
      startDate: periodBounds?.$1,
      endDateExclusive: periodBounds?.$2,
    );
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _searchController.clear();
        _searchQuery = '';
        _isSearching = false;
      } else {
        _isSearching = true;
      }
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
                title: 'All Invoices',
                isSelected:
                    _selectedPeriodFilter == InvoicePeriodFilter.allTime,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _selectedPeriodFilter = InvoicePeriodFilter.allTime;
                  });
                },
              ),
              _PeriodOptionTile(
                title: 'Today',
                isSelected: _selectedPeriodFilter == InvoicePeriodFilter.today,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _selectedPeriodFilter = InvoicePeriodFilter.today;
                  });
                },
              ),
              _PeriodOptionTile(
                title: 'This Week',
                isSelected:
                    _selectedPeriodFilter == InvoicePeriodFilter.thisWeek,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _selectedPeriodFilter = InvoicePeriodFilter.thisWeek;
                  });
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
      saveText: 'Apply',
    );

    if (pickedRange == null) {
      return;
    }

    setState(() {
      _customDateRange = pickedRange;
      _selectedPeriodFilter = InvoicePeriodFilter.customRange;
    });
  }

  String get _periodLabel {
    switch (_selectedPeriodFilter) {
      case InvoicePeriodFilter.allTime:
        return 'All Invoices';
      case InvoicePeriodFilter.today:
        return 'Today';
      case InvoicePeriodFilter.thisWeek:
        return 'This Week';
      case InvoicePeriodFilter.currentMonth:
        return _monthLabelFormat.format(DateTime.now());
      case InvoicePeriodFilter.customRange:
        final customRange = _customDateRange;
        if (customRange == null) {
          return 'Custom Range';
        }
        return '${_periodDateFormat.format(customRange.start)} - ${_periodDateFormat.format(customRange.end)}';
    }
  }

  String get _customPeriodSheetLabel {
    final customRange = _customDateRange;
    if (customRange == null) {
      return 'Custom Range';
    }

    return 'Custom: ${_periodDateFormat.format(customRange.start)} - ${_periodDateFormat.format(customRange.end)}';
  }

  (DateTime, DateTime)? get _selectedPeriodBounds {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    switch (_selectedPeriodFilter) {
      case InvoicePeriodFilter.allTime:
        return null;
      case InvoicePeriodFilter.today:
        return (startOfToday, startOfToday.add(const Duration(days: 1)));
      case InvoicePeriodFilter.thisWeek:
        final startOfWeek = startOfToday.subtract(
          Duration(days: startOfToday.weekday - DateTime.monday),
        );
        return (startOfWeek, startOfWeek.add(const Duration(days: 7)));
      case InvoicePeriodFilter.currentMonth:
        final startOfMonth = DateTime(now.year, now.month);
        final endOfMonthExclusive = DateTime(now.year, now.month + 1);
        return (startOfMonth, endOfMonthExclusive);
      case InvoicePeriodFilter.customRange:
        final customRange = _customDateRange;
        if (customRange == null) {
          return null;
        }
        final start = DateTime(
          customRange.start.year,
          customRange.start.month,
          customRange.start.day,
        );
        final endExclusive = DateTime(
          customRange.end.year,
          customRange.end.month,
          customRange.end.day + 1,
        );
        return (start, endExclusive);
    }
  }

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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF123C85),
              const Color(0xFF1E57B7),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0, 0.35, 0.35],
          ),
        ),
        child: SafeArea(
          child: Firebase.apps.isEmpty
              ? _buildDrawerBody(null)
              : StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  initialData: FirebaseAuth.instance.currentUser,
                  builder: (context, snapshot) {
                    return _buildDrawerBody(snapshot.data);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildDrawerBody(User? user) {
    final displayName = _displayNameForUser(user);
    final subtitle = user?.email ?? 'Not signed in';
    final authActionLabel = user == null ? 'Log In' : 'Log Out';
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
                  const _DrawerSectionLabel(title: 'Workspace'),
                  _DrawerMenuTile(
                    icon: Icons.badge_outlined,
                    title: 'My Profile',
                    onTap: () {
                      _openDrawerScreen(const ProfileSetupScreen());
                    },
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Products',
                    onTap: () {
                      _openDrawerPlaceholder(
                        title: 'Products',
                        icon: Icons.inventory_2_outlined,
                        description:
                            'Create and organize your product catalog, pricing, and reusable invoice items from one place.',
                        accentColor: const Color(0xFF16608A),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.groups_2_outlined,
                    title: 'Customers',
                    onTap: () {
                      _openDrawerPlaceholder(
                        title: 'Customers',
                        icon: Icons.groups_2_outlined,
                        description:
                            'Manage customer records, contact details, and billing relationships for every client account.',
                        accentColor: const Color(0xFF0F7D83),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Subscriptions',
                    onTap: () {
                      _openDrawerPlaceholder(
                        title: 'Subscriptions',
                        icon: Icons.workspace_premium_outlined,
                        description:
                            'Track active plans, recurring billing, renewals, and premium access features for your business.',
                        accentColor: const Color(0xFF5A4FCF),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.query_stats_outlined,
                    title: 'Analytics',
                    onTap: () {
                      _openDrawerPlaceholder(
                        title: 'Analytics',
                        icon: Icons.query_stats_outlined,
                        description:
                            'See billing trends, collections, overdue patterns, and business performance insights at a glance.',
                        accentColor: const Color(0xFF005C6B),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'GST',
                    onTap: () {
                      _openDrawerPlaceholder(
                        title: 'GST',
                        icon: Icons.receipt_long_outlined,
                        description:
                            'Prepare GST-ready records, tax summaries, and compliance-friendly invoice data for filing.',
                        accentColor: const Color(0xFF8A5A16),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _DrawerMenuTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      _openDrawerPlaceholder(
                        title: 'Settings',
                        icon: Icons.settings_outlined,
                        description:
                            'Control preferences, app behavior, business defaults, and account-level configuration settings.',
                        accentColor: const Color(0xFF3C4A6B),
                      );
                    },
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
                ? const Color(0xFFE7F0FF)
                : const Color(0xFFFFECEC),
            borderColor: user == null
                ? const Color(0xFFC7DAFF)
                : const Color(0xFFFFD1D1),
            iconColor: user == null
                ? const Color(0xFF123C85)
                : const Color(0xFFB3261E),
            textColor: user == null
                ? const Color(0xFF123C85)
                : const Color(0xFFB3261E),
            onTap: () {
              _handleDrawerAuthAction(user);
            },
          ),
        ],
      ),
    );
  }

  void _openDrawerScreen(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openDrawerPlaceholder({
    required String title,
    required IconData icon,
    required String description,
    required Color accentColor,
  }) {
    _openDrawerScreen(
      FeaturePlaceholderScreen(
        title: title,
        icon: icon,
        description: description,
        accentColor: accentColor,
      ),
    );
  }

  Future<void> _handleDrawerAuthAction(User? user) async {
    Navigator.pop(context);

    if (!mounted) {
      return;
    }

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    try {
      await AuthService().signOut();
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to log out: $error')));
    }
  }

  String _displayNameForUser(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'My Profile';
  }

  String _avatarLabelForUser(User? user) {
    final source = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.trim();

    if (source == null || source.isEmpty) {
      return 'G';
    }

    return source.characters.first.toUpperCase();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(150),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(180)),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade900.withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.teal.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(170),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(190)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: Colors.teal.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.teal.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Change',
                style: TextStyle(
                  color: Colors.teal.shade800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _DrawerMenuTile extends StatelessWidget {
  const _DrawerMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.backgroundColor = const Color(0xFFF4F8FF),
    this.borderColor = const Color(0xFFD5E4FF),
    this.iconColor = const Color(0xFF123C85),
    this.textColor = Colors.black87,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
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
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
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
        color: isSelected ? const Color(0xFF123C85) : Colors.grey.shade500,
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
