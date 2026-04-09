import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/analytics_models.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/purchase_order.dart';
import 'package:billeasy/services/analytics_service.dart';
import 'package:billeasy/screens/upgrade_screen.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/services/purchase_order_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/responsive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

// ─── Status colours (kept as semantic) ──────────────────────────────────────
const _kPaid = Color(0xFF22C55E);
const _kPaidBg = Color(0xFFDCFCE7);
const _kOverdue = Color(0xFFEF4444);
const _kOverdueBg = Color(0xFFFEE2E2);

// ─── Period enum ───────────────────────────────────────────────────────────────
enum _Period { monthly, quarterly, yearly, financialYear }

// ─── Tab enum ──────────────────────────────────────────────────────────────────
enum _GstTab { output, input, net, hsn, gstr3b, taxRate }

// ─── HSN aggregation model ────────────────────────────────────────────────────
class _HsnAggregate {
  _HsnAggregate(this.hsnCode);
  final String hsnCode;
  String description = '';
  String unit = '';
  double totalQuantity = 0;
  double taxableAmount = 0;
  double gstRate = 0;
  double cgstAmount = 0;
  double sgstAmount = 0;
  double igstAmount = 0;
  double totalTax = 0;
}

class GstReportScreen extends StatefulWidget {
  const GstReportScreen({super.key});

  @override
  State<GstReportScreen> createState() => _GstReportScreenState();
}

class _GstReportScreenState extends State<GstReportScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final FirebaseService _firebaseService = FirebaseService();
  final PurchaseOrderService _purchaseOrderService = PurchaseOrderService();
  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd MMM yyyy');

  _Period _selectedPeriod = _Period.monthly;
  int _selectedMonth = DateTime.now().month;
  int _selectedQuarter = ((DateTime.now().month - 1) ~/ 3) + 1;
  int _selectedYear = DateTime.now().year;
  late Stream<GstPeriodSummary?> _summaryStream;
  static const int _pageSize = 25;

  // Output (Sales) state
  final List<Invoice> _invoices = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _invoiceCursor;
  Object? _invoiceLoadError;
  bool _hasMoreInvoices = true;
  bool _isLoadingInvoices = false;
  bool _isLoadingMoreInvoices = false;
  bool _isSharingReport = false;
  int _loadGeneration = 0;

  // Input (Purchases) state — paginated like invoices
  final List<PurchaseOrder> _purchaseOrders = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _poCursor;
  bool _hasMorePOs = true;
  bool _isLoadingPurchaseOrders = false;
  bool _isLoadingMorePOs = false;
  Object? _poLoadError;

  // Tab state
  _GstTab _activeTab = _GstTab.output;
  StreamSubscription<AppPlan>? _planSub;

  @override
  void initState() {
    super.initState();
    _refreshSummaryStream();
    _loadInvoices(reset: true);
    _loadPurchaseOrders();
    _planSub = PlanService.instance.planStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _planSub?.cancel();
    super.dispose();
  }

  // ─── Date range helpers ──────────────────────────────────────────────────────

  DateTime get _startDate {
    switch (_selectedPeriod) {
      case _Period.monthly:
        return DateTime(_selectedYear, _selectedMonth, 1);
      case _Period.quarterly:
        final startMonth = (_selectedQuarter - 1) * 3 + 1;
        return DateTime(_selectedYear, startMonth, 1);
      case _Period.yearly:
        return DateTime(_selectedYear, 1, 1);
      case _Period.financialYear:
        // Indian Financial Year: April 1 of selected year
        return DateTime(_selectedYear, 4, 1);
    }
  }

  DateTime get _endDate {
    switch (_selectedPeriod) {
      case _Period.monthly:
        return DateTime(_selectedYear, _selectedMonth + 1, 1);
      case _Period.quarterly:
        final endMonth = _selectedQuarter * 3;
        if (endMonth == 12) {
          return DateTime(_selectedYear + 1, 1, 1);
        }
        return DateTime(_selectedYear, endMonth + 1, 1);
      case _Period.yearly:
        return DateTime(_selectedYear + 1, 1, 1);
      case _Period.financialYear:
        // Indian Financial Year: March 31 of next year (exclusive = April 1)
        return DateTime(_selectedYear + 1, 4, 1);
    }
  }

  String get _periodLabel {
    final start = _startDate;
    final end = _endDate.subtract(const Duration(days: 1));
    return '${_dateFormat.format(start)} – ${_dateFormat.format(end)}';
  }

  String get _summaryPeriodType {
    return switch (_selectedPeriod) {
      _Period.monthly => 'monthly',
      _Period.quarterly => 'quarterly',
      _Period.yearly => 'yearly',
      _Period.financialYear => 'financialYear',
    };
  }

  String get _summaryPeriodKey {
    return switch (_selectedPeriod) {
      _Period.monthly =>
        '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}',
      _Period.quarterly => '$_selectedYear-Q$_selectedQuarter',
      _Period.yearly => '$_selectedYear',
      _Period.financialYear => 'FY-$_selectedYear-${_selectedYear + 1}',
    };
  }

  void _refreshSummaryStream() {
    _summaryStream = _analyticsService.watchGstPeriodSummary(
      periodType: _summaryPeriodType,
      periodKey: _summaryPeriodKey,
    );
  }

  void _changePeriod(VoidCallback mutate) {
    setState(() {
      mutate();
      _refreshSummaryStream();
    });
    _loadInvoices(reset: true);
    _loadPurchaseOrders();
  }

  Future<void> _loadInvoices({required bool reset}) async {
    if (_isLoadingMoreInvoices) {
      return;
    }

    if (!reset && !_hasMoreInvoices) {
      return;
    }

    final generation = reset ? ++_loadGeneration : _loadGeneration;

    if (reset) {
      setState(() {
        _isLoadingInvoices = true;
        _isLoadingMoreInvoices = false;
        _invoiceLoadError = null;
        _hasMoreInvoices = true;
        _invoiceCursor = null;
      });
    } else {
      setState(() {
        _isLoadingMoreInvoices = true;
      });
    }

    try {
      final onlyMine = TeamService.instance.isTeamMember &&
          !TeamService.instance.can.canViewOthersInvoices;
      final page = await _firebaseService.getInvoicesPage(
        startDate: _startDate,
        endDateExclusive: _endDate,
        gstEnabled: true,
        createdByUid: onlyMine ? TeamService.instance.getActualUserId() : null,
        limit: _pageSize,
        startAfterDocument: reset ? null : _invoiceCursor,
      );

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        final pageItems = page.items
            .where((invoice) => invoice.hasGst)
            .toList();
        if (reset) {
          _invoices
            ..clear()
            ..addAll(pageItems);
        } else {
          _invoices.addAll(pageItems);
        }
        _invoiceCursor = page.cursor;
        _hasMoreInvoices = page.hasMore;
        _invoiceLoadError = null;
        _isLoadingInvoices = false;
        _isLoadingMoreInvoices = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      debugPrint('[GstReport] Invoice load error: $error\n$stackTrace');

      setState(() {
        _invoiceLoadError = error;
        _isLoadingInvoices = false;
        _isLoadingMoreInvoices = false;
        if (reset) {
          _invoices.clear();
        }
      });
    }
  }

  // ─── Load purchase orders (Input GST) ─────────────────────────────────────

  Future<void> _loadPurchaseOrders({bool reset = true}) async {
    if (_isLoadingMorePOs) return;
    if (!reset && !_hasMorePOs) return;

    if (reset) {
      setState(() {
        _isLoadingPurchaseOrders = true;
        _isLoadingMorePOs = false;
        _poLoadError = null;
        _hasMorePOs = true;
        _poCursor = null;
      });
    } else {
      setState(() => _isLoadingMorePOs = true);
    }

    try {
      // Respect team permissions: restricted members only see their own POs.
      final onlyMinePo = TeamService.instance.isTeamMember &&
          !TeamService.instance.can.canViewOthersInvoices;
      final page = await _purchaseOrderService.getPurchaseOrdersPage(
        startDate: _startDate,
        endDateExclusive: _endDate,
        status: PurchaseOrderStatus.received,
        gstEnabledOnly: true,
        createdByUid: onlyMinePo ? TeamService.instance.getActualUserId() : null,
        limit: _pageSize,
        startAfterDocument: reset ? null : _poCursor,
      );
      if (!mounted) return;

      setState(() {
        if (reset) {
          _purchaseOrders
            ..clear()
            ..addAll(page.items);
        } else {
          _purchaseOrders.addAll(page.items);
        }
        _poCursor = page.cursor;
        _hasMorePOs = page.hasMore;
        _poLoadError = null;
        _isLoadingPurchaseOrders = false;
        _isLoadingMorePOs = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('[GstReport] PO load error: $error\n$stackTrace');
      setState(() {
        _poLoadError = error;
        _isLoadingPurchaseOrders = false;
        _isLoadingMorePOs = false;
        if (reset) _purchaseOrders.clear();
      });
    }
  }

  // ─── Computed input GST fallback from loaded POs ──────────────────────────

  double get _fallbackInputTaxable =>
      _purchaseOrders.fold<double>(0, (acc, po) => acc + po.taxableAmount);
  double get _fallbackInputCgst =>
      _purchaseOrders.fold<double>(0, (acc, po) => acc + po.cgstAmount);
  double get _fallbackInputSgst =>
      _purchaseOrders.fold<double>(0, (acc, po) => acc + po.sgstAmount);
  double get _fallbackInputIgst =>
      _purchaseOrders.fold<double>(0, (acc, po) => acc + po.igstAmount);
  double get _fallbackInputTax =>
      _purchaseOrders.fold<double>(0, (acc, po) => acc + po.totalTax);

  // ─── Share/export ────────────────────────────────────────────────────────────

  /// PDF Summary — comprehensive totals, no individual invoices
  Future<void> _sharePdfSummary(List<Invoice> invoices) async {
    double totalTaxable = 0,
        totalCgst = 0,
        totalSgst = 0,
        totalIgst = 0,
        totalTax = 0,
        totalGrand = 0;
    for (final inv in invoices) {
      totalTaxable += inv.taxableAmount;
      totalCgst += inv.cgstAmount;
      totalSgst += inv.sgstAmount;
      totalIgst += inv.igstAmount;
      totalTax += inv.totalTax;
      totalGrand += inv.grandTotal;
    }

    double inputTaxable = 0,
        inputCgst = 0,
        inputSgst = 0,
        inputIgst = 0,
        inputTax = 0;
    for (final po in _purchaseOrders) {
      inputTaxable += po.taxableAmount;
      inputCgst += po.cgstAmount;
      inputSgst += po.sgstAmount;
      inputIgst += po.igstAmount;
      inputTax += po.totalTax;
    }
    final netPayable = totalTax - inputTax;

    final pdf = pw.Document();
    final headerStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
    final cellStyle = const pw.TextStyle(fontSize: 9);
    final fmt = _currencyFormat;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('GST Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(_periodLabel, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated by BillRaja', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (ctx) => [
          // ── Summary cards ──
          pw.Row(
            children: [
              _pdfSummaryBox('Output GST (Sales)', fmt.format(totalTax), '${invoices.length} Invoices'),
              pw.SizedBox(width: 16),
              _pdfSummaryBox('Input GST (Purchases)', fmt.format(inputTax), '${_purchaseOrders.length} POs'),
              pw.SizedBox(width: 16),
              _pdfSummaryBox(
                netPayable >= 0 ? 'Net GST Payable' : 'ITC Credit Available',
                fmt.format(netPayable.abs()),
                netPayable >= 0 ? 'Output - Input' : 'Carry forward',
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Output GST table ──
          pw.Text('Output GST — Invoice Breakdown', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: headerStyle,
            cellStyle: cellStyle,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            headers: ['Invoice #', 'Client', 'Date', 'Taxable', 'CGST', 'SGST', 'IGST', 'Total Tax', 'Grand Total'],
            data: [
              ...invoices.map((inv) => [
                inv.invoiceNumber,
                inv.clientName,
                _dateFormat.format(inv.createdAt),
                fmt.format(inv.taxableAmount),
                inv.gstType == 'igst' ? '-' : fmt.format(inv.cgstAmount),
                inv.gstType == 'igst' ? '-' : fmt.format(inv.sgstAmount),
                inv.gstType == 'igst' ? fmt.format(inv.igstAmount) : '-',
                fmt.format(inv.totalTax),
                fmt.format(inv.grandTotal),
              ]),
              // Total row
              ['TOTAL', '', '${invoices.length} inv', fmt.format(totalTaxable), fmt.format(totalCgst), fmt.format(totalSgst), fmt.format(totalIgst), fmt.format(totalTax), fmt.format(totalGrand)],
            ],
          ),

          if (_purchaseOrders.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Input GST — Purchase Order Breakdown', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              headers: ['PO #', 'Supplier', 'Date', 'Taxable', 'CGST', 'SGST', 'IGST', 'Total Tax', 'Grand Total'],
              data: [
                ..._purchaseOrders.map((po) => [
                  po.orderNumber,
                  po.supplierName,
                  _dateFormat.format(po.receivedAt ?? po.createdAt),
                  fmt.format(po.taxableAmount),
                  po.gstType == 'igst' ? '-' : fmt.format(po.cgstAmount),
                  po.gstType == 'igst' ? '-' : fmt.format(po.sgstAmount),
                  po.gstType == 'igst' ? fmt.format(po.igstAmount) : '-',
                  fmt.format(po.totalTax),
                  fmt.format(po.grandTotal),
                ]),
                ['TOTAL', '', '${_purchaseOrders.length} POs', fmt.format(inputTaxable), fmt.format(inputCgst), fmt.format(inputSgst), fmt.format(inputIgst), fmt.format(inputTax), ''],
              ],
            ),
          ],

          pw.SizedBox(height: 20),

          // ── Net liability summary ──
          pw.Text('Net GST Liability', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: headerStyle,
            cellStyle: cellStyle,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            headers: ['Component', 'Output (Sales)', 'Input (Purchases)', 'Net'],
            data: [
              ['Taxable Amount', fmt.format(totalTaxable), fmt.format(inputTaxable), fmt.format(totalTaxable - inputTaxable)],
              ['CGST', fmt.format(totalCgst), fmt.format(inputCgst), fmt.format(totalCgst - inputCgst)],
              ['SGST', fmt.format(totalSgst), fmt.format(inputSgst), fmt.format(totalSgst - inputSgst)],
              ['IGST', fmt.format(totalIgst), fmt.format(inputIgst), fmt.format(totalIgst - inputIgst)],
              ['Total Tax', fmt.format(totalTax), fmt.format(inputTax), fmt.format(netPayable)],
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      // On web: use printing package to show print/save dialog
      await Printing.sharePdf(bytes: bytes, filename: 'GST_Report_${_periodLabel.replaceAll(' ', '_')}.pdf');
    } else {
      final dir = await Directory.systemTemp.createTemp('gst_pdf');
      final file = File('${dir.path}/GST_Report_${_periodLabel.replaceAll(' ', '_')}.pdf');
      await file.writeAsBytes(bytes);
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'GST Report — $_periodLabel',
          ),
        );
      } finally {
        try {
          if (await dir.exists()) await dir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  pw.Expanded _pdfSummaryBox(String title, String value, String subtitle) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(subtitle, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ),
    );
  }

  /// CSV export — all invoices with full GST breakdown
  /// RFC 4180-compliant CSV field escaping:
  /// wraps in double quotes, escapes internal quotes by doubling them.
  static String _csvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  /// CSV export — all invoices with full GST breakdown (RFC 4180 compliant)
  Future<void> _shareCsv(List<Invoice> invoices) async {
    final buf = StringBuffer();
    // UTF-8 BOM for Excel compatibility
    buf.write('\uFEFF');

    // Header
    buf.writeln(
      'Invoice No,Date,Customer,GSTIN,B2B/B2C,Taxable Amount,CGST,SGST,IGST,Total Tax,Grand Total,Status,GST Type,GST Rate',
    );

    // Data rows
    for (final inv in invoices) {
      final date = _dateFormat.format(inv.createdAt);
      final b2bType = inv.customerGstin.isNotEmpty ? 'B2B' : 'B2C';
      buf.writeln(
        '${_csvField(inv.invoiceNumber)},$date,${_csvField(inv.clientName)},${_csvField(inv.customerGstin)},$b2bType,'
        '${inv.taxableAmount.toStringAsFixed(2)},'
        '${inv.cgstAmount.toStringAsFixed(2)},'
        '${inv.sgstAmount.toStringAsFixed(2)},'
        '${inv.igstAmount.toStringAsFixed(2)},'
        '${inv.totalTax.toStringAsFixed(2)},'
        '${inv.grandTotal.toStringAsFixed(2)},'
        '${inv.status.name},'
        '${inv.gstType},'
        '${inv.gstRate}',
      );
    }

    // Add PO rows if any
    if (_purchaseOrders.isNotEmpty) {
      buf.writeln();
      buf.writeln('Purchase Orders');
      buf.writeln(
        'PO No,Date,Supplier,Taxable Amount,CGST,SGST,IGST,Total Tax,Grand Total,GST Type',
      );
      for (final po in _purchaseOrders) {
        final date = _dateFormat.format(po.createdAt);
        buf.writeln(
          '${_csvField(po.orderNumber)},$date,${_csvField(po.supplierName)},'
          '${po.taxableAmount.toStringAsFixed(2)},'
          '${po.cgstAmount.toStringAsFixed(2)},'
          '${po.sgstAmount.toStringAsFixed(2)},'
          '${po.igstAmount.toStringAsFixed(2)},'
          '${po.totalTax.toStringAsFixed(2)},'
          '${po.grandTotal.toStringAsFixed(2)},'
          '${po.gstType}',
        );
      }
    }

    // Summary at bottom
    double totalTaxable = 0, totalTax = 0, totalGrand = 0;
    for (final inv in invoices) {
      totalTaxable += inv.taxableAmount;
      totalTax += inv.totalTax;
      totalGrand += inv.grandTotal;
    }
    buf.writeln();
    buf.writeln(
      'TOTALS,,,,,${totalTaxable.toStringAsFixed(2)},,,,'
      '${totalTax.toStringAsFixed(2)},${totalGrand.toStringAsFixed(2)}',
    );

    // Write to temp file and share
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'File export is not available on web. Use the mobile app to export reports.',
            ),
          ),
        );
      }
      return;
    }
    final dir = await Directory.systemTemp.createTemp('gst_report');
    final file = File(
      '${dir.path}/GST_Report_${_periodLabel.replaceAll(' ', '_')}.csv',
    );
    await file.writeAsString(buf.toString());

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'GST Report — $_periodLabel',
        ),
      );
    } finally {
      // Clean up temp file after sharing
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _shareFullReport(AppStrings s) async {
    if (_isSharingReport) return;

    // Show format choice
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.gstReportExportTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFFE53935),
                  size: 28,
                ),
                title: Text(
                  s.gstReportPdfSummary,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  s.gstReportPdfSubtitle,
                  style: const TextStyle(fontSize: 12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: const Color(0xFFFFF5F5),
                onTap: () => Navigator.pop(ctx, 'pdf'),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(
                  Icons.table_chart,
                  color: Color(0xFF2E7D32),
                  size: 28,
                ),
                title: Text(
                  s.gstReportCsvAll,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  s.gstReportCsvSubtitle,
                  style: const TextStyle(fontSize: 12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: const Color(0xFFF0FDF4),
                onTap: () => Navigator.pop(ctx, 'csv'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    setState(() => _isSharingReport = true);

    try {
      final onlyMineExport = TeamService.instance.isTeamMember &&
          !TeamService.instance.can.canViewOthersInvoices;
      final invoices = await _firebaseService.getAllInvoices(
        startDate: _startDate,
        endDateExclusive: _endDate,
        gstEnabled: true,
        createdByUid: onlyMineExport ? TeamService.instance.getActualUserId() : null,
      );

      if (!mounted) return;

      final gstInvoices = invoices.where((invoice) => invoice.hasGst).toList();
      if (gstInvoices.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.gstReportNoInvoices)));
        return;
      }

      if (choice == 'csv') {
        _shareCsv(gstInvoices);
      } else {
        _sharePdfSummary(gstInvoices);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.gstReportPrepareError(error.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingReport = false;
        });
      }
    }
  }

  // ─── Build helpers ───────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kPrimary,
                letterSpacing: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 6 : 9,
        ),
        decoration: BoxDecoration(
          color: selected ? kPrimary : context.cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _periodSelectorCard(AppStrings s) {
    final now = DateTime.now();
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Available months for selected year
    final maxMonth = (_selectedYear == now.year) ? now.month : 12;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period type row
          Row(
            children: [
              Expanded(
                child: _chip(
                  label: s.gstReportMonthly,
                  selected: _selectedPeriod == _Period.monthly,
                  onTap: () =>
                      _changePeriod(() => _selectedPeriod = _Period.monthly),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _chip(
                  label: s.gstReportQuarterly,
                  selected: _selectedPeriod == _Period.quarterly,
                  onTap: () =>
                      _changePeriod(() => _selectedPeriod = _Period.quarterly),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _chip(
                  label: s.gstReportYearly,
                  selected: _selectedPeriod == _Period.yearly,
                  onTap: () =>
                      _changePeriod(() => _selectedPeriod = _Period.yearly),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _chip(
                  label: 'FY',
                  selected: _selectedPeriod == _Period.financialYear,
                  onTap: () => _changePeriod(
                      () => _selectedPeriod = _Period.financialYear),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Sub-selector
          if (_selectedPeriod == _Period.monthly)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(maxMonth, (i) {
                final month = i + 1;
                return _chip(
                  label: monthNames[i],
                  selected: _selectedMonth == month,
                  compact: true,
                  onTap: () => _changePeriod(() => _selectedMonth = month),
                );
              }),
            )
          else if (_selectedPeriod == _Period.quarterly)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(
                  label: 'Q1 (Jan–Mar)',
                  selected: _selectedQuarter == 1,
                  compact: true,
                  onTap: () => _changePeriod(() => _selectedQuarter = 1),
                ),
                _chip(
                  label: 'Q2 (Apr–Jun)',
                  selected: _selectedQuarter == 2,
                  compact: true,
                  onTap: () => _changePeriod(() => _selectedQuarter = 2),
                ),
                _chip(
                  label: 'Q3 (Jul–Sep)',
                  selected: _selectedQuarter == 3,
                  compact: true,
                  onTap: () => _changePeriod(() => _selectedQuarter = 3),
                ),
                _chip(
                  label: 'Q4 (Oct–Dec)',
                  selected: _selectedQuarter == 4,
                  compact: true,
                  onTap: () => _changePeriod(() => _selectedQuarter = 4),
                ),
              ],
            )
          else if (_selectedPeriod == _Period.financialYear)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(
                  label: 'FY ${now.year - 2}–${now.year - 1}',
                  selected: _selectedYear == now.year - 2,
                  compact: true,
                  onTap: () =>
                      _changePeriod(() => _selectedYear = now.year - 2),
                ),
                _chip(
                  label: 'FY ${now.year - 1}–${now.year}',
                  selected: _selectedYear == now.year - 1,
                  compact: true,
                  onTap: () =>
                      _changePeriod(() => _selectedYear = now.year - 1),
                ),
                _chip(
                  label: 'FY ${now.year}–${now.year + 1}',
                  selected: _selectedYear == now.year,
                  compact: true,
                  onTap: () => _changePeriod(() => _selectedYear = now.year),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(
                  label: '${now.year - 2}',
                  selected: _selectedYear == now.year - 2,
                  compact: true,
                  onTap: () =>
                      _changePeriod(() => _selectedYear = now.year - 2),
                ),
                _chip(
                  label: '${now.year - 1}',
                  selected: _selectedYear == now.year - 1,
                  compact: true,
                  onTap: () =>
                      _changePeriod(() => _selectedYear = now.year - 1),
                ),
                _chip(
                  label: '${now.year}',
                  selected: _selectedYear == now.year,
                  compact: true,
                  onTap: () => _changePeriod(() => _selectedYear = now.year),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // Period range label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range_rounded, size: 14, color: kPrimary),
                const SizedBox(width: 6),
                Text(
                  _periodLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _netGstBanner({
    required AppStrings s,
    required double outputTax,
    required double inputTax,
    required int invoiceCount,
    required int poCount,
  }) {
    final netPayable = outputTax - inputTax;
    final isCredit = netPayable < 0;
    final gradient = isCredit
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF16A34A), Color(0xFF15803D)],
          )
        : kSignatureGradient;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [kWhisperShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.gstReportNetGstPayable,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currencyFormat.format(netPayable.abs()),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCredit
                        ? s.gstReportItcCreditAvailable
                        : s.gstReportOutputMinusInput,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _bannerBadge('$invoiceCount Invoices'),
                      const SizedBox(width: 8),
                      _bannerBadge('$poCount POs'),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCredit
                    ? Icons.arrow_downward_rounded
                    : Icons.account_balance_wallet_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _tabBar(AppStrings s) {
    final tabs = [
      _tabItem(s.gstTabOutput, _GstTab.output),
      _tabItem(s.gstTabInput, _GstTab.input),
      _tabItem(s.gstTabNet, _GstTab.net),
      _tabItem('HSN', _GstTab.hsn),
      _tabItem('GSTR-3B', _GstTab.gstr3b),
      _tabItem(s.gstTabTaxRate, _GstTab.taxRate),
    ];
    final expanded = windowSizeOf(context) != WindowSize.compact;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: expanded
          ? Wrap(spacing: 4, runSpacing: 4, children: tabs)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: tabs),
            ),
    );
  }

  Widget _tabItem(String label, _GstTab tab) {
    final selected = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? context.cs.surfaceContainerLowest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected ? const [kSubtleShadow] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? kPrimary : context.cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(InvoiceStatus status) {
    final s = AppStrings.of(context);
    Color fg, bg;
    String label;
    switch (status) {
      case InvoiceStatus.paid:
        fg = _kPaid;
        bg = _kPaidBg;
        label = s.statusPaid;
      case InvoiceStatus.pending:
        fg = const Color(0xFFEF4444);
        bg = const Color(0xFFFEE2E2);
        label = s.gstStatusUnpaid;
      case InvoiceStatus.overdue:
        fg = _kOverdue;
        bg = _kOverdueBg;
        label = s.statusOverdue;
      case InvoiceStatus.partiallyPaid:
        fg = const Color(0xFFEAB308);
        bg = const Color(0xFFFEF3C7);
        label = s.gstStatusPartial;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _gstRateBadge(double rate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.cs.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1)}% GST',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kPrimary,
        ),
      ),
    );
  }

  Widget _invoiceCard(Invoice inv) {
    final s = AppStrings.of(context);
    final isIgst = inv.gstType == 'igst';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [kSubtleShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inv.clientName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.cs.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  _dateFormat.format(inv.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Amount rows
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _amountRow(
                    s.gstLabelTaxable,
                    inv.taxableAmount,
                    context.cs.onSurface,
                  ),
                  if (isIgst) ...[
                    const SizedBox(height: 4),
                    _amountRow('IGST', inv.igstAmount, kPrimary),
                  ] else ...[
                    const SizedBox(height: 4),
                    _amountRow('CGST', inv.cgstAmount, kPrimary),
                    const SizedBox(height: 4),
                    _amountRow('SGST', inv.sgstAmount, kPrimary),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(
                      height: 1,
                      color: context.cs.surfaceContainerHighest,
                    ),
                  ),
                  _amountRow(
                    s.gstLabelTotalTax,
                    inv.totalTax,
                    context.cs.onSurface,
                    bold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Badges row
            Row(
              children: [
                _statusBadge(inv.effectiveStatus),
                const SizedBox(width: 8),
                _gstRateBadge(inv.gstRate),
                const Spacer(),
                Text(
                  isIgst ? 'Interstate' : 'Intrastate',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _purchaseOrderCard(PurchaseOrder po) {
    final s = AppStrings.of(context);
    final isIgst = po.gstType == 'igst';
    final receivedDate = po.receivedAt ?? po.createdAt;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [kSubtleShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        po.orderNumber,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        po.supplierName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.cs.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  _dateFormat.format(receivedDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Amount rows
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _amountRow(
                    s.gstLabelTaxable,
                    po.taxableAmount,
                    context.cs.onSurface,
                  ),
                  if (isIgst) ...[
                    const SizedBox(height: 4),
                    _amountRow('IGST', po.igstAmount, kPrimary),
                  ] else ...[
                    const SizedBox(height: 4),
                    _amountRow('CGST', po.cgstAmount, kPrimary),
                    const SizedBox(height: 4),
                    _amountRow('SGST', po.sgstAmount, kPrimary),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(
                      height: 1,
                      color: context.cs.surfaceContainerHighest,
                    ),
                  ),
                  _amountRow(
                    s.gstLabelTotalTax,
                    po.totalTax,
                    context.cs.onSurface,
                    bold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Badges row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _kPaidBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.gstStatusReceived,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kPaid,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _gstRateBadge(po.gstRate),
                const Spacer(),
                Text(
                  isIgst ? 'Interstate' : 'Intrastate',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(
    String label,
    double value,
    Color valueColor, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: context.cs.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          _currencyFormat.format(value),
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(AppStrings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: context.cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              s.gstReportNoInvoices,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _periodLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _poEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 36,
                color: context.cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.of(context).gstReportNoPurchaseOrders,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _periodLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Net Summary tab ──────────────────────────────────────────────────────

  Widget _netSummaryTab({
    required double outputTaxable,
    required double outputCgst,
    required double outputSgst,
    required double outputIgst,
    required double outputTax,
    required double inputTaxable,
    required double inputCgst,
    required double inputSgst,
    required double inputIgst,
    required double inputTax,
  }) {
    final netPayable = outputTax - inputTax;
    final expanded = windowSizeOf(context) == WindowSize.expanded;

    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Desktop: single DataTable ────────────────────────────
          if (expanded) ...[
            Container(
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [kSubtleShadow],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(context.cs.surfaceContainerLow),
                  columnSpacing: 24,
                  horizontalMargin: 16,
                  columns: [
                    DataColumn(label: Text('Component', style: _dtHeader)),
                    DataColumn(label: Text('Output (Sales)', style: _dtHeader), numeric: true),
                    DataColumn(label: Text('Input (Purchases)', style: _dtHeader), numeric: true),
                    DataColumn(label: Text('Net', style: _dtHeader), numeric: true),
                  ],
                  rows: [
                    _netDataRow(s.gstLabelTaxableAmount, outputTaxable, inputTaxable),
                    _netDataRow('CGST', outputCgst, inputCgst),
                    _netDataRow('SGST', outputSgst, inputSgst),
                    _netDataRow('IGST', outputIgst, inputIgst),
                    _netDataRow(s.gstLabelTotalTax, outputTax, inputTax, bold: true),
                  ],
                ),
              ),
            ),
          ] else ...[
          _comparisonTable(
            title: s.gstLabelTaxableAmount,
            outputValue: outputTaxable,
            inputValue: inputTaxable,
          ),
          const SizedBox(height: 10),
          _comparisonTable(
            title: 'CGST',
            outputValue: outputCgst,
            inputValue: inputCgst,
          ),
          const SizedBox(height: 10),
          _comparisonTable(
            title: 'SGST',
            outputValue: outputSgst,
            inputValue: inputSgst,
          ),
          const SizedBox(height: 10),
          _comparisonTable(
            title: 'IGST',
            outputValue: outputIgst,
            inputValue: inputIgst,
          ),
          const SizedBox(height: 10),
          _comparisonTable(
            title: s.gstLabelTotalTax,
            outputValue: outputTax,
            inputValue: inputTax,
            highlight: true,
          ),
          ],
          const SizedBox(height: 16),
          // Net payable row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: netPayable >= 0
                  ? kPrimary.withValues(alpha: 0.08)
                  : const Color(0xFF16A34A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: netPayable >= 0
                    ? kPrimary.withValues(alpha: 0.2)
                    : const Color(0xFF16A34A).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        netPayable >= 0
                            ? s.gstReportNetGstPayable
                            : s.gstReportNetItcCredit,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: netPayable >= 0
                              ? kPrimary
                              : const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.gstReportOutputMinusInput,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _currencyFormat.format(netPayable.abs()),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: netPayable >= 0 ? kPrimary : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _comparisonTable({
    required String title,
    required double outputValue,
    required double inputValue,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? context.cs.surfaceContainerLow
            : context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
              color: context.cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.of(context).gstReportOutputSales,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currencyFormat.format(outputValue),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: highlight
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: kPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: context.cs.surfaceContainerHighest,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.of(context).gstReportInputPurchases,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(inputValue),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: highlight
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Main build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    if (!PlanService.instance.hasReports) {
      return Scaffold(
        backgroundColor: context.cs.surface,
        appBar: AppBar(
          title: const Text('GST Report'),
          backgroundColor: context.cs.surface,
          foregroundColor: context.cs.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: context.cs.surfaceContainerHighest,
                ),
                const SizedBox(height: 16),
                Text(
                  'GST Reports',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This feature is currently unavailable. Please check back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const UpgradeScreen(featureName: 'GST Reports'),
                    ),
                  ),
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('View Plans'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.cs.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final invoices = _invoices;
    final purchaseOrders = _purchaseOrders;
    final loading = _isLoadingInvoices && invoices.isEmpty;

    // Output fallbacks
    final fallbackTaxable = invoices.fold<double>(
      0,
      (acc, i) => acc + i.taxableAmount,
    );
    final fallbackCgst = invoices.fold<double>(
      0,
      (acc, i) => acc + i.cgstAmount,
    );
    final fallbackSgst = invoices.fold<double>(
      0,
      (acc, i) => acc + i.sgstAmount,
    );
    final fallbackIgst = invoices.fold<double>(
      0,
      (acc, i) => acc + i.igstAmount,
    );
    final fallbackTax = invoices.fold<double>(0, (acc, i) => acc + i.totalTax);

    return StreamBuilder<GstPeriodSummary?>(
      stream: _summaryStream,
      builder: (context, summarySnapshot) {
        final summary = summarySnapshot.data;

        // Output GST values
        final totalTaxable = summary?.taxableAmount ?? fallbackTaxable;
        final totalCgst = summary?.cgstAmount ?? fallbackCgst;
        final totalSgst = summary?.sgstAmount ?? fallbackSgst;
        final totalIgst = summary?.igstAmount ?? fallbackIgst;
        final totalTax = summary?.totalTax ?? fallbackTax;
        final invoiceCount = summary?.invoiceCount ?? invoices.length;

        // Input GST values (from summary or fallback from loaded POs)
        final inputTaxable =
            summary?.inputTaxableAmount ?? _fallbackInputTaxable;
        final inputCgst = summary?.inputCgstAmount ?? _fallbackInputCgst;
        final inputSgst = summary?.inputSgstAmount ?? _fallbackInputSgst;
        final inputIgst = summary?.inputIgstAmount ?? _fallbackInputIgst;
        final inputTax = summary?.inputTotalTax ?? _fallbackInputTax;
        final poCount = summary?.inputPoCount ?? purchaseOrders.length;

        // GSTR-3B intra/inter breakdown (prefer summary, fallback to local)
        double fallbackIntraTaxable = 0,
            fallbackInterTaxable = 0;
        double fallbackIntraCgst = 0,
            fallbackIntraSgst = 0,
            fallbackInterIgst = 0;
        for (final inv in _invoices) {
          if (inv.gstType == 'igst') {
            fallbackInterIgst += inv.igstAmount;
            fallbackInterTaxable += inv.taxableAmount;
          } else {
            fallbackIntraCgst += inv.cgstAmount;
            fallbackIntraSgst += inv.sgstAmount;
            fallbackIntraTaxable += inv.taxableAmount;
          }
        }
        final gstr3bIntraTaxable =
            summary?.intraTaxableAmount ?? fallbackIntraTaxable;
        final gstr3bInterTaxable =
            summary?.interTaxableAmount ?? fallbackInterTaxable;
        final gstr3bIntraCgst = summary?.intraCgst ?? fallbackIntraCgst;
        final gstr3bIntraSgst = summary?.intraSgst ?? fallbackIntraSgst;
        final gstr3bInterIgst = summary?.interIgst ?? fallbackInterIgst;

        // Net
        final netPayable = totalTax - inputTax;

        // Drift detection: compare summary count vs loaded invoice count
        // Only meaningful for owners (non-restricted users) who see all data
        final isOwnerView = !TeamService.instance.isTeamMember ||
            TeamService.instance.can.canViewOthersInvoices;
        final hasDrift = isOwnerView &&
            summary != null &&
            !_hasMoreInvoices &&
            !_isLoadingInvoices &&
            (summary.invoiceCount - invoices.length).abs() > 0;

        return Scaffold(
          backgroundColor: context.cs.surface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: context.cs.surface,
            foregroundColor: context.cs.onSurface,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              s.gstReportTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
            ),
            centerTitle: false,
            iconTheme: IconThemeData(color: context.cs.onSurface),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kWebContentMaxWidth),
              child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _periodSelectorCard(s)),
                    if (loading)
                      const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(kPrimary),
                          ),
                        ),
                      )
                    else if (_invoiceLoadError != null && invoices.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              s.gstReportLoadError,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _kOverdue),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            _netGstBanner(
                              s: s,
                              outputTax: totalTax,
                              inputTax: inputTax,
                              invoiceCount: invoiceCount,
                              poCount: poCount,
                            ),
                            _sectionLabel(s.gstReportOverview),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: LayoutBuilder(builder: (context, constraints) {
                                final size = windowSizeOf(context);
                                final cols = size == WindowSize.expanded ? 4 : size == WindowSize.medium ? 3 : 2;
                                final ratio = size == WindowSize.expanded ? 2.0 : size == WindowSize.medium ? 1.8 : 1.55;
                                return GridView.count(
                                crossAxisCount: cols,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: ratio,
                                children: [
                                  _summaryCard(
                                    label: s.gstReportOutputGstSales,
                                    value: _currencyFormat.format(totalTax),
                                    color: kPrimary,
                                    icon: Icons.arrow_upward_rounded,
                                  ),
                                  _summaryCard(
                                    label: s.gstReportInputGstPurchases,
                                    value: _currencyFormat.format(inputTax),
                                    color: const Color(0xFF16A34A),
                                    icon: Icons.arrow_downward_rounded,
                                  ),
                                  _summaryCard(
                                    label: netPayable >= 0
                                        ? s.gstReportNetPayable
                                        : s.gstReportNetCredit,
                                    value: _currencyFormat.format(
                                      netPayable.abs(),
                                    ),
                                    color: netPayable >= 0
                                        ? context.cs.onSurface
                                        : const Color(0xFF16A34A),
                                    icon: Icons.account_balance_rounded,
                                  ),
                                  _summaryCard(
                                    label: 'Invoices / POs',
                                    value: '$invoiceCount / $poCount',
                                    color: context.cs.onSurface,
                                    icon: Icons.description_outlined,
                                  ),
                                ],
                              );
                              }),
                            ),
                            // Team-member note: summary includes all team data
                            if (TeamService.instance.isTeamMember &&
                                !TeamService.instance.can.canViewOthersInvoices)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.amber.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 15,
                                        color: Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          s.gstReportTeamSummaryNote,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Drift warning
                            if (hasDrift)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.orange.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.sync_problem_rounded,
                                        size: 15,
                                        color: Colors.orange.shade800,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          s.gstReportDriftWarning,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Tab bar
                            _tabBar(s),
                            const SizedBox(height: 8),
                            // Tab content
                            if (_activeTab == _GstTab.output)
                              _buildOutputTab(s, invoices)
                            else if (_activeTab == _GstTab.input)
                              _buildInputTab()
                            else if (_activeTab == _GstTab.hsn)
                              _buildHsnTab(invoices)
                            else if (_activeTab == _GstTab.gstr3b)
                              _buildGstr3bTab(
                                outputTaxable: totalTaxable,
                                outputCgst: totalCgst,
                                outputSgst: totalSgst,
                                outputIgst: totalIgst,
                                outputTax: totalTax,
                                inputTaxable: inputTaxable,
                                inputCgst: inputCgst,
                                inputSgst: inputSgst,
                                inputIgst: inputIgst,
                                inputTax: inputTax,
                                invoiceCount: invoiceCount,
                                poCount: poCount,
                                intraTaxable: gstr3bIntraTaxable,
                                interTaxable: gstr3bInterTaxable,
                                intraCgst: gstr3bIntraCgst,
                                intraSgst: gstr3bIntraSgst,
                                interIgst: gstr3bInterIgst,
                              )
                            else if (_activeTab == _GstTab.taxRate)
                              _buildTaxRateTab(invoices)
                            else
                              _netSummaryTab(
                                outputTaxable: totalTaxable,
                                outputCgst: totalCgst,
                                outputSgst: totalSgst,
                                outputIgst: totalIgst,
                                outputTax: totalTax,
                                inputTaxable: inputTaxable,
                                inputCgst: inputCgst,
                                inputSgst: inputSgst,
                                inputIgst: inputIgst,
                                inputTax: inputTax,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: GestureDetector(
                onTap: invoices.isEmpty || _isSharingReport
                    ? null
                    : () => _shareFullReport(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: invoices.isEmpty || _isSharingReport
                        ? null
                        : kSignatureGradient,
                    color: invoices.isEmpty || _isSharingReport
                        ? context.cs.surfaceContainerHighest
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: invoices.isEmpty || _isSharingReport
                        ? null
                        : const [kWhisperShadow],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSharingReport)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.share_rounded,
                          size: 20,
                          color: invoices.isEmpty
                              ? context.cs.onSurfaceVariant
                              : Colors.white,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        s.gstReportShareReport,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: invoices.isEmpty || _isSharingReport
                              ? context.cs.onSurfaceVariant
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── HSN Summary tab content ─────────────────────────────────────────────

  Widget _buildHsnTab(List<Invoice> invoices) {
    // Aggregate line items by HSN code
    final hsnMap = <String, _HsnAggregate>{};
    for (final inv in invoices) {
      // Discount ratio: proportion of subtotal that is taxable (post-discount).
      // GST law requires tax on post-discount amount, not on item.total directly.
      final discountRatio =
          inv.subtotal > 0 ? inv.taxableAmount / inv.subtotal : 1.0;
      for (final item in inv.items) {
        final code = item.hsnCode.trim().isEmpty
            ? AppStrings.of(context).gstNoHsn
            : item.hsnCode.trim();
        final agg = hsnMap.putIfAbsent(code, () => _HsnAggregate(code));
        agg.description = item.description;
        agg.totalQuantity += item.quantity;
        agg.unit = item.unit.isNotEmpty ? item.unit : agg.unit;
        // Use post-discount taxable amount per item
        final itemTaxable = item.total * discountRatio;
        agg.taxableAmount += itemTaxable;
        final itemGstRate = item.gstRate > 0 ? item.gstRate : inv.gstRate;
        agg.gstRate = itemGstRate;
        final isIgst = inv.gstType == 'igst';
        final tax = itemTaxable * itemGstRate / 100;
        if (isIgst) {
          agg.igstAmount += tax;
        } else {
          agg.cgstAmount += tax / 2;
          agg.sgstAmount += tax / 2;
        }
        agg.totalTax += tax;
      }
    }

    final hsnList = hsnMap.values.toList()
      ..sort((a, b) => b.taxableAmount.compareTo(a.taxableAmount));

    if (hsnList.isEmpty) {
      return _emptyState(AppStrings.of(context));
    }

    final totalTaxable = hsnList.fold<double>(0, (s, h) => s + h.taxableAmount);
    final totalTax = hsnList.fold<double>(0, (s, h) => s + h.totalTax);

    final expanded = windowSizeOf(context) == WindowSize.expanded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Summary row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: kPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.of(context).gstHsnFilingNote(hsnList.length),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Desktop: DataTable ───────────────────────────────────
          if (expanded) ...[
            Container(
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [kSubtleShadow],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(context.cs.surfaceContainerLow),
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    columns: [
                      DataColumn(label: Text('HSN Code', style: _dtHeader)),
                      DataColumn(label: Text('Description', style: _dtHeader)),
                      DataColumn(label: Text('Qty', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('UOM', style: _dtHeader)),
                      DataColumn(label: Text('Rate', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('Taxable', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('CGST', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('SGST', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('IGST', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('Total Tax', style: _dtHeader), numeric: true),
                    ],
                    rows: [
                      ...hsnList.map((h) => DataRow(cells: [
                        DataCell(Text(h.hsnCode, style: _dtBold)),
                        DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(h.description, style: _dtCell, overflow: TextOverflow.ellipsis))),
                        DataCell(Text(h.totalQuantity.toStringAsFixed(h.totalQuantity.truncateToDouble() == h.totalQuantity ? 0 : 2), style: _dtCell)),
                        DataCell(Text(h.unit.isNotEmpty ? h.unit : '-', style: _dtCell)),
                        DataCell(Text('${h.gstRate.toStringAsFixed(h.gstRate.truncateToDouble() == h.gstRate ? 0 : 1)}%', style: _dtCell)),
                        DataCell(Text(_currencyFormat.format(h.taxableAmount), style: _dtCell)),
                        DataCell(Text(_currencyFormat.format(h.cgstAmount), style: _dtCell)),
                        DataCell(Text(_currencyFormat.format(h.sgstAmount), style: _dtCell)),
                        DataCell(Text(_currencyFormat.format(h.igstAmount), style: _dtCell)),
                        DataCell(Text(_currencyFormat.format(h.totalTax), style: _dtBold)),
                      ])),
                      // Total row
                      DataRow(
                        color: WidgetStateProperty.all(context.cs.surfaceContainerLow),
                        cells: [
                          DataCell(Text('TOTAL', style: _dtBold)),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          DataCell(Text(_currencyFormat.format(totalTaxable), style: _dtBold)),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          DataCell(Text(_currencyFormat.format(totalTax), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 90),
          ] else ...[

          // ── Mobile: custom row layout ────────────────────────────
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    AppStrings.of(context).gstHsnCode,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    AppStrings.of(context).gstLabelTaxable,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    AppStrings.of(context).gstLabelTax,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // HSN rows
          Container(
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerLowest,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              children: [
                ...hsnList.asMap().entries.map((entry) {
                  final i = entry.key;
                  final h = entry.value;
                  return Column(
                    children: [
                      _hsnRow(h),
                      if (i < hsnList.length - 1)
                        Container(
                          height: 1,
                          color: context.cs.surfaceContainerLow,
                          margin: EdgeInsets.symmetric(horizontal: 12),
                        ),
                    ],
                  );
                }),
                // Total row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.cs.surfaceContainerLow,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          AppStrings.of(context).gstLabelTotal.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currencyFormat.format(totalTaxable),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currencyFormat.format(totalTax),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: kPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Detailed breakdown cards
          const SizedBox(height: 20),
          _sectionLabel(AppStrings.of(context).gstDetailedBreakdown),
          ...hsnList.map((h) => _hsnDetailCard(h)),
          const SizedBox(height: 90),
          ],
        ],
      ),
    );
  }

  Widget _hsnRow(_HsnAggregate h) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.hsnCode,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
                Text(
                  h.description,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format(h.taxableAmount),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format(h.totalTax),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hsnDetailCard(_HsnAggregate h) {
    final s = AppStrings.of(context);
    final isIgst = h.igstAmount > 0 && h.cgstAmount == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  h.hsnCode,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _gstRateBadge(h.gstRate),
              const Spacer(),
              Text(
                '${_formatQty(h.totalQuantity)}${h.unit.isNotEmpty ? ' ${h.unit}' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            h.description,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _amountRow(
                  s.gstLabelTaxable,
                  h.taxableAmount,
                  context.cs.onSurface,
                ),
                if (isIgst) ...[
                  const SizedBox(height: 4),
                  _amountRow('IGST', h.igstAmount, kPrimary),
                ] else ...[
                  const SizedBox(height: 4),
                  _amountRow('CGST', h.cgstAmount, kPrimary),
                  const SizedBox(height: 4),
                  _amountRow('SGST', h.sgstAmount, kPrimary),
                ],
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(
                    height: 1,
                    color: context.cs.surfaceContainerHighest,
                  ),
                ),
                _amountRow(
                  s.gstLabelTotalTax,
                  h.totalTax,
                  context.cs.onSurface,
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toStringAsFixed(0);
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }

  // ─── GSTR-3B Summary tab ──────────────────────────────────────────────────

  Widget _buildGstr3bTab({
    required double outputTaxable,
    required double outputCgst,
    required double outputSgst,
    required double outputIgst,
    required double outputTax,
    required double inputTaxable,
    required double inputCgst,
    required double inputSgst,
    required double inputIgst,
    required double inputTax,
    required int invoiceCount,
    required int poCount,
    required double intraTaxable,
    required double interTaxable,
    required double intraCgst,
    required double intraSgst,
    required double interIgst,
  }) {
    final netPayable = outputTax - inputTax;
    final isCredit = netPayable < 0;

    // Input ITC breakdown (POs don't have server-aggregated intra/inter yet)
    double inputIntraCgst = 0, inputIntraSgst = 0, inputInterIgst = 0;
    for (final po in _purchaseOrders) {
      if (po.gstType == 'igst') {
        inputInterIgst += po.igstAmount;
      } else {
        inputIntraCgst += po.cgstAmount;
        inputIntraSgst += po.sgstAmount;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.of(context).gstGstrSummaryFor(_periodLabel),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Table 3.1 — Outward Supplies
          _sectionLabel(AppStrings.of(context).gstrOutwardSupplies),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              children: [
                _gstr3bRow(
                  AppStrings.of(context).gstrOutwardSuppliesLabel,
                  outputTaxable,
                  outputTax,
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: context.cs.surfaceContainerLow),
                const SizedBox(height: 8),
                _gstr3bSubRow('Intrastate', intraTaxable, intraCgst, intraSgst),
                const SizedBox(height: 6),
                _gstr3bSubRow(
                  'Interstate',
                  interTaxable,
                  0,
                  0,
                  igst: interIgst,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Table 4 — ITC Summary
          _sectionLabel(AppStrings.of(context).gstrInputTaxCredit),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              children: [
                _gstr3bRow(
                  AppStrings.of(context).gstrItcAvailable,
                  inputTaxable,
                  inputTax,
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: context.cs.surfaceContainerLow),
                const SizedBox(height: 8),
                _gstr3bITCRow('CGST', inputIntraCgst, const Color(0xFF16A34A)),
                const SizedBox(height: 6),
                _gstr3bITCRow('SGST', inputIntraSgst, const Color(0xFF16A34A)),
                const SizedBox(height: 6),
                _gstr3bITCRow('IGST', inputInterIgst, const Color(0xFF16A34A)),
                const SizedBox(height: 8),
                Container(height: 1, color: context.cs.surfaceContainerLow),
                const SizedBox(height: 8),
                _gstr3bITCRow(
                  AppStrings.of(context).gstrTotalItc,
                  inputTax,
                  const Color(0xFF16A34A),
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Table 6 — Payment of Tax
          _sectionLabel(AppStrings.of(context).gstrPaymentOfTax),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isCredit
                  ? const LinearGradient(
                      colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                    )
                  : kSignatureGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [kWhisperShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCredit
                      ? AppStrings.of(context).gstReportItcCreditBalance
                      : AppStrings.of(context).gstReportNetTaxPayable,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currencyFormat.format(netPayable.abs()),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _bannerBadge(
                      'Output: ${_currencyFormat.format(outputTax)}',
                    ),
                    const SizedBox(width: 8),
                    _bannerBadge('ITC: ${_currencyFormat.format(inputTax)}'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _bannerBadge('$invoiceCount Invoices'),
                    const SizedBox(width: 8),
                    _bannerBadge('$poCount POs'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Component-wise net breakdown
          _sectionLabel(AppStrings.of(context).gstrComponentWiseNet),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              children: [
                _netComponentRow('CGST', outputCgst, inputIntraCgst),
                const SizedBox(height: 8),
                _netComponentRow('SGST', outputSgst, inputIntraSgst),
                const SizedBox(height: 8),
                _netComponentRow('IGST', outputIgst, inputInterIgst),
              ],
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _gstr3bRow(String label, double taxable, double tax) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.of(context).gstLabelTaxableValue,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(taxable),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppStrings.of(context).gstLabelTaxAmount,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(tax),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kPrimary,
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

  Widget _gstr3bSubRow(
    String label,
    double taxable,
    double cgst,
    double sgst, {
    double igst = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.cs.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format(taxable),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: igst > 0
                ? Text(
                    'IGST: ${_currencyFormat.format(igst)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  )
                : Text(
                    'C: ${_currencyFormat.format(cgst)} S: ${_currencyFormat.format(sgst)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _gstr3bITCRow(
    String label,
    double value,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: context.cs.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          _currencyFormat.format(value),
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _netComponentRow(String label, double output, double input) {
    final net = output - input;
    final isCredit = net < 0;
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Out: ${_currencyFormat.format(output)}',
                style: TextStyle(
                  fontSize: 10,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              Text(
                'In: ${_currencyFormat.format(input)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isCredit
                ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                : kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${isCredit ? '-' : ''}${_currencyFormat.format(net.abs())}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isCredit ? const Color(0xFF16A34A) : kPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Tax Rate-wise breakdown tab ──────────────────────────────────────────

  Widget _buildTaxRateTab(List<Invoice> invoices) {
    // Group invoices by tax rate
    final rateMap = <double, _TaxRateAggregate>{};
    for (final inv in invoices) {
      for (final item in inv.items) {
        final rate = item.gstRate > 0 ? item.gstRate : inv.gstRate;
        final agg = rateMap.putIfAbsent(rate, () => _TaxRateAggregate(rate));
        agg.invoiceCount += 1;
        agg.taxableAmount += item.total;
        final tax = item.total * rate / 100;
        agg.taxAmount += tax;
        agg.totalAmount += item.total + tax;
      }
    }

    final rates = rateMap.values.toList()
      ..sort((a, b) => a.rate.compareTo(b.rate));

    if (rates.isEmpty) {
      return _emptyState(AppStrings.of(context));
    }

    final totalTaxable = rates.fold<double>(0, (s, r) => s + r.taxableAmount);
    final totalTax = rates.fold<double>(0, (s, r) => s + r.taxAmount);
    final maxTaxable = rates
        .map((r) => r.taxableAmount)
        .fold<double>(0, (a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    // Colors for each rate
    final rateColors = <double, Color>{
      0: Color(0xFF94A3B8),
      5: Color(0xFF22C55E),
      12: Color(0xFF3B82F6),
      18: Color(0xFFF59E0B),
      28: Color(0xFFEF4444),
    };

    final expanded = windowSizeOf(context) == WindowSize.expanded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 16,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.of(context).gstTaxRateNote(rates.length),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Desktop: donut + DataTable side-by-side ──────────────
          if (expanded) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rates.length > 1) ...[
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CustomPaint(
                      painter: _DonutChartPainter(
                        segments: rates.map((r) {
                          final fraction = totalTaxable > 0 ? r.taxableAmount / totalTaxable : 0.0;
                          return _DonutSegment(fraction, rateColors[r.rate] ?? kPrimary);
                        }).toList(),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${rates.length}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.cs.onSurface)),
                            Text(AppStrings.of(context).gstRates, style: TextStyle(fontSize: 10, color: context.cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [kSubtleShadow],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(context.cs.surfaceContainerLow),
                        columnSpacing: 20,
                        horizontalMargin: 16,
                        columns: [
                          DataColumn(label: Text('GST Rate', style: _dtHeader)),
                          DataColumn(label: Text('Items', style: _dtHeader), numeric: true),
                          DataColumn(label: Text('Taxable', style: _dtHeader), numeric: true),
                          DataColumn(label: Text('Tax', style: _dtHeader), numeric: true),
                          DataColumn(label: Text('Total', style: _dtHeader), numeric: true),
                        ],
                        rows: [
                          ...rates.map((r) {
                            final color = rateColors[r.rate] ?? kPrimary;
                            return DataRow(cells: [
                              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text('${r.rate.toStringAsFixed(r.rate.truncateToDouble() == r.rate ? 0 : 1)}%', style: _dtBold),
                              ])),
                              DataCell(Text('${r.invoiceCount}', style: _dtCell)),
                              DataCell(Text(_currencyFormat.format(r.taxableAmount), style: _dtCell)),
                              DataCell(Text(_currencyFormat.format(r.taxAmount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
                              DataCell(Text(_currencyFormat.format(r.totalAmount), style: _dtCell)),
                            ]);
                          }),
                          DataRow(
                            color: WidgetStateProperty.all(context.cs.surfaceContainerLow),
                            cells: [
                              DataCell(Text('TOTAL', style: _dtBold)),
                              const DataCell(Text('')),
                              DataCell(Text(_currencyFormat.format(totalTaxable), style: _dtBold)),
                              DataCell(Text(_currencyFormat.format(totalTax), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary))),
                              const DataCell(Text('')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 90),
          ] else ...[

          // ── Mobile: original layout ─────────────────────────────
          // Visual donut chart
          if (rates.length > 1) ...[
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    segments: rates.map((r) {
                      final fraction = totalTaxable > 0
                          ? r.taxableAmount / totalTaxable
                          : 0.0;
                      return _DonutSegment(
                        fraction,
                        rateColors[r.rate] ?? kPrimary,
                      );
                    }).toList(),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${rates.length}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.cs.onSurface,
                          ),
                        ),
                        Text(
                          AppStrings.of(context).gstRates,
                          style: TextStyle(
                            fontSize: 10,
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Rate cards
          ...rates.map((r) {
            final color = rateColors[r.rate] ?? kPrimary;
            final barFraction = r.taxableAmount / maxTaxable;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [kSubtleShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${r.rate.toStringAsFixed(r.rate.truncateToDouble() == r.rate ? 0 : 1)}% GST',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${r.invoiceCount} item${r.invoiceCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      minHeight: 6,
                      backgroundColor: context.cs.surfaceContainerLow,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.of(context).gstLabelTaxable,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _currencyFormat.format(r.taxableAmount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              AppStrings.of(context).gstLabelTax,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _currencyFormat.format(r.taxAmount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppStrings.of(context).gstLabelTotal,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _currencyFormat.format(r.totalAmount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          // Summary
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.of(context).gstLabelTotalTaxable,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(totalTaxable),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppStrings.of(context).gstLabelTotalTax,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(totalTax),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 90),
          ],
        ],
      ),
    );
  }

  // ─── Output (Sales) tab content ───────────────────────────────────────────

  Widget _buildOutputTab(AppStrings s, List<Invoice> invoices) {
    if (invoices.isEmpty) {
      return _emptyState(s);
    }

    final expanded = windowSizeOf(context) == WindowSize.expanded;

    final loadMoreBtn = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _hasMoreInvoices && !_isLoadingMoreInvoices
              ? () => _loadInvoices(reset: false)
              : null,
          child: _isLoadingMoreInvoices
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_hasMoreInvoices ? s.gstLoadMore : s.gstNoMore),
        ),
      ),
    );

    if (expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(s.gstReportInvoiceBreakdown),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [kSubtleShadow],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(context.cs.surfaceContainerLow),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    columns: [
                      DataColumn(label: Text('Invoice #', style: _dtHeader)),
                      DataColumn(label: Text('Client', style: _dtHeader)),
                      DataColumn(label: Text('Date', style: _dtHeader)),
                      DataColumn(label: Text('Taxable', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('CGST', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('SGST', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('IGST', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('Total Tax', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('Grand Total', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('Status', style: _dtHeader)),
                    ],
                    rows: invoices.map((inv) {
                      final isIgst = inv.gstType == 'igst';
                      return DataRow(cells: [
                        DataCell(Text(inv.invoiceNumber, style: _dtBold)),
                        DataCell(Text(inv.clientName, style: _dtCell)),
                        DataCell(Text(_dateFormat.format(inv.createdAt), style: _dtCell)),
                        DataCell(Text(_currencyFormat.format(inv.taxableAmount), style: _dtCell)),
                        DataCell(Text(isIgst ? '-' : _currencyFormat.format(inv.cgstAmount), style: _dtCell)),
                        DataCell(Text(isIgst ? '-' : _currencyFormat.format(inv.sgstAmount), style: _dtCell)),
                        DataCell(Text(isIgst ? _currencyFormat.format(inv.igstAmount) : '-', style: _dtCell)),
                        DataCell(Text(_currencyFormat.format(inv.totalTax), style: _dtBold)),
                        DataCell(Text(_currencyFormat.format(inv.grandTotal), style: _dtBold)),
                        DataCell(_statusBadge(inv.status)),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          loadMoreBtn,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(s.gstReportInvoiceBreakdown),
        ...invoices.map((inv) => _invoiceCard(inv)),
        loadMoreBtn,
      ],
    );
  }

  // ─── DataTable text styles ─────────────────────────────────────────────────
  TextStyle get _dtHeader => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: context.cs.onSurfaceVariant,
      );
  TextStyle get _dtCell => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.cs.onSurface,
      );
  TextStyle get _dtBold => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.cs.onSurface,
      );

  DataRow _netDataRow(String label, double output, double input, {bool bold = false}) {
    final net = output - input;
    final isCredit = net < 0;
    return DataRow(
      color: bold ? WidgetStateProperty.all(context.cs.surfaceContainerLow) : null,
      cells: [
        DataCell(Text(label, style: bold ? _dtBold : _dtHeader)),
        DataCell(Text(_currencyFormat.format(output), style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: kPrimary))),
        DataCell(Text(_currencyFormat.format(input), style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: const Color(0xFF16A34A)))),
        DataCell(Text('${isCredit ? '-' : ''}${_currencyFormat.format(net.abs())}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isCredit ? const Color(0xFF16A34A) : kPrimary))),
      ],
    );
  }

  // ─── Input (Purchases) tab content ────────────────────────────────────────

  Widget _buildInputTab() {
    if (_isLoadingPurchaseOrders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(kPrimary),
          ),
        ),
      );
    }

    if (_poLoadError != null && _purchaseOrders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            AppStrings.of(context).gstReportPoLoadError,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kOverdue),
          ),
        ),
      );
    }

    if (_purchaseOrders.isEmpty) {
      return _poEmptyState();
    }

    final s = AppStrings.of(context);
    final expanded = windowSizeOf(context) == WindowSize.expanded;

    final loadMoreBtn = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _hasMorePOs && !_isLoadingMorePOs
              ? () => _loadPurchaseOrders(reset: false)
              : null,
          child: _isLoadingMorePOs
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_hasMorePOs ? s.gstLoadMore : s.gstNoMore),
        ),
      ),
    );

    if (expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(s.gstPurchaseOrderBreakdown),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [kSubtleShadow],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(context.cs.surfaceContainerLow),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    columns: [
                      DataColumn(label: Text('PO #', style: _dtHeader)),
                      DataColumn(label: Text('Supplier', style: _dtHeader)),
                      DataColumn(label: Text('Date', style: _dtHeader)),
                      DataColumn(label: Text('Taxable', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('CGST', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('SGST', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('IGST', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('Total Tax', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('Grand Total', style: _dtHeader), numeric: true),
                      DataColumn(label: Text('Status', style: _dtHeader)),
                    ],
                    rows: _purchaseOrders.map((po) {
                      final isIgst = po.gstType == 'igst';
                      final receivedDate = po.receivedAt ?? po.createdAt;
                      return DataRow(cells: [
                        DataCell(Text(po.orderNumber, style: _dtBold)),
                        DataCell(Text(po.supplierName, style: _dtCell)),
                        DataCell(Text(_dateFormat.format(receivedDate), style: _dtCell)),
                        DataCell(Text(_currencyFormat.format(po.taxableAmount), style: _dtCell)),
                        DataCell(Text(isIgst ? '-' : _currencyFormat.format(po.cgstAmount), style: _dtCell)),
                        DataCell(Text(isIgst ? '-' : _currencyFormat.format(po.sgstAmount), style: _dtCell)),
                        DataCell(Text(isIgst ? _currencyFormat.format(po.igstAmount) : '-', style: _dtCell)),
                        DataCell(Text(_currencyFormat.format(po.totalTax), style: _dtBold)),
                        DataCell(Text(_currencyFormat.format(po.grandTotal), style: _dtBold)),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _kPaidBg, borderRadius: BorderRadius.circular(20)),
                          child: Text(s.gstStatusReceived, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kPaid)),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          loadMoreBtn,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(s.gstPurchaseOrderBreakdown),
        ..._purchaseOrders.map((po) => _purchaseOrderCard(po)),
        loadMoreBtn,
      ],
    );
  }
}

// ── Tax Rate aggregation model ────────────────────────────────────────────────
class _TaxRateAggregate {
  _TaxRateAggregate(this.rate);
  final double rate;
  int invoiceCount = 0;
  double taxableAmount = 0;
  double taxAmount = 0;
  double totalAmount = 0;
}

// ── Donut Chart Painter (for Tax Rate tab) ────────────────────────────────────
class _DonutSegment {
  _DonutSegment(this.fraction, this.color);
  final double fraction;
  final Color color;
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.segments});
  final List<_DonutSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    paint.color = const Color(0xFFE5E7EB);
    canvas.drawArc(rect.deflate(7), 0, 2 * 3.14159265, false, paint);

    double startAngle = -3.14159265 / 2;
    for (final seg in segments) {
      if (seg.fraction <= 0) continue;
      final sweepAngle = seg.fraction * 2 * 3.14159265;
      paint.color = seg.color;
      canvas.drawArc(rect.deflate(7), startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
