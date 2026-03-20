import 'dart:io';

import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/services/eway_bill_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/screens/upgrade_screen.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:share_plus/share_plus.dart';

BoxDecoration _cardDeco() => BoxDecoration(
      color: kSurfaceLowest,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [kSubtleShadow],
    );

class EWayBillScreen extends StatefulWidget {
  const EWayBillScreen({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<EWayBillScreen> createState() => _EWayBillScreenState();
}

class _EWayBillScreenState extends State<EWayBillScreen> {
  final _service = EWayBillService();
  final _profileService = ProfileService();
  final _vehicleCtrl = TextEditingController();
  final _transporterGstinCtrl = TextEditingController();
  final _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final _dateFmt = DateFormat('dd MMM yyyy');

  String _transportMode = '1';
  bool _isGenerating = false;

  static const _transportModes = {
    '1': 'Road',
    '2': 'Rail',
    '3': 'Air',
    '4': 'Ship',
  };

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _transporterGstinCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateAndShare(BusinessProfile? profile) async {
    if (profile == null) {
      _showSnack('Business profile not loaded. Please try again.');
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final json = _service.buildJson(
        invoice: widget.invoice,
        profile: profile,
        vehicleNo: _vehicleCtrl.text.trim(),
        transporterGstin: _transporterGstinCtrl.text.trim(),
        transportMode: _transportMode,
      );
      final jsonStr = _service.toJsonString(json);

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/eway_bill_${widget.invoice.invoiceNumber}.json',
      );
      await file.writeAsString(jsonStr);

      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject:
              'E-Way Bill JSON — ${widget.invoice.invoiceNumber}',
          text:
              'E-Way Bill data for invoice ${widget.invoice.invoiceNumber}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to generate JSON: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _openPortal() {
    SharePlus.instance.share(
      ShareParams(
        text: 'Open this URL to file E-Way Bill: https://ewaybillgst.gov.in',
        subject: 'E-Way Bill Portal',
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (!PlanService.instance.hasEwayBill) {
      return Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          title: const Text('E-Way Bill'),
          backgroundColor: kSurface,
          foregroundColor: kOnSurface,
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
                const Icon(Icons.lock_outline, size: 64, color: kSurfaceDim),
                const SizedBox(height: 16),
                const Text('E-Way Bill', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kOnSurface)),
                const SizedBox(height: 8),
                const Text('Upgrade to Maharaja plan to generate E-Way Bills.', textAlign: TextAlign.center, style: TextStyle(color: kOnSurfaceVariant)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen(featureName: 'E-Way Bill'))),
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Upgrade Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
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

    return StreamBuilder<BusinessProfile?>(
      stream: _profileService.watchCurrentProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final validationErrors = profile != null
            ? _service.validate(widget.invoice, profile)
            : <String>[];

        return Scaffold(
          backgroundColor: kSurface,
          appBar: AppBar(
            backgroundColor: kSurface,
            foregroundColor: kOnSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'E-Way Bill',
              style: TextStyle(
                color: kOnSurface,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // ── Info banner ────────────────────────────────────────────
                _buildInfoBanner(),
                const SizedBox(height: 16),

                // ── Validation errors ──────────────────────────────────────
                if (validationErrors.isNotEmpty) ...[
                  _buildErrorCard(validationErrors),
                  const SizedBox(height: 16),
                ],

                // ── Invoice summary ────────────────────────────────────────
                _buildInvoiceSummary(),
                const SizedBox(height: 16),

                // ── Items preview ──────────────────────────────────────────
                _buildItemsPreview(),
                const SizedBox(height: 16),

                // ── Transport form ─────────────────────────────────────────
                _buildTransportForm(),
                const SizedBox(height: 24),

                // ── Action buttons ─────────────────────────────────────────
                _buildActionButtons(profile, validationErrors),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Info banner ─────────────────────────────────────────────────────────────

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kPrimaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: kPrimary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Manual upload required. Direct filing via NIC API coming soon.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Validation error card ───────────────────────────────────────────────────

  Widget _buildErrorCard(List<String> errors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: Color(0xFFB91C1C),
              ),
              SizedBox(width: 8),
              Text(
                'Issues to fix before filing',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...errors.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F1D1D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Invoice summary ─────────────────────────────────────────────────────────

  Widget _buildInvoiceSummary() {
    final inv = widget.invoice;
    final gstLabel = inv.gstEnabled
        ? (inv.gstType == 'igst'
            ? 'IGST ${inv.gstRate.toStringAsFixed(0)}%'
            : 'CGST+SGST ${inv.gstRate.toStringAsFixed(0)}%')
        : 'No GST';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice Summary',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kOnSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: kSurfaceDim),
          const SizedBox(height: 12),
          _summaryRow('Invoice #', inv.invoiceNumber),
          _summaryRow('Date', _dateFmt.format(inv.createdAt)),
          _summaryRow('Customer', inv.clientName),
          _summaryRow(
            'Amount',
            _currencyFmt.format(inv.grandTotal),
            valueColor: kPrimary,
          ),
          _summaryRow('GST Type', gstLabel),
          if (inv.placeOfSupply.isNotEmpty)
            _summaryRow('Place of Supply', inv.placeOfSupply),
          if (inv.customerGstin.isNotEmpty)
            _summaryRow('Customer GSTIN', inv.customerGstin),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: kOnSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? kOnSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // ── Items preview ───────────────────────────────────────────────────────────

  Widget _buildItemsPreview() {
    final items = widget.invoice.items;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Items',
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
                  color: kSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: kSurfaceDim),
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final hsnMissing = item.hsnCode.trim().isEmpty;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: kSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.description,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kOnSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _pill(
                                  'Qty: ${item.quantityLabel}',
                                  kOnSurfaceVariant,
                                  kSurfaceContainerLow,
                                ),
                                const SizedBox(width: 6),
                                _pill(
                                  hsnMissing
                                      ? 'HSN: missing'
                                      : 'HSN: ${item.hsnCode}',
                                  hsnMissing
                                      ? const Color(0xFFB91C1C)
                                      : kPrimary,
                                  hsnMissing
                                      ? const Color(0xFFFEE2E2)
                                      : kPrimaryContainer,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _currencyFmt.format(item.total),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kOnSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < items.length - 1)
                  Container(height: 1, color: kSurfaceContainerLow),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _pill(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Transport form ──────────────────────────────────────────────────────────

  Widget _buildTransportForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transport Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kOnSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Transport Mode dropdown
          const Text(
            'Transport Mode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _transportMode,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kOutlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kOutlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimary, width: 1.5),
              ),
              filled: true,
              fillColor: kSurfaceLowest,
            ),
            items: _transportModes.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _transportMode = val);
            },
          ),
          const SizedBox(height: 14),

          // Vehicle Number
          const Text(
            'Vehicle Number',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _vehicleCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'e.g. MH12AB1234',
              hintStyle: const TextStyle(color: kTextTertiary, fontSize: 13),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kOutlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kOutlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimary, width: 1.5),
              ),
              filled: true,
              fillColor: kSurfaceLowest,
            ),
          ),
          const SizedBox(height: 14),

          // Transporter GSTIN
          const Text(
            'Transporter GSTIN (optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _transporterGstinCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Enter if applicable',
              hintStyle: const TextStyle(color: kTextTertiary, fontSize: 13),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kOutlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kOutlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimary, width: 1.5),
              ),
              filled: true,
              fillColor: kSurfaceLowest,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ──────────────────────────────────────────────────────────

  Widget _buildActionButtons(
    BusinessProfile? profile,
    List<String> errors,
  ) {
    final canGenerate = profile != null;

    return Column(
      children: [
        // Generate & Share JSON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canGenerate && !_isGenerating
                ? () => _generateAndShare(profile)
                : null,
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(
              _isGenerating ? 'Generating…' : 'Generate & Share JSON',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: kSurfaceDim,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Open E-Way Bill Portal
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openPortal,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text(
              'Open E-Way Bill Portal',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: kOnSurface,
              side: BorderSide(color: kOutlineVariant, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        if (errors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Fix the issues above before generating the E-Way Bill JSON.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFFB91C1C).withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
