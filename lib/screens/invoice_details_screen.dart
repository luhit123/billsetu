import 'dart:typed_data';

import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/invoice.dart';
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
        final sellerName = _sellerName(profile);

        return Scaffold(
          appBar: AppBar(title: const Text('Invoice Details')),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _previewInvoicePdf(context, profile),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Preview / Print'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _shareInvoicePdf(context, profile),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share PDF'),
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
                                  'Issued by $sellerName',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(_statusLabel(invoice.status)),
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
                              label: 'Invoice Date',
                              value: _dateFormat.format(invoice.createdAt),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HeaderMeta(
                              label: 'Grand Total',
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
                  title: 'Seller',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Store', value: sellerName),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: 'Address',
                        value: _profileValueOrFallback(
                          profile?.address,
                          'Not added yet',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: 'Phone',
                        value: _profileValueOrFallback(
                          profile?.phoneNumber,
                          'Not added yet',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _DetailSection(
                  title: 'Customer',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Name', value: customerName),
                      const SizedBox(height: 10),
                      _InfoRow(label: 'Reference', value: invoice.clientId),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _DetailSection(
                  title: 'Items',
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
                                      label: 'Qty',
                                      value: item.quantity.toString(),
                                    ),
                                  ),
                                  Expanded(
                                    child: _InfoRow(
                                      label: 'Unit Price',
                                      value: _currencyFormat.format(
                                        item.unitPrice,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _InfoRow(
                                      label: 'Total',
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
                  title: 'Amount Summary',
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Subtotal',
                        value: _currencyFormat.format(invoice.subtotal),
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        label: 'Discount',
                        value: invoice.hasDiscount
                            ? '${_discountLabel(invoice)} (-${_currencyFormat.format(invoice.discountAmount)})'
                            : _currencyFormat.format(0),
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        label: 'Items Count',
                        value: invoice.items.length.toString(),
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        label: 'Status',
                        value: _statusLabel(invoice.status),
                      ),
                      const Divider(height: 24),
                      _SummaryRow(
                        label: 'Grand Total',
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
    try {
      final bytes = await _buildPdfBytes(profile);
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
    try {
      final bytes = await _buildPdfBytes(profile);
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

  Future<Uint8List> _buildPdfBytes(BusinessProfile? profile) async {
    final resolvedProfile = await _resolveProfile(profile);
    return InvoicePdfService().buildInvoicePdf(
      invoice: invoice,
      profile: resolvedProfile,
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Unable to generate invoice PDF: $error')),
      );
  }

  String _sellerName(BusinessProfile? profile) {
    final storeName = profile?.storeName.trim() ?? '';
    if (storeName.isNotEmpty) {
      return storeName;
    }

    return 'Your Store';
  }

  String _profileValueOrFallback(String? value, String fallback) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }

    return fallback;
  }

  String _statusLabel(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.overdue:
        return 'Overdue';
    }
  }

  String _discountLabel(Invoice invoice) {
    if (invoice.discountType == null || invoice.discountValue <= 0) {
      return 'No discount';
    }

    switch (invoice.discountType!) {
      case InvoiceDiscountType.percentage:
        final value = invoice.discountValue;
        final formattedValue = value.truncateToDouble() == value
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(2);
        return '$formattedValue% off';
      case InvoiceDiscountType.overall:
        return 'Overall discount';
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
