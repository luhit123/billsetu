import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/create_invoice_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/widgets/invoice_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget homescreen() => const HomeScreen();

enum InvoiceFilter {
  all,
  paid,
  pending,
  overdue,
}

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

  late final Stream<List<Invoice>> _invoicesStream;

  InvoiceFilter _selectedFilter = InvoiceFilter.all;

  @override
  void initState() {
    super.initState();
    _invoicesStream = widget.invoicesStream ?? FirebaseService().getInvoicesStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      drawerScrimColor: Colors.black45,
      appBar: AppBar(
        title: const Text(
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
      ),
      body: StreamBuilder<List<Invoice>>(
        stream: _invoicesStream,
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
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Total Billed',
                                value: _currencyFormat.format(totalBilled),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Collected',
                                value: _currencyFormat.format(collected),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Outstanding',
                                value: _currencyFormat.format(outstanding),
                              ),
                            ),
                          ],
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
                              _buildFilterChip(InvoiceFilter.pending, 'Pending'),
                              const SizedBox(width: 8),
                              _buildFilterChip(InvoiceFilter.overdue, 'Overdue'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: filteredInvoices.isEmpty
                              ? Center(
                                  child: Text(
                                    invoices.isEmpty
                                        ? 'No invoices available yet.'
                                        : 'No invoices match this filter.',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
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
                                            builder: (_) => InvoiceDetailsScreen(
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
            MaterialPageRoute(
              builder: (_) => const CreateInvoiceScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Invoice> _applyFilter(List<Invoice> invoices) {
    switch (_selectedFilter) {
      case InvoiceFilter.all:
        return invoices;
      case InvoiceFilter.paid:
        return invoices
            .where((invoice) => invoice.status == InvoiceStatus.paid)
            .toList();
      case InvoiceFilter.pending:
        return invoices
            .where((invoice) => invoice.status == InvoiceStatus.pending)
            .toList();
      case InvoiceFilter.overdue:
        return invoices
            .where((invoice) => invoice.status == InvoiceStatus.overdue)
            .toList();
    }
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withAlpha(30),
                    ),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.person_outline_rounded),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Guest user placeholder',
                              style: TextStyle(
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
                _DrawerMenuTile(
                  icon: Icons.badge_outlined,
                  title: 'My Profile',
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaceholderMessage('My Profile section coming soon.');
                  },
                ),
                const SizedBox(height: 8),
                _DrawerMenuTile(
                  icon: Icons.login_rounded,
                  title: 'Log In',
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaceholderMessage('Log In placeholder for now.');
                  },
                ),
                const SizedBox(height: 8),
                _DrawerMenuTile(
                  icon: Icons.logout_rounded,
                  title: 'Log Out',
                  onTap: () {
                    Navigator.pop(context);
                    _showPlaceholderMessage('Log Out placeholder for now.');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPlaceholderMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

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

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({
    required this.size,
    required this.colors,
  });

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
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

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
            color: const Color(0xFFF4F8FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD5E4FF)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF123C85)),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
