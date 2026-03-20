import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/analytics_models.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/services/analytics_service.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

// ─── Period enum ───────────────────────────────────────────────────────────────
enum _Period { monthly, quarterly, yearly }

class GstReportScreen extends StatefulWidget {
  const GstReportScreen({super.key});

  @override
  State<GstReportScreen> createState() => _GstReportScreenState();
}

class _GstReportScreenState extends State<GstReportScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final FirebaseService _firebaseService = FirebaseService();
  final _currencyFormat = kRsCurrencyFormat;
  final _dateFormat = kDateFormat;

  _Period _selectedPeriod = _Period.monthly;
  int _selectedMonth = DateTime.now().month;
  int _selectedQuarter = ((DateTime.now().month - 1) ~/ 3) + 1;
  int _selectedYear = DateTime.now().year;
  late Stream<GstPeriodSummary?> _summaryStream;
  static const int _pageSize = 25;

  final List<Invoice> _invoices = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _invoiceCursor;
  Object? _invoiceLoadError;
  bool _hasMoreInvoices = true;
  bool _isLoadingInvoices = false;
  bool _isLoadingMoreInvoices = false;
  bool _isSharingReport = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _refreshSummaryStream();
    _loadInvoices(reset: true);
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

  // ─── Share/export ────────────────────────────────────────────────────────────

  void _shareReport(List<Invoice> invoices, AppStrings s) {
    final buf = StringBuffer();
    buf.writeln('GST Report — $_periodLabel');
    buf.writeln('=' * 40);
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

    SharePlus.instance.share(
      ShareParams(text: buf.toString(), subject: 'GST Report — $_periodLabel'),
    );
  }

  Future<void> _shareFullReport(AppStrings s) async {
    if (_isSharingReport) {
      return;
    }

    setState(() {
      _isSharingReport = true;
    });

    try {
      final invoices = await _firebaseService.getAllInvoices(
        startDate: _startDate,
        endDateExclusive: _endDate,
        gstEnabled: true,
      );

      if (!mounted) {
        return;
      }

      final gstInvoices = invoices.where((invoice) => invoice.hasGst).toList();
      if (gstInvoices.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.gstReportNoInvoices)));
        return;
      }

      _shareReport(gstInvoices, s);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to prepare share report: $error')),
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
              color: kTeal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTeal,
              letterSpacing: 1.2,
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
          gradient: selected ? kGradient : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? Colors.transparent : kBorder,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kNavy.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: kNavy.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
              color: kBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range_rounded, size: 14, color: kTeal),
                const SizedBox(width: 6),
                Text(
                  _periodLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
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
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: kNavy.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _currencyFormat.format(value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalTaxBanner({
    required AppStrings s,
    required double totalTax,
    required int count,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: kGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kNavy.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
                    s.gstReportTotalTax,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currencyFormat.format(totalTax),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.gstReportInvoiceCount(count),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
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
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(InvoiceStatus status) {
    Color fg, bg;
    String label;
    switch (status) {
      case InvoiceStatus.paid:
        fg = kPaid;
        bg = kPaidBg;
        label = 'Paid';
      case InvoiceStatus.pending:
        fg = kPending;
        bg = kPendingBg;
        label = 'Pending';
      case InvoiceStatus.overdue:
        fg = kOverdue;
        bg = kOverdueBg;
        label = 'Overdue';
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
        color: kTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kTeal.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1)}% GST',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kTeal,
        ),
      ),
    );
  }

  Widget _invoiceCard(Invoice inv) {
    final isIgst = inv.gstType == 'igst';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: kNavy.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inv.clientName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kTextSecondary,
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
                    color: kTextSecondary,
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
                color: kBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _amountRow('Taxable', inv.taxableAmount, kTextPrimary),
                  if (isIgst) ...[
                    const SizedBox(height: 4),
                    _amountRow('IGST', inv.igstAmount, kPrimary),
                  ] else ...[
                    const SizedBox(height: 4),
                    _amountRow('CGST', inv.cgstAmount, kTeal),
                    const SizedBox(height: 4),
                    _amountRow('SGST', inv.sgstAmount, kTeal),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, color: kBorder),
                  ),
                  _amountRow('Total Tax', inv.totalTax, kNavy, bold: true),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Badges row
            Row(
              children: [
                _statusBadge(inv.status),
                const SizedBox(width: 8),
                _gstRateBadge(inv.gstRate),
                const Spacer(),
                Text(
                  isIgst ? 'Interstate' : 'Intrastate',
                  style: const TextStyle(
                    fontSize: 11,
                    color: kTextSecondary,
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
            color: kTextSecondary,
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
                color: kBackground,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder, width: 1.5),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              s.gstReportNoInvoices,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _periodLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final invoices = _invoices;
    final loading = _isLoadingInvoices && invoices.isEmpty;
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
        final totalTaxable = summary?.taxableAmount ?? fallbackTaxable;
        final totalCgst = summary?.cgstAmount ?? fallbackCgst;
        final totalSgst = summary?.sgstAmount ?? fallbackSgst;
        final totalIgst = summary?.igstAmount ?? fallbackIgst;
        final totalTax = summary?.totalTax ?? fallbackTax;
        final invoiceCount = summary?.invoiceCount ?? invoices.length;

        return Scaffold(
          backgroundColor: kBackground,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: const BoxDecoration(gradient: kGradient),
            ),
            title: Text(
              s.gstReportTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            centerTitle: false,
            iconTheme: const IconThemeData(color: Colors.white),
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
                            valueColor: AlwaysStoppedAnimation(kTeal),
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
                              style: const TextStyle(color: kOverdue),
                            ),
                          ),
                        ),
                      )
                    else if (invoices.isEmpty)
                      SliverToBoxAdapter(child: _emptyState(s))
                    else
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            _totalTaxBanner(
                              s: s,
                              totalTax: totalTax,
                              count: invoiceCount,
                            ),
                            _sectionLabel(s.gstReportSubtitle),
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
                                    label: s.gstReportTaxableAmount,
                                    value: totalTaxable,
                                    color: kNavy,
                                    icon: Icons.receipt_outlined,
                                  ),
                                  _summaryCard(
                                    label: s.gstReportTotalCgst,
                                    value: totalCgst,
                                    color: kTeal,
                                    icon: Icons.percent_rounded,
                                  ),
                                  _summaryCard(
                                    label: s.gstReportTotalSgst,
                                    value: totalSgst,
                                    color: kTeal,
                                    icon: Icons.percent_rounded,
                                  ),
                                  _summaryCard(
                                    label: s.gstReportTotalIgst,
                                    value: totalIgst,
                                    color: kPrimary,
                                    icon: Icons.swap_horiz_rounded,
                                  ),
                                ],
                              ),
                            ),
                            _sectionLabel(s.gstReportInvoiceBreakdown),
                            ...invoices.map((inv) => _invoiceCard(inv)),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed:
                                      _hasMoreInvoices &&
                                          !_isLoadingMoreInvoices
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
                        : kGradient,
                    color: invoices.isEmpty || _isSharingReport
                        ? kBorder
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: invoices.isEmpty || _isSharingReport
                        ? null
                        : [
                            BoxShadow(
                              color: kNavy.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                              ? kTextSecondary
                              : Colors.white,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        s.gstReportShareReport,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: invoices.isEmpty || _isSharingReport
                              ? kTextSecondary
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
}
