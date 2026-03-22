import 'dart:io';
import 'dart:typed_data';

import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/member.dart';
import 'package:billeasy/modals/subscription_plan.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

BoxDecoration _cardDeco() => const BoxDecoration(
      color: kSurfaceLowest,
      borderRadius: BorderRadius.all(Radius.circular(20)),
      boxShadow: [kWhisperShadow],
    );

// ─────────────────────────────────────────────────────────────────────────────

class MembershipInvoiceScreen extends StatefulWidget {
  const MembershipInvoiceScreen({
    super.key,
    required this.member,
    required this.plan,
  });

  final Member member;
  final SubscriptionPlan plan;

  @override
  State<MembershipInvoiceScreen> createState() =>
      _MembershipInvoiceScreenState();
}

class _MembershipInvoiceScreenState extends State<MembershipInvoiceScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );

  bool _isGeneratingPdf = false;
  BusinessProfile? _profile;

  Member get _member => widget.member;
  SubscriptionPlan get _plan => widget.plan;

  Color get _planColor {
    try {
      final hex = _plan.colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return kPrimary;
    }
  }

  String get _invoiceNumber {
    final datePart = DateFormat('yyyyMMdd').format(_member.startDate);
    final idSuffix = _member.id.length >= 4
        ? _member.id.substring(_member.id.length - 4).toUpperCase()
        : _member.id.toUpperCase();
    return 'MEM-$datePart-$idSuffix';
  }

  bool get _isRecurring => _plan.planType == PlanType.recurring;

  DateTime get _nextRenewalDate => _member.endDate.add(const Duration(days: 1));

  double get _discountAmount =>
      _plan.discountPercent > 0 ? _plan.price * _plan.discountPercent / 100 : 0;

  double get _totalAmount {
    double total = _plan.effectivePrice;
    if (_isRecurring) {
      total += _member.joiningFeePaid;
    }
    return total;
  }

  int get _totalDuration => _member.endDate.difference(_member.startDate).inDays;

  double get _progressFraction {
    if (_totalDuration <= 0) return 1.0;
    final elapsed =
        DateTime.now().difference(_member.startDate).inDays.clamp(0, _totalDuration);
    return elapsed / _totalDuration;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService().getCurrentProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: kBuildGradientAppBar(titleText: 'Membership Invoice'),
      bottomNavigationBar: _buildBottomBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildMemberDetailsCard(),
            const SizedBox(height: 16),
            _buildPlanDetailsCard(),
            const SizedBox(height: 16),
            _buildPaymentSummaryCard(),
          ],
        ),
      ),
    );
  }

  // ── Bottom Action Bar ──────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: kSurfaceLowest,
        boxShadow: [kWhisperShadow],
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isGeneratingPdf ? null : _downloadPdf,
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Download PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kOnSurface,
                  side: const BorderSide(color: kOutlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isGeneratingPdf ? null : _shareViaWhatsApp,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header Card ────────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    final planColor = _planColor;
    final lighter = Color.lerp(planColor, Colors.white, 0.3)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [planColor, lighter],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: planColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.card_membership_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Membership Invoice',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _invoiceNumber,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderMetaTile(
                icon: Icons.calendar_today_outlined,
                label: 'Issue Date',
                value: _dateFormat.format(_member.startDate),
              ),
              const SizedBox(width: 12),
              _HeaderMetaTile(
                icon: Icons.currency_rupee_rounded,
                label: 'Total Amount',
                value: _currencyFormat.format(_totalAmount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Member Details Card ────────────────────────────────────────────────────

  Widget _buildMemberDetailsCard() {
    return Container(
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Member Details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kOnSurface,
              ),
            ),
          ),
          Container(height: 1, color: kSurfaceContainer),
          _InfoRow(label: 'Name', value: _member.name),
          if (_member.phone.trim().isNotEmpty)
            _InfoRow(label: 'Phone', value: _member.phone),
          if (_member.email.trim().isNotEmpty)
            _InfoRow(label: 'Email', value: _member.email),
          _InfoRow(
            label: 'Member Since',
            value: _dateFormat.format(_member.startDate),
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ── Plan Details Card ──────────────────────────────────────────────────────

  Widget _buildPlanDetailsCard() {
    final planColor = _planColor;
    final daysLeft = _member.daysLeft;
    final totalDays = _totalDuration;

    return Container(
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Plan Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kOnSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: planColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isRecurring ? 'Recurring' : 'Package',
                    style: TextStyle(
                      color: planColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: kSurfaceContainer),
          // Plan name
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: planColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: planColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _plan.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kOnSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _plan.durationLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Start → End dates
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start Date',
                          style: TextStyle(
                            color: kOnSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateFormat.format(_member.startDate),
                          style: const TextStyle(
                            color: kOnSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: planColor,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'End Date',
                          style: TextStyle(
                            color: kOnSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateFormat.format(_member.endDate),
                          style: const TextStyle(
                            color: kOnSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Next renewal (recurring only)
          if (_isRecurring) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: planColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: planColor.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.autorenew_rounded, size: 18, color: planColor),
                    const SizedBox(width: 10),
                    Text(
                      'Next Renewal',
                      style: TextStyle(
                        color: kOnSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _dateFormat.format(_nextRenewalDate),
                      style: TextStyle(
                        color: planColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Days remaining progress bar
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _member.daysLeftLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kOnSurfaceVariant,
                      ),
                    ),
                    Text(
                      '$totalDays days total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kTextTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 1.0 - _progressFraction,
                    minHeight: 8,
                    backgroundColor: kSurfaceContainerLow,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      daysLeft <= 7
                          ? kOverdue
                          : daysLeft <= 30
                              ? kPending
                              : planColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final (bg, text, label) = switch (_member.status) {
      MemberStatus.active => (
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
          'Active',
        ),
      MemberStatus.expired => (
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C),
          'Expired',
        ),
      MemberStatus.frozen => (
          const Color(0xFFDBEAFE),
          const Color(0xFF1E40AF),
          'Frozen',
        ),
      MemberStatus.cancelled => (
          const Color(0xFFF3F4F6),
          const Color(0xFF6B7280),
          'Cancelled',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Payment Summary Card ───────────────────────────────────────────────────

  Widget _buildPaymentSummaryCard() {
    final hasJoiningFee = _isRecurring && _member.joiningFeePaid > 0;
    final hasDiscount = _plan.discountPercent > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kOnSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: kSurfaceContainer),
          const SizedBox(height: 12),
          _SummaryLine(
            label: _isRecurring ? 'Plan Price' : 'Package Fee',
            value: _currencyFormat.format(_plan.price),
          ),
          if (hasDiscount) ...[
            const SizedBox(height: 8),
            _SummaryLine(
              label: 'Discount (${_plan.discountPercent.toStringAsFixed(0)}%)',
              value: '-${_currencyFormat.format(_discountAmount)}',
              valueColor: const Color(0xFFEF4444),
            ),
          ],
          if (hasJoiningFee) ...[
            const SizedBox(height: 8),
            _SummaryLine(
              label: 'Joining Fee',
              value: _currencyFormat.format(_member.joiningFeePaid),
            ),
          ],
          const SizedBox(height: 8),
          _SummaryLine(
            label: 'Payment Status',
            value: _member.amountPaid >= _plan.effectivePrice ? 'Paid' : 'Pending',
            valueColor: _member.amountPaid >= _plan.effectivePrice
                ? const Color(0xFF15803D)
                : const Color(0xFFB45309),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: kOutlineVariant, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kOnSurface,
                ),
              ),
              Text(
                _currencyFormat.format(_totalAmount),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── PDF Generation ─────────────────────────────────────────────────────────

  Future<Uint8List> _buildMembershipPdf() async {
    final pdf = pw.Document();
    final profile = _profile;
    final businessName = profile?.storeName.trim().isNotEmpty == true
        ? profile!.storeName
        : 'BillRaja';

    // Parse plan color for PDF
    PdfColor planPdfColor;
    try {
      final hex = _plan.colorHex.replaceFirst('#', '');
      final r = int.parse(hex.substring(0, 2), radix: 16) / 255;
      final g = int.parse(hex.substring(2, 4), radix: 16) / 255;
      final b = int.parse(hex.substring(4, 6), radix: 16) / 255;
      planPdfColor = PdfColor(r, g, b);
    } catch (_) {
      planPdfColor = const PdfColor(0.0, 0.34, 1.0);
    }

    final headerTextStyle = pw.TextStyle(
      color: PdfColors.white,
      fontSize: 10,
    );
    final headerBoldStyle = pw.TextStyle(
      color: PdfColors.white,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );
    final bodyText = const pw.TextStyle(fontSize: 10);
    final bodyBold = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
    final labelStyle = pw.TextStyle(
      fontSize: 9,
      color: const PdfColor(0.45, 0.51, 0.62),
    );
    final titleStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: const PdfColor(0.08, 0.13, 0.22),
    );
    final sectionTitle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: const PdfColor(0.2, 0.25, 0.35),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(24),
                color: planPdfColor,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      businessName,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (profile?.address.trim().isNotEmpty == true)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(profile!.address, style: headerTextStyle),
                      ),
                    if (profile?.phoneNumber.trim().isNotEmpty == true)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Phone: ${profile!.phoneNumber}',
                          style: headerTextStyle,
                        ),
                      ),
                    pw.SizedBox(height: 16),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('MEMBERSHIP INVOICE', style: headerBoldStyle),
                        pw.Text(_invoiceNumber, style: headerBoldStyle),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Date: ${_dateFormat.format(_member.startDate)}',
                      style: headerTextStyle,
                    ),
                  ],
                ),
              ),
              // ── Body ──────────────────────────────
              pw.Padding(
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Member details
                    pw.Text('Member Details', style: sectionTitle),
                    pw.SizedBox(height: 8),
                    _pdfRow('Name', _member.name, bodyText, bodyBold),
                    if (_member.phone.trim().isNotEmpty)
                      _pdfRow('Phone', _member.phone, bodyText, bodyBold),
                    if (_member.email.trim().isNotEmpty)
                      _pdfRow('Email', _member.email, bodyText, bodyBold),
                    _pdfRow('Member Since',
                        _dateFormat.format(_member.startDate), bodyText, bodyBold),
                    pw.SizedBox(height: 20),

                    // Plan details table
                    pw.Text('Plan Details', style: sectionTitle),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: const PdfColor(0.87, 0.90, 0.95),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1),
                        1: const pw.FlexColumnWidth(1),
                      },
                      children: [
                        _pdfTableRow(
                            'Plan Name', _plan.name, bodyText, bodyBold,
                            bg: planPdfColor.shade(0.05)),
                        _pdfTableRow('Type',
                            _isRecurring ? 'Recurring' : 'Package', bodyText, bodyBold),
                        _pdfTableRow(
                            'Duration', _plan.durationLabel, bodyText, bodyBold,
                            bg: planPdfColor.shade(0.05)),
                        _pdfTableRow('Start Date',
                            _dateFormat.format(_member.startDate), bodyText, bodyBold),
                        _pdfTableRow('End Date',
                            _dateFormat.format(_member.endDate), bodyText, bodyBold,
                            bg: planPdfColor.shade(0.05)),
                        if (_isRecurring)
                          _pdfTableRow('Next Renewal',
                              _dateFormat.format(_nextRenewalDate), bodyText, bodyBold),
                        _pdfTableRow('Status', _member.status.name[0].toUpperCase() +
                            _member.status.name.substring(1), bodyText, bodyBold,
                            bg: _isRecurring ? null : planPdfColor.shade(0.05)),
                      ],
                    ),
                    pw.SizedBox(height: 20),

                    // Payment summary
                    pw.Text('Payment Summary', style: sectionTitle),
                    pw.SizedBox(height: 8),
                    _pdfRow(
                      _isRecurring ? 'Plan Price' : 'Package Fee',
                      _currencyFormat.format(_plan.price),
                      bodyText,
                      bodyBold,
                    ),
                    if (_plan.discountPercent > 0)
                      _pdfRow(
                        'Discount (${_plan.discountPercent.toStringAsFixed(0)}%)',
                        '-${_currencyFormat.format(_discountAmount)}',
                        bodyText,
                        bodyBold,
                      ),
                    if (_isRecurring && _member.joiningFeePaid > 0)
                      _pdfRow(
                        'Joining Fee',
                        _currencyFormat.format(_member.joiningFeePaid),
                        bodyText,
                        bodyBold,
                      ),
                    pw.Divider(color: const PdfColor(0.87, 0.90, 0.95)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Amount', style: titleStyle),
                        pw.Text(
                          _currencyFormat.format(_totalAmount),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: planPdfColor,
                          ),
                        ),
                      ],
                    ),
                    if (_isRecurring) ...[
                      pw.SizedBox(height: 20),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: planPdfColor.shade(0.05),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text('Next Renewal: ', style: bodyBold),
                            pw.Text(
                              _dateFormat.format(_nextRenewalDate),
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: planPdfColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Spacer(),
              // ── Footer ────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                color: const PdfColor(0.97, 0.98, 1.00),
                child: pw.Center(
                  child: pw.Text(
                    'Generated by BillRaja',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: const PdfColor(0.45, 0.51, 0.62),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfRow(
    String label,
    String value,
    pw.TextStyle textStyle,
    pw.TextStyle boldStyle,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: textStyle),
          pw.Text(value, style: boldStyle),
        ],
      ),
    );
  }

  pw.TableRow _pdfTableRow(
    String label,
    String value,
    pw.TextStyle textStyle,
    pw.TextStyle boldStyle, {
    PdfColor? bg,
  }) {
    return pw.TableRow(
      decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: textStyle),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: boldStyle),
        ),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _buildMembershipPdf();
      await Printing.layoutPdf(
        name: 'MembershipInvoice_${_member.name.replaceAll(' ', '_')}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('PDF error: $error')),
        );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _shareViaWhatsApp() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _buildMembershipPdf();
      final dir = await getTemporaryDirectory();
      final fileName =
          'MembershipInvoice_${_member.name.replaceAll(' ', '_')}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Hi ${_member.name}, here is your membership invoice for the ${_plan.name} plan. '
            'Valid till ${_dateFormat.format(_member.endDate)}.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Share error: $error')),
        );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _HeaderMetaTile extends StatelessWidget {
  const _HeaderMetaTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white.withOpacity(0.8)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: kOnSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: kOnSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Container(height: 1, color: kSurfaceContainerLow),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.valueColor = kOnSurface,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: kOnSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
