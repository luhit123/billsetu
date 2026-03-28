import 'dart:io';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/analytics_models.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/purchase_order.dart';
import 'package:billeasy/services/analytics_service.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

// ─── Status colours (kept as semantic) ──────────────────────────────────────
const _kPaid = Color(0xFF22C55E);
const _kPaidBg = Color(0xFFDCFCE7);
const _kPending = Color(0xFFF59E0B);
const _kPendingBg = Color(0xFFFEF3C7);
const _kOverdue = Color(0xFFEF4444);
const _kOverdueBg = Color(0xFFFEE2E2);

// ─── Period enum ───────────────────────────────────────────────────────────────
enum _Period { monthly, quarterly, yearly }

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

  // Input (Purchases) state
  final List<PurchaseOrder> _purchaseOrders = [];
  bool _isLoadingPurchaseOrders = false;
  Object? _poLoadError;

  // Tab state
  _GstTab _activeTab = _GstTab.output;

  @override
  void initState() {
    super.initState();
    _refreshSummaryStream();
    _loadInvoices(reset: true);
    _loadPurchaseOrders();
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
    };
  }

  String get _summaryPeriodKey {
    return switch (_selectedPeriod) {
      _Period.monthly =>
        '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}',
      _Period.quarterly => '$_selectedYear-Q$_selectedQuarter',
      _Period.yearly => '$_selectedYear',
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
      final page = await _firebaseService.getInvoicesPage(
        startDate: _startDate,
        endDateExclusive: _endDate,
        gstEnabled: true,
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
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

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

  Future<void> _loadPurchaseOrders() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isLoadingPurchaseOrders = true;
      _poLoadError = null;
      _purchaseOrders.clear();
    });

    try {
      final startTimestamp = Timestamp.fromDate(_startDate);
      final endTimestamp = Timestamp.fromDate(_endDate);

      // Simple query by createdAt range — filter client-side to avoid
      // needing a Firestore composite index on status+gstEnabled+receivedAt.
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('purchaseOrders')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThan: endTimestamp)
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) return;

      final orders = snapshot.docs
          .map((doc) => PurchaseOrder.fromMap(doc.data(), docId: doc.id))
          .where((po) =>
              po.status == PurchaseOrderStatus.received &&
              po.gstEnabled)
          .toList();

      setState(() {
        _purchaseOrders.addAll(orders);
        _isLoadingPurchaseOrders = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _poLoadError = error;
        _isLoadingPurchaseOrders = false;
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

  void _shareReport(List<Invoice> invoices, AppStrings s) {
    final buf = StringBuffer();
    buf.writeln('GST Report — $_periodLabel');
    buf.writeln('=' * 40);

    // ── Output GST (Sales) ──
    buf.writeln();
    buf.writeln('OUTPUT GST (Sales)');
    buf.writeln('Invoices with GST: ${invoices.length}');
    buf.writeln();

    double totalTaxable = 0,
        totalCgst = 0,
        totalSgst = 0,
        totalIgst = 0,
        totalTax = 0;
    for (final inv in invoices) {
      totalTaxable += inv.taxableAmount;
      totalCgst += inv.cgstAmount;
      totalSgst += inv.sgstAmount;
      totalIgst += inv.igstAmount;
      totalTax += inv.totalTax;
    }

    buf.writeln('Taxable Amount : ${_currencyFormat.format(totalTaxable)}');
    buf.writeln('Total CGST     : ${_currencyFormat.format(totalCgst)}');
    buf.writeln('Total SGST     : ${_currencyFormat.format(totalSgst)}');
    buf.writeln('Total IGST     : ${_currencyFormat.format(totalIgst)}');
    buf.writeln('Total Tax      : ${_currencyFormat.format(totalTax)}');

    // ── Input GST (Purchases) ──
    buf.writeln();
    buf.writeln('INPUT GST (Purchases)');
    buf.writeln('Received POs with GST: ${_purchaseOrders.length}');
    buf.writeln();

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

    buf.writeln('Taxable Amount : ${_currencyFormat.format(inputTaxable)}');
    buf.writeln('Total CGST     : ${_currencyFormat.format(inputCgst)}');
    buf.writeln('Total SGST     : ${_currencyFormat.format(inputSgst)}');
    buf.writeln('Total IGST     : ${_currencyFormat.format(inputIgst)}');
    buf.writeln('Total Tax      : ${_currencyFormat.format(inputTax)}');

    // ── Net GST ──
    final netPayable = totalTax - inputTax;
    buf.writeln();
    buf.writeln('NET GST');
    buf.writeln(
        netPayable >= 0
            ? 'Net Payable    : ${_currencyFormat.format(netPayable)}'
            : 'ITC Credit     : ${_currencyFormat.format(netPayable.abs())}');

    // ── Invoice breakdown ──
    buf.writeln();
    buf.writeln('Invoice Breakdown:');
    buf.writeln('-' * 40);

    for (final inv in invoices) {
      buf.writeln('${inv.invoiceNumber}  ${inv.clientName}');
      buf.writeln('  Date    : ${_dateFormat.format(inv.createdAt)}');
      buf.writeln('  Taxable : ${_currencyFormat.format(inv.taxableAmount)}');
      if (inv.gstType == 'igst') {
        buf.writeln('  IGST    : ${_currencyFormat.format(inv.igstAmount)}');
      } else {
        buf.writeln(
          '  CGST    : ${_currencyFormat.format(inv.cgstAmount)}  SGST: ${_currencyFormat.format(inv.sgstAmount)}',
        );
      }
      buf.writeln('  Tax     : ${_currencyFormat.format(inv.totalTax)}');
      buf.writeln('  Status  : ${inv.status.name}');
      buf.writeln();
    }

    // ── PO breakdown ──
    if (_purchaseOrders.isNotEmpty) {
      buf.writeln('Purchase Order Breakdown:');
      buf.writeln('-' * 40);

      for (final po in _purchaseOrders) {
        buf.writeln('${po.orderNumber}  ${po.supplierName}');
        buf.writeln('  Date    : ${_dateFormat.format(po.createdAt)}');
        buf.writeln('  Taxable : ${_currencyFormat.format(po.taxableAmount)}');
        if (po.gstType == 'igst') {
          buf.writeln('  IGST    : ${_currencyFormat.format(po.igstAmount)}');
        } else {
          buf.writeln(
            '  CGST    : ${_currencyFormat.format(po.cgstAmount)}  SGST: ${_currencyFormat.format(po.sgstAmount)}',
          );
        }
        buf.writeln('  Tax     : ${_currencyFormat.format(po.totalTax)}');
        buf.writeln();
      }
    }

    SharePlus.instance.share(
      ShareParams(text: buf.toString(), subject: 'GST Report — $_periodLabel'),
    );
  }

  /// PDF Summary — comprehensive totals, no individual invoices
  void _sharePdfSummary(List<Invoice> invoices) {
    double totalTaxable = 0, totalCgst = 0, totalSgst = 0, totalIgst = 0, totalTax = 0, totalGrand = 0;
    for (final inv in invoices) {
      totalTaxable += inv.taxableAmount;
      totalCgst += inv.cgstAmount;
      totalSgst += inv.sgstAmount;
      totalIgst += inv.igstAmount;
      totalTax += inv.totalTax;
      totalGrand += inv.grandTotal;
    }

    double inputTaxable = 0, inputCgst = 0, inputSgst = 0, inputIgst = 0, inputTax = 0;
    for (final po in _purchaseOrders) {
      inputTaxable += po.taxableAmount;
      inputCgst += po.cgstAmount;
      inputSgst += po.sgstAmount;
      inputIgst += po.igstAmount;
      inputTax += po.totalTax;
    }
    final netPayable = totalTax - inputTax;

    final buf = StringBuffer();
    buf.writeln('GST REPORT — $_periodLabel');
    buf.writeln('${'=' * 44}');
    buf.writeln();
    buf.writeln('OUTPUT GST (Sales)');
    buf.writeln('  Total Invoices   : ${invoices.length}');
    buf.writeln('  Taxable Amount   : ${_currencyFormat.format(totalTaxable)}');
    buf.writeln('  CGST             : ${_currencyFormat.format(totalCgst)}');
    buf.writeln('  SGST             : ${_currencyFormat.format(totalSgst)}');
    buf.writeln('  IGST             : ${_currencyFormat.format(totalIgst)}');
    buf.writeln('  Total Tax        : ${_currencyFormat.format(totalTax)}');
    buf.writeln('  Grand Total      : ${_currencyFormat.format(totalGrand)}');
    buf.writeln();
    buf.writeln('INPUT GST (Purchases)');
    buf.writeln('  Total POs        : ${_purchaseOrders.length}');
    buf.writeln('  Taxable Amount   : ${_currencyFormat.format(inputTaxable)}');
    buf.writeln('  CGST             : ${_currencyFormat.format(inputCgst)}');
    buf.writeln('  SGST             : ${_currencyFormat.format(inputSgst)}');
    buf.writeln('  IGST             : ${_currencyFormat.format(inputIgst)}');
    buf.writeln('  Total Tax        : ${_currencyFormat.format(inputTax)}');
    buf.writeln();
    buf.writeln('NET GST LIABILITY');
    buf.writeln(netPayable >= 0
        ? '  Net Payable      : ${_currencyFormat.format(netPayable)}'
        : '  ITC Credit       : ${_currencyFormat.format(netPayable.abs())}');
    buf.writeln();
    buf.writeln('Generated by BillRaja');

    SharePlus.instance.share(
      ShareParams(text: buf.toString(), subject: 'GST Report Summary — $_periodLabel'),
    );
  }

  /// CSV export — all invoices with full GST breakdown
  Future<void> _shareCsv(List<Invoice> invoices) async {
    final buf = StringBuffer();
    // Header
    buf.writeln('Invoice No,Date,Customer,GSTIN,Taxable Amount,CGST,SGST,IGST,Total Tax,Grand Total,Status,GST Type,GST Rate');

    // Data rows
    for (final inv in invoices) {
      final date = _dateFormat.format(inv.createdAt);
      final name = inv.clientName.replaceAll(',', ' '); // escape commas
      final gstin = inv.customerGstin;
      buf.writeln(
        '${inv.invoiceNumber},$date,$name,$gstin,'
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
      buf.writeln('PO No,Date,Supplier,Taxable Amount,CGST,SGST,IGST,Total Tax,Grand Total,GST Type');
      for (final po in _purchaseOrders) {
        final date = _dateFormat.format(po.createdAt);
        final name = po.supplierName.replaceAll(',', ' ');
        buf.writeln(
          '${po.orderNumber},$date,$name,'
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
    buf.writeln('TOTALS,,,'
        '${totalTaxable.toStringAsFixed(2)},,,,${totalTax.toStringAsFixed(2)},${totalGrand.toStringAsFixed(2)}');

    // Write to temp file and share
    final dir = await Directory.systemTemp.createTemp('gst_report');
    final file = File('${dir.path}/GST_Report_${_periodLabel.replaceAll(' ', '_')}.csv');
    await file.writeAsString(buf.toString());

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'GST Report — $_periodLabel'),
    );
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
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Export GST Report', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFE53935), size: 28),
                title: const Text('PDF Summary', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Comprehensive summary — no individual invoices', style: TextStyle(fontSize: 12)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xFFFFF5F5),
                onTap: () => Navigator.pop(ctx, 'pdf'),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Color(0xFF2E7D32), size: 28),
                title: const Text('CSV (All Invoices)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Every invoice with GST breakdown — for filing', style: TextStyle(fontSize: 12)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      final invoices = await _firebaseService.getAllInvoices(
        startDate: _startDate,
        endDateExclusive: _endDate,
        gstEnabled: true,
      );

      if (!mounted) return;

      final gstInvoices = invoices.where((invoice) => invoice.hasGst).toList();
      if (gstInvoices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.gstReportNoInvoices)));
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
        SnackBar(content: Text('Unable to prepare report: $error')),
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
          color: selected ? kPrimary : kSurfaceLowest,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : kTextSecondary,
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
        color: kSurfaceLowest,
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
              color: kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range_rounded, size: 14, color: kPrimary),
                const SizedBox(width: 6),
                Text(
                  _periodLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kOnSurface,
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
        color: kSurfaceLowest,
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
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: kOnSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _netGstBanner({
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
                  const Text(
                    'Net GST Payable',
                    style: TextStyle(
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
                        ? 'ITC Credit Available'
                        : 'Output GST - Input GST',
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

  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tabItem('Output', _GstTab.output),
            _tabItem('Input', _GstTab.input),
            _tabItem('Net', _GstTab.net),
            _tabItem('HSN', _GstTab.hsn),
            _tabItem('GSTR-3B', _GstTab.gstr3b),
            _tabItem('Tax Rate', _GstTab.taxRate),
          ],
        ),
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
          color: selected ? kSurfaceLowest : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected ? const [kSubtleShadow] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? kPrimary : kOnSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(InvoiceStatus status) {
    Color fg, bg;
    String label;
    switch (status) {
      case InvoiceStatus.paid:
        fg = _kPaid;
        bg = _kPaidBg;
        label = 'Paid';
      case InvoiceStatus.pending:
        fg = const Color(0xFFEF4444);
        bg = const Color(0xFFFEE2E2);
        label = 'Unpaid';
      case InvoiceStatus.overdue:
        fg = _kOverdue;
        bg = _kOverdueBg;
        label = 'Overdue';
      case InvoiceStatus.partiallyPaid:
        fg = const Color(0xFFEAB308);
        bg = const Color(0xFFFEF3C7);
        label = 'Partial';
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
        color: kPrimaryContainer,
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
    final isIgst = inv.gstType == 'igst';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
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
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kOnSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inv.clientName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kOnSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  _dateFormat.format(inv.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: kOnSurfaceVariant,
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
                color: kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _amountRow('Taxable', inv.taxableAmount, kOnSurface),
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
                    child: Divider(height: 1, color: kSurfaceDim),
                  ),
                  _amountRow('Total Tax', inv.totalTax, kOnSurface, bold: true),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: kOnSurfaceVariant,
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
    final isIgst = po.gstType == 'igst';
    final receivedDate = po.receivedAt ?? po.createdAt;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
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
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kOnSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        po.supplierName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kOnSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  _dateFormat.format(receivedDate),
                  style: const TextStyle(
                    fontSize: 11,
                    color: kOnSurfaceVariant,
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
                color: kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _amountRow('Taxable', po.taxableAmount, kOnSurface),
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
                    child: Divider(height: 1, color: kSurfaceDim),
                  ),
                  _amountRow('Total Tax', po.totalTax, kOnSurface, bold: true),
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
                  child: const Text(
                    'Received',
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: kOnSurfaceVariant,
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
            color: kOnSurfaceVariant,
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
                color: kSurfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: kOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              s.gstReportNoInvoices,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _periodLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kOnSurfaceVariant),
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
              decoration: const BoxDecoration(
                color: kSurfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 36,
                color: kOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No received purchase orders with GST',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kOnSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _periodLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kOnSurfaceVariant),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _comparisonTable(
            title: 'Taxable Amount',
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
            title: 'Total Tax',
            outputValue: outputTax,
            inputValue: inputTax,
            highlight: true,
          ),
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
                            ? 'Net GST Payable'
                            : 'Net ITC Credit',
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
                        'Output Tax - Input Tax',
                        style: const TextStyle(
                          fontSize: 11,
                          color: kOnSurfaceVariant,
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
                    color: netPayable >= 0
                        ? kPrimary
                        : const Color(0xFF16A34A),
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
        color: highlight ? kSurfaceContainerLow : kSurfaceLowest,
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
              color: kOnSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Output (Sales)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: kOnSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currencyFormat.format(outputValue),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                        color: kPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: kSurfaceDim,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Input (Purchases)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: kOnSurfaceVariant,
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

        // Net
        final netPayable = totalTax - inputTax;

        return Scaffold(
          backgroundColor: kSurface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: kSurface,
            foregroundColor: kOnSurface,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              s.gstReportTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kOnSurface,
              ),
            ),
            centerTitle: false,
            iconTheme: const IconThemeData(color: kOnSurface),
          ),
          body: Column(
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
                              'Error loading data: $_invoiceLoadError',
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
                              outputTax: totalTax,
                              inputTax: inputTax,
                              invoiceCount: invoiceCount,
                              poCount: poCount,
                            ),
                            _sectionLabel('GST OVERVIEW'),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.55,
                                children: [
                                  _summaryCard(
                                    label: 'Output GST (Sales)',
                                    value: _currencyFormat.format(totalTax),
                                    color: kPrimary,
                                    icon: Icons.arrow_upward_rounded,
                                  ),
                                  _summaryCard(
                                    label: 'Input GST (Purchases)',
                                    value: _currencyFormat.format(inputTax),
                                    color: const Color(0xFF16A34A),
                                    icon: Icons.arrow_downward_rounded,
                                  ),
                                  _summaryCard(
                                    label: netPayable >= 0
                                        ? 'Net Payable'
                                        : 'Net Credit',
                                    value: _currencyFormat
                                        .format(netPayable.abs()),
                                    color: netPayable >= 0
                                        ? kOnSurface
                                        : const Color(0xFF16A34A),
                                    icon: Icons.account_balance_rounded,
                                  ),
                                  _summaryCard(
                                    label: 'Invoices / POs',
                                    value: '$invoiceCount / $poCount',
                                    color: kOnSurface,
                                    icon: Icons.description_outlined,
                                  ),
                                ],
                              ),
                            ),
                            // Tab bar
                            _tabBar(),
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
                        ? kSurfaceDim
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
                              ? kOnSurfaceVariant
                              : Colors.white,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        s.gstReportShareReport,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: invoices.isEmpty || _isSharingReport
                              ? kOnSurfaceVariant
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
      for (final item in inv.items) {
        final code = item.hsnCode.trim().isEmpty ? 'No HSN' : item.hsnCode.trim();
        final agg = hsnMap.putIfAbsent(code, () => _HsnAggregate(code));
        agg.description = item.description;
        agg.totalQuantity += item.quantity;
        agg.unit = item.unit.isNotEmpty ? item.unit : agg.unit;
        agg.taxableAmount += item.total;
        final itemGstRate = item.gstRate > 0 ? item.gstRate : inv.gstRate;
        agg.gstRate = itemGstRate;
        final isIgst = inv.gstType == 'igst';
        final tax = item.total * itemGstRate / 100;
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
                const Icon(Icons.info_outline_rounded, size: 16, color: kPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HSN summary for GSTR-1 filing — ${hsnList.length} HSN code${hsnList.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kSurfaceContainerLow,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('HSN Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOnSurfaceVariant))),
                Expanded(flex: 2, child: Text('Taxable', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOnSurfaceVariant))),
                Expanded(flex: 2, child: Text('Tax', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOnSurfaceVariant))),
              ],
            ),
          ),

          // HSN rows
          Container(
            decoration: BoxDecoration(
              color: kSurfaceLowest,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
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
                        Container(height: 1, color: kSurfaceContainerLow, margin: const EdgeInsets.symmetric(horizontal: 12)),
                    ],
                  );
                }),
                // Total row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: kSurfaceContainerLow,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kOnSurface))),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(totalTaxable), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kOnSurface))),
                      Expanded(flex: 2, child: Text(_currencyFormat.format(totalTax), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Detailed breakdown cards
          const SizedBox(height: 20),
          _sectionLabel('DETAILED BREAKDOWN'),
          ...hsnList.map((h) => _hsnDetailCard(h)),
          const SizedBox(height: 90),
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
                Text(h.hsnCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kOnSurface)),
                Text(h.description, style: const TextStyle(fontSize: 10, color: kOnSurfaceVariant), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(_currencyFormat.format(h.taxableAmount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurface)),
          ),
          Expanded(
            flex: 2,
            child: Text(_currencyFormat.format(h.totalTax), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _hsnDetailCard(_HsnAggregate h) {
    final isIgst = h.igstAmount > 0 && h.cgstAmount == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kPrimaryContainer, borderRadius: BorderRadius.circular(20)),
                child: Text(h.hsnCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
              ),
              const SizedBox(width: 8),
              _gstRateBadge(h.gstRate),
              const Spacer(),
              Text(
                '${_formatQty(h.totalQuantity)}${h.unit.isNotEmpty ? ' ${h.unit}' : ''}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kOnSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(h.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kOnSurfaceVariant)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kSurfaceContainerLow, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                _amountRow('Taxable', h.taxableAmount, kOnSurface),
                if (isIgst) ...[
                  const SizedBox(height: 4),
                  _amountRow('IGST', h.igstAmount, kPrimary),
                ] else ...[
                  const SizedBox(height: 4),
                  _amountRow('CGST', h.cgstAmount, kPrimary),
                  const SizedBox(height: 4),
                  _amountRow('SGST', h.sgstAmount, kPrimary),
                ],
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: kSurfaceDim)),
                _amountRow('Total Tax', h.totalTax, kOnSurface, bold: true),
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
  }) {
    final netPayable = outputTax - inputTax;
    final isCredit = netPayable < 0;

    // Separate intrastate vs interstate from invoices
    double intraCgst = 0, intraSgst = 0, interIgst = 0;
    double intraTaxable = 0, interTaxable = 0;
    for (final inv in _invoices) {
      if (inv.gstType == 'igst') {
        interIgst += inv.igstAmount;
        interTaxable += inv.taxableAmount;
      } else {
        intraCgst += inv.cgstAmount;
        intraSgst += inv.sgstAmount;
        intraTaxable += inv.taxableAmount;
      }
    }

    // Input ITC breakdown
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
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 16, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GSTR-3B Summary for $_periodLabel',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Table 3.1 — Outward Supplies
          _sectionLabel('3.1 — OUTWARD SUPPLIES'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurfaceLowest,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              children: [
                _gstr3bRow('(a) Outward taxable supplies (other than zero rated, nil rated and exempted)', outputTaxable, outputTax),
                const SizedBox(height: 8),
                Container(height: 1, color: kSurfaceContainerLow),
                const SizedBox(height: 8),
                _gstr3bSubRow('Intrastate', intraTaxable, intraCgst, intraSgst),
                const SizedBox(height: 6),
                _gstr3bSubRow('Interstate', interTaxable, 0, 0, igst: interIgst),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Table 4 — ITC Summary
          _sectionLabel('4 — INPUT TAX CREDIT (ITC)'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurfaceLowest,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              children: [
                _gstr3bRow('(A) ITC Available', inputTaxable, inputTax),
                const SizedBox(height: 8),
                Container(height: 1, color: kSurfaceContainerLow),
                const SizedBox(height: 8),
                _gstr3bITCRow('CGST', inputIntraCgst, const Color(0xFF16A34A)),
                const SizedBox(height: 6),
                _gstr3bITCRow('SGST', inputIntraSgst, const Color(0xFF16A34A)),
                const SizedBox(height: 6),
                _gstr3bITCRow('IGST', inputInterIgst, const Color(0xFF16A34A)),
                const SizedBox(height: 8),
                Container(height: 1, color: kSurfaceContainerLow),
                const SizedBox(height: 8),
                _gstr3bITCRow('Total ITC', inputTax, const Color(0xFF16A34A), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Table 6 — Payment of Tax
          _sectionLabel('6 — PAYMENT OF TAX'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isCredit
                  ? const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF15803D)])
                  : kSignatureGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [kWhisperShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCredit ? 'ITC Credit Balance' : 'Net Tax Payable',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  _currencyFormat.format(netPayable.abs()),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _bannerBadge('Output: ${_currencyFormat.format(outputTax)}'),
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
          _sectionLabel('COMPONENT-WISE NET TAX'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSurfaceLowest,
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
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Taxable Value', style: TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                  Text(_currencyFormat.format(taxable), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kOnSurface)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Tax Amount', style: TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                  Text(_currencyFormat.format(tax), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kPrimary)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gstr3bSubRow(String label, double taxable, double cgst, double sgst, {double igst = 0}) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.4), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kOnSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          Expanded(flex: 2, child: Text(_currencyFormat.format(taxable), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kOnSurface), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: igst > 0
              ? Text('IGST: ${_currencyFormat.format(igst)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPrimary), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)
              : Text('C: ${_currencyFormat.format(cgst)} S: ${_currencyFormat.format(sgst)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPrimary), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _gstr3bITCRow(String label, double value, Color color, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: kOnSurfaceVariant)),
        ),
        Text(
          _currencyFormat.format(value),
          style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _netComponentRow(String label, double output, double input) {
    final net = output - input;
    final isCredit = net < 0;
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurfaceVariant))),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Out: ${_currencyFormat.format(output)}', style: const TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
              Text('In: ${_currencyFormat.format(input)}', style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isCredit ? const Color(0xFF16A34A).withValues(alpha: 0.1) : kPrimary.withValues(alpha: 0.1),
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

    final rates = rateMap.values.toList()..sort((a, b) => a.rate.compareTo(b.rate));

    if (rates.isEmpty) {
      return _emptyState(AppStrings.of(context));
    }

    final totalTaxable = rates.fold<double>(0, (s, r) => s + r.taxableAmount);
    final totalTax = rates.fold<double>(0, (s, r) => s + r.taxAmount);
    final maxTaxable = rates.map((r) => r.taxableAmount).fold<double>(0, (a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    // Colors for each rate
    final rateColors = <double, Color>{
      0: Color(0xFF94A3B8),
      5: Color(0xFF22C55E),
      12: Color(0xFF3B82F6),
      18: Color(0xFFF59E0B),
      28: Color(0xFFEF4444),
    };

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
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pie_chart_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tax rate breakdown — ${rates.length} rate${rates.length == 1 ? '' : 's'} applied',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Visual donut chart
          if (rates.length > 1) ...[
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
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
                        Text('${rates.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kOnSurface)),
                        const Text('Rates', style: TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
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
                color: kSurfaceLowest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [kSubtleShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${r.rate.toStringAsFixed(r.rate.truncateToDouble() == r.rate ? 0 : 1)}% GST',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${r.invoiceCount} item${r.invoiceCount == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kOnSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      minHeight: 6,
                      backgroundColor: kSurfaceContainerLow,
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
                            const Text('Taxable', style: TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                            Text(_currencyFormat.format(r.taxableAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kOnSurface)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('Tax', style: TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                            Text(_currencyFormat.format(r.taxAmount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                            Text(_currencyFormat.format(r.totalAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kOnSurface)),
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
                      const Text('Total Taxable', style: TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                      Text(_currencyFormat.format(totalTaxable), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kOnSurface)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Tax', style: TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                      Text(_currencyFormat.format(totalTax), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kPrimary)),
                    ],
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

  // ─── Output (Sales) tab content ───────────────────────────────────────────

  Widget _buildOutputTab(AppStrings s, List<Invoice> invoices) {
    if (invoices.isEmpty) {
      return _emptyState(s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(s.gstReportInvoiceBreakdown),
        ...invoices.map((inv) => _invoiceCard(inv)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed:
                  _hasMoreInvoices && !_isLoadingMoreInvoices
                      ? () => _loadInvoices(reset: false)
                      : null,
              child: _isLoadingMoreInvoices
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _hasMoreInvoices
                          ? 'Load more invoices'
                          : 'No more invoices',
                    ),
            ),
          ),
        ),
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
            'Error loading purchase orders: $_poLoadError',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kOverdue),
          ),
        ),
      );
    }

    if (_purchaseOrders.isEmpty) {
      return _poEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PURCHASE ORDER BREAKDOWN'),
        ..._purchaseOrders.map((po) => _purchaseOrderCard(po)),
        const SizedBox(height: 90),
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
