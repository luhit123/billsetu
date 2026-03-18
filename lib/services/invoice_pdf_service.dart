import 'dart:typed_data';

import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfService {
  static const PdfColor _brandDark = PdfColor(0.07, 0.24, 0.52);
  static const PdfColor _brandLight = PdfColor(0.13, 0.63, 0.67);
  static const PdfColor _paperTint = PdfColor(0.95, 0.97, 1);
  static const PdfColor _border = PdfColor(0.86, 0.89, 0.93);
  static const PdfColor _mutedText = PdfColor(0.39, 0.44, 0.53);
  static const PdfColor _darkText = PdfColor(0.12, 0.16, 0.23);
  static const PdfColor _success = PdfColor(0.12, 0.55, 0.29);
  static const PdfColor _warning = PdfColor(0.83, 0.49, 0.09);
  static const PdfColor _danger = PdfColor(0.76, 0.15, 0.15);

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _generatedFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  Future<Uint8List> buildInvoicePdf({
    required Invoice invoice,
    BusinessProfile? profile,
  }) async {
    final document = pw.Document(
      title: invoice.invoiceNumber,
      author: _sellerName(profile),
      subject: 'BillEasy invoice ${invoice.invoiceNumber}',
      creator: 'BillEasy',
    );

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 28),
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildHeader(invoice, profile),
          pw.SizedBox(height: 22),
          _buildPartySection(invoice, profile),
          pw.SizedBox(height: 22),
          _buildItemsTable(invoice),
          pw.SizedBox(height: 22),
          _buildTotalsSection(invoice),
          pw.SizedBox(height: 18),
          _buildNotesSection(invoice),
        ],
      ),
    );

    return document.save();
  }

  String fileNameForInvoice(Invoice invoice) {
    final invoicePart = _sanitizeForFileName(invoice.invoiceNumber, 'invoice');
    final clientPart = _sanitizeForFileName(invoice.clientName, 'customer');
    return 'BillEasy_${invoicePart}_$clientPart.pdf';
  }

  pw.Widget _buildHeader(Invoice invoice, BusinessProfile? profile) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(24),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_brandDark, _brandLight],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(22),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BillEasy',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2.4,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Prepared for ${_customerName(invoice)}',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Issued by ${_sellerName(profile)}',
                  style: pw.TextStyle(
                    color: const PdfColor(0.91, 0.95, 1),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 18),
          pw.Container(
            width: 195,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(18),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildStatusBadge(invoice.status),
                pw.SizedBox(height: 16),
                _buildMetaLine('Invoice No.', invoice.invoiceNumber),
                pw.SizedBox(height: 10),
                _buildMetaLine(
                  'Invoice Date',
                  _dateFormat.format(invoice.createdAt),
                ),
                pw.SizedBox(height: 10),
                _buildMetaLine(
                  'Grand Total',
                  _formatCurrency(invoice.grandTotal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPartySection(Invoice invoice, BusinessProfile? profile) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildPartyCard(
            heading: 'From',
            title: _sellerName(profile),
            rows: [
              _profileValue(profile?.address, 'Store address not added'),
              _profileValue(profile?.phoneNumber, 'Phone number not added'),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: _buildPartyCard(
            heading: 'Bill To',
            title: _customerName(invoice),
            rows: [
              if (invoice.clientId.trim().isNotEmpty)
                'Reference: ${invoice.clientId.trim()}',
              'Status: ${_statusLabel(invoice.status)}',
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPartyCard({
    required String heading,
    required String title,
    required List<String> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _paperTint,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _border, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            heading.toUpperCase(),
            style: pw.TextStyle(
              color: _brandDark,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            title,
            style: pw.TextStyle(
              color: _darkText,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          ...rows.map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text(
                row,
                style: pw.TextStyle(
                  color: _mutedText,
                  fontSize: 11,
                  lineSpacing: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(Invoice invoice) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _brandDark),
        children: [
          _tableCell('Item', isHeader: true),
          _tableCell('Qty', isHeader: true, alignment: pw.Alignment.center),
          _tableCell(
            'Unit Price',
            isHeader: true,
            alignment: pw.Alignment.centerRight,
          ),
          _tableCell(
            'Amount',
            isHeader: true,
            alignment: pw.Alignment.centerRight,
          ),
        ],
      ),
    ];

    for (var index = 0; index < invoice.items.length; index++) {
      final item = invoice.items[index];
      final isStriped = index.isOdd;

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isStriped ? _paperTint : PdfColors.white,
          ),
          children: [
            _tableCell('${index + 1}. ${item.description}'),
            _tableCell(
              item.quantity.toString(),
              alignment: pw.Alignment.center,
            ),
            _tableCell(
              _formatCurrency(item.unitPrice),
              alignment: pw.Alignment.centerRight,
            ),
            _tableCell(
              _formatCurrency(item.total),
              alignment: pw.Alignment.centerRight,
              valueColor: _darkText,
              fontWeight: pw.FontWeight.bold,
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Items',
          style: pw.TextStyle(
            color: _darkText,
            fontSize: 17,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _border, width: 0.8),
            bottom: pw.BorderSide(color: _border, width: 0.8),
            left: pw.BorderSide(color: _border, width: 0.8),
            right: pw.BorderSide(color: _border, width: 0.8),
          ),
          columnWidths: const {
            0: pw.FlexColumnWidth(4.4),
            1: pw.FlexColumnWidth(1.1),
            2: pw.FlexColumnWidth(1.8),
            3: pw.FlexColumnWidth(1.9),
          },
          children: rows,
        ),
      ],
    );
  }

  pw.Widget _buildTotalsSection(Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(18),
              border: pw.Border.all(color: _border, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    color: _darkText,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  '${invoice.items.length} item(s) billed • ${_statusLabel(invoice.status)}',
                  style: pw.TextStyle(color: _mutedText, fontSize: 11),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  invoice.hasDiscount
                      ? '${_discountLabel(invoice)} reduced the original subtotal by ${_formatCurrency(invoice.discountAmount)}.'
                      : 'No invoice-level discount has been applied to this bill.',
                  style: pw.TextStyle(
                    color: _mutedText,
                    fontSize: 11,
                    lineSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Container(
          width: 220,
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: _paperTint,
            borderRadius: pw.BorderRadius.circular(18),
            border: pw.Border.all(color: _border, width: 1),
          ),
          child: pw.Column(
            children: [
              _summaryLine('Subtotal', _formatCurrency(invoice.subtotal)),
              pw.SizedBox(height: 12),
              _summaryLine(
                'Discount',
                invoice.hasDiscount
                    ? '-${_formatCurrency(invoice.discountAmount)}'
                    : _formatCurrency(0),
                valueColor: invoice.hasDiscount ? _success : _darkText,
              ),
              if (invoice.hasDiscount) ...[
                pw.SizedBox(height: 6),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    _discountLabel(invoice),
                    style: pw.TextStyle(color: _mutedText, fontSize: 10),
                  ),
                ),
              ],
              pw.Divider(color: _border, height: 22),
              _summaryLine(
                'Grand Total',
                _formatCurrency(invoice.grandTotal),
                emphasize: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildNotesSection(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _border, width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 34,
            height: 34,
            decoration: const pw.BoxDecoration(
              color: _paperTint,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text(
                'i',
                style: pw.TextStyle(
                  color: _brandDark,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Text(
              'Payment status for this invoice is currently marked as ${_statusLabel(invoice.status)}. '
              'This invoice was generated digitally using BillEasy and is ready to preview, print, or share.',
              style: pw.TextStyle(
                color: _mutedText,
                fontSize: 11,
                lineSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by BillEasy on ${_generatedFormat.format(DateTime.now())}',
            style: pw.TextStyle(color: _mutedText, fontSize: 9),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(color: _mutedText, fontSize: 9),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatusBadge(InvoiceStatus status) {
    final color = _statusColor(status);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _statusBackground(status),
        borderRadius: pw.BorderRadius.circular(999),
      ),
      child: pw.Text(
        _statusLabel(status),
        style: pw.TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _buildMetaLine(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(color: _mutedText, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: _darkText,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _tableCell(
    String value, {
    bool isHeader = false,
    pw.Alignment alignment = pw.Alignment.centerLeft,
    PdfColor? valueColor,
    pw.FontWeight? fontWeight,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: pw.Align(
        alignment: alignment,
        child: pw.Text(
          value,
          style: pw.TextStyle(
            color: isHeader ? PdfColors.white : valueColor ?? _mutedText,
            fontSize: isHeader ? 10 : 11,
            fontWeight:
                fontWeight ??
                (isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ),
      ),
    );
  }

  pw.Widget _summaryLine(
    String label,
    String value, {
    bool emphasize = false,
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: emphasize ? _darkText : _mutedText,
            fontSize: emphasize ? 12 : 11,
            fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: valueColor ?? _darkText,
            fontSize: emphasize ? 16 : 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _sellerName(BusinessProfile? profile) {
    final storeName = profile?.storeName.trim() ?? '';
    if (storeName.isNotEmpty) {
      return storeName;
    }

    return 'Your Store';
  }

  String _customerName(Invoice invoice) {
    final clientName = invoice.clientName.trim();
    if (clientName.isNotEmpty) {
      return clientName;
    }

    final clientId = invoice.clientId.trim();
    if (clientId.isNotEmpty) {
      return clientId;
    }

    return 'Customer';
  }

  String _profileValue(String? value, String fallback) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }

    return fallback;
  }

  String _discountLabel(Invoice invoice) {
    if (!invoice.hasDiscount || invoice.discountType == null) {
      return 'No discount';
    }

    switch (invoice.discountType!) {
      case InvoiceDiscountType.percentage:
        final value = invoice.discountValue;
        final formatted = value.truncateToDouble() == value
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(2);
        return '$formatted% off';
      case InvoiceDiscountType.overall:
        return 'Overall discount';
    }
  }

  String _formatCurrency(double value) {
    return _currencyFormat.format(value);
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

  PdfColor _statusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return _success;
      case InvoiceStatus.pending:
        return _warning;
      case InvoiceStatus.overdue:
        return _danger;
    }
  }

  PdfColor _statusBackground(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return const PdfColor(0.91, 0.97, 0.92);
      case InvoiceStatus.pending:
        return const PdfColor(1, 0.96, 0.87);
      case InvoiceStatus.overdue:
        return const PdfColor(0.99, 0.91, 0.91);
    }
  }

  String _sanitizeForFileName(String value, String fallback) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return fallback;
    }

    final sanitized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return sanitized.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
