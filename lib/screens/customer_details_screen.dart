import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/create_invoice_screen.dart';
import 'package:billeasy/screens/customer_form_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/widgets/customer_groups_sheet.dart';
import 'package:billeasy/widgets/invoice_card.dart';
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
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Client?>(
      stream: _clientService.watchClient(widget.client.id),
      initialData: widget.client,
      builder: (context, clientSnapshot) {
        final client = clientSnapshot.data ?? widget.client;

        return StreamBuilder<List<Invoice>>(
          stream: _firebaseService.getInvoicesForClientStream(client.id),
          builder: (context, invoiceSnapshot) {
            if (invoiceSnapshot.connectionState == ConnectionState.waiting &&
                !invoiceSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final invoices = invoiceSnapshot.data ?? const <Invoice>[];
            final totalBilled = invoices.fold<double>(
              0,
              (runningTotal, invoice) => runningTotal + invoice.grandTotal,
            );
            final outstanding = invoices
                .where((invoice) => invoice.status != InvoiceStatus.paid)
                .fold<double>(
                  0,
                  (runningTotal, invoice) => runningTotal + invoice.grandTotal,
                );

            final s = AppStrings.of(context);
            return Scaffold(
              appBar: AppBar(
                title: Text(s.customerDetailsTitle),
                actions: [
                  IconButton(
                    onPressed: () => _editCustomer(client),
                    tooltip: s.customerDetailsEditTooltip,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => _moveCustomerToGroup(client),
                    tooltip: client.groupId.isEmpty
                        ? s.customerDetailsMoveGroup
                        : s.customerDetailsChangeGroup,
                    icon: const Icon(Icons.folder_open_rounded),
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: () => _createInvoiceForCustomer(client),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(s.customerDetailsCreateInvoice),
                ),
              ),
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFEAF8FF),
                      Color(0xFFF4FBFF),
                      Color(0xFFFFFFFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _CustomerHeroCard(client: client),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: s.customerDetailsStatInvoices,
                              value: invoices.length.toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: s.customerDetailsStatTotalBilled,
                              value: _currencyFormat.format(totalBilled),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StatCard(
                        label: s.customerDetailsStatOutstanding,
                        value: _currencyFormat.format(outstanding),
                        accentColor: outstanding > 0
                            ? const Color(0xFFB3261E)
                            : const Color(0xFF0F7D83),
                      ),
                      const SizedBox(height: 18),
                      _DetailSection(
                        title: s.customerDetailsContact,
                        children: [
                          _InfoRow(
                            label: s.customerDetailsGroup,
                            value: _valueOrFallback(client.groupName),
                          ),
                          _InfoRow(
                            label: s.customerDetailsPhone,
                            value: _valueOrFallback(client.phone),
                          ),
                          if (client.email.trim().isNotEmpty)
                            _InfoRow(
                              label: s.customerDetailsEmail,
                              value: client.email.trim(),
                            ),
                          _InfoRow(
                            label: s.customerDetailsAddress,
                            value: _valueOrFallback(client.address),
                          ),
                        ],
                      ),
                      if (client.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _DetailSection(
                          title: s.customerDetailsNotes,
                          children: [
                            Text(
                              client.notes.trim(),
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontSize: 14.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      _DetailSection(
                        title: s.customerDetailsHistory,
                        children: [
                          if (invoiceSnapshot.hasError)
                            Text(
                              s.customerDetailsHistoryError,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else if (invoices.isEmpty)
                            Text(
                              s.customerDetailsHistoryEmpty,
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                height: 1.5,
                              ),
                            )
                          else
                            ...invoices.map((invoice) {
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
                                  _firebaseService.updateInvoiceStatus(
                                    invoice.id,
                                    status,
                                  );
                                },
                                onDelete: () {
                                  _firebaseService.deleteInvoice(invoice.id);
                                },
                              );
                            }),
                        ],
                      ),
                      if (client.updatedAt != null) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            s.customerDetailsLastUpdated(_dateFormat.format(client.updatedAt!)),
                            style: TextStyle(
                              color: Colors.blueGrey.shade500,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

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
      final updatedClient = await _clientService.updateClientGroup(
        client: client,
        groupId: selection.groupId,
        groupName: selection.groupName,
      );

      if (!mounted) {
        return;
      }

      final s = AppStrings.of(context);
      final message = updatedClient.groupName.trim().isEmpty
          ? s.customerDetailsNowUngrouped(updatedClient.name)
          : s.customerDetailsMovedToGroup(updatedClient.name, updatedClient.groupName);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).customerDetailsFailedUpdateGroup(error.toString()))),
      );
    }
  }

  String _valueOrFallback(String value) {
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? AppStrings.of(context).customerDetailsNotAdded : trimmedValue;
  }
}

class _CustomerHeroCard extends StatelessWidget {
  const _CustomerHeroCard({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF123C85), Color(0xFF0F7D83)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
            child: Text(
              client.initials,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  client.subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.accentColor = const Color(0xFF123C85),
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF123C85),
            ),
          ),
          const SizedBox(height: 14),
          ..._withSpacing(children),
        ],
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> widgets) {
    final spacedWidgets = <Widget>[];
    for (var index = 0; index < widgets.length; index++) {
      spacedWidgets.add(widgets[index]);
      if (index < widgets.length - 1) {
        spacedWidgets.add(const SizedBox(height: 12));
      }
    }
    return spacedWidgets;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
