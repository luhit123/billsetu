import 'dart:typed_data';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/customer_details_screen.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/invoice_pdf_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  InvoiceDetailsScreen({super.key, required this.invoice});

  final Invoice invoice;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final customerName = invoice.clientName;
    final Stream<BusinessProfile?> profileStream = Firebase.apps.isEmpty
        ? Stream<BusinessProfile?>.value(null)
        : ProfileService().watchCurrentProfile();

    return StreamBuilder<BusinessProfile?>(
      stream: profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final s = AppStrings.of(context);
        final sellerName = _sellerName(profile, s);
        return Scaffold(
          appBar: AppBar(title: Text(s.detailsTitle)),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _previewInvoicePdf(context, profile),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(s.detailsPreviewPrint),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _shareInvoicePdf(context, profile),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(s.detailsSharePdf),
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade600, Colors.teal.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                            child: Text(
                              customerName.isEmpty ? '?' : customerName[0],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invoice.invoiceNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  customerName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  s.detailsIssuedBy(sellerName),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(_statusLabel(invoice.status, s)),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _statusTextColor(invoice.status),
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide.none,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _HeaderMeta(
                              label: s.createInvoiceDate,
                              value: _dateFormat.format(invoice.createdAt),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HeaderMeta(
                              label: s.createSummaryGrandTotal,
                              value: _currencyFormat.format(invoice.grandTotal),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _DetailSection(
                  title: s.detailsSeller,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: s.detailsStore, value: sellerName),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: s.detailsAddress,
                        value: _profileValueOrFallback(
                          profile?.address,
                          s.detailsNotAddedYet,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: s.detailsPhone,
                        value: _profileValueOrFallback(
                          profile?.phoneNumber,
                          s.detailsNotAddedYet,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _DetailSection(
                  title: s.detailsCustomer,
                  child: StreamBuilder<Client?>(
                    stream: Firebase.apps.isEmpty
                        ? Stream<Client?>.value(null)
                        : ClientService().watchClient(invoice.clientId),
                    builder: (context, clientSnapshot) {
                      final client = clientSnapshot.data;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(label: s.detailsName, value: customerName),
                          const SizedBox(height: 10),
                          _InfoRow(
                            label: s.detailsReference,
                            value: invoice.clientId,
                          ),
                          if (client != null &&
                              client.phone.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _InfoRow(
                              label: s.detailsPhone,
                              value: client.phone.trim(),
                            ),
                          ],
                          if (client != null &&
                              client.email.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _InfoRow(
                              label: s.detailsEmail,
                              value: client.email.trim(),
                            ),
                          ],
                          if (client != null &&
                              client.address.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _InfoRow(
                              label: s.detailsAddress,
                              value: client.address.trim(),
                            ),
                          ],
                          if (client != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CustomerDetailsScreen(client: client),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.person_search_outlined),
                                label: Text(s.detailsOpenProfile),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _DetailSection(
                  title: s.detailsItems,
                  child: Column(
                    children: [
                      ...invoice.items.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.description,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoRow(
                                      label: s.detailsItemQty,
                                      value: item.quantityLabel,
                                    ),
                                  ),
                                  Expanded(
                                    child: _InfoRow(
                                      label: s.detailsItemUnitPrice,
                                      value: _currencyFormat.format(
                                        item.unitPrice,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _InfoRow(
                                      label: s.detailsItemTotal,
                                      value: _currencyFormat.format(item.total),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _DetailSection(
                  title: s.detailsAmountSummary,
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: s.detailsSubtotal,
                        value: _currencyFormat.format(invoice.subtotal),
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        label: s.detailsDiscount,
                        value: invoice.hasDiscount
                            ? '${_discountLabel(invoice, s)} (-${_currencyFormat.format(invoice.discountAmount)})'
                            : _currencyFormat.format(0),
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        label: s.detailsItemsCount,
                        value: invoice.items.length.toString(),
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        label: s.detailsStatus,
                        value: _statusLabel(invoice.status, s),
                      ),
                      const Divider(height: 24),
                      _SummaryRow(
                        label: s.createSummaryGrandTotal,
                        value: _currencyFormat.format(invoice.grandTotal),
                        isEmphasized: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _previewInvoicePdf(
    BuildContext context,
    BusinessProfile? profile,
  ) async {
    final language = AppStrings.of(context).language;
    try {
      final bytes = await _buildPdfBytes(profile, language);
      await Printing.layoutPdf(
        name: InvoicePdfService().fileNameForInvoice(invoice),
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showExportError(context, error);
    }
  }

  Future<void> _shareInvoicePdf(
    BuildContext context,
    BusinessProfile? profile,
  ) async {
    final language = AppStrings.of(context).language;
    try {
      final bytes = await _buildPdfBytes(profile, language);
      await Printing.sharePdf(
        bytes: bytes,
        filename: InvoicePdfService().fileNameForInvoice(invoice),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showExportError(context, error);
    }
  }

  Future<Uint8List> _buildPdfBytes(
    BusinessProfile? profile,
    AppLanguage language,
  ) async {
    final resolvedProfile = await _resolveProfile(profile);
    return InvoicePdfService().buildInvoicePdf(
      invoice: invoice,
      profile: resolvedProfile,
      language: language,
    );
  }

  Future<BusinessProfile?> _resolveProfile(BusinessProfile? profile) async {
    if (profile != null || Firebase.apps.isEmpty) {
      return profile;
    }

    try {
      return await ProfileService().getCurrentProfile();
    } catch (_) {
      return profile;
    }
  }

  void _showExportError(BuildContext context, Object error) {
    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(s.detailsPdfError(error.toString()))),
      );
  }

  String _sellerName(BusinessProfile? profile, AppStrings s) {
    final storeName = profile?.storeName.trim() ?? '';
    if (storeName.isNotEmpty) {
      return storeName;
    }

    return s.detailsYourStore;
  }

  String _profileValueOrFallback(String? value, String fallback) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }

    return fallback;
  }

  String _statusLabel(InvoiceStatus status, AppStrings s) {
    switch (status) {
      case InvoiceStatus.paid:
        return s.statusPaid;
      case InvoiceStatus.pending:
        return s.statusPending;
      case InvoiceStatus.overdue:
        return s.statusOverdue;
    }
  }

  String _discountLabel(Invoice invoice, AppStrings s) {
    if (invoice.discountType == null || invoice.discountValue <= 0) {
      return s.detailsNoDiscount;
    }

    switch (invoice.discountType!) {
      case InvoiceDiscountType.percentage:
        final value = invoice.discountValue;
        final formattedValue = value.truncateToDouble() == value
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(2);
        return s.detailsPctOff(formattedValue);
      case InvoiceDiscountType.overall:
        return s.detailsOverallDiscount;
    }
  }

  Color _statusTextColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return Colors.green.shade800;
      case InvoiceStatus.pending:
        return Colors.orange.shade800;
      case InvoiceStatus.overdue:
        return Colors.red.shade800;
    }
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _HeaderMeta extends StatelessWidget {
  const _HeaderMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isEmphasized = false,
  });

  final String label;
  final String value;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: isEmphasized ? 18 : 15,
      fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w600,
      color: isEmphasized ? Colors.teal.shade800 : Colors.black87,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textStyle),
        Text(value, style: textStyle),
      ],
    );
  }
}
