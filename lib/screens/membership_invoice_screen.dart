import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/line_item.dart';
import 'package:billeasy/modals/member.dart';
import 'package:billeasy/modals/subscription_plan.dart';
import 'package:billeasy/screens/template_picker_sheet.dart';
import 'package:billeasy/services/invoice_pdf_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

BoxDecoration _cardDeco(BuildContext context) => BoxDecoration(
  color: context.cs.surfaceContainerLowest,
  borderRadius: const BorderRadius.all(Radius.circular(20)),
  boxShadow: const [kWhisperShadow],
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

  static const _kTemplatePrefsKey = 'membership_invoice_template';
  bool _isGeneratingPdf = false;
  BusinessProfile? _profile;
  InvoiceTemplate _template = InvoiceTemplate.vyapar;

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

  int get _totalDuration =>
      _member.endDate.difference(_member.startDate).inDays;

  double get _progressFraction {
    if (_totalDuration <= 0) return 1.0;
    final elapsed = DateTime.now()
        .difference(_member.startDate)
        .inDays
        .clamp(0, _totalDuration);
    return elapsed / _totalDuration;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTemplate();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService().getCurrentProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      debugPrint('[MembershipInvoice] Profile load failed: $e');
    }
  }

  Future<void> _loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kTemplatePrefsKey);
    if (saved != null && mounted) {
      final t = InvoiceTemplate.values.where((e) => e.name == saved);
      if (t.isNotEmpty) setState(() => _template = t.first);
    }
  }

  Future<void> _pickTemplate() async {
    final picked = await showModalBottomSheet<InvoiceTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TemplatePicker(current: _template),
    );
    if (picked != null && mounted) {
      setState(() => _template = picked);
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(_kTemplatePrefsKey, picked.name);
    }
  }

  /// Convert membership data into an Invoice for the template-based PDF generator.
  Invoice _toInvoice() {
    final items = <LineItem>[
      LineItem(
        description:
            '${_plan.name} (${_plan.durationLabel}${_isRecurring ? ' - Recurring' : ' - Package'})',
        quantity: 1,
        unitPrice: _plan.price,
      ),
    ];
    if (_isRecurring && _member.joiningFeePaid > 0) {
      items.add(
        LineItem(
          description: 'Joining Fee (one-time)',
          quantity: 1,
          unitPrice: _member.joiningFeePaid,
        ),
      );
    }
    return Invoice(
      id: _invoiceNumber,
      ownerId: _member.ownerId,
      invoiceNumber: _invoiceNumber,
      clientId: _member.id,
      clientName: _member.name,
      items: items,
      createdAt: _member.startDate,
      status: InvoiceStatus.paid,
      dueDate: _member.endDate,
      discountType: _plan.discountPercent > 0
          ? InvoiceDiscountType.percentage
          : null,
      discountValue: _plan.discountPercent,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: kBuildGradientAppBar(
        titleText: 'Membership Invoice',
        actions: [
          IconButton(
            onPressed: _pickTemplate,
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Change Template',
          ),
        ],
      ),
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
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
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
                  foregroundColor: context.cs.onSurface,
                  side: BorderSide(color: context.cs.outlineVariant),
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
                  backgroundColor: context.cs.primary,
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
          Container(height: 1, color: Colors.white.withOpacity(0.2)),
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
      decoration: _cardDeco(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Member Details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
            ),
          ),
          Container(height: 1, color: context.cs.surfaceContainer),
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
      decoration: _cardDeco(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  'Plan Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
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
          Container(height: 1, color: context.cs.surfaceContainer),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _plan.durationLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.cs.onSurfaceVariant,
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
                color: context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Date',
                          style: TextStyle(
                            color: context.cs.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateFormat.format(_member.startDate),
                          style: TextStyle(
                            color: context.cs.onSurface,
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
                        Text(
                          'End Date',
                          style: TextStyle(
                            color: context.cs.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateFormat.format(_member.endDate),
                          style: TextStyle(
                            color: context.cs.onSurface,
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
                  border: Border.all(color: planColor.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.autorenew_rounded, size: 18, color: planColor),
                    const SizedBox(width: 10),
                    Text(
                      'Next Renewal',
                      style: TextStyle(
                        color: context.cs.onSurfaceVariant,
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '$totalDays days total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.cs.onSurfaceVariant.withAlpha(153),
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
                    backgroundColor: context.cs.surfaceContainerLow,
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
      decoration: _cardDeco(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: context.cs.surfaceContainer),
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
            value: _member.amountPaid >= _plan.effectivePrice
                ? 'Paid'
                : 'Pending',
            valueColor: _member.amountPaid >= _plan.effectivePrice
                ? const Color(0xFF15803D)
                : const Color(0xFFB45309),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: context.cs.outlineVariant, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
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

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf() async {
    // Use the same template system as regular invoices
    final invoice = _toInvoice();
    final pdfService = InvoicePdfService();
    return pdfService.buildInvoicePdf(
      invoice: invoice,
      profile: _profile,
      template: _template,
      includePayment: false,
    );
  }

  Future<void> _downloadPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _generatePdf();
      await Printing.layoutPdf(
        name: 'MembershipInvoice_${_member.name.replaceAll(' ', '_')}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              userFriendlyError(
                error,
                fallback: 'Failed to generate PDF. Please try again.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _shareViaWhatsApp() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _generatePdf();
      final text =
          'Hi ${_member.name}, here is your membership invoice for the ${_plan.name} plan. '
          'Valid till ${_dateFormat.format(_member.endDate)}.';

      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'application/pdf',
                name:
                    'MembershipInvoice_${_member.name.replaceAll(' ', '_')}.pdf',
              ),
            ],
            text: text,
          ),
        );
      } else {
        final dir = await getTemporaryDirectory();
        final fileName =
            'MembershipInvoice_${_member.name.replaceAll(' ', '_')}.pdf';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles([XFile(file.path)], text: text);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              userFriendlyError(
                error,
                fallback: 'Failed to share. Please try again.',
              ),
            ),
          ),
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
                  style: TextStyle(
                    color: context.cs.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: context.cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Container(height: 1, color: context.cs.surfaceContainerLow),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.cs.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? context.cs.onSurface,
          ),
        ),
      ],
    );
  }
}
