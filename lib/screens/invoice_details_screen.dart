import 'dart:io';
import 'dart:typed_data';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/customer_details_screen.dart';
import 'package:billeasy/screens/eway_bill_screen.dart';
import 'package:billeasy/screens/template_picker_sheet.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/invoice_pdf_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/whatsapp_share_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTemplatePrefsKey = 'invoice_template';

BoxDecoration _cardDeco() => const BoxDecoration(
      color: kSurfaceLowest,
      borderRadius: BorderRadius.all(Radius.circular(20)),
      boxShadow: [kWhisperShadow],
    );

// ────────────────────────────────────────────────────────────────────────────

class InvoiceDetailsScreen extends StatefulWidget {
  const InvoiceDetailsScreen({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  InvoiceTemplate _template = InvoiceTemplate.vyapar;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kTemplatePrefsKey);
    if (saved != null) {
      final match = InvoiceTemplate.values.where((t) => t.name == saved);
      if (match.isNotEmpty && mounted) {
        setState(() => _template = match.first);
      }
    }
  }

  Future<void> _saveTemplate(InvoiceTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTemplatePrefsKey, template.name);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final customerName = invoice.clientName;
    final Stream<BusinessProfile?> profileStream =
        ProfileService().watchCurrentProfile();

    return StreamBuilder<BusinessProfile?>(
      stream: profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final s = AppStrings.of(context);
        final sellerName = _sellerName(profile, s);

        return Scaffold(
          backgroundColor: kSurface,
          appBar: AppBar(
            backgroundColor: kSurface,
            foregroundColor: kOnSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              s.detailsTitle,
              style: const TextStyle(
                color: kOnSurface,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            actions: [
              // Change template icon button
              IconButton(
                tooltip: 'Change Template',
                icon: const Icon(Icons.style_rounded, color: kOnSurfaceVariant),
                onPressed: () => _changeTemplate(context, profile, s),
              ),
            ],
          ),

          // ── Bottom action bar ────────────────────────────────────────────
          bottomNavigationBar: Container(
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
                      onPressed: () =>
                          _previewInvoicePdf(context, profile),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(s.detailsPreviewPrint),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kOnSurface,
                        side: const BorderSide(color: kOutlineVariant),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Share button → opens WhatsAppShareSheet
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _openShareSheet(context, profile),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: Text(s.detailsSharePdf),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 20),
              children: [
                // ── Hero card ───────────────────────────────────────────
                _buildHeroCard(context, s, customerName, sellerName),
                const SizedBox(height: 16),

                // ── Seller ──────────────────────────────────────────────
                _SectionCard(
                  title: s.detailsSeller,
                  children: [
                    _InfoRow(
                        label: s.detailsStore, value: sellerName),
                    _InfoRow(
                      label: s.detailsAddress,
                      value: _profileValueOrFallback(
                        profile?.address,
                        s.detailsNotAddedYet,
                      ),
                    ),
                    _InfoRow(
                      label: s.detailsPhone,
                      value: _profileValueOrFallback(
                        profile?.phoneNumber,
                        s.detailsNotAddedYet,
                      ),
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Customer ─────────────────────────────────────────────
                _buildCustomerCard(context, s, customerName),
                const SizedBox(height: 16),

                // ── Items ─────────────────────────────────────────────────
                _buildItemsCard(context, s),
                const SizedBox(height: 16),

                // ── Summary ───────────────────────────────────────────────
                _buildSummaryCard(context, s),
                const SizedBox(height: 8),

                // ── E-Way Bill button ─────────────────────────────────────
                if (widget.invoice.grandTotal > 50000 &&
                    widget.invoice.gstEnabled)
                  _buildEWayBillButton(context),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── E-Way Bill ─────────────────────────────────────────────────────────────

  Widget _buildEWayBillButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EWayBillScreen(invoice: widget.invoice),
              ),
            );
          },
          icon: const Icon(Icons.local_shipping_outlined, size: 18, color: kPrimary),
          label: const Text(
            'Generate E-Way Bill',
            style: TextStyle(
              color: kPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: kPrimary,
            side: const BorderSide(color: kPrimary, width: 1.4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  // ── Change Template ────────────────────────────────────────────────────────

  Future<void> _changeTemplate(
    BuildContext context,
    BusinessProfile? profile,
    AppStrings s,
  ) async {
    final result = await showModalBottomSheet<InvoiceTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TemplatePicker(current: _template),
    );
    if (result != null && result != _template) {
      setState(() => _template = result);
      await _saveTemplate(result);
    }
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard(
    BuildContext context,
    AppStrings s,
    String customerName,
    String sellerName,
  ) {
    final invoice = widget.invoice;
    final initials = customerName.trim().isEmpty
        ? '?'
        : customerName
            .trim()
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + info + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: kSignatureGradient,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
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
                        color: kOnSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customerName,
                      style: const TextStyle(
                        color: kOnSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      s.detailsIssuedBy(sellerName),
                      style: const TextStyle(
                        color: kOnSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: invoice.status),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: kSurfaceContainer),
          const SizedBox(height: 16),
          // Bottom row: date + grand total
          Row(
            children: [
              Expanded(
                child: _MetaTile(
                  icon: Icons.calendar_today_outlined,
                  label: s.createInvoiceDate,
                  value: _dateFormat.format(invoice.createdAt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetaTile(
                  icon: Icons.currency_rupee_rounded,
                  label: s.createSummaryGrandTotal,
                  value: _currencyFormat.format(invoice.grandTotal),
                  valueColor: kPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Customer card ─────────────────────────────────────────────────────────

  Widget _buildCustomerCard(
      BuildContext context, AppStrings s, String customerName) {
    return StreamBuilder<Client?>(
      stream: ClientService().watchClient(widget.invoice.clientId),
      builder: (context, clientSnapshot) {
        final client = clientSnapshot.data;
        return _SectionCard(
          title: s.detailsCustomer,
          children: [
            _InfoRow(label: s.detailsName, value: customerName),
            _InfoRow(
                label: s.detailsReference, value: widget.invoice.clientId),
            if (client != null && client.phone.trim().isNotEmpty)
              _InfoRow(
                  label: s.detailsPhone,
                  value: client.phone.trim()),
            if (client != null && client.email.trim().isNotEmpty)
              _InfoRow(
                  label: s.detailsEmail,
                  value: client.email.trim()),
            if (client != null && client.address.trim().isNotEmpty)
              _InfoRow(
                label: s.detailsAddress,
                value: client.address.trim(),
                isLast: false,
              ),
            if (client != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerDetailsScreen(client: client),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_search_outlined,
                      size: 16, color: kPrimary),
                  label: Text(
                    s.detailsOpenProfile,
                    style: const TextStyle(
                        color: kPrimary,
                        fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Items card ─────────────────────────────────────────────────────────────

  Widget _buildItemsCard(BuildContext context, AppStrings s) {
    final invoice = widget.invoice;
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
                  '',
                  // section title placeholder — text below
                ),
                Text(
                  s.detailsItems,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kOnSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${invoice.items.length} ${invoice.items.length == 1 ? "item" : "items"}',
                    style: const TextStyle(
                      color: kPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: kSurfaceContainerLow),
          // Item rows
          ...invoice.items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isLast = i == invoice.items.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: kSurfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: kPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.description,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kOnSurface,
                              ),
                            ),
                          ),
                          Text(
                            _currencyFormat.format(item.total),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kOnSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const SizedBox(width: 34),
                          _ItemPill(
                              label:
                                  'Qty: ${item.quantityLabel}'),
                          const SizedBox(width: 8),
                          _ItemPill(
                            label:
                                '@ ${_currencyFormat.format(item.unitPrice)}',
                          ),
                          if (widget.invoice.gstEnabled && item.gstRate > 0) ...[
                            const SizedBox(width: 8),
                            _ItemPill(label: 'GST: ${item.gstRate.toStringAsFixed(0)}%'),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                      height: 1,
                      color: kSurfaceContainerLow,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16)),
              ],
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(BuildContext context, AppStrings s) {
    final invoice = widget.invoice;
    final hasDiscount = invoice.hasDiscount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _SummaryLine(
            label: s.detailsSubtotal,
            value: _currencyFormat.format(invoice.subtotal),
          ),
          if (hasDiscount) ...[
            const SizedBox(height: 8),
            _SummaryLine(
              label: s.detailsDiscount,
              value:
                  '${_discountLabel(invoice, s)} (-${_currencyFormat.format(invoice.discountAmount)})',
              valueColor: const Color(0xFFEF4444),
            ),
          ],
          if (invoice.hasGst) ...[
            const SizedBox(height: 8),
            if (invoice.gstType == 'cgst_sgst') ...[
              _SummaryLine(
                label: 'CGST',
                value: '+${_currencyFormat.format(invoice.cgstAmount)}',
                valueColor: const Color(0xFF059669),
              ),
              const SizedBox(height: 4),
              _SummaryLine(
                label: 'SGST',
                value: '+${_currencyFormat.format(invoice.sgstAmount)}',
                valueColor: const Color(0xFF059669),
              ),
            ] else
              _SummaryLine(
                label: 'IGST',
                value: '+${_currencyFormat.format(invoice.igstAmount)}',
                valueColor: const Color(0xFF059669),
              ),
          ],
          const SizedBox(height: 8),
          _SummaryLine(
            label: s.detailsItemsCount,
            value: invoice.items.length.toString(),
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            label: s.detailsStatus,
            value: _statusLabel(invoice.status, s),
            valueColor: _statusTextColor(invoice.status),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: kOutlineVariant, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.createSummaryGrandTotal,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kOnSurface,
                ),
              ),
              Text(
                _currencyFormat.format(invoice.grandTotal),
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

  // ── Logic ─────────────────────────────────────────────────────────────────

  Future<void> _previewInvoicePdf(
    BuildContext context,
    BusinessProfile? profile,
  ) async {
    final language = AppStrings.of(context).language;
    try {
      final bytes = await _buildPdfBytes(profile, language, includePayment: false);
      await Printing.layoutPdf(
        name: InvoicePdfService().fileNameForInvoice(widget.invoice),
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (!context.mounted) return;
      _showExportError(context, error);
    }
  }

  /// Generates the PDF, saves it to a temp file, then opens [WhatsAppShareSheet].
  Future<void> _openShareSheet(
    BuildContext context,
    BusinessProfile? profile,
  ) async {
    final language = AppStrings.of(context).language;
    File? pdfFile;
    Uint8List? pdfBytes;
    String? clientPhone;

    try {
      pdfBytes = await _buildPdfBytes(profile, language, includePayment: false);
      final dir = await getTemporaryDirectory();
      final fileName = InvoicePdfService().fileNameForInvoice(widget.invoice);
      pdfFile = File('${dir.path}/$fileName');
      await pdfFile.writeAsBytes(pdfBytes);
    } catch (_) {
      // PDF generation failed — we'll still open the sheet without a file
    }

    // Try fetching client phone
    try {
      final client = await ClientService().getClient(widget.invoice.clientId);
      clientPhone = client?.phone;
    } catch (_) {
      // ignore — sheet handles missing phone
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WhatsAppShareSheet(
        invoice: widget.invoice,
        pdfFile: pdfFile,
        pdfBytes: pdfBytes,
        currencyFormat: _currencyFormat,
        clientPhone: clientPhone,
      ),
    );
  }

  Future<Uint8List> _buildPdfBytes(
    BusinessProfile? profile,
    AppLanguage language, {
    bool includePayment = true,
  }) async {
    final resolvedProfile = await _resolveProfile(profile);
    return InvoicePdfService().buildInvoicePdf(
      invoice: widget.invoice,
      profile: resolvedProfile,
      language: language,
      template: _template,
      includePayment: includePayment,
    );
  }

  Future<BusinessProfile?> _resolveProfile(
      BusinessProfile? profile) async {
    if (profile != null) return profile;
    try {
      return await ProfileService().getCurrentProfile();
    } catch (_) {
      return profile;
    }
  }

  void _showExportError(BuildContext context, Object error) {
    final s = AppStrings.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
            content: Text(s.detailsPdfError(error.toString()))),
      );
  }

  String _sellerName(BusinessProfile? profile, AppStrings s) {
    final storeName = profile?.storeName.trim() ?? '';
    return storeName.isNotEmpty ? storeName : s.detailsYourStore;
  }

  String _profileValueOrFallback(String? value, String fallback) {
    final normalized = value?.trim() ?? '';
    return normalized.isNotEmpty ? normalized : fallback;
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

  String _discountLabel(Invoice invoice, AppStrings s) {
    if (invoice.discountType == null || invoice.discountValue <= 0) {
      return s.detailsNoDiscount;
    }
    switch (invoice.discountType!) {
      case InvoiceDiscountType.percentage:
        final value = invoice.discountValue;
        final formattedValue = value.truncateToDouble() == value
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(2);
        return s.detailsPctOff(formattedValue);
      case InvoiceDiscountType.overall:
        return s.detailsOverallDiscount;
    }
  }

  Color _statusTextColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return const Color(0xFF15803D);
      case InvoiceStatus.pending:
        return const Color(0xFFB45309);
      case InvoiceStatus.overdue:
        return const Color(0xFFB91C1C);
    }
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

/// White card section with a title and a list of rows separated by dividers.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kOnSurface,
              ),
            ),
          ),
          Container(height: 1, color: kSurfaceContainer),
          ...children,
        ],
      ),
    );
  }
}

/// Label + value row inside a _SectionCard, with an optional divider below.
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
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
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

/// Small pill badge for status (Paid / Pending / Overdue).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, text, label) = switch (status) {
      InvoiceStatus.paid => (
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
          'Paid',
        ),
      InvoiceStatus.pending => (
          const Color(0xFFFEF3C7),
          const Color(0xFFB45309),
          'Pending',
        ),
      InvoiceStatus.overdue => (
          const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C),
          'Overdue',
        ),
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
}

/// Two-line tile showing an icon, label, and value — used in the hero card.
class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = kOnSurface,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kOnSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: kOnSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
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
    );
  }
}

/// Small gray pill used inside item rows (qty, unit price).
class _ItemPill extends StatelessWidget {
  const _ItemPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kOnSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Label + value in a horizontal row for the summary section.
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
