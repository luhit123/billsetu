import 'dart:async';
import 'dart:io';
import 'package:billeasy/l10n/app_strings.dart';
import 'package:flutter/foundation.dart' show consolidateHttpClientResponseBytes;
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Available PDF invoice templates.
enum InvoiceTemplate {
  classic, modern, compact,
  minimalist, bold, elegant, professional, vibrant,
  clean, royal, stripe, grid, pastel, dark,
  retail, wholesale, services, creative, simple, gstPro,
}

/// Configurable style that drives the parameterized PDF builder.
class TemplateStyle {
  final String name;
  final PdfColor primaryColor;
  final PdfColor secondaryColor;
  final PdfColor headerBg;
  final PdfColor headerText;
  final PdfColor bodyText;
  final PdfColor mutedText;
  final PdfColor tableBorder;
  final PdfColor tableHeaderBg;
  final PdfColor tableHeaderText;
  final PdfColor tableRowAlt;
  final PdfColor accentColor;
  final PdfColor surfaceColor;
  final double headerHeight; // 0 = auto
  final bool showGradientStrip;
  final bool showFullWidthHeader;
  final bool compactMode;
  final double sectionSpacing;
  final double fontSize;

  const TemplateStyle({
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.headerBg,
    required this.headerText,
    required this.bodyText,
    required this.mutedText,
    required this.tableBorder,
    required this.tableHeaderBg,
    required this.tableHeaderText,
    required this.tableRowAlt,
    required this.accentColor,
    required this.surfaceColor,
    this.headerHeight = 0,
    this.showGradientStrip = false,
    this.showFullWidthHeader = true,
    this.compactMode = false,
    this.sectionSpacing = 24,
    this.fontSize = 10,
  });
}

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

  static Completer<void>? _fontLoadCompleter;

  Future<void> _loadFonts(AppLanguage language) async {
    if (_fontRegular != null) return; // already loaded
    if (_fontLoadCompleter != null) {
      await _fontLoadCompleter!.future; // wait for in-progress load
      return;
    }
    _fontLoadCompleter = Completer<void>();
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
        case AppLanguage.gujarati:
          final dataGu = await rootBundle.load(
            'assets/fonts/NotoSansGujarati.ttf',
          );
          _fontRegular = pw.Font.ttf(dataGu);
          _fontBold = pw.Font.ttf(dataGu);
        case AppLanguage.tamil:
          final dataTa = await rootBundle.load(
            'assets/fonts/NotoSansTamil.ttf',
          );
          _fontRegular = pw.Font.ttf(dataTa);
          _fontBold = pw.Font.ttf(dataTa);
        case AppLanguage.english:
        default:
          _fontRegular = pw.Font.helvetica();
          _fontBold = pw.Font.helveticaBold();
      }
      _fontLoadCompleter!.complete();
    } catch (e) {
      _fontRegular = pw.Font.helvetica();
      _fontBold = pw.Font.helveticaBold();
      _fontLoadCompleter!.complete();
    }
  }

  Future<Uint8List> buildInvoicePdf({
    required Invoice invoice,
    BusinessProfile? profile,
    AppLanguage language = AppLanguage.english,
    InvoiceTemplate template = InvoiceTemplate.classic,
    bool includePayment = true,
  }) async {
    if (invoice.items.isEmpty) {
      throw ArgumentError('Cannot generate PDF for invoice with no items');
    }
    await _loadFonts(language);
    // Null-safety fallback: if _loadFonts failed to set fonts for any reason
    _fontRegular ??= pw.Font.helvetica();
    _fontBold ??= pw.Font.helveticaBold();
    // PDF structural labels are always English — the pdf package cannot do
    // Indic script shaping (Devanagari / Bengali conjuncts, vowel marks) so
    // regional text breaks apart visually. English labels render perfectly with
    // every font and match standard Indian business invoice format.
    const s = AppStrings(AppLanguage.english);

    switch (template) {
      case InvoiceTemplate.classic:
        return _buildClassicPdf(invoice, profile, s, includePayment: includePayment);
      case InvoiceTemplate.modern:
        return _buildModernPdf(invoice, profile, s, includePayment: includePayment);
      case InvoiceTemplate.compact:
        return _buildCompactPdf(invoice, profile, s, includePayment: includePayment);
      default:
        return _buildStyledPdf(invoice, profile, s, _templateStyles[template]!, includePayment: includePayment);
    }
  }

  // ── Template style presets ───────────────────────────────────────────────

  static const Map<InvoiceTemplate, TemplateStyle> _templateStyles = {
    InvoiceTemplate.minimalist: TemplateStyle(
      name: 'Minimalist',
      primaryColor: PdfColor(0.15, 0.15, 0.15),
      secondaryColor: PdfColor(0.60, 0.60, 0.60),
      headerBg: PdfColors.white,
      headerText: PdfColor(0.10, 0.10, 0.10),
      bodyText: PdfColor(0.20, 0.20, 0.20),
      mutedText: PdfColor(0.55, 0.55, 0.55),
      tableBorder: PdfColor(0.85, 0.85, 0.85),
      tableHeaderBg: PdfColor(0.96, 0.96, 0.96),
      tableHeaderText: PdfColor(0.10, 0.10, 0.10),
      tableRowAlt: PdfColor(0.98, 0.98, 0.98),
      accentColor: PdfColor(0.15, 0.15, 0.15),
      surfaceColor: PdfColors.white,
      showFullWidthHeader: false,
      sectionSpacing: 28,
    ),
    InvoiceTemplate.bold: TemplateStyle(
      name: 'Bold',
      primaryColor: PdfColor(0.12, 0.12, 0.12),
      secondaryColor: PdfColor(0.85, 0.20, 0.20),
      headerBg: PdfColor(0.12, 0.12, 0.12),
      headerText: PdfColors.white,
      bodyText: PdfColor(0.15, 0.15, 0.15),
      mutedText: PdfColor(0.45, 0.45, 0.45),
      tableBorder: PdfColor(0.30, 0.30, 0.30),
      tableHeaderBg: PdfColor(0.12, 0.12, 0.12),
      tableHeaderText: PdfColors.white,
      tableRowAlt: PdfColor(0.95, 0.95, 0.95),
      accentColor: PdfColor(0.85, 0.20, 0.20),
      surfaceColor: PdfColor(0.97, 0.97, 0.97),
      showGradientStrip: true,
      fontSize: 11,
    ),
    InvoiceTemplate.elegant: TemplateStyle(
      name: 'Elegant',
      primaryColor: PdfColor(0.44, 0.33, 0.18),
      secondaryColor: PdfColor(0.72, 0.60, 0.35),
      headerBg: PdfColor(0.98, 0.96, 0.91),
      headerText: PdfColor(0.30, 0.22, 0.10),
      bodyText: PdfColor(0.25, 0.22, 0.18),
      mutedText: PdfColor(0.55, 0.50, 0.42),
      tableBorder: PdfColor(0.85, 0.80, 0.70),
      tableHeaderBg: PdfColor(0.44, 0.33, 0.18),
      tableHeaderText: PdfColor(0.98, 0.96, 0.91),
      tableRowAlt: PdfColor(0.98, 0.96, 0.92),
      accentColor: PdfColor(0.72, 0.60, 0.35),
      surfaceColor: PdfColor(0.99, 0.97, 0.93),
      showGradientStrip: true,
      sectionSpacing: 26,
    ),
    InvoiceTemplate.professional: TemplateStyle(
      name: 'Professional',
      primaryColor: PdfColor(0.20, 0.38, 0.56),
      secondaryColor: PdfColor(0.35, 0.55, 0.72),
      headerBg: PdfColor(0.20, 0.38, 0.56),
      headerText: PdfColors.white,
      bodyText: PdfColor(0.20, 0.25, 0.32),
      mutedText: PdfColor(0.48, 0.53, 0.60),
      tableBorder: PdfColor(0.82, 0.86, 0.90),
      tableHeaderBg: PdfColor(0.20, 0.38, 0.56),
      tableHeaderText: PdfColors.white,
      tableRowAlt: PdfColor(0.94, 0.96, 0.98),
      accentColor: PdfColor(0.35, 0.55, 0.72),
      surfaceColor: PdfColor(0.96, 0.97, 0.98),
    ),
    InvoiceTemplate.vibrant: TemplateStyle(
      name: 'Vibrant',
      primaryColor: PdfColor(0.90, 0.35, 0.20),
      secondaryColor: PdfColor(0.95, 0.55, 0.30),
      headerBg: PdfColor(0.90, 0.35, 0.20),
      headerText: PdfColors.white,
      bodyText: PdfColor(0.22, 0.22, 0.22),
      mutedText: PdfColor(0.50, 0.50, 0.50),
      tableBorder: PdfColor(0.88, 0.85, 0.83),
      tableHeaderBg: PdfColor(0.90, 0.35, 0.20),
      tableHeaderText: PdfColors.white,
      tableRowAlt: PdfColor(0.99, 0.96, 0.94),
      accentColor: PdfColor(0.95, 0.55, 0.30),
      surfaceColor: PdfColor(0.99, 0.97, 0.96),
      showGradientStrip: true,
    ),
    InvoiceTemplate.clean: TemplateStyle(
      name: 'Clean',
      primaryColor: PdfColor(0.40, 0.45, 0.50),
      secondaryColor: PdfColor(0.55, 0.62, 0.68),
      headerBg: PdfColor(0.96, 0.97, 0.98),
      headerText: PdfColor(0.25, 0.28, 0.32),
      bodyText: PdfColor(0.25, 0.28, 0.32),
      mutedText: PdfColor(0.55, 0.58, 0.62),
      tableBorder: PdfColor(0.88, 0.90, 0.92),
      tableHeaderBg: PdfColor(0.92, 0.94, 0.96),
      tableHeaderText: PdfColor(0.30, 0.33, 0.38),
      tableRowAlt: PdfColor(0.97, 0.98, 0.99),
      accentColor: PdfColor(0.40, 0.65, 0.80),
      surfaceColor: PdfColor(0.98, 0.98, 0.99),
      showFullWidthHeader: false,
      sectionSpacing: 22,
    ),
    InvoiceTemplate.royal: TemplateStyle(
      name: 'Royal',
      primaryColor: PdfColor(0.35, 0.15, 0.55),
      secondaryColor: PdfColor(0.75, 0.60, 0.20),
      headerBg: PdfColor(0.35, 0.15, 0.55),
      headerText: PdfColors.white,
      bodyText: PdfColor(0.20, 0.15, 0.28),
      mutedText: PdfColor(0.50, 0.45, 0.58),
      tableBorder: PdfColor(0.82, 0.78, 0.88),
      tableHeaderBg: PdfColor(0.35, 0.15, 0.55),
      tableHeaderText: PdfColor(0.95, 0.90, 0.70),
      tableRowAlt: PdfColor(0.96, 0.94, 0.98),
      accentColor: PdfColor(0.75, 0.60, 0.20),
      surfaceColor: PdfColor(0.97, 0.96, 0.99),
      showGradientStrip: true,
    ),
    InvoiceTemplate.stripe: TemplateStyle(
      name: 'Stripe',
      primaryColor: PdfColor(0.06, 0.42, 0.44),
      secondaryColor: PdfColor(0.10, 0.58, 0.60),
      headerBg: PdfColor(0.06, 0.42, 0.44),
      headerText: PdfColors.white,
      bodyText: PdfColor(0.18, 0.22, 0.25),
      mutedText: PdfColor(0.48, 0.52, 0.55),
      tableBorder: PdfColor(0.82, 0.88, 0.88),
      tableHeaderBg: PdfColor(0.06, 0.42, 0.44),
      tableHeaderText: PdfColors.white,
      tableRowAlt: PdfColor(0.94, 0.97, 0.97),
      accentColor: PdfColor(0.10, 0.58, 0.60),
      surfaceColor: PdfColor(0.96, 0.98, 0.98),
    ),
    InvoiceTemplate.grid: TemplateStyle(
      name: 'Grid',
      primaryColor: PdfColor(0.18, 0.18, 0.22),
      secondaryColor: PdfColor(0.40, 0.40, 0.45),
      headerBg: PdfColor(0.18, 0.18, 0.22),
      headerText: PdfColors.white,
      bodyText: PdfColor(0.18, 0.18, 0.22),
      mutedText: PdfColor(0.48, 0.48, 0.52),
      tableBorder: PdfColor(0.40, 0.40, 0.45),
      tableHeaderBg: PdfColor(0.18, 0.18, 0.22),
      tableHeaderText: PdfColors.white,
      tableRowAlt: PdfColor(0.95, 0.95, 0.96),
      accentColor: PdfColor(0.18, 0.18, 0.22),
      surfaceColor: PdfColor(0.97, 0.97, 0.97),
      showFullWidthHeader: false,
      fontSize: 10,
    ),
    InvoiceTemplate.pastel: TemplateStyle(
      name: 'Pastel',
      primaryColor: PdfColor(0.50, 0.40, 0.65),
      secondaryColor: PdfColor(0.55, 0.78, 0.72),
      headerBg: PdfColor(0.92, 0.88, 0.96),
      headerText: PdfColor(0.35, 0.25, 0.50),
      bodyText: PdfColor(0.28, 0.28, 0.32),
      mutedText: PdfColor(0.55, 0.55, 0.60),
      tableBorder: PdfColor(0.85, 0.85, 0.90),
      tableHeaderBg: PdfColor(0.50, 0.40, 0.65),
      tableHeaderText: PdfColors.white,
      tableRowAlt: PdfColor(0.95, 0.97, 0.96),
      accentColor: PdfColor(0.55, 0.78, 0.72),
      surfaceColor: PdfColor(0.97, 0.96, 0.99),
      showGradientStrip: true,
    ),
    InvoiceTemplate.dark: TemplateStyle(
      name: 'Dark',
      primaryColor: PdfColor(0.90, 0.75, 0.30),
      secondaryColor: PdfColor(0.95, 0.82, 0.40),
      headerBg: PdfColor(0.10, 0.10, 0.18),
      headerText: PdfColor(0.92, 0.90, 0.85),
      bodyText: PdfColor(0.10, 0.10, 0.14),
      mutedText: PdfColor(0.45, 0.45, 0.50),
      tableBorder: PdfColor(0.75, 0.75, 0.78),
      tableHeaderBg: PdfColor(0.10, 0.10, 0.18),
      tableHeaderText: PdfColor(0.90, 0.75, 0.30),
      tableRowAlt: PdfColor(0.94, 0.94, 0.95),
      accentColor: PdfColor(0.90, 0.75, 0.30),
      surfaceColor: PdfColor(0.96, 0.96, 0.97),
      showGradientStrip: true,
    ),
    InvoiceTemplate.retail: TemplateStyle(
      name: 'Retail',
      primaryColor: PdfColor(0.15, 0.52, 0.28),
      secondaryColor: PdfColor(0.22, 0.65, 0.38),
      headerBg: PdfColor(0.15, 0.52, 0.28),
      headerText: PdfColors.white,
      bodyText: PdfColor(0.18, 0.22, 0.18),
      mutedText: PdfColor(0.45, 0.50, 0.45),
      tableBorder: PdfColor(0.80, 0.88, 0.82),
      tableHeaderBg: PdfColor(0.15, 0.52, 0.28),
      tableHeaderText: PdfColors.white,
      tableRowAlt: PdfColor(0.94, 0.97, 0.95),
      accentColor: PdfColor(0.22, 0.65, 0.38),
      surfaceColor: PdfColor(0.96, 0.98, 0.96),
    ),
    InvoiceTemplate.wholesale: TemplateStyle(
      name: 'Wholesale',
      primaryColor: PdfColor(0.45, 0.32, 0.18),
      secondaryColor: PdfColor(0.62, 0.48, 0.30),
      headerBg: PdfColor(0.45, 0.32, 0.18),
      headerText: PdfColor(0.98, 0.95, 0.88),
      bodyText: PdfColor(0.25, 0.20, 0.15),
      mutedText: PdfColor(0.55, 0.50, 0.42),
      tableBorder: PdfColor(0.82, 0.78, 0.72),
      tableHeaderBg: PdfColor(0.45, 0.32, 0.18),
      tableHeaderText: PdfColor(0.98, 0.95, 0.88),
      tableRowAlt: PdfColor(0.97, 0.95, 0.92),
      accentColor: PdfColor(0.62, 0.48, 0.30),
      surfaceColor: PdfColor(0.98, 0.96, 0.93),
      showFullWidthHeader: false,
    ),
    InvoiceTemplate.services: TemplateStyle(
      name: 'Services',
      primaryColor: PdfColor(0.25, 0.35, 0.52),
      secondaryColor: PdfColor(0.50, 0.58, 0.68),
      headerBg: PdfColor(0.25, 0.35, 0.52),
      headerText: PdfColors.white,
      bodyText: PdfColor(0.22, 0.25, 0.30),
      mutedText: PdfColor(0.50, 0.53, 0.58),
      tableBorder: PdfColor(0.82, 0.85, 0.90),
      tableHeaderBg: PdfColor(0.25, 0.35, 0.52),
      tableHeaderText: PdfColors.white,
      tableRowAlt: PdfColor(0.95, 0.96, 0.98),
      accentColor: PdfColor(0.50, 0.58, 0.68),
      surfaceColor: PdfColor(0.96, 0.97, 0.98),
      sectionSpacing: 26,
    ),
    InvoiceTemplate.creative: TemplateStyle(
      name: 'Creative',
      primaryColor: PdfColor(0.88, 0.38, 0.35),
      secondaryColor: PdfColor(0.35, 0.78, 0.68),
      headerBg: PdfColor(0.88, 0.38, 0.35),
      headerText: PdfColors.white,
      bodyText: PdfColor(0.22, 0.22, 0.25),
      mutedText: PdfColor(0.50, 0.50, 0.55),
      tableBorder: PdfColor(0.85, 0.85, 0.88),
      tableHeaderBg: PdfColor(0.88, 0.38, 0.35),
      tableHeaderText: PdfColors.white,
      tableRowAlt: PdfColor(0.96, 0.98, 0.97),
      accentColor: PdfColor(0.35, 0.78, 0.68),
      surfaceColor: PdfColor(0.98, 0.97, 0.97),
      showGradientStrip: true,
    ),
    InvoiceTemplate.simple: TemplateStyle(
      name: 'Simple',
      primaryColor: PdfColor(0.0, 0.0, 0.0),
      secondaryColor: PdfColor(0.40, 0.40, 0.40),
      headerBg: PdfColors.white,
      headerText: PdfColor(0.0, 0.0, 0.0),
      bodyText: PdfColor(0.0, 0.0, 0.0),
      mutedText: PdfColor(0.45, 0.45, 0.45),
      tableBorder: PdfColor(0.0, 0.0, 0.0),
      tableHeaderBg: PdfColors.white,
      tableHeaderText: PdfColor(0.0, 0.0, 0.0),
      tableRowAlt: PdfColors.white,
      accentColor: PdfColor(0.0, 0.0, 0.0),
      surfaceColor: PdfColors.white,
      showFullWidthHeader: false,
      sectionSpacing: 20,
    ),
    InvoiceTemplate.gstPro: TemplateStyle(
      name: 'GST Pro',
      primaryColor: PdfColor(0.24, 0.22, 0.55),
      secondaryColor: PdfColor(0.38, 0.35, 0.72),
      headerBg: PdfColor(0.24, 0.22, 0.55),
      headerText: PdfColors.white,
      bodyText: PdfColor(0.18, 0.18, 0.25),
      mutedText: PdfColor(0.48, 0.48, 0.55),
      tableBorder: PdfColor(0.80, 0.80, 0.88),
      tableHeaderBg: PdfColor(0.24, 0.22, 0.55),
      tableHeaderText: PdfColors.white,
      tableRowAlt: PdfColor(0.95, 0.95, 0.98),
      accentColor: PdfColor(0.38, 0.35, 0.72),
      surfaceColor: PdfColor(0.96, 0.96, 0.99),
      showGradientStrip: true,
      sectionSpacing: 26,
    ),
  };

  // ── Styled PDF (parameterized template engine) ─────────────────────────

  Future<Uint8List> _buildStyledPdf(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s,
    TemplateStyle style, {
    bool includePayment = true,
  }) async {
    final document = pw.Document(
      title: invoice.invoiceNumber,
      author: _sellerName(profile, s),
      subject: 'BillRaja invoice ${invoice.invoiceNumber}',
      creator: 'BillRaja',
    );

    final theme = pw.ThemeData.withFont(base: _fontRegular!, bold: _fontBold!);
    final paymentWidget = (includePayment && profile != null)
        ? await _paymentSection(profile)
        : pw.SizedBox.shrink();

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: style.showFullWidthHeader
              ? const pw.EdgeInsets.fromLTRB(0, 0, 0, 32)
              : const pw.EdgeInsets.fromLTRB(36, 0, 36, 32),
        ),
        footer: (ctx) => _styledFooter(ctx, s, style),
        build: (ctx) {
          final children = <pw.Widget>[];

          // Gradient strip
          if (style.showGradientStrip && !style.showFullWidthHeader) {
            children.add(
              pw.Container(
                height: 5,
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [style.primaryColor, style.secondaryColor],
                  ),
                ),
              ),
            );
          }

          // Header
          children.add(_styledHeader(invoice, profile, s, style));

          // Body wrapper for full-width header templates
          if (style.showFullWidthHeader) {
            children.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 36),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: style.sectionSpacing),
                    _styledPartySection(invoice, profile, s, style),
                    pw.SizedBox(height: style.sectionSpacing),
                    _styledItemsTable(invoice, s, style),
                    pw.SizedBox(height: style.sectionSpacing),
                    _styledTotalsSection(invoice, s, style),
                    pw.SizedBox(height: 20),
                    paymentWidget,
                    pw.SizedBox(height: 16),
                    _footNote(invoice, s),
                  ],
                ),
              ),
            );
          } else {
            children.addAll([
              pw.SizedBox(height: style.sectionSpacing),
              _styledPartySection(invoice, profile, s, style),
              pw.SizedBox(height: style.sectionSpacing),
              _styledItemsTable(invoice, s, style),
              pw.SizedBox(height: style.sectionSpacing),
              _styledTotalsSection(invoice, s, style),
              pw.SizedBox(height: 20),
              paymentWidget,
              pw.SizedBox(height: 16),
              _footNote(invoice, s),
            ]);
          }

          return children;
        },
      ),
    );

    return document.save();
  }

  pw.Widget _styledHeader(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s,
    TemplateStyle style,
  ) {
    final sellerName = _sellerName(profile, s);
    final gstin = profile?.gstin ?? '';

    if (style.showFullWidthHeader) {
      return pw.Container(
        width: double.infinity,
        color: style.headerBg,
        padding: const pw.EdgeInsets.fromLTRB(36, 28, 36, 28),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    sellerName,
                    style: pw.TextStyle(
                      color: style.headerText,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (gstin.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'GSTIN: $gstin',
                      style: pw.TextStyle(
                        color: style.headerText.shade(0.2),
                        fontSize: 9,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '${s.pdfInvoiceNo}: ${invoice.invoiceNumber}',
                    style: pw.TextStyle(
                      color: style.headerText.shade(0.3),
                      fontSize: 9,
                    ),
                  ),
                  pw.Text(
                    '${s.pdfInvoiceDate}: ${_dateFormat.format(invoice.createdAt)}',
                    style: pw.TextStyle(
                      color: style.headerText.shade(0.3),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: style.accentColor,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'TAX INVOICE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  _fmt(invoice.grandTotal),
                  style: pw.TextStyle(
                    color: style.headerText,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  s.detailsGrandTotal,
                  style: pw.TextStyle(
                    color: style.headerText.shade(0.3),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Non-full-width: boxed header
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (style.showGradientStrip) pw.SizedBox(height: 22),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    s.pdfInvoice,
                    style: pw.TextStyle(
                      color: style.primaryColor,
                      fontSize: 30,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    sellerName,
                    style: pw.TextStyle(color: style.mutedText, fontSize: 11),
                  ),
                  if (gstin.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'GSTIN: $gstin',
                      style: pw.TextStyle(color: style.mutedText, fontSize: 9),
                    ),
                  ],
                ],
              ),
            ),
            pw.Container(
              width: 196,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: style.surfaceColor,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: style.tableBorder, width: 0.8),
              ),
              child: pw.Column(
                children: [
                  _styledMetaRow('TAX INVOICE', '', style, emphasize: true),
                  pw.Divider(color: style.tableBorder, height: 14, thickness: 0.6),
                  _styledMetaRow(s.pdfInvoiceNo, invoice.invoiceNumber, style),
                  pw.Divider(color: style.tableBorder, height: 14, thickness: 0.6),
                  _styledMetaRow(s.pdfInvoiceDate, _dateFormat.format(invoice.createdAt), style),
                  pw.Divider(color: style.tableBorder, height: 14, thickness: 0.6),
                  _styledMetaRow(s.detailsGrandTotal, _fmt(invoice.grandTotal), style, emphasize: true),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _styledMetaRow(String label, String value, TemplateStyle style, {bool emphasize = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(
          color: emphasize ? style.primaryColor : style.mutedText,
          fontSize: emphasize ? 10 : 9,
          fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
        )),
        if (value.isNotEmpty)
          pw.Text(value, style: pw.TextStyle(
            color: emphasize ? style.primaryColor : style.bodyText,
            fontSize: emphasize ? 13 : 10,
            fontWeight: pw.FontWeight.bold,
          )),
      ],
    );
  }

  pw.Widget _styledPartySection(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s,
    TemplateStyle style,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _styledPartyBox(
            label: s.pdfFrom,
            name: _sellerName(profile, s),
            lines: [
              _profileVal(profile?.address, s.pdfAddressNotAdded),
              _profileVal(profile?.phoneNumber, s.pdfPhoneNotAdded),
            ],
            style: style,
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: _styledPartyBox(
            label: s.pdfBillTo,
            name: _customerName(invoice),
            lines: [
              if (invoice.customerGstin.isNotEmpty)
                'GSTIN: ${invoice.customerGstin}',
              '${s.detailsStatus}: ${_statusLabel(invoice.status, s)}',
            ],
            style: style,
          ),
        ),
      ],
    );
  }

  pw.Widget _styledPartyBox({
    required String label,
    required String name,
    required List<String> lines,
    required TemplateStyle style,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: style.tableBorder, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: style.accentColor,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            name,
            style: pw.TextStyle(
              color: style.primaryColor,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (lines.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            ...lines.map(
              (l) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  l,
                  style: pw.TextStyle(color: style.mutedText, fontSize: 9),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _styledItemsTable(Invoice invoice, AppStrings s, TemplateStyle style) {
    final hasHsn = invoice.items.any((i) => i.hsnCode.isNotEmpty);
    final hasGst = invoice.gstEnabled;

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: style.tableHeaderBg),
        children: [
          _styledCell(s.pdfItem, header: true, style: style),
          _styledCell(s.detailsItemQty, header: true, align: pw.Alignment.center, style: style),
          _styledCell(s.detailsItemUnitPrice, header: true, align: pw.Alignment.centerRight, style: style),
          _styledCell(s.pdfAmount, header: true, align: pw.Alignment.centerRight, style: style),
          if (hasGst) _styledCell('GST%', header: true, align: pw.Alignment.center, style: style),
          if (hasHsn) _styledCell('HSN/SAC', header: true, align: pw.Alignment.center, style: style),
        ],
      ),
    ];

    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? PdfColors.white : style.tableRowAlt,
          ),
          children: [
            _styledCell('${i + 1}.  ${item.description}', style: style),
            _styledCell(item.quantityLabel, align: pw.Alignment.center, style: style),
            _styledCell(_fmt(item.unitPrice), align: pw.Alignment.centerRight, style: style),
            _styledCell(_fmt(item.total), align: pw.Alignment.centerRight, bold: true, style: style),
            if (hasGst)
              _styledCell('${item.gstRate.toStringAsFixed(0)}%', align: pw.Alignment.center, style: style),
            if (hasHsn)
              _styledCell(item.hsnCode.isEmpty ? '-' : item.hsnCode, align: pw.Alignment.center, style: style),
          ],
        ),
      );
    }

    int colIdx = 4;
    final colWidths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(hasHsn || hasGst ? 3.5 : 4.5),
      1: const pw.FlexColumnWidth(1.1),
      2: const pw.FlexColumnWidth(1.9),
      3: const pw.FlexColumnWidth(1.9),
    };
    if (hasGst) colWidths[colIdx++] = const pw.FlexColumnWidth(1.0);
    if (hasHsn) colWidths[colIdx++] = const pw.FlexColumnWidth(1.5);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          s.detailsItems.toUpperCase(),
          style: pw.TextStyle(
            color: style.primaryColor,
            fontSize: style.fontSize,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: style.tableBorder, width: 0.5),
          columnWidths: colWidths,
          children: rows,
        ),
      ],
    );
  }

  pw.Widget _styledCell(
    String value, {
    bool header = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    bool bold = false,
    required TemplateStyle style,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          value,
          style: pw.TextStyle(
            color: header ? style.tableHeaderText : style.bodyText,
            fontSize: header ? 9 : style.fontSize,
            fontWeight: (header || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  pw.Widget _styledTotalsSection(Invoice invoice, AppStrings s, TemplateStyle style) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 240,
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: style.tableBorder, width: 0.8),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            _styledSummaryRow(s.detailsSubtotal, _fmt(invoice.subtotal), style),
            if (invoice.hasDiscount) ...[
              pw.SizedBox(height: 8),
              _styledSummaryRow(
                s.detailsDiscount,
                '-${_fmt(invoice.discountAmount)}',
                style,
                valueColor: const PdfColor(0.10, 0.52, 0.27),
              ),
            ],
            if (invoice.hasGst) ...[
              pw.SizedBox(height: 8),
              if (invoice.gstType == 'cgst_sgst') ...[
                _styledSummaryRow('CGST', _fmt(invoice.cgstAmount), style, valueColor: style.primaryColor),
                pw.SizedBox(height: 6),
                _styledSummaryRow('SGST', _fmt(invoice.sgstAmount), style, valueColor: style.primaryColor),
              ] else
                _styledSummaryRow('IGST', _fmt(invoice.igstAmount), style, valueColor: style.primaryColor),
            ],
            pw.SizedBox(height: 4),
            pw.Divider(color: style.primaryColor, height: 16, thickness: 0.6),
            _styledSummaryRow(s.detailsGrandTotal, _fmt(invoice.grandTotal), style, emphasize: true),
          ],
        ),
      ),
    );
  }

  pw.Widget _styledSummaryRow(
    String label,
    String value,
    TemplateStyle style, {
    bool emphasize = false,
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: emphasize ? style.primaryColor : style.mutedText,
            fontSize: emphasize ? 12 : 10,
            fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: valueColor ?? (emphasize ? style.primaryColor : style.bodyText),
            fontSize: emphasize ? 15 : 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _styledFooter(pw.Context ctx, AppStrings s, TemplateStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 0),
      child: pw.Column(
        children: [
          pw.Container(height: 1.5, color: style.accentColor),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Thank you for your business',
                style: pw.TextStyle(
                  color: style.primaryColor,
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.Text(
                '${s.pdfPage} ${ctx.pageNumber} ${s.pdfOf} ${ctx.pagesCount}',
                style: pw.TextStyle(color: style.mutedText, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Classic PDF (original design) ─────────────────────────────────────────

  Future<Uint8List> _buildClassicPdf(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s, {
    bool includePayment = true,
  }) async {
    final document = pw.Document(
      title: invoice.invoiceNumber,
      author: _sellerName(profile, s),
      subject: 'BillRaja invoice ${invoice.invoiceNumber}',
      creator: 'BillRaja',
    );

    final theme = pw.ThemeData.withFont(base: _fontRegular!, bold: _fontBold!);
    final paymentWidget = (includePayment && profile != null) ? await _paymentSection(profile) : pw.SizedBox.shrink();

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
          paymentWidget,
          pw.SizedBox(height: 16),
          _footNote(invoice, s),
        ],
      ),
    );

    return document.save();
  }

  // ── Modern PDF (navy gradient header, teal accents) ───────────────────────

  static const PdfColor _modernNavy = PdfColor(0.04, 0.14, 0.31);  // 0xFF1E3A8A
  static const PdfColor _modernTeal = PdfColor(0.06, 0.49, 0.51);  // 0xFF6366F1
  static const PdfColor _modernRowAlt = PdfColor(0.94, 0.96, 1.00); // 0xFFF8FAFC

  Future<Uint8List> _buildModernPdf(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s, {
    bool includePayment = true,
  }) async {
    final document = pw.Document(
      title: invoice.invoiceNumber,
      author: _sellerName(profile, s),
      subject: 'BillRaja invoice ${invoice.invoiceNumber}',
      creator: 'BillRaja',
    );

    final theme = pw.ThemeData.withFont(base: _fontRegular!, bold: _fontBold!);
    final paymentWidget = (includePayment && profile != null) ? await _paymentSection(profile) : pw.SizedBox.shrink();

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(0, 0, 0, 32),
        ),
        footer: (ctx) => _modernFooter(ctx, s),
        build: (ctx) => [
          _modernHeader(invoice, profile, s),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 24),
                _modernPartySection(invoice, profile, s),
                pw.SizedBox(height: 24),
                _modernItemsTable(invoice, s),
                pw.SizedBox(height: 24),
                _modernTotalsSection(invoice, s),
                pw.SizedBox(height: 20),
                paymentWidget,
              ],
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _modernHeader(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s,
  ) {
    final sellerName = _sellerName(profile, s);
    final gstin = profile?.gstin ?? '';

    return pw.Container(
      width: double.infinity,
      color: _modernNavy,
      padding: const pw.EdgeInsets.fromLTRB(36, 28, 36, 28),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: company info
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  sellerName,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (gstin.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'GSTIN: $gstin',
                    style: pw.TextStyle(
                      color: const PdfColor(0.85, 0.90, 0.95),
                      fontSize: 9,
                    ),
                  ),
                ],
                pw.SizedBox(height: 10),
                pw.Text(
                  '${s.pdfInvoiceNo}: ${invoice.invoiceNumber}',
                  style: pw.TextStyle(
                    color: const PdfColor(0.75, 0.83, 0.92),
                    fontSize: 9,
                  ),
                ),
                pw.Text(
                  '${s.pdfInvoiceDate}: ${_dateFormat.format(invoice.createdAt)}',
                  style: pw.TextStyle(
                    color: const PdfColor(0.75, 0.83, 0.92),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          // Right: TAX INVOICE badge + total
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: _modernTeal,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'TAX INVOICE',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                _fmt(invoice.grandTotal),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                s.detailsGrandTotal,
                style: pw.TextStyle(
                  color: const PdfColor(0.75, 0.83, 0.92),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _modernPartySection(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _modernPartyBox(
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
          child: _modernPartyBox(
            label: s.pdfBillTo,
            name: _customerName(invoice),
            lines: [
              if (invoice.customerGstin.isNotEmpty)
                'GSTIN: ${invoice.customerGstin}',
              '${s.detailsStatus}: ${_statusLabel(invoice.status, s)}',
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _modernPartyBox({
    required String label,
    required String name,
    required List<String> lines,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _modernNavy, width: 0.8),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: _modernTeal,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            name,
            style: pw.TextStyle(
              color: _modernNavy,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (lines.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            ...lines.map(
              (l) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  l,
                  style: pw.TextStyle(
                    color: _mutedText,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _modernItemsTable(Invoice invoice, AppStrings s) {
    final hasHsn = invoice.items.any((i) => i.hsnCode.isNotEmpty);
    final hasGst = invoice.gstEnabled;

    final rows = <pw.TableRow>[
      // Teal header row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _modernTeal),
        children: [
          _modernCell(s.pdfItem, header: true),
          _modernCell(s.detailsItemQty, header: true, align: pw.Alignment.center),
          _modernCell(s.detailsItemUnitPrice, header: true, align: pw.Alignment.centerRight),
          _modernCell(s.pdfAmount, header: true, align: pw.Alignment.centerRight),
          if (hasGst) _modernCell('GST%', header: true, align: pw.Alignment.center),
          if (hasHsn) _modernCell('HSN/SAC', header: true, align: pw.Alignment.center),
        ],
      ),
    ];

    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isEven ? PdfColors.white : _modernRowAlt,
          ),
          children: [
            _modernCell('${i + 1}.  ${item.description}'),
            _modernCell(item.quantityLabel, align: pw.Alignment.center),
            _modernCell(_fmt(item.unitPrice), align: pw.Alignment.centerRight),
            _modernCell(_fmt(item.total), align: pw.Alignment.centerRight, bold: true),
            if (hasGst)
              _modernCell(
                '${item.gstRate.toStringAsFixed(0)}%',
                align: pw.Alignment.center,
              ),
            if (hasHsn)
              _modernCell(
                item.hsnCode.isEmpty ? '-' : item.hsnCode,
                align: pw.Alignment.center,
              ),
          ],
        ),
      );
    }

    int colIdx = 4;
    final colWidths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(hasHsn || hasGst ? 3.5 : 4.5),
      1: const pw.FlexColumnWidth(1.1),
      2: const pw.FlexColumnWidth(1.9),
      3: const pw.FlexColumnWidth(1.9),
    };
    if (hasGst) colWidths[colIdx++] = const pw.FlexColumnWidth(1.0);
    if (hasHsn) colWidths[colIdx++] = const pw.FlexColumnWidth(1.5);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          s.detailsItems.toUpperCase(),
          style: pw.TextStyle(
            color: _modernNavy,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _border, width: 0.5),
          columnWidths: colWidths,
          children: rows,
        ),
      ],
    );
  }

  pw.Widget _modernCell(
    String value, {
    bool header = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          value,
          style: pw.TextStyle(
            color: header ? PdfColors.white : _bodyText,
            fontSize: header ? 9 : 10,
            fontWeight: (header || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  pw.Widget _modernTotalsSection(Invoice invoice, AppStrings s) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 240,
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _modernNavy, width: 0.8),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            _modernSummaryRow(s.detailsSubtotal, _fmt(invoice.subtotal)),
            if (invoice.hasDiscount) ...[
              pw.SizedBox(height: 8),
              _modernSummaryRow(
                s.detailsDiscount,
                '-${_fmt(invoice.discountAmount)}',
                valueColor: _success,
              ),
            ],
            if (invoice.hasGst) ...[
              pw.SizedBox(height: 8),
              if (invoice.gstType == 'cgst_sgst') ...[
                _modernSummaryRow('CGST', _fmt(invoice.cgstAmount), valueColor: _modernNavy),
                pw.SizedBox(height: 6),
                _modernSummaryRow('SGST', _fmt(invoice.sgstAmount), valueColor: _modernNavy),
              ] else
                _modernSummaryRow('IGST', _fmt(invoice.igstAmount), valueColor: _modernNavy),
            ],
            pw.SizedBox(height: 4),
            pw.Divider(color: _modernNavy, height: 16, thickness: 0.6),
            _modernSummaryRow(s.detailsGrandTotal, _fmt(invoice.grandTotal), emphasize: true),
          ],
        ),
      ),
    );
  }

  pw.Widget _modernSummaryRow(
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
            color: emphasize ? _modernNavy : _mutedText,
            fontSize: emphasize ? 12 : 10,
            fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: valueColor ?? (emphasize ? _modernNavy : _bodyText),
            fontSize: emphasize ? 15 : 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _modernFooter(pw.Context ctx, AppStrings s) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 0),
      child: pw.Column(
        children: [
          pw.Container(height: 1.5, color: _modernTeal),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Thank you for your business',
                style: pw.TextStyle(
                  color: _modernNavy,
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.Text(
                '${s.pdfPage} ${ctx.pageNumber} ${s.pdfOf} ${ctx.pagesCount}',
                style: pw.TextStyle(color: _mutedText, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Compact PDF (dense, thermal-printer style) ────────────────────────────

  static const PdfColor _compactBorder = PdfColor(0.70, 0.70, 0.70);
  static const PdfColor _compactText = PdfColor(0.10, 0.10, 0.10);
  static const PdfColor _compactMuted = PdfColor(0.45, 0.45, 0.45);

  Future<Uint8List> _buildCompactPdf(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s, {
    bool includePayment = true,
  }) async {
    final document = pw.Document(
      title: invoice.invoiceNumber,
      author: _sellerName(profile, s),
      subject: 'BillRaja invoice ${invoice.invoiceNumber}',
      creator: 'BillRaja',
    );

    final theme = pw.ThemeData.withFont(base: _fontRegular!, bold: _fontBold!);

    final paymentWidget = (includePayment && profile != null) ? await _paymentSection(profile) : pw.SizedBox.shrink();

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
        ),
        footer: (ctx) => _compactFooter(ctx, s),
        build: (ctx) => [
          _compactHeader(invoice, profile, s),
          pw.SizedBox(height: 10),
          _compactPartySection(invoice, profile, s),
          pw.SizedBox(height: 10),
          _compactItemsTable(invoice, s),
          pw.SizedBox(height: 10),
          _compactTotalsSection(invoice, s),
          pw.SizedBox(height: 14),
          paymentWidget,
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _compactHeader(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _sellerName(profile, s),
                  style: pw.TextStyle(
                    color: _compactText,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (profile?.gstin != null && profile!.gstin.isNotEmpty)
                  pw.Text(
                    'GSTIN: ${profile.gstin}',
                    style: pw.TextStyle(color: _compactMuted, fontSize: 6),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'TAX INVOICE',
                  style: pw.TextStyle(
                    color: _compactText,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  invoice.invoiceNumber,
                  style: pw.TextStyle(color: _compactMuted, fontSize: 6),
                ),
                pw.Text(
                  _dateFormat.format(invoice.createdAt),
                  style: pw.TextStyle(color: _compactMuted, fontSize: 6),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: _compactBorder),
      ],
    );
  }

  pw.Widget _compactPartySection(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                s.pdfFrom,
                style: pw.TextStyle(
                  color: _compactMuted,
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                _sellerName(profile, s),
                style: pw.TextStyle(color: _compactText, fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                _profileVal(profile?.address, s.pdfAddressNotAdded),
                style: pw.TextStyle(color: _compactMuted, fontSize: 6),
              ),
              pw.Text(
                _profileVal(profile?.phoneNumber, s.pdfPhoneNotAdded),
                style: pw.TextStyle(color: _compactMuted, fontSize: 6),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                s.pdfBillTo,
                style: pw.TextStyle(
                  color: _compactMuted,
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                _customerName(invoice),
                style: pw.TextStyle(color: _compactText, fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
              if (invoice.customerGstin.isNotEmpty)
                pw.Text(
                  'GSTIN: ${invoice.customerGstin}',
                  style: pw.TextStyle(color: _compactMuted, fontSize: 6),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _compactItemsTable(Invoice invoice, AppStrings s) {
    final hasHsn = invoice.items.any((i) => i.hsnCode.isNotEmpty);
    final hasGst = invoice.gstEnabled;

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor(0.85, 0.85, 0.85)),
        children: [
          _compactCell(s.pdfItem, header: true),
          _compactCell(s.detailsItemQty, header: true, align: pw.Alignment.center),
          _compactCell(s.detailsItemUnitPrice, header: true, align: pw.Alignment.centerRight),
          _compactCell(s.pdfAmount, header: true, align: pw.Alignment.centerRight),
          if (hasGst) _compactCell('GST%', header: true, align: pw.Alignment.center),
          if (hasHsn) _compactCell('HSN', header: true, align: pw.Alignment.center),
        ],
      ),
    ];

    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      rows.add(
        pw.TableRow(
          children: [
            _compactCell('${i + 1}. ${item.description}'),
            _compactCell(item.quantityLabel, align: pw.Alignment.center),
            _compactCell(_fmt(item.unitPrice), align: pw.Alignment.centerRight),
            _compactCell(_fmt(item.total), align: pw.Alignment.centerRight, bold: true),
            if (hasGst)
              _compactCell(
                '${item.gstRate.toStringAsFixed(0)}%',
                align: pw.Alignment.center,
              ),
            if (hasHsn)
              _compactCell(
                item.hsnCode.isEmpty ? '-' : item.hsnCode,
                align: pw.Alignment.center,
              ),
          ],
        ),
      );
    }

    int colIdx = 4;
    final colWidths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(hasHsn || hasGst ? 3.5 : 4.5),
      1: const pw.FlexColumnWidth(1.0),
      2: const pw.FlexColumnWidth(1.8),
      3: const pw.FlexColumnWidth(1.8),
    };
    if (hasGst) colWidths[colIdx++] = const pw.FlexColumnWidth(0.9);
    if (hasHsn) colWidths[colIdx++] = const pw.FlexColumnWidth(1.2);

    return pw.Table(
      border: pw.TableBorder.all(color: _compactBorder, width: 0.4),
      columnWidths: colWidths,
      children: rows,
    );
  }

  pw.Widget _compactCell(
    String value, {
    bool header = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          value,
          style: pw.TextStyle(
            color: _compactText,
            fontSize: 8,
            fontWeight: (header || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  pw.Widget _compactTotalsSection(Invoice invoice, AppStrings s) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 200,
        child: pw.Column(
          children: [
            _compactTotalRow(s.detailsSubtotal, _fmt(invoice.subtotal)),
            if (invoice.hasDiscount)
              _compactTotalRow(s.detailsDiscount, '-${_fmt(invoice.discountAmount)}'),
            if (invoice.hasGst) ...[
              if (invoice.gstType == 'cgst_sgst') ...[
                _compactTotalRow('CGST', _fmt(invoice.cgstAmount)),
                _compactTotalRow('SGST', _fmt(invoice.sgstAmount)),
              ] else
                _compactTotalRow('IGST', _fmt(invoice.igstAmount)),
            ],
            pw.Container(height: 0.5, color: _compactBorder),
            pw.SizedBox(height: 3),
            _compactTotalRow(s.detailsGrandTotal, _fmt(invoice.grandTotal), bold: true),
          ],
        ),
      ),
    );
  }

  pw.Widget _compactTotalRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: _compactMuted,
              fontSize: 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _compactText,
              fontSize: 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _compactFooter(pw.Context ctx, AppStrings s) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '${s.pdfGeneratedBy} · ${_generatedFormat.format(DateTime.now())}',
          style: pw.TextStyle(color: _compactMuted, fontSize: 6),
        ),
        pw.Text(
          '${s.pdfPage} ${ctx.pageNumber} ${s.pdfOf} ${ctx.pagesCount}',
          style: pw.TextStyle(color: _compactMuted, fontSize: 6),
        ),
      ],
    );
  }

  String fileNameForInvoice(Invoice invoice) {
    final invoicePart = _sanitize(invoice.invoiceNumber, 'invoice');
    final clientPart = _sanitize(invoice.clientName, 'customer');
    return 'BillRaja_${invoicePart}_$clientPart.pdf';
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
                      'BillRaja',
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
                        if (invoice.placeOfSupply.isNotEmpty) ...[
                          pw.Divider(color: _border, height: 14, thickness: 0.6),
                          _metaRow('Place of Supply', invoice.placeOfSupply),
                        ],
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
              if (profile?.gstin != null && profile!.gstin.isNotEmpty)
                'GSTIN: ${profile.gstin}',
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
              if (invoice.customerGstin.isNotEmpty)
                'GSTIN: ${invoice.customerGstin}',
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
    final hasHsn = invoice.items.any((i) => i.hsnCode.isNotEmpty);
    final hasGst = invoice.gstEnabled;

    final headerCells = [
      _cell(s.pdfItem, header: true),
      _cell(s.detailsItemQty, header: true, align: pw.Alignment.center),
      _cell(
        s.detailsItemUnitPrice,
        header: true,
        align: pw.Alignment.centerRight,
      ),
      _cell(s.pdfAmount, header: true, align: pw.Alignment.centerRight),
      if (hasGst)
        _cell('GST%', header: true, align: pw.Alignment.center),
      if (hasHsn)
        _cell('HSN/SAC', header: true, align: pw.Alignment.center),
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
            if (hasGst)
              _cell(
                '${item.gstRate.toStringAsFixed(0)}%',
                align: pw.Alignment.center,
              ),
            if (hasHsn)
              _cell(
                item.hsnCode.isEmpty ? '-' : item.hsnCode,
                align: pw.Alignment.center,
              ),
          ],
        ),
      );
    }

    int colIdx = 4;
    final colWidths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(hasHsn || hasGst ? 3.5 : 4.5),
      1: const pw.FlexColumnWidth(1.1),
      2: const pw.FlexColumnWidth(1.9),
      3: const pw.FlexColumnWidth(1.9),
    };
    if (hasGst) colWidths[colIdx++] = const pw.FlexColumnWidth(1.0);
    if (hasHsn) colWidths[colIdx++] = const pw.FlexColumnWidth(1.5);

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
            columnWidths: colWidths,
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
                if (invoice.hasGst) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    invoice.gstType == 'igst'
                        ? 'IGST  =  ${_fmt(invoice.igstAmount)}'
                        : 'CGST + SGST  =  ${_fmt(invoice.totalTax)}',
                    style: pw.TextStyle(
                      color: _navy,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      lineSpacing: 2,
                    ),
                  ),
                ],
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
              if (invoice.hasGst) ...[
                pw.SizedBox(height: 10),
                if (invoice.gstType == 'cgst_sgst') ...[
                  _summaryRow(
                    'CGST',
                    _fmt(invoice.cgstAmount),
                    valueColor: _navy,
                  ),
                  pw.SizedBox(height: 6),
                  _summaryRow(
                    'SGST',
                    _fmt(invoice.sgstAmount),
                    valueColor: _navy,
                  ),
                ] else
                  _summaryRow(
                    'IGST',
                    _fmt(invoice.igstAmount),
                    valueColor: _navy,
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
        '${_statusLabel(invoice.status, s)} · BillRaja',
        style: pw.TextStyle(color: _mutedText, fontSize: 10, lineSpacing: 2),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Payment Section (UPI) — only rendered if user has set up UPI
  // -------------------------------------------------------------------------

  /// Downloads the QR code image bytes from the given URL.
  /// Returns null if download fails.
  static Future<Uint8List?> _downloadImage(String url) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);
      httpClient.close();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<pw.Widget> _paymentSection(BusinessProfile profile) async {
    final hasUpi = profile.upiId.isNotEmpty;
    final hasNumber = profile.upiNumber.isNotEmpty;
    final hasQr = profile.upiQrUrl.isNotEmpty;

    if (!hasUpi && !hasNumber && !hasQr) {
      return pw.SizedBox.shrink();
    }

    pw.Widget? qrImage;
    if (hasQr) {
      final bytes = await _downloadImage(profile.upiQrUrl);
      if (bytes != null) {
        qrImage = pw.Image(pw.MemoryImage(bytes), width: 100, height: 100);
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _mutedText, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Payment Details',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _headingText,
                  ),
                ),
                pw.SizedBox(height: 8),
                if (hasUpi) ...[
                  pw.Text('UPI ID', style: pw.TextStyle(fontSize: 8, color: _mutedText)),
                  pw.SizedBox(height: 2),
                  pw.Text(profile.upiId, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                ],
                if (hasNumber) ...[
                  pw.Text('UPI Number', style: pw.TextStyle(fontSize: 8, color: _mutedText)),
                  pw.SizedBox(height: 2),
                  pw.Text(profile.upiNumber, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ],
            ),
          ),
          if (qrImage != null) ...[
            pw.SizedBox(width: 16),
            pw.Column(
              children: [
                qrImage,
                pw.SizedBox(height: 4),
                pw.Text('Scan to Pay', style: pw.TextStyle(fontSize: 7, color: _mutedText)),
              ],
            ),
          ],
        ],
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
