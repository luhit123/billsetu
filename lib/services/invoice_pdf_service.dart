import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfService {
  // Brand palette
  static const PdfColor _navy = PdfColor(0.07, 0.24, 0.52);
  static const PdfColor _teal = PdfColor(0.06, 0.49, 0.51);
  static const PdfColor _navyLight = PdfColor(0.14, 0.34, 0.65);
  static const PdfColor _surface = PdfColor(0.97, 0.98, 1.00);
  static const PdfColor _border = PdfColor(0.87, 0.90, 0.95);
  static const PdfColor _mutedText = PdfColor(0.45, 0.51, 0.62);
  static const PdfColor _bodyText = PdfColor(0.20, 0.25, 0.35);
  static const PdfColor _headingText = PdfColor(0.08, 0.13, 0.22);
  static const PdfColor _success = PdfColor(0.10, 0.52, 0.27);
  static const PdfColor _warning = PdfColor(0.72, 0.40, 0.04);
  static const PdfColor _danger = PdfColor(0.74, 0.13, 0.13);
  static const PdfColor _successBg = PdfColor(0.91, 0.97, 0.93);
  static const PdfColor _warningBg = PdfColor(1.00, 0.96, 0.86);
  static const PdfColor _dangerBg = PdfColor(0.99, 0.91, 0.91);

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _generatedFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  pw.Font? _fontRegular;
  pw.Font? _fontBold;

  Future<void> _loadFonts(AppLanguage language) async {
    if (_fontRegular != null) return;
    try {
      switch (language) {
        case AppLanguage.hindi:
          final data = await rootBundle.load(
            'assets/fonts/NotoSansDevanagari.ttf',
          );
          _fontRegular = pw.Font.ttf(data);
          _fontBold = pw.Font.ttf(data);
        case AppLanguage.assamese:
          final data = await rootBundle.load(
            'assets/fonts/NotoSansBengali.ttf',
          );
          _fontRegular = pw.Font.ttf(data);
          _fontBold = pw.Font.ttf(data);
        case AppLanguage.english:
          _fontRegular = pw.Font.helvetica();
          _fontBold = pw.Font.helveticaBold();
      }
    } catch (_) {
      _fontRegular = pw.Font.helvetica();
      _fontBold = pw.Font.helveticaBold();
    }
  }

  Future<Uint8List> buildInvoicePdf({
    required Invoice invoice,
    BusinessProfile? profile,
    AppLanguage language = AppLanguage.english,
  }) async {
    await _loadFonts(language);
    // PDF structural labels are always English — the pdf package cannot do
    // Indic script shaping (Devanagari / Bengali conjuncts, vowel marks) so
    // regional text breaks apart visually. English labels render perfectly with
    // every font and match standard Indian business invoice format.
    const s = AppStrings(AppLanguage.english);

    final document = pw.Document(
      title: invoice.invoiceNumber,
      author: _sellerName(profile, s),
      subject: 'BillEasy invoice ${invoice.invoiceNumber}',
      creator: 'BillEasy',
    );

    final theme = pw.ThemeData.withFont(base: _fontRegular!, bold: _fontBold!);

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 0, 36, 32),
        ),
        footer: (ctx) => _footer(ctx, s),
        build: (ctx) => [
          _header(invoice, profile, s),
          pw.SizedBox(height: 26),
          _partySection(invoice, profile, s),
          pw.SizedBox(height: 26),
          _itemsTable(invoice, s),
          pw.SizedBox(height: 26),
          _totalsSection(invoice, s),
          pw.SizedBox(height: 20),
          _footNote(invoice, s),
        ],
      ),
    );

    return document.save();
  }

  String fileNameForInvoice(Invoice invoice) {
    final invoicePart = _sanitize(invoice.invoiceNumber, 'invoice');
    final clientPart = _sanitize(invoice.clientName, 'customer');
    return 'BillEasy_${invoicePart}_$clientPart.pdf';
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  pw.Widget _header(Invoice invoice, BusinessProfile? profile, AppStrings s) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Gradient accent strip
        pw.Container(
          height: 5,
          decoration: const pw.BoxDecoration(
            gradient: pw.LinearGradient(colors: [_navy, _teal]),
          ),
        ),
        pw.SizedBox(height: 22),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: branding + invoice label
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor(0.07, 0.24, 0.52, 0.10),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'BillEasy',
                      style: pw.TextStyle(
                        color: _navyLight,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    s.pdfInvoice,
                    style: pw.TextStyle(
                      color: _headingText,
                      fontSize: 34,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    _sellerName(profile, s),
                    style: pw.TextStyle(color: _mutedText, fontSize: 11),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            // Right: meta card
            pw.Container(
              width: 196,
              decoration: pw.BoxDecoration(
                color: _surface,
                borderRadius: pw.BorderRadius.circular(14),
                border: pw.Border.all(color: _border, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Status banner inside card
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _statusBg(invoice.status),
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(13),
                        topRight: pw.Radius.circular(13),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          s.detailsStatus.toUpperCase(),
                          style: pw.TextStyle(
                            color: _statusColor(invoice.status),
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        pw.Text(
                          _statusLabel(invoice.status, s),
                          style: pw.TextStyle(
                            color: _statusColor(invoice.status),
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(16),
                    child: pw.Column(
                      children: [
                        _metaRow(s.pdfInvoiceNo, invoice.invoiceNumber),
                        pw.Divider(color: _border, height: 14, thickness: 0.6),
                        _metaRow(
                          s.pdfInvoiceDate,
                          _dateFormat.format(invoice.createdAt),
                        ),
                        pw.Divider(color: _border, height: 14, thickness: 0.6),
                        _metaRow(
                          s.detailsGrandTotal,
                          _fmt(invoice.grandTotal),
                          valueStyle: pw.TextStyle(
                            color: _navy,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Party (From / Bill To)
  // -------------------------------------------------------------------------

  pw.Widget _partySection(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _partyCard(
            label: s.pdfFrom,
            name: _sellerName(profile, s),
            lines: [
              _profileVal(profile?.address, s.pdfAddressNotAdded),
              _profileVal(profile?.phoneNumber, s.pdfPhoneNotAdded),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: _partyCard(
            label: s.pdfBillTo,
            name: _customerName(invoice),
            lines: [
              if (invoice.clientId.trim().isNotEmpty)
                '${s.detailsReference}: ${invoice.clientId.trim()}',
              '${s.detailsStatus}: ${_statusLabel(invoice.status, s)}',
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _partyCard({
    required String label,
    required String name,
    required List<String> lines,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: _border, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: _teal,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            name,
            style: pw.TextStyle(
              color: _headingText,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (lines.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(height: 0.6, color: _border),
            pw.SizedBox(height: 10),
            ...lines.map(
              (line) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Text(
                  line,
                  style: pw.TextStyle(
                    color: _mutedText,
                    fontSize: 10,
                    lineSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Items table
  // -------------------------------------------------------------------------

  pw.Widget _itemsTable(Invoice invoice, AppStrings s) {
    final headerCells = [
      _cell(s.pdfItem, header: true),
      _cell(s.detailsItemQty, header: true, align: pw.Alignment.center),
      _cell(
        s.detailsItemUnitPrice,
        header: true,
        align: pw.Alignment.centerRight,
      ),
      _cell(s.pdfAmount, header: true, align: pw.Alignment.centerRight),
    ];

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_navy, _navyLight]),
        ),
        children: headerCells,
      ),
    ];

    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? PdfColors.white : _surface,
          ),
          children: [
            _cell('${i + 1}.  ${item.description}'),
            _cell(item.quantityLabel, align: pw.Alignment.center),
            _cell(_fmt(item.unitPrice), align: pw.Alignment.centerRight),
            _cell(
              _fmt(item.total),
              align: pw.Alignment.centerRight,
              color: _bodyText,
              bold: true,
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel(s.detailsItems),
        pw.SizedBox(height: 10),
        pw.ClipRRect(
          horizontalRadius: 12,
          verticalRadius: 12,
          child: pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _border, width: 0.6),
              left: pw.BorderSide(color: _border, width: 0.6),
              right: pw.BorderSide(color: _border, width: 0.6),
              bottom: pw.BorderSide(color: _border, width: 0.6),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(4.5),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(1.9),
              3: pw.FlexColumnWidth(1.9),
            },
            children: rows,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Totals section
  // -------------------------------------------------------------------------

  pw.Widget _totalsSection(Invoice invoice, AppStrings s) {
    final discLabel = _discountLabel(invoice, s);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(14),
              border: pw.Border.all(color: _border, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionLabel(s.detailsAmountSummary),
                pw.SizedBox(height: 10),
                pw.Text(
                  s.pdfItemsCount(invoice.items.length),
                  style: pw.TextStyle(
                    color: _mutedText,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  invoice.hasDiscount
                      ? '$discLabel  |  -${_fmt(invoice.discountAmount)}'
                      : s.detailsNoDiscount,
                  style: pw.TextStyle(
                    color: invoice.hasDiscount ? _success : _mutedText,
                    fontSize: 10,
                    lineSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Container(
          width: 218,
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: _surface,
            borderRadius: pw.BorderRadius.circular(14),
            border: pw.Border.all(color: _border, width: 0.8),
          ),
          child: pw.Column(
            children: [
              _summaryRow(s.detailsSubtotal, _fmt(invoice.subtotal)),
              pw.SizedBox(height: 10),
              _summaryRow(
                s.detailsDiscount,
                invoice.hasDiscount
                    ? '-${_fmt(invoice.discountAmount)}'
                    : _fmt(0),
                valueColor: invoice.hasDiscount ? _success : _bodyText,
              ),
              if (invoice.hasDiscount) ...[
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    discLabel,
                    style: pw.TextStyle(color: _mutedText, fontSize: 9),
                  ),
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Divider(color: _border, height: 20, thickness: 0.6),
              _summaryRow(
                s.detailsGrandTotal,
                _fmt(invoice.grandTotal),
                emphasize: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Footnote (above footer)
  // -------------------------------------------------------------------------

  pw.Widget _footNote(Invoice invoice, AppStrings s) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: _teal, width: 3)),
        color: const PdfColor(0.94, 0.99, 0.99),
      ),
      child: pw.Text(
        '${_statusLabel(invoice.status, s)} · BillEasy',
        style: pw.TextStyle(color: _mutedText, fontSize: 10, lineSpacing: 2),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Footer
  // -------------------------------------------------------------------------

  pw.Widget _footer(pw.Context ctx, AppStrings s) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              '${s.pdfGeneratedBy} · ${_generatedFormat.format(DateTime.now())}',
              style: pw.TextStyle(color: _mutedText, fontSize: 8),
            ),
          ),
          pw.Text(
            '${s.pdfPage} ${ctx.pageNumber} ${s.pdfOf} ${ctx.pagesCount}',
            style: pw.TextStyle(color: _mutedText, fontSize: 8),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Shared helpers
  // -------------------------------------------------------------------------

  pw.Widget _sectionLabel(String text) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 3, height: 14, color: _teal),
        pw.SizedBox(width: 8),
        pw.Text(
          text,
          style: pw.TextStyle(
            color: _headingText,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _metaRow(String label, String value, {pw.TextStyle? valueStyle}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(color: _mutedText, fontSize: 9)),
        pw.Text(
          value,
          style:
              valueStyle ??
              pw.TextStyle(
                color: _bodyText,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
        ),
      ],
    );
  }

  pw.Widget _cell(
    String value, {
    bool header = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          value,
          style: pw.TextStyle(
            color: header ? PdfColors.white : color ?? _mutedText,
            fontSize: header ? 9 : 11,
            fontWeight: (header || bold)
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            letterSpacing: header ? 0.6 : 0,
          ),
        ),
      ),
    );
  }

  pw.Widget _summaryRow(
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
            color: emphasize ? _headingText : _mutedText,
            fontSize: emphasize ? 12 : 11,
            fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: valueColor ?? (emphasize ? _navy : _bodyText),
            fontSize: emphasize ? 16 : 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
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

  PdfColor _statusBg(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return _successBg;
      case InvoiceStatus.pending:
        return _warningBg;
      case InvoiceStatus.overdue:
        return _dangerBg;
    }
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

  String _sellerName(BusinessProfile? profile, AppStrings s) {
    final name = profile?.storeName.trim() ?? '';
    return name.isNotEmpty ? name : s.detailsYourStore;
  }

  String _customerName(Invoice invoice) {
    final name = invoice.clientName.trim();
    if (name.isNotEmpty) return name;
    final id = invoice.clientId.trim();
    if (id.isNotEmpty) return id;
    return 'Customer';
  }

  String _profileVal(String? value, String fallback) {
    final v = value?.trim() ?? '';
    return v.isNotEmpty ? v : fallback;
  }

  String _discountLabel(Invoice invoice, AppStrings s) {
    if (!invoice.hasDiscount || invoice.discountType == null) {
      return s.detailsNoDiscount;
    }
    switch (invoice.discountType!) {
      case InvoiceDiscountType.percentage:
        final v = invoice.discountValue;
        final formatted = v.truncateToDouble() == v
            ? v.toStringAsFixed(0)
            : v.toStringAsFixed(2);
        return s.detailsPctOff(formatted);
      case InvoiceDiscountType.overall:
        return s.detailsOverallDiscount;
    }
  }

  String _fmt(double value) => _currencyFormat.format(value);

  String _sanitize(String value, String fallback) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return fallback;
    final r = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return r.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
