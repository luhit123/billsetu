import 'dart:async';
import 'dart:io';
import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/services/logo_cache_service.dart';
import 'package:billeasy/services/signature_service.dart';
import 'package:flutter/foundation.dart'
    show consolidateHttpClientResponseBytes, debugPrint, kIsWeb;
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:billeasy/utils/upi_utils.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Available PDF invoice templates.
enum InvoiceTemplate {
  classic,
  modern,
  compact,
  vyapar,
  minimalist,
  bold,
  elegant,
  professional,
  vibrant,
  clean,
  royal,
  stripe,
  grid,
  pastel,
  dark,
  retail,
  wholesale,
  services,
  creative,
  simple,
  gstPro,
  // Structurally different layouts
  banner,
  sidebarLayout,
  bordered,
  twoColumn,
  receipt,
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

class _VyColors {
  final PdfColor primary;
  final PdfColor labelBg;
  final PdfColor border;
  final PdfColor black;
  final PdfColor body;
  final PdfColor muted;
  const _VyColors(
    this.primary,
    this.labelBg,
    this.border,
    this.black,
    this.body,
    this.muted,
  );
}

class InvoicePdfService {
  // Singleton — keeps fonts cached across calls
  static final InvoicePdfService _instance = InvoicePdfService._();
  factory InvoicePdfService() => _instance;
  InvoicePdfService._();

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

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _generatedFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs.',
    decimalDigits: 0,
  );

  pw.Font? _fontRegular;
  pw.Font? _fontBold;

  // Active color scheme for current PDF build
  _VyColors _c = _VyColors(
    _vyPrimary,
    _vyLabelBg,
    _vyBorder,
    _vyBlack,
    _vyBody,
    _vyMuted,
  );

  // Cached logo image for the current PDF build
  pw.ImageProvider? _logoImage;

  // Dynamic UPI QR image bytes for the current PDF build
  Uint8List? _invoiceQrBytes;

  // Client details for the current PDF build (phone, email, address)
  Client? _client;

  /// Pre-load fonts at app startup so first PDF is instant.
  Future<void> preloadFonts([AppLanguage language = AppLanguage.english]) =>
      _loadFonts(language);

  static Completer<void>? _fontLoadCompleter;

  AppLanguage? _loadedLanguage;

  Future<void> _loadFonts(AppLanguage language) async {
    if (_fontRegular != null && _loadedLanguage == language)
      return; // already loaded for this language
    // Reset if language changed
    if (_loadedLanguage != null && _loadedLanguage != language) {
      _fontRegular = null;
      _fontBold = null;
      _fontLoadCompleter = null;
    }
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
          // NOTE: assets/fonts/NotoSansGujarati.ttf is not yet bundled.
          // Falls through to the catch block which uses NotoSansDevanagari
          // as a graceful fallback (Latin + digits render correctly).
          final dataGu = await rootBundle.load(
            'assets/fonts/NotoSansGujarati.ttf',
          );
          _fontRegular = pw.Font.ttf(dataGu);
          _fontBold = pw.Font.ttf(dataGu);
        case AppLanguage.tamil:
          // NOTE: assets/fonts/NotoSansTamil.ttf is not yet bundled.
          // Falls through to the catch block which uses NotoSansDevanagari
          // as a graceful fallback (Latin + digits render correctly).
          final dataTa = await rootBundle.load(
            'assets/fonts/NotoSansTamil.ttf',
          );
          _fontRegular = pw.Font.ttf(dataTa);
          _fontBold = pw.Font.ttf(dataTa);
        case AppLanguage.english:
          // Use NotoSansDevanagari for English too — it covers Latin + ₹ symbol
          final dataEn = await rootBundle.load(
            'assets/fonts/NotoSansDevanagari.ttf',
          );
          _fontRegular = pw.Font.ttf(dataEn);
          _fontBold = pw.Font.ttf(dataEn);
      }
      _loadedLanguage = language;
      _fontLoadCompleter!.complete();
    } catch (e) {
      // Fallback: try NotoSansDevanagari, then Helvetica
      try {
        final fallback = await rootBundle.load(
          'assets/fonts/NotoSansDevanagari.ttf',
        );
        _fontRegular = pw.Font.ttf(fallback);
        _fontBold = pw.Font.ttf(fallback);
      } catch (_) {
        _fontRegular = pw.Font.helvetica();
        _fontBold = pw.Font.helveticaBold();
      }
      _loadedLanguage = language;
      _fontLoadCompleter!.complete();
    }
  }

  Future<Uint8List> buildInvoicePdf({
    required Invoice invoice,
    BusinessProfile? profile,
    Client? client,
    AppLanguage language = AppLanguage.english,
    InvoiceTemplate template = InvoiceTemplate.vyapar,
    bool includePayment = true,
  }) async {
    if (invoice.items.isEmpty) {
      throw ArgumentError('Cannot generate PDF for invoice with no items');
    }
    _client = client;
    await _loadFonts(language);
    // Null-safety fallback: if _loadFonts failed to set fonts for any reason
    _fontRegular ??= pw.Font.helvetica();
    _fontBold ??= pw.Font.helveticaBold();
    // PDF structural labels are always English — the pdf package cannot do
    // Indic script shaping (Devanagari / Bengali conjuncts, vowel marks) so
    // regional text breaks apart visually. English labels render perfectly with
    // every font and match standard Indian business invoice format.
    const s = AppStrings(AppLanguage.english);

    final colors =
        _vyColorMap[template] ?? _vyColorMap[InvoiceTemplate.vyapar]!;

    // Load business logo: try local cache first, then network
    _logoImage = null;
    try {
      final cachedLogo = await LogoCacheService.load();
      if (cachedLogo != null && cachedLogo.isNotEmpty) {
        debugPrint(
          '[InvoicePdf] Logo loaded from local cache: ${cachedLogo.length} bytes',
        );
        _logoImage = pw.MemoryImage(cachedLogo);
      } else if (profile != null && profile.logoUrl.isNotEmpty) {
        debugPrint('[InvoicePdf] Cache empty, downloading logo...');
        final logoBytes = await _downloadImage(profile.logoUrl);
        if (logoBytes != null && logoBytes.isNotEmpty) {
          debugPrint('[InvoicePdf] Logo downloaded: ${logoBytes.length} bytes');
          _logoImage = pw.MemoryImage(logoBytes);
          await LogoCacheService.save(logoBytes);
        }
      }
    } catch (e) {
      debugPrint('[InvoicePdf] Logo load error: $e');
    }

    // Generate dynamic UPI QR code if merchant has UPI ID
    _invoiceQrBytes = null;
    if (profile != null && profile.upiId.isNotEmpty && invoice.grandTotal > 0) {
      try {
        // Use received amount (what customer is paying now), or grand total if nothing recorded
        final upiAmount = invoice.amountReceived > 0
            ? invoice.amountReceived
            : invoice.grandTotal;
        final upiLink = buildUpiPaymentLink(
          upiId: profile.upiId,
          businessName: profile.storeName,
          amount: upiAmount,
          invoiceNumber: invoice.invoiceNumber,
        );
        _invoiceQrBytes = await generateQrImageBytes(upiLink, size: 200);
      } catch (_) {
        // Skip QR if generation fails
      }
    }

    // Route structurally different layouts to their own builders.
    Future<Uint8List> Function() builder;
    final styledTemplate = _templateStyles[template];
    if (styledTemplate != null) {
      builder = () => _buildStyledPdf(
        invoice,
        profile,
        s,
        styledTemplate,
        includePayment: includePayment,
      );
    } else {
      switch (template) {
        case InvoiceTemplate.classic:
          builder = () => _buildClassicPdf(
            invoice,
            profile,
            s,
            includePayment: includePayment,
          );
        case InvoiceTemplate.modern:
          builder = () => _buildModernPdf(
            invoice,
            profile,
            s,
            includePayment: includePayment,
          );
        case InvoiceTemplate.compact:
          builder = () => _buildCompactPdf(
            invoice,
            profile,
            s,
            includePayment: includePayment,
          );
        case InvoiceTemplate.banner:
          builder = () => _buildBannerPdf(
            invoice,
            profile,
            s,
            includePayment: includePayment,
            colors: colors,
          );
        case InvoiceTemplate.sidebarLayout:
          builder = () => _buildSidebarPdf(
            invoice,
            profile,
            s,
            includePayment: includePayment,
            colors: colors,
          );
        case InvoiceTemplate.bordered:
          builder = () => _buildBorderedPdf(
            invoice,
            profile,
            s,
            includePayment: includePayment,
            colors: colors,
          );
        case InvoiceTemplate.twoColumn:
          builder = () => _buildTwoColumnPdf(
            invoice,
            profile,
            s,
            includePayment: includePayment,
            colors: colors,
          );
        case InvoiceTemplate.receipt:
          builder = () => _buildReceiptPdf(
            invoice,
            profile,
            s,
            includePayment: includePayment,
            colors: colors,
          );
        case InvoiceTemplate.vyapar:
          builder = () => _buildVyaparPdf(
            invoice,
            profile,
            s,
            includePayment: includePayment,
            colors: colors,
          );
        default:
          builder = () => _buildVyaparPdf(
            invoice,
            profile,
            s,
            includePayment: includePayment,
            colors: colors,
          );
      }
    }

    try {
      return await builder();
    } on RangeError {
      _fontRegular = pw.Font.helvetica();
      _fontBold = pw.Font.helveticaBold();
      _loadedLanguage = null;
      return builder();
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
              ? const pw.EdgeInsets.fromLTRB(0, 0, 0, 24)
              : const pw.EdgeInsets.fromLTRB(28, 0, 28, 24),
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
            if (_logoImage != null) ...[
              pw.Image(
                _logoImage!,
                width: 50,
                height: 50,
                fit: pw.BoxFit.contain,
              ),
              pw.SizedBox(width: 14),
            ],
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
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
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
            if (_logoImage != null) ...[
              pw.Image(
                _logoImage!,
                width: 50,
                height: 50,
                fit: pw.BoxFit.contain,
              ),
              pw.SizedBox(width: 14),
            ],
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
                  pw.Divider(
                    color: style.tableBorder,
                    height: 14,
                    thickness: 0.6,
                  ),
                  _styledMetaRow(s.pdfInvoiceNo, invoice.invoiceNumber, style),
                  pw.Divider(
                    color: style.tableBorder,
                    height: 14,
                    thickness: 0.6,
                  ),
                  _styledMetaRow(
                    s.pdfInvoiceDate,
                    _dateFormat.format(invoice.createdAt),
                    style,
                  ),
                  pw.Divider(
                    color: style.tableBorder,
                    height: 14,
                    thickness: 0.6,
                  ),
                  _styledMetaRow(
                    s.detailsGrandTotal,
                    _fmt(invoice.grandTotal),
                    style,
                    emphasize: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _styledMetaRow(
    String label,
    String value,
    TemplateStyle style, {
    bool emphasize = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: emphasize ? style.primaryColor : style.mutedText,
            fontSize: emphasize ? 10 : 9,
            fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        if (value.isNotEmpty)
          pw.Text(
            value,
            style: pw.TextStyle(
              color: emphasize ? style.primaryColor : style.bodyText,
              fontSize: emphasize ? 13 : 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
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

  pw.Widget _styledItemsTable(
    Invoice invoice,
    AppStrings s,
    TemplateStyle style,
  ) {
    final hasHsn = invoice.items.any((i) => i.hsnCode.isNotEmpty);
    final hasGst = invoice.gstEnabled;

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: style.tableHeaderBg),
        children: [
          _styledCell(s.pdfItem, header: true, style: style),
          _styledCell(
            s.detailsItemQty,
            header: true,
            align: pw.Alignment.center,
            style: style,
          ),
          _styledCell(
            s.detailsItemUnitPrice,
            header: true,
            align: pw.Alignment.centerRight,
            style: style,
          ),
          _styledCell(
            s.pdfAmount,
            header: true,
            align: pw.Alignment.centerRight,
            style: style,
          ),
          if (hasGst)
            _styledCell(
              'GST%',
              header: true,
              align: pw.Alignment.center,
              style: style,
            ),
          if (hasHsn)
            _styledCell(
              'HSN/SAC',
              header: true,
              align: pw.Alignment.center,
              style: style,
            ),
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
            _styledCell(
              item.quantityLabel,
              align: pw.Alignment.center,
              style: style,
            ),
            _styledCell(
              _fmt(item.unitPrice),
              align: pw.Alignment.centerRight,
              style: style,
            ),
            _styledCell(
              _fmt(item.total),
              align: pw.Alignment.centerRight,
              bold: true,
              style: style,
            ),
            if (hasGst)
              _styledCell(
                '${item.gstRate.toStringAsFixed(0)}%',
                align: pw.Alignment.center,
                style: style,
              ),
            if (hasHsn)
              _styledCell(
                item.hsnCode.isEmpty ? '-' : item.hsnCode,
                align: pw.Alignment.center,
                style: style,
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
            fontWeight: (header || bold)
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  pw.Widget _styledTotalsSection(
    Invoice invoice,
    AppStrings s,
    TemplateStyle style,
  ) {
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
                _styledSummaryRow(
                  'CGST',
                  _fmt(invoice.cgstAmount),
                  style,
                  valueColor: style.primaryColor,
                ),
                pw.SizedBox(height: 6),
                _styledSummaryRow(
                  'SGST',
                  _fmt(invoice.sgstAmount),
                  style,
                  valueColor: style.primaryColor,
                ),
              ] else
                _styledSummaryRow(
                  'IGST',
                  _fmt(invoice.igstAmount),
                  style,
                  valueColor: style.primaryColor,
                ),
            ],
            pw.SizedBox(height: 4),
            pw.Divider(color: style.primaryColor, height: 16, thickness: 0.6),
            _styledSummaryRow(
              s.detailsGrandTotal,
              _fmt(invoice.grandTotal),
              style,
              emphasize: true,
            ),
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
            color:
                valueColor ?? (emphasize ? style.primaryColor : style.bodyText),
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

  // ── Vyapar-style PDF ────────────────────────────────────────────────────

  // Default Vyapar colors — high contrast blue
  static final PdfColor _vyPrimary = PdfColor.fromHex('#0B57D0');
  static final PdfColor _vyLabelBg = PdfColor.fromHex('#D3E3FD');
  static final PdfColor _vyBorder = PdfColor.fromHex('#7CACF8');
  static const PdfColor _vyBlack = PdfColor(0.0, 0.0, 0.0);
  static final PdfColor _vyBody = PdfColor.fromHex('#1D1D1F');
  static final PdfColor _vyMuted = PdfColor.fromHex('#6B6B6B');

  // Per-template color overrides — high contrast, synced with widget preview
  static final Map<InvoiceTemplate, _VyColors> _vyColorMap = {
    InvoiceTemplate.vyapar: _VyColors(
      PdfColor.fromHex('#0B57D0'),
      PdfColor.fromHex('#D3E3FD'),
      PdfColor.fromHex('#7CACF8'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1D1D1F'),
      PdfColor.fromHex('#6B6B6B'),
    ),
    InvoiceTemplate.classic: _VyColors(
      PdfColor.fromHex('#1B3A5C'),
      PdfColor.fromHex('#D6E4F0'),
      PdfColor.fromHex('#8AACC8'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.modern: _VyColors(
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#E8E8E8'),
      PdfColor.fromHex('#A0A0A0'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#2D2D2D'),
      PdfColor.fromHex('#6E6E6E'),
    ),
    InvoiceTemplate.compact: _VyColors(
      PdfColor.fromHex('#1B7A3D'),
      PdfColor.fromHex('#CCF0D8'),
      PdfColor.fromHex('#6DC08A'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.minimalist: _VyColors(
      PdfColor.fromHex('#3C3C3C'),
      PdfColor.fromHex('#ECECEC'),
      PdfColor.fromHex('#B0B0B0'),
      PdfColor.fromHex('#111111'),
      PdfColor.fromHex('#2A2A2A'),
      PdfColor.fromHex('#787878'),
    ),
    InvoiceTemplate.bold: _VyColors(
      PdfColor.fromHex('#C62828'),
      PdfColor.fromHex('#FFCDD2'),
      PdfColor.fromHex('#E57373'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.elegant: _VyColors(
      PdfColor.fromHex('#5D4037'),
      PdfColor.fromHex('#EFEBE9'),
      PdfColor.fromHex('#BCAAA4'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#6D5D53'),
    ),
    InvoiceTemplate.professional: _VyColors(
      PdfColor.fromHex('#0D47A1'),
      PdfColor.fromHex('#BBDEFB'),
      PdfColor.fromHex('#64B5F6'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.vibrant: _VyColors(
      PdfColor.fromHex('#D50000'),
      PdfColor.fromHex('#FFCDD2'),
      PdfColor.fromHex('#EF9A9A'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.clean: _VyColors(
      PdfColor.fromHex('#00838F'),
      PdfColor.fromHex('#B2EBF2'),
      PdfColor.fromHex('#4DD0E1'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.royal: _VyColors(
      PdfColor.fromHex('#6A1B9A'),
      PdfColor.fromHex('#E1BEE7'),
      PdfColor.fromHex('#CE93D8'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.stripe: _VyColors(
      PdfColor.fromHex('#01579B'),
      PdfColor.fromHex('#B3E5FC'),
      PdfColor.fromHex('#4FC3F7'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.grid: _VyColors(
      PdfColor.fromHex('#37474F'),
      PdfColor.fromHex('#CFD8DC'),
      PdfColor.fromHex('#90A4AE'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.pastel: _VyColors(
      PdfColor.fromHex('#8E24AA'),
      PdfColor.fromHex('#F3E5F5'),
      PdfColor.fromHex('#BA68C8'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.dark: _VyColors(
      PdfColor.fromHex('#263238'),
      PdfColor.fromHex('#CFD8DC'),
      PdfColor.fromHex('#78909C'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.retail: _VyColors(
      PdfColor.fromHex('#E65100'),
      PdfColor.fromHex('#FFE0B2'),
      PdfColor.fromHex('#FFB74D'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.wholesale: _VyColors(
      PdfColor.fromHex('#00695C'),
      PdfColor.fromHex('#B2DFDB'),
      PdfColor.fromHex('#4DB6AC'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.services: _VyColors(
      PdfColor.fromHex('#283593'),
      PdfColor.fromHex('#C5CAE9'),
      PdfColor.fromHex('#7986CB'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.creative: _VyColors(
      PdfColor.fromHex('#C2185B'),
      PdfColor.fromHex('#F8BBD0'),
      PdfColor.fromHex('#F06292'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.simple: _VyColors(
      PdfColor.fromHex('#424242'),
      PdfColor.fromHex('#E0E0E0'),
      PdfColor.fromHex('#9E9E9E'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#212121'),
      PdfColor.fromHex('#616161'),
    ),
    InvoiceTemplate.gstPro: _VyColors(
      PdfColor.fromHex('#006064'),
      PdfColor.fromHex('#B2EBF2'),
      PdfColor.fromHex('#00ACC1'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    // Structurally different layouts
    InvoiceTemplate.banner: _VyColors(
      PdfColor.fromHex('#1565C0'),
      PdfColor.fromHex('#E3F2FD'),
      PdfColor.fromHex('#42A5F5'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.sidebarLayout: _VyColors(
      PdfColor.fromHex('#2E7D32'),
      PdfColor.fromHex('#E8F5E9'),
      PdfColor.fromHex('#66BB6A'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.bordered: _VyColors(
      PdfColor.fromHex('#4E342E'),
      PdfColor.fromHex('#EFEBE9'),
      PdfColor.fromHex('#8D6E63'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.twoColumn: _VyColors(
      PdfColor.fromHex('#AD1457'),
      PdfColor.fromHex('#FCE4EC'),
      PdfColor.fromHex('#EC407A'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
    InvoiceTemplate.receipt: _VyColors(
      PdfColor.fromHex('#333333'),
      PdfColor.fromHex('#F5F5F5'),
      PdfColor.fromHex('#999999'),
      PdfColor(0, 0, 0),
      PdfColor.fromHex('#1A1A1A'),
      PdfColor.fromHex('#5C5C5C'),
    ),
  };

  // Adaptive sizing parameters — computed per-invoice to fit one page
  double _vySectionSpacing = 10;
  double _vyBaseFontSize = 10;
  double _vyCellPadV = 6;
  double _vySignatureHeight = 60;
  double _vyTitleFontSize = 22;
  double _vySellerNameFontSize = 16;

  void _computeAdaptiveSizing(Invoice invoice, bool hasPayment) {
    final n = invoice.items.length;
    // Aggressive compaction — everything must fit one page
    _vySectionSpacing = n > 4 ? (6 - (n - 4) * 0.5).clamp(1.0, 6.0) : 6;
    _vyCellPadV = n > 4 ? (4 - (n - 4) * 0.15).clamp(1.5, 4.0) : 4;
    _vySignatureHeight = n > 6 ? (40.0 - (n - 6) * 3.0).clamp(14.0, 40.0) : 40;
    // Shrink fonts earlier
    _vyBaseFontSize = n > 8 ? (9 - (n - 8) * 0.15).clamp(6.5, 9.0) : 9;
    _vyTitleFontSize = n > 6 ? (18 - (n - 6) * 0.5).clamp(12.0, 18.0) : 18;
    _vySellerNameFontSize = n > 6 ? (12 - (n - 6) * 0.3).clamp(8.0, 12.0) : 12;
    // Extra compaction when payment section is present
    if (hasPayment && n > 3) {
      _vySectionSpacing = (_vySectionSpacing - 1.5).clamp(0.5, 6.0);
      _vySignatureHeight = (_vySignatureHeight - 8).clamp(10.0, 40.0);
    }
  }

  Future<Uint8List> _buildVyaparPdf(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s, {
    bool includePayment = true,
    _VyColors? colors,
  }) async {
    _c =
        colors ??
        _VyColors(
          _vyPrimary,
          _vyLabelBg,
          _vyBorder,
          _vyBlack,
          _vyBody,
          _vyMuted,
        );

    final hasPayment =
        includePayment &&
        profile != null &&
        (profile.upiId.isNotEmpty ||
            profile.upiNumber.isNotEmpty ||
            profile.upiQrUrl.isNotEmpty);
    _computeAdaptiveSizing(invoice, hasPayment);

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

    // Load saved signature
    final signatureBytes = await SignatureService.load();

    const pageFormat = PdfPageFormat.a4;
    const marginH = 16.0, marginTop = 14.0, marginBottom = 14.0;
    final usableWidth = pageFormat.width - marginH * 2;

    document.addPage(
      pw.Page(
        theme: theme,
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.fromLTRB(
          marginH,
          marginTop,
          marginH,
          marginBottom,
        ),
        build: (ctx) {
          final content = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _vyTitle(),
              pw.SizedBox(height: _vySectionSpacing),
              _vySellerBox(profile, s),
              pw.SizedBox(height: _vySectionSpacing),
              _vyBillToInvoiceDetails(invoice, profile, s),
              pw.SizedBox(height: _vySectionSpacing),
              _vyItemsTable(invoice, s),
              _vyTotalsBlock(invoice, s),
              pw.SizedBox(height: _vySectionSpacing),
              paymentWidget,
              // Terms + Signature SIDE BY SIDE (like Vyapar)
              pw.SizedBox(height: _vySectionSpacing),
              _vyTermsAndSignatureRow(profile, s, signatureBytes),
              pw.SizedBox(height: _vySectionSpacing),
              _vyFooter(ctx, s),
            ],
          );
          // Scale entire content to fit one page — no clipping
          return pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.topLeft,
            child: pw.SizedBox(width: usableWidth, child: content),
          );
        },
      ),
    );

    return document.save();
  }

  // Section 1 — Title
  pw.Widget _vyTitle() {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.symmetric(vertical: _vyCellPadV * 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _c.border, width: 1)),
      ),
      child: pw.Center(
        child: pw.Text(
          'Tax\nInvoice',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: _c.primary,
            fontSize: _vyTitleFontSize,
            fontWeight: pw.FontWeight.bold,
            lineSpacing: _vyTitleFontSize > 18 ? 4 : 2,
          ),
        ),
      ),
    );
  }

  // Section 2 — Seller Info Box
  pw.Widget _vySellerBox(BusinessProfile? profile, AppStrings s) {
    final sellerName = _sellerName(profile, s);
    final phone = profile?.phoneNumber ?? '';
    final smallFont = _vyBaseFontSize;

    final sellerDetails = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          sellerName,
          style: pw.TextStyle(
            color: _c.black,
            fontSize: _vySellerNameFontSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (phone.trim().isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            'Phone: $phone',
            style: pw.TextStyle(color: _c.muted, fontSize: smallFont),
          ),
        ],
        if (profile != null && profile.gstin.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            'GSTIN: ${profile.gstin}',
            style: pw.TextStyle(color: _c.muted, fontSize: smallFont),
          ),
        ],
        if (profile != null && profile.address.trim().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            profile.address.trim(),
            style: pw.TextStyle(color: _c.muted, fontSize: smallFont),
          ),
        ],
      ],
    );

    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(_vyCellPadV * 2),
      decoration: pw.BoxDecoration(
        color: _c.labelBg,
        border: pw.Border.all(color: _c.border, width: 1),
      ),
      child: _logoImage != null
          ? pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(
                  _logoImage!,
                  width: 48,
                  height: 48,
                  fit: pw.BoxFit.contain,
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(child: sellerDetails),
              ],
            )
          : sellerDetails,
    );
  }

  // Section 3 — Bill To / Invoice Details (2-column grid)
  pw.Widget _vyBillToInvoiceDetails(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s,
  ) {
    final fs = _vyBaseFontSize;
    final custFs = (fs + 2).clamp(8.0, 12.0);
    return pw.Table(
      border: pw.TableBorder.all(color: _c.border, width: 1),
      columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
      children: [
        // Header row
        pw.TableRow(
          children: [
            pw.Container(
              color: _c.labelBg,
              padding: pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: _vyCellPadV,
              ),
              child: pw.Text(
                'Bill To:',
                style: pw.TextStyle(
                  color: _c.black,
                  fontSize: fs,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Container(
              color: _c.labelBg,
              padding: pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: _vyCellPadV,
              ),
              child: pw.Text(
                'Invoice Details:',
                style: pw.TextStyle(
                  color: _c.black,
                  fontSize: fs,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        // Content row
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(_vyCellPadV + 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _customerName(invoice),
                    style: pw.TextStyle(
                      color: _c.black,
                      fontSize: custFs,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (_client != null && _client!.phone.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Phone: ${_client!.phone.trim()}',
                      style: pw.TextStyle(color: _c.body, fontSize: fs - 1),
                    ),
                  ],
                  if (_client != null && _client!.email.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Email: ${_client!.email.trim()}',
                      style: pw.TextStyle(color: _c.body, fontSize: fs - 1),
                    ),
                  ],
                  if (_client != null &&
                      _client!.address.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _client!.address.trim(),
                      style: pw.TextStyle(color: _c.body, fontSize: fs - 1),
                    ),
                  ],
                  if (invoice.customerGstin.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'GSTIN: ${invoice.customerGstin}',
                      style: pw.TextStyle(color: _c.body, fontSize: fs - 1),
                    ),
                  ],
                ],
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(_vyCellPadV + 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'No: ${invoice.invoiceNumber}',
                    style: pw.TextStyle(color: _c.body, fontSize: fs),
                  ),
                  pw.SizedBox(height: 2),
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: 'Date: ',
                          style: pw.TextStyle(color: _c.body, fontSize: fs),
                        ),
                        pw.TextSpan(
                          text: _dateFormat.format(invoice.createdAt),
                          style: pw.TextStyle(
                            color: _c.black,
                            fontSize: fs,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (invoice.dueDate != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Due: ${_dateFormat.format(invoice.dueDate!)}',
                      style: pw.TextStyle(color: _c.body, fontSize: fs),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Section 4 — Items Table
  pw.Widget _vyItemsTable(Invoice invoice, AppStrings s) {
    final hasHsn = invoice.items.any((i) => i.hsnCode.isNotEmpty);
    final hasGst = invoice.gstEnabled;
    final hasDisc = invoice.items.any((i) => i.discountPercent > 0);

    // Dynamic columns — only show what's needed
    int colIdx = 0;
    final colWidths = <int, pw.TableColumnWidth>{};
    colWidths[colIdx++] = const pw.FixedColumnWidth(22); // #
    colWidths[colIdx++] = const pw.FlexColumnWidth(2.5); // Item Name
    if (hasHsn) colWidths[colIdx++] = const pw.FlexColumnWidth(1.2);
    colWidths[colIdx++] = const pw.FlexColumnWidth(0.7); // Qty
    colWidths[colIdx++] = const pw.FlexColumnWidth(1); // Rate
    colWidths[colIdx++] = const pw.FlexColumnWidth(1); // Amt (Qty×Rate)
    if (hasDisc) {
      colWidths[colIdx++] = const pw.FlexColumnWidth(0.7); // Disc%
      colWidths[colIdx++] = const pw.FlexColumnWidth(1); // After Disc
    }
    if (hasGst) {
      colWidths[colIdx++] = const pw.FlexColumnWidth(0.7); // GST%
      colWidths[colIdx++] = const pw.FlexColumnWidth(1); // GST Amt
    }
    colWidths[colIdx++] = const pw.FlexColumnWidth(1.1); // Total

    // Header
    final headerCells = <pw.Widget>[
      _vyCell('#', header: true, align: pw.TextAlign.center),
      _vyCell('Item', header: true),
    ];
    if (hasHsn)
      headerCells.add(_vyCell('HSN', header: true, align: pw.TextAlign.center));
    headerCells.add(_vyCell('Qty', header: true, align: pw.TextAlign.right));
    headerCells.add(_vyCell('Rate', header: true, align: pw.TextAlign.right));
    headerCells.add(_vyCell('Amt', header: true, align: pw.TextAlign.right));
    if (hasDisc) {
      headerCells.add(
        _vyCell('Disc', header: true, align: pw.TextAlign.center),
      );
      headerCells.add(
        _vyCell('After\nDisc', header: true, align: pw.TextAlign.right),
      );
    }
    if (hasGst) {
      headerCells.add(_vyCell('GST', header: true, align: pw.TextAlign.center));
      headerCells.add(
        _vyCell('Tax\nAmt', header: true, align: pw.TextAlign.right),
      );
    }
    headerCells.add(_vyCell('Total', header: true, align: pw.TextAlign.right));

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _c.labelBg),
        children: headerCells,
      ),
    ];

    // Item rows
    for (var i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];

      final cells = <pw.Widget>[
        _vyCell('${i + 1}', align: pw.TextAlign.center),
        _vyCell(item.description, bold: true),
      ];
      if (hasHsn)
        cells.add(
          _vyCell(
            item.hsnCode.isEmpty ? '' : item.hsnCode,
            align: pw.TextAlign.center,
          ),
        );
      cells.add(_vyCell(item.quantityText, align: pw.TextAlign.right));
      cells.add(
        _vyCell('${_vyNum(item.unitPrice)}', align: pw.TextAlign.right),
      );
      cells.add(_vyCell('${_vyNum(item.rawTotal)}', align: pw.TextAlign.right));
      if (hasDisc) {
        cells.add(
          _vyCell(
            item.discountPercent > 0
                ? '${item.discountPercent.toStringAsFixed(0)}%'
                : '-',
            align: pw.TextAlign.center,
          ),
        );
        cells.add(_vyCell('${_vyNum(item.total)}', align: pw.TextAlign.right));
      }
      if (hasGst) {
        cells.add(
          _vyCell(
            item.gstRate > 0 ? '${item.gstRate.toStringAsFixed(0)}%' : '-',
            align: pw.TextAlign.center,
          ),
        );
        cells.add(
          _vyCell(
            item.gstRate > 0 ? '${_vyNum(item.gstAmount)}' : '-',
            align: pw.TextAlign.right,
          ),
        );
      }
      cells.add(
        _vyCell(
          '${_vyNum(item.totalWithGst)}',
          align: pw.TextAlign.right,
          bold: true,
        ),
      );

      rows.add(pw.TableRow(children: cells));
    }

    // Total row
    final itemCount = invoice.items.length;
    final totalRaw = invoice.items.fold<double>(0, (s, i) => s + i.rawTotal);
    final totalAfterDisc = invoice.items.fold<double>(0, (s, i) => s + i.total);
    final totalGstAmt = invoice.items.fold<double>(
      0,
      (s, i) => s + i.gstAmount,
    );
    final totalFinal = invoice.items.fold<double>(
      0,
      (s, i) => s + i.totalWithGst,
    );

    final totalCells = <pw.Widget>[
      _vyCell('', bold: true),
      _vyCell('Total ($itemCount items)', bold: true),
    ];
    if (hasHsn) totalCells.add(_vyCell(''));
    totalCells.add(_vyCell(''));
    totalCells.add(_vyCell(''));
    totalCells.add(
      _vyCell('${_vyNum(totalRaw)}', bold: true, align: pw.TextAlign.right),
    );
    if (hasDisc) {
      totalCells.add(_vyCell(''));
      totalCells.add(
        _vyCell(
          '${_vyNum(totalAfterDisc)}',
          bold: true,
          align: pw.TextAlign.right,
        ),
      );
    }
    if (hasGst) {
      totalCells.add(_vyCell(''));
      totalCells.add(
        _vyCell(
          '${_vyNum(totalGstAmt)}',
          bold: true,
          align: pw.TextAlign.right,
        ),
      );
    }
    totalCells.add(
      _vyCell('${_vyNum(totalFinal)}', bold: true, align: pw.TextAlign.right),
    );

    rows.add(pw.TableRow(children: totalCells));

    return pw.Table(
      border: pw.TableBorder.all(color: _c.border, width: 0.5),
      columnWidths: colWidths,
      children: rows,
    );
  }

  pw.Widget _vyCell(
    String value, {
    bool header = false,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    final headerFs = (_vyBaseFontSize - 1).clamp(6.0, 9.0);
    final bodyFs = _vyBaseFontSize;
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: _vyCellPadV),
      child: pw.Text(
        value,
        textAlign: align,
        style: pw.TextStyle(
          color: _c.black,
          fontSize: header ? headerFs : bodyFs,
          fontWeight: (header || bold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _vyNum(double value) {
    return value.toStringAsFixed(2);
  }

  // Section 5 — Totals Block
  pw.Widget _vyTotalsBlock(Invoice invoice, AppStrings s) {
    final received = invoice.amountReceived;
    final balance = invoice.grandTotal - received;
    final rawTotal = invoice.items.fold<double>(
      0,
      (sum, i) => sum + i.rawTotal,
    );
    final itemDiscTotal = invoice.items.fold<double>(
      0,
      (sum, i) => sum + i.discountAmount,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left side: empty
        pw.Expanded(child: pw.SizedBox()),
        // Right side: totals — takes ~half the page width
        pw.Container(
          width: 280,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _c.border, width: 1),
          ),
          child: pw.Column(
            children: [
              _vyTotalRow('Sub Total', 'Rs. ${_vyNum(rawTotal)}'),
              if (itemDiscTotal > 0)
                _vyTotalRow('Item Discounts', '- Rs. ${_vyNum(itemDiscTotal)}'),
              if (invoice.discountAmount > 0)
                _vyTotalRow(
                  'Discount${invoice.discountType == InvoiceDiscountType.percentage ? ' (${invoice.discountValue.toStringAsFixed(0)}%)' : ''}',
                  '- Rs. ${_vyNum(invoice.discountAmount)}',
                ),
              if (itemDiscTotal > 0 ||
                  invoice.discountAmount > 0 ||
                  invoice.totalTax > 0)
                _vyTotalRow(
                  'Taxable Amount',
                  'Rs. ${_vyNum(invoice.taxableAmount)}',
                ),
              if (invoice.totalTax > 0) ...[
                if (invoice.gstType == 'cgst_sgst') ...[
                  _vyTotalRow('CGST', 'Rs. ${_vyNum(invoice.cgstAmount)}'),
                  _vyTotalRow('SGST', 'Rs. ${_vyNum(invoice.sgstAmount)}'),
                ] else if (invoice.igstAmount > 0)
                  _vyTotalRow('IGST', 'Rs. ${_vyNum(invoice.igstAmount)}'),
                _vyTotalRow('Total Tax', 'Rs. ${_vyNum(invoice.totalTax)}'),
              ],
              _vyTotalRow(
                'Grand Total',
                'Rs. ${_vyNum(invoice.grandTotal)}',
                bold: true,
                highlight: true,
              ),
              // Amount in words
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: _vyCellPadV,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: _c.border, width: 1),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Invoice Amount In Words :',
                      style: pw.TextStyle(
                        color: _c.black,
                        fontSize: _vyBaseFontSize - 1,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _numberToWords(
                        invoice.grandTotal.truncate(),
                        ((invoice.grandTotal * 100).round() % 100),
                      ),
                      style: pw.TextStyle(
                        color: _c.body,
                        fontSize: _vyBaseFontSize - 1,
                      ),
                    ),
                  ],
                ),
              ),
              _vyTotalRow('Amount Received', 'Rs. ${_vyNum(received)}'),
              if (invoice.paymentMethod.isNotEmpty)
                _vyTotalRow('Payment Mode', invoice.paymentMethod),
              _vyTotalRow('Balance Due', 'Rs. ${_vyNum(balance)}', bold: true),
              if (invoice.notes != null && invoice.notes!.isNotEmpty)
                pw.Container(
                  width: double.infinity,
                  padding: pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: _vyCellPadV + 2,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _c.labelBg,
                    border: pw.Border(
                      top: pw.BorderSide(color: _c.primary, width: 1),
                    ),
                  ),
                  child: pw.Text(
                    invoice.notes!,
                    style: pw.TextStyle(
                      fontSize: _vyBaseFontSize - 1,
                      color: _c.primary,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _vyTotalRow(
    String label,
    String value, {
    bool bold = false,
    bool highlight = false,
  }) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 10, vertical: _vyCellPadV),
      decoration: pw.BoxDecoration(
        color: highlight ? _c.primary : null,
        border: pw.Border(top: pw.BorderSide(color: _c.border, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: highlight ? PdfColors.white : _c.black,
              fontSize: highlight ? _vyBaseFontSize + 1 : _vyBaseFontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: highlight ? PdfColors.white : _c.black,
              fontSize: highlight ? _vyBaseFontSize + 1 : _vyBaseFontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Terms (left) + Signature (right) — side by side like Vyapar
  pw.Widget _vyTermsAndSignatureRow(
    BusinessProfile? profile,
    AppStrings s,
    Uint8List? signatureImage,
  ) {
    final sellerName = _sellerName(profile, s);
    final fs = _vyBaseFontSize;

    pw.Widget sigArea;
    if (signatureImage != null) {
      final img = pw.MemoryImage(signatureImage);
      sigArea = pw.Container(
        width: double.infinity,
        height: _vySignatureHeight,
        margin: pw.EdgeInsets.symmetric(
          horizontal: 8,
          vertical: _vyCellPadV - 1,
        ),
        child: pw.Image(img, fit: pw.BoxFit.contain),
      );
    } else {
      sigArea = pw.Container(
        width: double.infinity,
        height: _vySignatureHeight,
        margin: pw.EdgeInsets.symmetric(
          horizontal: 8,
          vertical: _vyCellPadV - 1,
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _c.border, width: 1),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FixedColumnWidth(200),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _c.labelBg),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: _vyCellPadV,
              ),
              child: pw.Text(
                'Terms and conditions',
                style: pw.TextStyle(
                  color: _c.black,
                  fontSize: fs,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: _vyCellPadV,
              ),
              child: pw.Text(
                'For $sellerName:',
                style: pw.TextStyle(
                  color: _c.black,
                  fontSize: fs,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        // Content row
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(_vyCellPadV),
              child: pw.Text(
                'Thank you for doing business with us.',
                style: pw.TextStyle(color: _c.body, fontSize: fs - 1),
              ),
            ),
            pw.Column(
              children: [
                sigArea,
                pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: _vyCellPadV),
                  child: pw.Text(
                    'Authorized Signatory',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(color: _c.body, fontSize: fs - 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _vyFooter(pw.Context ctx, AppStrings s) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${s.pdfGeneratedBy} \u00b7 ${_generatedFormat.format(DateTime.now())}',
            style: pw.TextStyle(color: _c.muted, fontSize: 8),
          ),
          pw.Text(
            '${s.pdfPage} ${ctx.pageNumber} ${s.pdfOf} ${ctx.pagesCount}',
            style: pw.TextStyle(color: _c.muted, fontSize: 8),
          ),
        ],
      ),
    );
  }

  /// Converts a whole number to Indian English words (e.g. 600 → "Six Hundred Rupees only").
  static String _numberToWords(int number, [int paise = 0]) {
    try {
      final rupeePart = _numberToWordsInner(number);
      if (paise > 0 && paise < 100) {
        final paisePart = _numberToWordsInner(
          paise,
        ).replaceAll(' Rupees only', '');
        return '$rupeePart and $paisePart Paise only';
      }
      return rupeePart;
    } catch (_) {
      return 'Rupees ${number.toString()} only';
    }
  }

  static String _numberToWordsInner(int number) {
    if (number == 0) return 'Zero Rupees only';
    if (number < 0) return 'Minus ${_numberToWordsInner(-number)}';

    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    String twoDigits(int v) {
      if (v < 20) return ones[v];
      final t = v ~/ 10;
      final o = v % 10;
      return o == 0 ? tens[t] : '${tens[t]} ${ones[o]}';
    }

    String threeDigits(int v) {
      if (v == 0) return '';
      final h = v ~/ 100;
      final r = v % 100;
      if (h == 0) return twoDigits(r);
      if (r == 0) return '${ones[h]} Hundred';
      return '${ones[h]} Hundred ${twoDigits(r)}';
    }

    // Indian numbering: Crore (10^7), Lakh (10^5), Thousand (10^3), Hundred
    var rem = number;
    final parts = <String>[];
    if (rem >= 10000000) {
      final croreVal = rem ~/ 10000000;
      parts.add(
        '${_numberToWordsInner(croreVal).replaceAll(' Rupees only', '')} Crore',
      );
      rem %= 10000000;
    }
    if (rem >= 100000) {
      parts.add('${twoDigits(rem ~/ 100000)} Lakh');
      rem %= 100000;
    }
    if (rem >= 1000) {
      parts.add('${twoDigits(rem ~/ 1000)} Thousand');
      rem %= 1000;
    }
    if (rem > 0) {
      parts.add(threeDigits(rem));
    }

    return '${parts.join(' ')} Rupees only';
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
    final paymentWidget = (includePayment && profile != null)
        ? await _paymentSection(profile)
        : pw.SizedBox.shrink();

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

  static const PdfColor _modernNavy = PdfColor(0.04, 0.14, 0.31); // 0xFF1E3A8A
  static const PdfColor _modernTeal = PdfColor(0.06, 0.49, 0.51); // 0xFF6366F1
  static const PdfColor _modernRowAlt = PdfColor(
    0.94,
    0.96,
    1.00,
  ); // 0xFFF8FAFC

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
    final paymentWidget = (includePayment && profile != null)
        ? await _paymentSection(profile)
        : pw.SizedBox.shrink();

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
              if (_client != null && _client!.phone.trim().isNotEmpty)
                'Phone: ${_client!.phone.trim()}',
              if (_client != null && _client!.email.trim().isNotEmpty)
                'Email: ${_client!.email.trim()}',
              if (_client != null && _client!.address.trim().isNotEmpty)
                _client!.address.trim(),
              if (invoice.customerGstin.isNotEmpty)
                'GSTIN: ${invoice.customerGstin}',
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
                  style: pw.TextStyle(color: _mutedText, fontSize: 9),
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
          _modernCell(
            s.detailsItemQty,
            header: true,
            align: pw.Alignment.center,
          ),
          _modernCell(
            s.detailsItemUnitPrice,
            header: true,
            align: pw.Alignment.centerRight,
          ),
          _modernCell(
            s.pdfAmount,
            header: true,
            align: pw.Alignment.centerRight,
          ),
          if (hasGst)
            _modernCell('GST%', header: true, align: pw.Alignment.center),
          if (hasHsn)
            _modernCell('HSN/SAC', header: true, align: pw.Alignment.center),
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
            _modernCell(
              _fmt(item.total),
              align: pw.Alignment.centerRight,
              bold: true,
            ),
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
            fontWeight: (header || bold)
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
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
                _modernSummaryRow(
                  'CGST',
                  _fmt(invoice.cgstAmount),
                  valueColor: _modernNavy,
                ),
                pw.SizedBox(height: 6),
                _modernSummaryRow(
                  'SGST',
                  _fmt(invoice.sgstAmount),
                  valueColor: _modernNavy,
                ),
              ] else
                _modernSummaryRow(
                  'IGST',
                  _fmt(invoice.igstAmount),
                  valueColor: _modernNavy,
                ),
            ],
            pw.SizedBox(height: 4),
            pw.Divider(color: _modernNavy, height: 16, thickness: 0.6),
            _modernSummaryRow(
              s.detailsGrandTotal,
              _fmt(invoice.grandTotal),
              emphasize: true,
            ),
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

    final paymentWidget = (includePayment && profile != null)
        ? await _paymentSection(profile)
        : pw.SizedBox.shrink();

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
                style: pw.TextStyle(
                  color: _compactText,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
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
                style: pw.TextStyle(
                  color: _compactText,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (_client != null && _client!.phone.trim().isNotEmpty)
                pw.Text(
                  'Phone: ${_client!.phone.trim()}',
                  style: pw.TextStyle(color: _compactMuted, fontSize: 6),
                ),
              if (_client != null && _client!.email.trim().isNotEmpty)
                pw.Text(
                  'Email: ${_client!.email.trim()}',
                  style: pw.TextStyle(color: _compactMuted, fontSize: 6),
                ),
              if (_client != null && _client!.address.trim().isNotEmpty)
                pw.Text(
                  _client!.address.trim(),
                  style: pw.TextStyle(color: _compactMuted, fontSize: 6),
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
          _compactCell(
            s.detailsItemQty,
            header: true,
            align: pw.Alignment.center,
          ),
          _compactCell(
            s.detailsItemUnitPrice,
            header: true,
            align: pw.Alignment.centerRight,
          ),
          _compactCell(
            s.pdfAmount,
            header: true,
            align: pw.Alignment.centerRight,
          ),
          if (hasGst)
            _compactCell('GST%', header: true, align: pw.Alignment.center),
          if (hasHsn)
            _compactCell('HSN', header: true, align: pw.Alignment.center),
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
            _compactCell(
              _fmt(item.total),
              align: pw.Alignment.centerRight,
              bold: true,
            ),
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
            fontWeight: (header || bold)
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
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
              _compactTotalRow(
                s.detailsDiscount,
                '-${_fmt(invoice.discountAmount)}',
              ),
            if (invoice.hasGst) ...[
              if (invoice.gstType == 'cgst_sgst') ...[
                _compactTotalRow('CGST', _fmt(invoice.cgstAmount)),
                _compactTotalRow('SGST', _fmt(invoice.sgstAmount)),
              ] else
                _compactTotalRow('IGST', _fmt(invoice.igstAmount)),
            ],
            pw.Container(height: 0.5, color: _compactBorder),
            pw.SizedBox(height: 3),
            _compactTotalRow(
              s.detailsGrandTotal,
              _fmt(invoice.grandTotal),
              bold: true,
            ),
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
                          pw.Divider(
                            color: _border,
                            height: 14,
                            thickness: 0.6,
                          ),
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
              if (_client != null && _client!.phone.trim().isNotEmpty)
                'Phone: ${_client!.phone.trim()}',
              if (_client != null && _client!.email.trim().isNotEmpty)
                'Email: ${_client!.email.trim()}',
              if (_client != null && _client!.address.trim().isNotEmpty)
                _client!.address.trim(),
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
      if (hasGst) _cell('GST%', header: true, align: pw.Alignment.center),
      if (hasHsn) _cell('HSN/SAC', header: true, align: pw.Alignment.center),
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
        'BillRaja',
        style: pw.TextStyle(color: _mutedText, fontSize: 10, lineSpacing: 2),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Payment Section (UPI) — only rendered if user has set up UPI
  // -------------------------------------------------------------------------

  /// Downloads image bytes from a URL. Works on both web and native.
  /// Returns null if download fails.
  /// Strips the `token` query parameter from a Firebase Storage URL.
  /// With public-read storage rules, the token is unnecessary and an
  /// expired/revoked token causes 403 errors.
  static String _stripStorageToken(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('firebasestorage') &&
          uri.queryParameters.containsKey('token')) {
        final params = Map<String, String>.from(uri.queryParameters)
          ..remove('token');
        return uri.replace(queryParameters: params).toString();
      }
    } catch (e) {
      debugPrint('[InvoicePdf] URL token strip failed: $e');
    }
    return url;
  }

  /// Downloads image bytes from a URL. Works on both web and native.
  static Future<Uint8List?> _downloadImage(String rawUrl) async {
    // Strip expired Firebase Storage tokens — public-read rules don't need them
    final url = _stripStorageToken(rawUrl);
    try {
      // First try: use NetworkAssetBundle (works on both web and native)
      try {
        final uri = Uri.parse(url);
        final bundle = NetworkAssetBundle(uri);
        final data = await bundle
            .load(url)
            .timeout(const Duration(seconds: 15));
        final bytes = data.buffer.asUint8List();
        if (bytes.isNotEmpty) return bytes;
      } catch (e) {
        debugPrint('[InvoicePdf] NetworkAssetBundle failed: $e');
      }

      // Fallback for native: use HttpClient directly
      if (!kIsWeb) {
        final httpClient = HttpClient();
        httpClient.connectionTimeout = const Duration(seconds: 10);
        final request = await httpClient.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode == 200) {
          final bytes = await consolidateHttpClientResponseBytes(response);
          httpClient.close();
          if (bytes.isNotEmpty) return bytes;
        } else {
          debugPrint(
            '[InvoicePdf] HttpClient failed: HTTP ${response.statusCode}',
          );
          httpClient.close();
        }
      }

      return null;
    } catch (e) {
      debugPrint('[InvoicePdf] Image download error: $e');
      return null;
    }
  }

  Future<pw.Widget> _paymentSection(BusinessProfile profile) async {
    final hasUpi = profile.upiId.isNotEmpty;
    final hasNumber = profile.upiNumber.isNotEmpty;
    final hasQr = profile.upiQrUrl.isNotEmpty;
    final hasDynamicQr = _invoiceQrBytes != null;

    if (!hasUpi && !hasNumber && !hasQr && !hasDynamicQr) {
      return pw.SizedBox.shrink();
    }

    // Prefer dynamic (invoice-specific) QR, fall back to static QR from profile
    pw.Widget? qrImage;
    if (hasDynamicQr) {
      qrImage = pw.Image(
        pw.MemoryImage(_invoiceQrBytes!),
        width: 100,
        height: 100,
      );
    } else if (hasQr) {
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
                // QR code is sufficient — no need to display UPI ID/number text
              ],
            ),
          ),
          if (qrImage != null) ...[
            pw.SizedBox(width: 16),
            pw.Column(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _border, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: qrImage,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Scan to Pay',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _headingText,
                  ),
                ),
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

  // ═════════════════════════════════════════════════════════════════════════
  // STRUCTURALLY DIFFERENT TEMPLATES
  // ═════════════════════════════════════════════════════════════════════════

  /// Template 1: BANNER — Full-width colored header banner
  Future<Uint8List> _buildBannerPdf(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s, {
    bool includePayment = true,
    _VyColors? colors,
  }) async {
    _c =
        colors ??
        _VyColors(
          _vyPrimary,
          _vyLabelBg,
          _vyBorder,
          _vyBlack,
          _vyBody,
          _vyMuted,
        );
    final hasPayment =
        includePayment &&
        profile != null &&
        (profile.upiId.isNotEmpty ||
            profile.upiNumber.isNotEmpty ||
            profile.upiQrUrl.isNotEmpty);
    _computeAdaptiveSizing(invoice, hasPayment);

    final document = pw.Document(
      title: invoice.invoiceNumber,
      creator: 'BillRaja',
    );
    final theme = pw.ThemeData.withFont(base: _fontRegular!, bold: _fontBold!);
    final signatureBytes = await SignatureService.load();
    final paymentWidget = (includePayment && profile != null)
        ? await _paymentSection(profile)
        : pw.SizedBox.shrink();

    const pageFormat = PdfPageFormat.a4;

    document.addPage(
      pw.Page(
        theme: theme,
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(0),
        build: (ctx) {
          final content = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Full-width banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                color: _c.primary,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (_logoImage != null) ...[
                          pw.Image(
                            _logoImage!,
                            width: 44,
                            height: 44,
                            fit: pw.BoxFit.contain,
                          ),
                          pw.SizedBox(width: 12),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              _sellerName(profile, s),
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: _vySellerNameFontSize + 2,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            if (profile?.phoneNumber.isNotEmpty == true)
                              pw.Text(
                                profile!.phoneNumber,
                                style: pw.TextStyle(
                                  color: PdfColor.fromHex('#FFFFFFCC'),
                                  fontSize: _vyBaseFontSize,
                                ),
                              ),
                            if (profile?.gstin.isNotEmpty == true)
                              pw.Text(
                                'GSTIN: ${profile!.gstin}',
                                style: pw.TextStyle(
                                  color: PdfColor.fromHex('#FFFFFFCC'),
                                  fontSize: _vyBaseFontSize,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'TAX INVOICE',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: _vyTitleFontSize,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          invoice.invoiceNumber,
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#FFFFFFCC'),
                            fontSize: _vyBaseFontSize + 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Invoice details bar
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                color: _c.labelBg,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Date: ${_dateFormat.format(invoice.createdAt)}',
                      style: pw.TextStyle(
                        fontSize: _vyBaseFontSize,
                        color: _c.body,
                      ),
                    ),
                    if (invoice.dueDate != null)
                      pw.Text(
                        'Due: ${_dateFormat.format(invoice.dueDate!)}',
                        style: pw.TextStyle(
                          fontSize: _vyBaseFontSize,
                          color: _c.body,
                        ),
                      ),
                    pw.Text(
                      'Status: ${invoice.status.name.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: _vyBaseFontSize,
                        fontWeight: pw.FontWeight.bold,
                        color: _c.primary,
                      ),
                    ),
                  ],
                ),
              ),
              // Content with padding
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Bill To
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _c.border, width: 0.5),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILL TO',
                            style: pw.TextStyle(
                              fontSize: _vyBaseFontSize - 1,
                              fontWeight: pw.FontWeight.bold,
                              color: _c.primary,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            invoice.clientName,
                            style: pw.TextStyle(
                              fontSize: _vyBaseFontSize + 1,
                              fontWeight: pw.FontWeight.bold,
                              color: _c.body,
                            ),
                          ),
                          if (_client != null &&
                              _client!.phone.trim().isNotEmpty)
                            pw.Text(
                              'Phone: ${_client!.phone.trim()}',
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                          if (_client != null &&
                              _client!.email.trim().isNotEmpty)
                            pw.Text(
                              'Email: ${_client!.email.trim()}',
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                          if (_client != null &&
                              _client!.address.trim().isNotEmpty)
                            pw.Text(
                              _client!.address.trim(),
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                          if (invoice.customerGstin.isNotEmpty)
                            pw.Text(
                              'GSTIN: ${invoice.customerGstin}',
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: _vySectionSpacing),
                    _vyItemsTable(invoice, s),
                    _vyTotalsBlock(invoice, s),
                    pw.SizedBox(height: _vySectionSpacing),
                    paymentWidget,
                    pw.SizedBox(height: _vySectionSpacing),
                    _vyTermsAndSignatureRow(profile, s, signatureBytes),
                    pw.SizedBox(height: _vySectionSpacing),
                    _vyFooter(ctx, s),
                  ],
                ),
              ),
            ],
          );
          return pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.topLeft,
            child: pw.SizedBox(width: pageFormat.width, child: content),
          );
        },
      ),
    );
    return document.save();
  }

  /// Template 2: SIDEBAR — Left accent bar with content on right
  Future<Uint8List> _buildSidebarPdf(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s, {
    bool includePayment = true,
    _VyColors? colors,
  }) async {
    _c =
        colors ??
        _VyColors(
          _vyPrimary,
          _vyLabelBg,
          _vyBorder,
          _vyBlack,
          _vyBody,
          _vyMuted,
        );
    final hasPayment =
        includePayment &&
        profile != null &&
        (profile.upiId.isNotEmpty ||
            profile.upiNumber.isNotEmpty ||
            profile.upiQrUrl.isNotEmpty);
    _computeAdaptiveSizing(invoice, hasPayment);

    final document = pw.Document(
      title: invoice.invoiceNumber,
      creator: 'BillRaja',
    );
    final theme = pw.ThemeData.withFont(base: _fontRegular!, bold: _fontBold!);
    final signatureBytes = await SignatureService.load();
    final paymentWidget = (includePayment && profile != null)
        ? await _paymentSection(profile)
        : pw.SizedBox.shrink();

    const pageFormat = PdfPageFormat.a4;
    const sidebarWidth = 60.0;
    final contentWidth = pageFormat.width - sidebarWidth - 32;

    document.addPage(
      pw.Page(
        theme: theme,
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(0),
        build: (ctx) {
          final mainContent = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Title row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TAX INVOICE',
                    style: pw.TextStyle(
                      fontSize: _vyTitleFontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: _c.primary,
                    ),
                  ),
                  pw.Text(
                    invoice.invoiceNumber,
                    style: pw.TextStyle(
                      fontSize: _vyBaseFontSize + 2,
                      fontWeight: pw.FontWeight.bold,
                      color: _c.body,
                    ),
                  ),
                ],
              ),
              pw.Divider(color: _c.primary, thickness: 2),
              pw.SizedBox(height: _vySectionSpacing),
              _vySellerBox(profile, s),
              pw.SizedBox(height: _vySectionSpacing),
              _vyBillToInvoiceDetails(invoice, profile, s),
              pw.SizedBox(height: _vySectionSpacing),
              _vyItemsTable(invoice, s),
              _vyTotalsBlock(invoice, s),
              pw.SizedBox(height: _vySectionSpacing),
              paymentWidget,
              pw.SizedBox(height: _vySectionSpacing),
              _vyTermsAndSignatureRow(profile, s, signatureBytes),
              pw.SizedBox(height: _vySectionSpacing),
              _vyFooter(ctx, s),
            ],
          );

          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Sidebar accent bar
              pw.Container(
                width: sidebarWidth,
                height: pageFormat.height,
                color: _c.primary,
                padding: const pw.EdgeInsets.symmetric(vertical: 20),
                child: pw.Column(
                  children: [
                    pw.Transform.rotateBox(
                      angle: -1.5708, // -90 degrees
                      child: pw.Text(
                        _sellerName(profile, s),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    alignment: pw.Alignment.topLeft,
                    child: pw.SizedBox(width: contentWidth, child: mainContent),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return document.save();
  }

  /// Template 3: BORDERED — Thick bordered boxes around every section
  Future<Uint8List> _buildBorderedPdf(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s, {
    bool includePayment = true,
    _VyColors? colors,
  }) async {
    _c =
        colors ??
        _VyColors(
          _vyPrimary,
          _vyLabelBg,
          _vyBorder,
          _vyBlack,
          _vyBody,
          _vyMuted,
        );
    final hasPayment =
        includePayment &&
        profile != null &&
        (profile.upiId.isNotEmpty ||
            profile.upiNumber.isNotEmpty ||
            profile.upiQrUrl.isNotEmpty);
    _computeAdaptiveSizing(invoice, hasPayment);

    final document = pw.Document(
      title: invoice.invoiceNumber,
      creator: 'BillRaja',
    );
    final theme = pw.ThemeData.withFont(base: _fontRegular!, bold: _fontBold!);
    final signatureBytes = await SignatureService.load();
    final paymentWidget = (includePayment && profile != null)
        ? await _paymentSection(profile)
        : pw.SizedBox.shrink();

    const pageFormat = PdfPageFormat.a4;
    final usableWidth = pageFormat.width - 32;

    document.addPage(
      pw.Page(
        theme: theme,
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(16),
        build: (ctx) {
          final content = pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _c.primary, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                // Double-line title header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: _c.primary, width: 2),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: _vyTitleFontSize,
                        fontWeight: pw.FontWeight.bold,
                        color: _c.primary,
                      ),
                    ),
                  ),
                ),
                // Seller info box
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: _c.primary, width: 1),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (_logoImage != null) ...[
                            pw.Image(
                              _logoImage!,
                              width: 40,
                              height: 40,
                              fit: pw.BoxFit.contain,
                            ),
                            pw.SizedBox(width: 8),
                          ],
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                _sellerName(profile, s),
                                style: pw.TextStyle(
                                  fontSize: _vySellerNameFontSize,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _c.body,
                                ),
                              ),
                              if (profile?.phoneNumber.isNotEmpty == true)
                                pw.Text(
                                  'Ph: ${profile!.phoneNumber}',
                                  style: pw.TextStyle(
                                    fontSize: _vyBaseFontSize,
                                    color: _c.muted,
                                  ),
                                ),
                              if (profile?.address.isNotEmpty == true)
                                pw.Text(
                                  profile!.address,
                                  style: pw.TextStyle(
                                    fontSize: _vyBaseFontSize - 1,
                                    color: _c.muted,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          if (profile?.gstin.isNotEmpty == true)
                            pw.Text(
                              'GSTIN: ${profile!.gstin}',
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize,
                                fontWeight: pw.FontWeight.bold,
                                color: _c.body,
                              ),
                            ),
                          pw.Text(
                            'Invoice: ${invoice.invoiceNumber}',
                            style: pw.TextStyle(
                              fontSize: _vyBaseFontSize,
                              color: _c.body,
                            ),
                          ),
                          pw.Text(
                            'Date: ${_dateFormat.format(invoice.createdAt)}',
                            style: pw.TextStyle(
                              fontSize: _vyBaseFontSize,
                              color: _c.muted,
                            ),
                          ),
                          if (invoice.dueDate != null)
                            pw.Text(
                              'Due: ${_dateFormat.format(invoice.dueDate!)}',
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize,
                                color: _c.muted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Bill To boxed
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: _c.primary, width: 1),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILL TO:',
                        style: pw.TextStyle(
                          fontSize: _vyBaseFontSize - 1,
                          fontWeight: pw.FontWeight.bold,
                          color: _c.primary,
                        ),
                      ),
                      pw.Text(
                        invoice.clientName,
                        style: pw.TextStyle(
                          fontSize: _vyBaseFontSize + 1,
                          fontWeight: pw.FontWeight.bold,
                          color: _c.body,
                        ),
                      ),
                      if (_client != null && _client!.phone.trim().isNotEmpty)
                        pw.Text(
                          'Phone: ${_client!.phone.trim()}',
                          style: pw.TextStyle(
                            fontSize: _vyBaseFontSize - 1,
                            color: _c.muted,
                          ),
                        ),
                      if (_client != null && _client!.email.trim().isNotEmpty)
                        pw.Text(
                          'Email: ${_client!.email.trim()}',
                          style: pw.TextStyle(
                            fontSize: _vyBaseFontSize - 1,
                            color: _c.muted,
                          ),
                        ),
                      if (_client != null && _client!.address.trim().isNotEmpty)
                        pw.Text(
                          _client!.address.trim(),
                          style: pw.TextStyle(
                            fontSize: _vyBaseFontSize - 1,
                            color: _c.muted,
                          ),
                        ),
                      if (invoice.customerGstin.isNotEmpty)
                        pw.Text(
                          'GSTIN: ${invoice.customerGstin}',
                          style: pw.TextStyle(
                            fontSize: _vyBaseFontSize - 1,
                            color: _c.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                // Items + totals
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _vyItemsTable(invoice, s),
                      _vyTotalsBlock(invoice, s),
                    ],
                  ),
                ),
                // Payment
                if (hasPayment)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                    child: paymentWidget,
                  ),
                // Terms + Signature boxed
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: _c.primary, width: 2),
                    ),
                  ),
                  padding: const pw.EdgeInsets.all(8),
                  child: _vyTermsAndSignatureRow(profile, s, signatureBytes),
                ),
                // Footer
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: _c.primary, width: 1),
                    ),
                  ),
                  padding: const pw.EdgeInsets.all(4),
                  child: _vyFooter(ctx, s),
                ),
              ],
            ),
          );
          return pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.topLeft,
            child: pw.SizedBox(width: usableWidth, child: content),
          );
        },
      ),
    );
    return document.save();
  }

  /// Template 4: TWO COLUMN — Seller & Bill-to side by side, compact layout
  Future<Uint8List> _buildTwoColumnPdf(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s, {
    bool includePayment = true,
    _VyColors? colors,
  }) async {
    _c =
        colors ??
        _VyColors(
          _vyPrimary,
          _vyLabelBg,
          _vyBorder,
          _vyBlack,
          _vyBody,
          _vyMuted,
        );
    final hasPayment =
        includePayment &&
        profile != null &&
        (profile.upiId.isNotEmpty ||
            profile.upiNumber.isNotEmpty ||
            profile.upiQrUrl.isNotEmpty);
    _computeAdaptiveSizing(invoice, hasPayment);

    final document = pw.Document(
      title: invoice.invoiceNumber,
      creator: 'BillRaja',
    );
    final theme = pw.ThemeData.withFont(base: _fontRegular!, bold: _fontBold!);
    final signatureBytes = await SignatureService.load();
    final paymentWidget = (includePayment && profile != null)
        ? await _paymentSection(profile)
        : pw.SizedBox.shrink();

    const pageFormat = PdfPageFormat.a4;
    final usableWidth = pageFormat.width - 32;

    document.addPage(
      pw.Page(
        theme: theme,
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(16),
        build: (ctx) {
          final content = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Title centered with accent lines
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Container(height: 2, color: _c.primary),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                    child: pw.Text(
                      'TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: _vyTitleFontSize,
                        fontWeight: pw.FontWeight.bold,
                        color: _c.primary,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Container(height: 2, color: _c.primary),
                  ),
                ],
              ),
              pw.SizedBox(height: _vySectionSpacing),
              // Two-column: Seller | Bill-to + Invoice details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Seller
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: _c.labelBg,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'FROM',
                            style: pw.TextStyle(
                              fontSize: _vyBaseFontSize - 2,
                              fontWeight: pw.FontWeight.bold,
                              color: _c.primary,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          if (_logoImage != null) ...[
                            pw.Image(
                              _logoImage!,
                              width: 36,
                              height: 36,
                              fit: pw.BoxFit.contain,
                            ),
                            pw.SizedBox(height: 4),
                          ],
                          pw.Text(
                            _sellerName(profile, s),
                            style: pw.TextStyle(
                              fontSize: _vyBaseFontSize + 1,
                              fontWeight: pw.FontWeight.bold,
                              color: _c.body,
                            ),
                          ),
                          if (profile?.phoneNumber.isNotEmpty == true)
                            pw.Text(
                              profile!.phoneNumber,
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                          if (profile?.gstin.isNotEmpty == true)
                            pw.Text(
                              'GSTIN: ${profile!.gstin}',
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                          if (profile?.address.isNotEmpty == true)
                            pw.Text(
                              profile!.address,
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // Right: Bill-to + dates
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _c.border, width: 0.5),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILL TO',
                            style: pw.TextStyle(
                              fontSize: _vyBaseFontSize - 2,
                              fontWeight: pw.FontWeight.bold,
                              color: _c.primary,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            invoice.clientName,
                            style: pw.TextStyle(
                              fontSize: _vyBaseFontSize + 1,
                              fontWeight: pw.FontWeight.bold,
                              color: _c.body,
                            ),
                          ),
                          if (_client != null &&
                              _client!.phone.trim().isNotEmpty)
                            pw.Text(
                              'Ph: ${_client!.phone.trim()}',
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                          if (_client != null &&
                              _client!.email.trim().isNotEmpty)
                            pw.Text(
                              _client!.email.trim(),
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                          if (_client != null &&
                              _client!.address.trim().isNotEmpty)
                            pw.Text(
                              _client!.address.trim(),
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                          if (invoice.customerGstin.isNotEmpty)
                            pw.Text(
                              'GSTIN: ${invoice.customerGstin}',
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Inv: ${invoice.invoiceNumber}',
                            style: pw.TextStyle(
                              fontSize: _vyBaseFontSize - 1,
                              color: _c.body,
                            ),
                          ),
                          pw.Text(
                            'Date: ${_dateFormat.format(invoice.createdAt)}',
                            style: pw.TextStyle(
                              fontSize: _vyBaseFontSize - 1,
                              color: _c.muted,
                            ),
                          ),
                          if (invoice.dueDate != null)
                            pw.Text(
                              'Due: ${_dateFormat.format(invoice.dueDate!)}',
                              style: pw.TextStyle(
                                fontSize: _vyBaseFontSize - 1,
                                color: _c.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: _vySectionSpacing),
              _vyItemsTable(invoice, s),
              _vyTotalsBlock(invoice, s),
              pw.SizedBox(height: _vySectionSpacing),
              paymentWidget,
              pw.SizedBox(height: _vySectionSpacing),
              _vyTermsAndSignatureRow(profile, s, signatureBytes),
              pw.SizedBox(height: _vySectionSpacing),
              _vyFooter(ctx, s),
            ],
          );
          return pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.topLeft,
            child: pw.SizedBox(width: usableWidth, child: content),
          );
        },
      ),
    );
    return document.save();
  }

  /// Template 5: RECEIPT — Narrow receipt/thermal printer style
  Future<Uint8List> _buildReceiptPdf(
    Invoice invoice,
    BusinessProfile? profile,
    AppStrings s, {
    bool includePayment = true,
    _VyColors? colors,
  }) async {
    _c =
        colors ??
        _VyColors(
          _vyPrimary,
          _vyLabelBg,
          _vyBorder,
          _vyBlack,
          _vyBody,
          _vyMuted,
        );
    _computeAdaptiveSizing(invoice, false);

    final document = pw.Document(
      title: invoice.invoiceNumber,
      creator: 'BillRaja',
    );
    final theme = pw.ThemeData.withFont(base: _fontRegular!, bold: _fontBold!);

    // Receipt uses narrow page
    const pageFormat = PdfPageFormat(
      226.77,
      double.infinity,
      marginAll: 8,
    ); // ~80mm thermal width
    final fs = 7.0;

    pw.Widget dashedLine() => pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: List.generate(
          38,
          (_) => pw.Expanded(
            child: pw.Container(
              height: 0.5,
              color: _c.muted,
              margin: const pw.EdgeInsets.symmetric(horizontal: 1),
            ),
          ),
        ),
      ),
    );

    document.addPage(
      pw.Page(
        theme: theme,
        pageFormat: pageFormat,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Logo centered (small for receipt)
              if (_logoImage != null) ...[
                pw.Center(
                  child: pw.Image(
                    _logoImage!,
                    width: 36,
                    height: 36,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
              // Store name centered
              pw.Text(
                _sellerName(profile, s),
                style: pw.TextStyle(
                  fontSize: fs + 4,
                  fontWeight: pw.FontWeight.bold,
                  color: _c.body,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (profile?.phoneNumber.isNotEmpty == true)
                pw.Text(
                  profile!.phoneNumber,
                  style: pw.TextStyle(fontSize: fs, color: _c.muted),
                  textAlign: pw.TextAlign.center,
                ),
              if (profile?.address.isNotEmpty == true)
                pw.Text(
                  profile!.address,
                  style: pw.TextStyle(fontSize: fs - 1, color: _c.muted),
                  textAlign: pw.TextAlign.center,
                ),
              if (profile?.gstin.isNotEmpty == true)
                pw.Text(
                  'GSTIN: ${profile!.gstin}',
                  style: pw.TextStyle(fontSize: fs, color: _c.body),
                  textAlign: pw.TextAlign.center,
                ),
              dashedLine(),
              pw.Text(
                'TAX INVOICE',
                style: pw.TextStyle(
                  fontSize: fs + 2,
                  fontWeight: pw.FontWeight.bold,
                  color: _c.primary,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'No: ${invoice.invoiceNumber}',
                    style: pw.TextStyle(fontSize: fs, color: _c.body),
                  ),
                  pw.Text(
                    _dateFormat.format(invoice.createdAt),
                    style: pw.TextStyle(fontSize: fs, color: _c.muted),
                  ),
                ],
              ),
              dashedLine(),
              // Customer
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Customer: ${invoice.clientName}',
                  style: pw.TextStyle(
                    fontSize: fs,
                    fontWeight: pw.FontWeight.bold,
                    color: _c.body,
                  ),
                ),
              ),
              if (_client != null && _client!.phone.trim().isNotEmpty)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'Ph: ${_client!.phone.trim()}',
                    style: pw.TextStyle(fontSize: fs - 1, color: _c.muted),
                  ),
                ),
              if (_client != null && _client!.address.trim().isNotEmpty)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    _client!.address.trim(),
                    style: pw.TextStyle(fontSize: fs - 1, color: _c.muted),
                  ),
                ),
              if (invoice.customerGstin.isNotEmpty)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'GSTIN: ${invoice.customerGstin}',
                    style: pw.TextStyle(fontSize: fs - 1, color: _c.muted),
                  ),
                ),
              dashedLine(),
              // Items header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        fontSize: fs,
                        fontWeight: pw.FontWeight.bold,
                        color: _c.body,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(
                        fontSize: fs,
                        fontWeight: pw.FontWeight.bold,
                        color: _c.body,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Rate',
                      style: pw.TextStyle(
                        fontSize: fs,
                        fontWeight: pw.FontWeight.bold,
                        color: _c.body,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Amt',
                      style: pw.TextStyle(
                        fontSize: fs,
                        fontWeight: pw.FontWeight.bold,
                        color: _c.body,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              // Items
              ...invoice.items.expand(
                (item) => [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text(
                            item.description,
                            style: pw.TextStyle(fontSize: fs, color: _c.body),
                            maxLines: 1,
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            '${item.quantity}',
                            style: pw.TextStyle(fontSize: fs, color: _c.body),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            _fmt(item.unitPrice),
                            style: pw.TextStyle(fontSize: fs, color: _c.body),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            _fmt(item.total),
                            style: pw.TextStyle(fontSize: fs, color: _c.body),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.discountPercent > 0)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, bottom: 1),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '  Disc ${item.discountPercent.toStringAsFixed(item.discountPercent == item.discountPercent.truncateToDouble() ? 0 : 1)}%',
                            style: pw.TextStyle(
                              fontSize: fs - 1,
                              color: _c.muted,
                            ),
                          ),
                          pw.Text(
                            '- ${_fmt(item.discountAmount)}',
                            style: pw.TextStyle(
                              fontSize: fs - 1,
                              color: _c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (invoice.gstEnabled && item.gstRate > 0)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, bottom: 1),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '  GST ${item.gstRate.toStringAsFixed(item.gstRate == item.gstRate.truncateToDouble() ? 0 : 1)}%',
                            style: pw.TextStyle(
                              fontSize: fs - 1,
                              color: _c.muted,
                            ),
                          ),
                          pw.Text(
                            _fmt(item.gstAmount),
                            style: pw.TextStyle(
                              fontSize: fs - 1,
                              color: _c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              dashedLine(),
              // Totals
              _receiptTotalLine(
                'Sub Total',
                _fmt(
                  invoice.items.fold<double>(0, (sum, i) => sum + i.rawTotal),
                ),
                fs,
              ),
              if (invoice.items.any((i) => i.discountAmount > 0))
                _receiptTotalLine(
                  'Item Discounts',
                  '- ${_fmt(invoice.items.fold<double>(0, (sum, i) => sum + i.discountAmount))}',
                  fs,
                ),
              if (invoice.discountAmount > 0)
                _receiptTotalLine(
                  'Discount',
                  '- ${_fmt(invoice.discountAmount)}',
                  fs,
                ),
              if (invoice.items.any((i) => i.discountAmount > 0) ||
                  invoice.discountAmount > 0 ||
                  invoice.totalTax > 0)
                _receiptTotalLine(
                  'Taxable Amt',
                  _fmt(invoice.taxableAmount),
                  fs,
                ),
              if (invoice.gstEnabled) ...[
                if (invoice.gstType == 'cgst_sgst') ...[
                  _receiptTotalLine('CGST', _fmt(invoice.cgstAmount), fs),
                  _receiptTotalLine('SGST', _fmt(invoice.sgstAmount), fs),
                ] else
                  _receiptTotalLine('IGST', _fmt(invoice.igstAmount), fs),
              ],
              dashedLine(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'GRAND TOTAL',
                    style: pw.TextStyle(
                      fontSize: fs + 2,
                      fontWeight: pw.FontWeight.bold,
                      color: _c.primary,
                    ),
                  ),
                  pw.Text(
                    _fmt(invoice.grandTotal),
                    style: pw.TextStyle(
                      fontSize: fs + 2,
                      fontWeight: pw.FontWeight.bold,
                      color: _c.primary,
                    ),
                  ),
                ],
              ),
              if (invoice.amountReceived > 0) ...[
                pw.SizedBox(height: 2),
                _receiptTotalLine('Paid', _fmt(invoice.amountReceived), fs),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Balance Due',
                        style: pw.TextStyle(
                          fontSize: fs,
                          fontWeight: pw.FontWeight.bold,
                          color: invoice.balanceDue <= 0
                              ? PdfColor.fromHex('#059669')
                              : PdfColor.fromHex('#D97706'),
                        ),
                      ),
                      pw.Text(
                        _fmt(invoice.balanceDue),
                        style: pw.TextStyle(
                          fontSize: fs,
                          fontWeight: pw.FontWeight.bold,
                          color: invoice.balanceDue <= 0
                              ? PdfColor.fromHex('#059669')
                              : PdfColor.fromHex('#D97706'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              dashedLine(),
              if (invoice.dueDate != null)
                pw.Text(
                  'Due Date: ${_dateFormat.format(invoice.dueDate!)}',
                  style: pw.TextStyle(fontSize: fs, color: _c.muted),
                  textAlign: pw.TextAlign.center,
                ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(
                  fontSize: fs,
                  fontWeight: pw.FontWeight.bold,
                  color: _c.body,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated by BillRaja',
                style: pw.TextStyle(fontSize: fs - 1, color: _c.muted),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
    return document.save();
  }

  pw.Widget _receiptTotalLine(String label, String value, double fs) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: fs, color: _c.muted),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fs,
              fontWeight: pw.FontWeight.bold,
              color: _c.body,
            ),
          ),
        ],
      ),
    );
  }
}
