import 'dart:typed_data';

import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/services/invoice_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Flutter widget color theme matching the PDF _VyColors.
class InvoiceColors {
  final Color primary;
  final Color labelBg;
  final Color border;
  final Color black;
  final Color body;
  final Color muted;
  const InvoiceColors(this.primary, this.labelBg, this.border, this.black, this.body, this.muted);
}

/// Maps each InvoiceTemplate to Flutter Colors — high contrast, modern.
/// primary: bold header/accent, labelBg: tinted header row, border: visible grid,
/// black: #000 text, body: dark secondary text, muted: tertiary.
const Map<InvoiceTemplate, InvoiceColors> templateColorMap = {
  //                                    primary               labelBg               border                black                 body                  muted
  InvoiceTemplate.vyapar:       InvoiceColors(Color(0xFF0B57D0), Color(0xFFD3E3FD), Color(0xFF7CACF8), Color(0xFF000000), Color(0xFF1D1D1F), Color(0xFF6B6B6B)),
  InvoiceTemplate.classic:      InvoiceColors(Color(0xFF1B3A5C), Color(0xFFD6E4F0), Color(0xFF8AACC8), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.modern:       InvoiceColors(Color(0xFF1A1A1A), Color(0xFFE8E8E8), Color(0xFFA0A0A0), Color(0xFF000000), Color(0xFF2D2D2D), Color(0xFF6E6E6E)),
  InvoiceTemplate.compact:      InvoiceColors(Color(0xFF1B7A3D), Color(0xFFCCF0D8), Color(0xFF6DC08A), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.minimalist:   InvoiceColors(Color(0xFF3C3C3C), Color(0xFFECECEC), Color(0xFFB0B0B0), Color(0xFF111111), Color(0xFF2A2A2A), Color(0xFF787878)),
  InvoiceTemplate.bold:         InvoiceColors(Color(0xFFC62828), Color(0xFFFFCDD2), Color(0xFFE57373), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.elegant:      InvoiceColors(Color(0xFF5D4037), Color(0xFFEFEBE9), Color(0xFFBCAAA4), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF6D5D53)),
  InvoiceTemplate.professional: InvoiceColors(Color(0xFF0D47A1), Color(0xFFBBDEFB), Color(0xFF64B5F6), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.vibrant:      InvoiceColors(Color(0xFFD50000), Color(0xFFFFCDD2), Color(0xFFEF9A9A), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.clean:        InvoiceColors(Color(0xFF00838F), Color(0xFFB2EBF2), Color(0xFF4DD0E1), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.royal:        InvoiceColors(Color(0xFF6A1B9A), Color(0xFFE1BEE7), Color(0xFFCE93D8), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.stripe:       InvoiceColors(Color(0xFF01579B), Color(0xFFB3E5FC), Color(0xFF4FC3F7), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.grid:         InvoiceColors(Color(0xFF37474F), Color(0xFFCFD8DC), Color(0xFF90A4AE), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.pastel:       InvoiceColors(Color(0xFF8E24AA), Color(0xFFF3E5F5), Color(0xFFBA68C8), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.dark:         InvoiceColors(Color(0xFF263238), Color(0xFFCFD8DC), Color(0xFF78909C), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.retail:       InvoiceColors(Color(0xFFE65100), Color(0xFFFFE0B2), Color(0xFFFFB74D), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.wholesale:    InvoiceColors(Color(0xFF00695C), Color(0xFFB2DFDB), Color(0xFF4DB6AC), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.services:     InvoiceColors(Color(0xFF283593), Color(0xFFC5CAE9), Color(0xFF7986CB), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.creative:     InvoiceColors(Color(0xFFC2185B), Color(0xFFF8BBD0), Color(0xFFF06292), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.simple:       InvoiceColors(Color(0xFF424242), Color(0xFFE0E0E0), Color(0xFF9E9E9E), Color(0xFF000000), Color(0xFF212121), Color(0xFF616161)),
  InvoiceTemplate.gstPro:       InvoiceColors(Color(0xFF006064), Color(0xFFB2EBF2), Color(0xFF00ACC1), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  // Structurally different layouts
  InvoiceTemplate.banner:       InvoiceColors(Color(0xFF1565C0), Color(0xFFE3F2FD), Color(0xFF42A5F5), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.sidebarLayout:InvoiceColors(Color(0xFF2E7D32), Color(0xFFE8F5E9), Color(0xFF66BB6A), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.bordered:     InvoiceColors(Color(0xFF4E342E), Color(0xFFEFEBE9), Color(0xFF8D6E63), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.twoColumn:    InvoiceColors(Color(0xFFAD1457), Color(0xFFFCE4EC), Color(0xFFEC407A), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
  InvoiceTemplate.receipt:      InvoiceColors(Color(0xFF333333), Color(0xFFF5F5F5), Color(0xFF999999), Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF5C5C5C)),
};

/// A Flutter widget that renders the invoice exactly like the PDF.
/// Use inside a ScrollView — it never clips.
class InvoicePreviewWidget extends StatelessWidget {
  const InvoicePreviewWidget({
    super.key,
    required this.invoice,
    this.profile,
    this.template = InvoiceTemplate.vyapar,
    this.signatureImage,
    this.onSignatureTap,
    this.onTermsTap,
    this.termsText,
  });

  final Invoice invoice;
  final BusinessProfile? profile;
  final InvoiceTemplate template;
  final Uint8List? signatureImage;
  final VoidCallback? onSignatureTap;
  final VoidCallback? onTermsTap;
  final String? termsText;

  InvoiceColors get _c => templateColorMap[template] ?? templateColorMap[InvoiceTemplate.vyapar]!;

  String get _sellerName {
    final name = profile?.storeName.trim() ?? '';
    return name.isNotEmpty ? name : 'Your Store';
  }

  static final _dateFormat = DateFormat('dd-MM-yyyy');
  static final _numFormat = NumberFormat('#,##,##0.00', 'en_IN');

  String _fmt(double v) => _numFormat.format(v);

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final hasHsn = invoice.items.any((i) => i.hsnCode.isNotEmpty);
    final hasGst = invoice.gstEnabled;
    switch (template) {
      case InvoiceTemplate.banner:      return _buildBannerLayout(c, hasHsn, hasGst);
      case InvoiceTemplate.sidebarLayout: return _buildSidebarLayout(c, hasHsn, hasGst);
      case InvoiceTemplate.bordered:    return _buildBorderedLayout(c, hasHsn, hasGst);
      case InvoiceTemplate.twoColumn:   return _buildTwoColumnLayout(c, hasHsn, hasGst);
      case InvoiceTemplate.receipt:     return _buildReceiptLayout(c, hasHsn, hasGst);
      default:                          return _buildDefaultLayout(c, hasHsn, hasGst);
    }
  }

  // ── Default (Vyapar) Layout ──────────────────────────────────────────────────
  Widget _buildDefaultLayout(InvoiceColors c, bool hasHsn, bool hasGst) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Center(
              child: Text(
                'Tax Invoice',
                style: TextStyle(
                  color: c.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          // ── Seller Box ──
          _bordered(c, child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_sellerName, style: TextStyle(color: c.black, fontSize: 12, fontWeight: FontWeight.bold)),
                if (profile?.phoneNumber != null && profile!.phoneNumber.isNotEmpty)
                  Text('Phone no.: ${profile!.phoneNumber}', style: TextStyle(color: c.body, fontSize: 9)),
                if (profile?.address != null && profile!.address.isNotEmpty)
                  Text(profile!.address, style: TextStyle(color: c.body, fontSize: 9)),
                if (profile?.gstin != null && profile!.gstin.isNotEmpty)
                  Text('GSTIN: ${profile!.gstin}', style: TextStyle(color: c.body, fontSize: 9)),
              ],
            ),
          )),

          // ── Bill To + Invoice Details ──
          _bordered(c, child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bill To
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _labelHeader(c, 'Bill To:'),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invoice.clientName, style: TextStyle(color: c.black, fontSize: 10, fontWeight: FontWeight.bold)),
                          if (invoice.customerGstin.isNotEmpty)
                            Text('GSTIN: ${invoice.customerGstin}', style: TextStyle(color: c.body, fontSize: 8)),
                        ],
                      ),
                    ),
                  ],
                )),
                Container(width: 1, color: c.border),
                // Invoice Details
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _labelHeader(c, 'Invoice Details:'),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No: ${invoice.invoiceNumber}', style: TextStyle(color: c.body, fontSize: 9)),
                          const SizedBox(height: 2),
                          RichText(text: TextSpan(children: [
                            TextSpan(text: 'Date: ', style: TextStyle(color: c.body, fontSize: 9)),
                            TextSpan(text: _dateFormat.format(invoice.createdAt), style: TextStyle(color: c.black, fontSize: 9, fontWeight: FontWeight.bold)),
                          ])),
                          if (invoice.dueDate != null) ...[
                            const SizedBox(height: 2),
                            Text('Due: ${_dateFormat.format(invoice.dueDate!)}', style: TextStyle(color: c.body, fontSize: 9)),
                          ],
                        ],
                      ),
                    ),
                  ],
                )),
              ],
            ),
          )),

          // ── Items Table ──
          _buildItemsTable(c, hasHsn, hasGst),

          // ── Totals Block ──
          _buildTotalsBlock(c),

          const SizedBox(height: 6),

          // ── Terms — tappable ──
          GestureDetector(
            onTap: onTermsTap,
            child: _bordered(c, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelHeader(c, 'Terms And Conditions:'),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          termsText?.isNotEmpty == true ? termsText! : 'Thank you for doing business with us.',
                          style: TextStyle(color: c.body, fontSize: 9),
                        ),
                      ),
                      if (onTermsTap != null)
                        Icon(Icons.edit, size: 10, color: c.primary.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
              ],
            )),
          ),

          const SizedBox(height: 6),

          // ── Signature Block — tappable ──
          Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 180,
                child: GestureDetector(
                  onTap: onSignatureTap,
                  child: _bordered(c, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _labelHeader(c, 'For $_sellerName:'),
                      Container(
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: signatureImage != null
                            ? Image.memory(signatureImage!, fit: BoxFit.contain)
                            : Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: onSignatureTap != null
                                        ? c.primary.withValues(alpha: 0.4)
                                        : c.border,
                                    width: onSignatureTap != null ? 1.5 : 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  color: onSignatureTap != null
                                      ? c.primary.withValues(alpha: 0.03)
                                      : null,
                                ),
                                child: onSignatureTap != null
                                    ? Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.draw_rounded,
                                                size: 12, color: c.primary.withValues(alpha: 0.5)),
                                            const SizedBox(width: 4),
                                            Text('Tap to sign',
                                              style: TextStyle(
                                                color: c.primary.withValues(alpha: 0.5),
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : null,
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Text('Authorized Signatory', style: TextStyle(color: c.body, fontSize: 8)),
                      ),
                    ],
                  )),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Footer ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'Generated by BillRaja · ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: TextStyle(color: c.muted, fontSize: 7),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared: Terms + Signature ────────────────────────────────────────────────
  Widget _buildTermsAndSignature(InvoiceColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onTermsTap,
          child: _bordered(c, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _labelHeader(c, 'Terms And Conditions:'),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Row(children: [
                  Expanded(child: Text(
                    termsText?.isNotEmpty == true ? termsText! : 'Thank you for doing business with us.',
                    style: TextStyle(color: c.body, fontSize: 9),
                  )),
                  if (onTermsTap != null)
                    Icon(Icons.edit, size: 10, color: c.primary.withValues(alpha: 0.4)),
                ]),
              ),
            ],
          )),
        ),
        const SizedBox(height: 6),
        Row(children: [
          const Spacer(),
          SizedBox(
            width: 180,
            child: GestureDetector(
              onTap: onSignatureTap,
              child: _bordered(c, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _labelHeader(c, 'For $_sellerName:'),
                  Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: signatureImage != null
                        ? Image.memory(signatureImage!, fit: BoxFit.contain)
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: onSignatureTap != null ? c.primary.withValues(alpha: 0.4) : c.border,
                                width: onSignatureTap != null ? 1.5 : 0.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              color: onSignatureTap != null ? c.primary.withValues(alpha: 0.03) : null,
                            ),
                            child: onSignatureTap != null
                                ? Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.draw_rounded, size: 12, color: c.primary.withValues(alpha: 0.5)),
                                    const SizedBox(width: 4),
                                    Text('Tap to sign', style: TextStyle(color: c.primary.withValues(alpha: 0.5), fontSize: 8, fontWeight: FontWeight.w600)),
                                  ]))
                                : null,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text('Authorized Signatory', style: TextStyle(color: c.body, fontSize: 8)),
                  ),
                ],
              )),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Banner Layout ────────────────────────────────────────────────────────────
  Widget _buildBannerLayout(InvoiceColors c, bool hasHsn, bool hasGst) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Full-width colored banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: c.primary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_sellerName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    if (profile?.phoneNumber.isNotEmpty == true)
                      Text(profile!.phoneNumber, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 8)),
                    if (profile?.gstin.isNotEmpty == true)
                      Text('GSTIN: ${profile!.gstin}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 8)),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('TAX INVOICE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(invoice.invoiceNumber, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          // Details bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: c.labelBg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date: ${_dateFormat.format(invoice.createdAt)}', style: TextStyle(fontSize: 8, color: c.body)),
                if (invoice.dueDate != null)
                  Text('Due: ${_dateFormat.format(invoice.dueDate!)}', style: TextStyle(fontSize: 8, color: c.body)),
                Text(invoice.status.name.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: c.primary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bill To
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BILL TO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: c.primary)),
                      const SizedBox(height: 2),
                      Text(invoice.clientName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.black)),
                      if (invoice.customerGstin.isNotEmpty)
                        Text('GSTIN: ${invoice.customerGstin}', style: TextStyle(fontSize: 8, color: c.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildItemsTable(c, hasHsn, hasGst),
                _buildTotalsBlock(c),
                const SizedBox(height: 6),
                _buildTermsAndSignature(c),
                const SizedBox(height: 6),
                Text('Generated by BillRaja · ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: TextStyle(color: c.muted, fontSize: 7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar Layout ───────────────────────────────────────────────────────────
  Widget _buildSidebarLayout(InvoiceColors c, bool hasHsn, bool hasGst) {
    return Container(
      color: Colors.white,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left colored sidebar
            Container(
              width: 28,
              color: c.primary,
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(_sellerName,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('TAX INVOICE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.primary)),
                      Text(invoice.invoiceNumber, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.body)),
                    ]),
                    Divider(color: c.primary, thickness: 2, height: 10),
                    if (profile?.phoneNumber.isNotEmpty == true || profile?.gstin.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (profile?.phoneNumber.isNotEmpty == true)
                            Text('Phone: ${profile!.phoneNumber}', style: TextStyle(fontSize: 8, color: c.body)),
                          if (profile?.address.isNotEmpty == true)
                            Text(profile!.address, style: TextStyle(fontSize: 8, color: c.body)),
                          if (profile?.gstin.isNotEmpty == true)
                            Text('GSTIN: ${profile!.gstin}', style: TextStyle(fontSize: 8, color: c.body)),
                        ]),
                      ),
                    _bordered(c, child: IntrinsicHeight(child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _labelHeader(c, 'Bill To:'),
                          Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(invoice.clientName, style: TextStyle(color: c.black, fontSize: 10, fontWeight: FontWeight.bold)),
                            if (invoice.customerGstin.isNotEmpty)
                              Text('GSTIN: ${invoice.customerGstin}', style: TextStyle(color: c.body, fontSize: 8)),
                          ])),
                        ])),
                        Container(width: 1, color: c.border),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _labelHeader(c, 'Invoice Details:'),
                          Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Date: ${_dateFormat.format(invoice.createdAt)}', style: TextStyle(color: c.body, fontSize: 8)),
                            if (invoice.dueDate != null)
                              Text('Due: ${_dateFormat.format(invoice.dueDate!)}', style: TextStyle(color: c.body, fontSize: 8)),
                          ])),
                        ])),
                      ],
                    ))),
                    const SizedBox(height: 6),
                    _buildItemsTable(c, hasHsn, hasGst),
                    _buildTotalsBlock(c),
                    const SizedBox(height: 6),
                    _buildTermsAndSignature(c),
                    const SizedBox(height: 6),
                    Text('Generated by BillRaja · ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                        style: TextStyle(color: c.muted, fontSize: 7)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bordered Layout ──────────────────────────────────────────────────────────
  Widget _buildBorderedLayout(InvoiceColors c, bool hasHsn, bool hasGst) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thick top-bar header
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: c.primary, width: 5),
                bottom: BorderSide(color: c.primary, width: 1.5),
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_sellerName, style: TextStyle(color: c.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                  if (profile?.phoneNumber.isNotEmpty == true)
                    Text(profile!.phoneNumber, style: TextStyle(color: c.body, fontSize: 8)),
                  if (profile?.address.isNotEmpty == true)
                    Text(profile!.address, style: TextStyle(color: c.body, fontSize: 8)),
                  if (profile?.gstin.isNotEmpty == true)
                    Text('GSTIN: ${profile!.gstin}', style: TextStyle(color: c.body, fontSize: 8)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('TAX INVOICE', style: TextStyle(color: c.black, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(invoice.invoiceNumber, style: TextStyle(color: c.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('Date: ${_dateFormat.format(invoice.createdAt)}', style: TextStyle(color: c.body, fontSize: 8)),
                  if (invoice.dueDate != null)
                    Text('Due: ${_dateFormat.format(invoice.dueDate!)}', style: TextStyle(color: c.body, fontSize: 8)),
                ]),
              ],
            ),
          ),
          // Bill To — primary-colored thick border box
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: c.primary, width: 2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: c.primary,
                child: const Text('BILL TO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(invoice.clientName, style: TextStyle(color: c.black, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (invoice.customerGstin.isNotEmpty)
                    Text('GSTIN: ${invoice.customerGstin}', style: TextStyle(color: c.body, fontSize: 8)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildItemsTable(c, hasHsn, hasGst),
                _buildTotalsBlock(c),
                const SizedBox(height: 6),
                _buildTermsAndSignature(c),
              ],
            ),
          ),
          // Bottom accent bar
          Container(height: 5, color: c.primary, margin: const EdgeInsets.only(top: 8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('Generated by BillRaja · ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: TextStyle(color: c.muted, fontSize: 7)),
          ),
        ],
      ),
    );
  }

  // ── Two-Column Layout ────────────────────────────────────────────────────────
  Widget _buildTwoColumnLayout(InvoiceColors c, bool hasHsn, bool hasGst) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.primary, width: 2))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_sellerName, style: TextStyle(color: c.primary, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('TAX INVOICE', style: TextStyle(color: c.black, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ),
          // Two-column: Bill To | Invoice Details
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    color: c.labelBg.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bill To', style: TextStyle(color: c.primary, fontSize: 8, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(invoice.clientName, style: TextStyle(color: c.black, fontSize: 10, fontWeight: FontWeight.bold)),
                    if (invoice.customerGstin.isNotEmpty)
                      Text('GSTIN: ${invoice.customerGstin}', style: TextStyle(color: c.body, fontSize: 8)),
                  ]),
                )),
                const SizedBox(width: 8),
                Expanded(child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    color: c.labelBg.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Invoice Details', style: TextStyle(color: c.primary, fontSize: 8, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('No: ${invoice.invoiceNumber}', style: TextStyle(color: c.body, fontSize: 8)),
                    Text('Date: ${_dateFormat.format(invoice.createdAt)}', style: TextStyle(color: c.body, fontSize: 8)),
                    if (invoice.dueDate != null)
                      Text('Due: ${_dateFormat.format(invoice.dueDate!)}', style: TextStyle(color: c.body, fontSize: 8)),
                    if (profile?.gstin.isNotEmpty == true)
                      Text('GSTIN: ${profile!.gstin}', style: TextStyle(color: c.body, fontSize: 8)),
                  ]),
                )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildItemsTable(c, hasHsn, hasGst),
                _buildTotalsBlock(c),
                const SizedBox(height: 6),
                _buildTermsAndSignature(c),
                const SizedBox(height: 6),
                Text('Generated by BillRaja · ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: TextStyle(color: c.muted, fontSize: 7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Receipt Layout ───────────────────────────────────────────────────────────
  Widget _buildReceiptLayout(InvoiceColors c, bool hasHsn, bool hasGst) {
    final rawTotal = invoice.items.fold<double>(0, (s, i) => s + i.rawTotal);
    final itemDiscTotal = invoice.items.fold<double>(0, (s, i) => s + i.discountAmount);

    Widget dashed() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: List.generate(28, (_) => Expanded(
        child: Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 1), color: c.muted),
      ))),
    );

    Widget totalLine(String label, String value, {bool bold = false, Color? col}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 8, color: col ?? c.body, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 8, color: col ?? c.body, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]),
    );

    return Container(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_sellerName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.body), textAlign: TextAlign.center),
                if (profile?.phoneNumber.isNotEmpty == true)
                  Text(profile!.phoneNumber, style: TextStyle(fontSize: 8, color: c.muted), textAlign: TextAlign.center),
                if (profile?.address.isNotEmpty == true)
                  Text(profile!.address, style: TextStyle(fontSize: 7, color: c.muted), textAlign: TextAlign.center),
                if (profile?.gstin.isNotEmpty == true)
                  Text('GSTIN: ${profile!.gstin}', style: TextStyle(fontSize: 8, color: c.body), textAlign: TextAlign.center),
                dashed(),
                Text('TAX INVOICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.primary), textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('No: ${invoice.invoiceNumber}', style: TextStyle(fontSize: 8, color: c.body)),
                  Text(_dateFormat.format(invoice.createdAt), style: TextStyle(fontSize: 8, color: c.muted)),
                ]),
                dashed(),
                Align(alignment: Alignment.centerLeft,
                  child: Text('Customer: ${invoice.clientName}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c.body))),
                if (invoice.customerGstin.isNotEmpty)
                  Align(alignment: Alignment.centerLeft,
                    child: Text('GSTIN: ${invoice.customerGstin}', style: TextStyle(fontSize: 8, color: c.muted))),
                dashed(),
                // Items header
                Row(children: [
                  Expanded(flex: 4, child: Text('Item', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: c.body))),
                  Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: c.body), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Rate', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: c.body), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('Amt', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: c.body), textAlign: TextAlign.right)),
                ]),
                const SizedBox(height: 2),
                ...invoice.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(children: [
                    Expanded(flex: 4, child: Text(item.description, style: TextStyle(fontSize: 8, color: c.body), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 1, child: Text(item.quantityText, style: TextStyle(fontSize: 8, color: c.body), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('₹${_fmt(item.unitPrice)}', style: TextStyle(fontSize: 8, color: c.body), textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('₹${_fmt(item.total)}', style: TextStyle(fontSize: 8, color: c.body), textAlign: TextAlign.right)),
                  ]),
                )),
                dashed(),
                totalLine('Sub Total', '₹${_fmt(rawTotal)}'),
                if (itemDiscTotal > 0)
                  totalLine('Item Discounts', '- ₹${_fmt(itemDiscTotal)}'),
                if (invoice.discountAmount > 0)
                  totalLine('Discount', '- ₹${_fmt(invoice.discountAmount)}'),
                if (itemDiscTotal > 0 || invoice.discountAmount > 0 || invoice.totalTax > 0)
                  totalLine('Taxable Amt', '₹${_fmt(invoice.taxableAmount)}'),
                if (invoice.totalTax > 0) ...[
                  if (invoice.gstType == 'cgst_sgst') ...[
                    totalLine('CGST', '₹${_fmt(invoice.cgstAmount)}'),
                    totalLine('SGST', '₹${_fmt(invoice.sgstAmount)}'),
                  ] else
                    totalLine('IGST', '₹${_fmt(invoice.igstAmount)}'),
                ],
                dashed(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('GRAND TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.primary)),
                  Text('₹${_fmt(invoice.grandTotal)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.primary)),
                ]),
                dashed(),
                const SizedBox(height: 2),
                Text('Thank you for your business!', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: c.body), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Generated by BillRaja', style: TextStyle(fontSize: 7, color: c.muted), textAlign: TextAlign.center),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Items Table ──
  Widget _buildItemsTable(InvoiceColors c, bool hasHsn, bool hasGst) {
    final hasDisc = invoice.items.any((i) => i.discountPercent > 0);

    // Dynamic columns: only show what's needed
    int col = 0;
    final widths = <int, TableColumnWidth>{};
    widths[col++] = const FixedColumnWidth(18);    // #
    widths[col++] = const FlexColumnWidth(2.5);    // Item Name
    if (hasHsn) widths[col++] = const FlexColumnWidth(1.2); // HSN
    widths[col++] = const FlexColumnWidth(0.7);    // Qty
    widths[col++] = const FlexColumnWidth(1);      // Rate
    widths[col++] = const FlexColumnWidth(1);      // Amount (Qty×Rate)
    if (hasDisc) {
      widths[col++] = const FlexColumnWidth(0.7);  // Disc%
      widths[col++] = const FlexColumnWidth(1);    // After Disc
    }
    if (hasGst) {
      widths[col++] = const FlexColumnWidth(0.7);  // GST%
      widths[col++] = const FlexColumnWidth(1);    // GST Amt
    }
    widths[col++] = const FlexColumnWidth(1.1);    // Total

    return Table(
      border: TableBorder.all(color: c.border, width: 0.5),
      columnWidths: widths,
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(color: c.labelBg),
          children: [
            _hCell(c, '#'),
            _hCell(c, 'Item', align: TextAlign.left),
            if (hasHsn) _hCell(c, 'HSN'),
            _hCell(c, 'Qty'),
            _hCell(c, 'Rate'),
            _hCell(c, 'Amt'),
            if (hasDisc) ...[
              _hCell(c, 'Disc'),
              _hCell(c, 'After\nDisc'),
            ],
            if (hasGst) ...[
              _hCell(c, 'GST'),
              _hCell(c, 'Tax\nAmt'),
            ],
            _hCell(c, 'Total'),
          ],
        ),
        // Item rows
        for (var i = 0; i < invoice.items.length; i++)
          _itemRow(c, i, invoice.items[i], hasHsn, hasGst, hasDisc),
        // Total row
        _totalRow(c, hasHsn, hasGst, hasDisc),
      ],
    );
  }

  TableRow _itemRow(InvoiceColors c, int idx, item, bool hasHsn, bool hasGst, bool hasDisc) {
    return TableRow(children: [
      _dCell(c, '${idx + 1}'),
      _dCell(c, item.description, bold: true, align: TextAlign.left),
      if (hasHsn) _dCell(c, item.hsnCode),
      _dCell(c, item.quantityText),
      _dCell(c, '₹${_fmt(item.unitPrice)}'),
      _dCell(c, '₹${_fmt(item.rawTotal)}'),                             // Qty × Rate
      if (hasDisc) ...[
        _dCell(c, item.discountPercent > 0 ? '${item.discountPercent.toStringAsFixed(0)}%' : '-'),
        _dCell(c, '₹${_fmt(item.total)}'),                              // After discount
      ],
      if (hasGst) ...[
        _dCell(c, item.gstRate > 0 ? '${item.gstRate.toStringAsFixed(0)}%' : '-'),
        _dCell(c, item.gstRate > 0 ? '₹${_fmt(item.gstAmount)}' : '-'), // GST amount
      ],
      _dCell(c, '₹${_fmt(item.totalWithGst)}', bold: true),             // Final total
    ]);
  }

  TableRow _totalRow(InvoiceColors c, bool hasHsn, bool hasGst, bool hasDisc) {
    final itemCount = invoice.items.length;
    final totalRaw = invoice.items.fold<double>(0, (s, i) => s + i.rawTotal);
    final totalAfterDisc = invoice.items.fold<double>(0, (s, i) => s + i.total);
    final totalGstAmt = invoice.items.fold<double>(0, (s, i) => s + i.gstAmount);
    final totalFinal = invoice.items.fold<double>(0, (s, i) => s + i.totalWithGst);
    return TableRow(
      decoration: BoxDecoration(color: c.labelBg.withValues(alpha: 0.5)),
      children: [
        _dCell(c, '', bold: true),
        _dCell(c, 'Total ($itemCount items)', bold: true, align: TextAlign.left),
        if (hasHsn) _dCell(c, ''),
        _dCell(c, ''),
        _dCell(c, ''),
        _dCell(c, '₹${_fmt(totalRaw)}', bold: true),
        if (hasDisc) ...[
          _dCell(c, ''),
          _dCell(c, '₹${_fmt(totalAfterDisc)}', bold: true),
        ],
        if (hasGst) ...[
          _dCell(c, ''),
          _dCell(c, '₹${_fmt(totalGstAmt)}', bold: true),
        ],
        _dCell(c, '₹${_fmt(totalFinal)}', bold: true),
      ],
    );
  }

  // ── Totals Block ──
  Widget _buildTotalsBlock(InvoiceColors c) {
    final received = invoice.amountReceived;
    final balance = invoice.balanceDue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount in words on the left
        Expanded(child: _bordered(c, child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice Amount In Words :', style: TextStyle(color: c.black, fontSize: 8, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(_numberToWords(invoice.grandTotal.round()), style: TextStyle(color: c.body, fontSize: 8)),
            ],
          ),
        ))),
        // Totals on the right
        SizedBox(
          width: 200,
          child: _bordered(c, child: Column(
            children: [
              // Per-item discount total (sum of all item-level discounts)
              ..._buildSubtotalRows(c),
              if (invoice.totalTax > 0) ...[
                if (invoice.gstType == 'cgst_sgst') ...[
                  _totRow(c, 'CGST', '₹ ${_fmt(invoice.cgstAmount)}'),
                  _totRow(c, 'SGST', '₹ ${_fmt(invoice.sgstAmount)}'),
                ] else if (invoice.igstAmount > 0)
                  _totRow(c, 'IGST', '₹ ${_fmt(invoice.igstAmount)}'),
                _totRow(c, 'Total Tax', '₹ ${_fmt(invoice.totalTax)}'),
              ],
              _totRow(c, 'Grand Total', '₹ ${_fmt(invoice.grandTotal)}', bold: true, highlight: true),
              _totRow(c, 'Received', '₹ ${_fmt(received)}'),
              _totRow(c, 'Balance', '₹ ${_fmt(balance)}', bold: true),
            ],
          )),
        ),
      ],
    );
  }

  List<Widget> _buildSubtotalRows(InvoiceColors c) {
    final rows = <Widget>[];
    // Raw total (before any discounts)
    final rawTotal = invoice.items.fold<double>(0, (s, i) => s + i.rawTotal);
    final itemDiscTotal = invoice.items.fold<double>(0, (s, i) => s + i.discountAmount);

    rows.add(_totRow(c, 'Sub Total', '₹ ${_fmt(rawTotal)}'));

    // Per-item discounts
    if (itemDiscTotal > 0) {
      rows.add(_totRow(c, 'Item Discounts', '- ₹ ${_fmt(itemDiscTotal)}'));
    }

    // Order-level discount
    if (invoice.discountAmount > 0) {
      rows.add(_totRow(c, 'Discount${invoice.discountType == InvoiceDiscountType.percentage ? ' (${invoice.discountValue.toStringAsFixed(0)}%)' : ''}', '- ₹ ${_fmt(invoice.discountAmount)}'));
    }

    // Taxable amount (show if any discount or tax exists)
    if (itemDiscTotal > 0 || invoice.discountAmount > 0 || invoice.totalTax > 0) {
      rows.add(_totRow(c, 'Taxable Amount', '₹ ${_fmt(invoice.taxableAmount)}'));
    }

    return rows;
  }

  // ── Helper widgets ──

  Widget _bordered(InvoiceColors c, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.border, width: 1),
      ),
      child: child,
    );
  }

  Widget _labelHeader(InvoiceColors c, String text) {
    return Container(
      width: double.infinity,
      color: c.labelBg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(text, style: TextStyle(color: c.black, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _hCell(InvoiceColors c, String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(text, textAlign: align, style: TextStyle(color: c.black, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Widget _dCell(InvoiceColors c, String text, {bool bold = false, TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(text, textAlign: align, style: TextStyle(
        color: c.black,
        fontSize: 8,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      )),
    );
  }

  Widget _totRow(InvoiceColors c, String label, String value, {bool bold = false, bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? c.primary : null,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: highlight ? Colors.white : c.black,
            fontSize: 8,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          )),
          Text(value, style: TextStyle(
            color: highlight ? Colors.white : c.black,
            fontSize: 8,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  static String _numberToWords(int number) {
    if (number == 0) return 'Zero';
    if (number < 0) return 'Minus ${_numberToWords(-number)}';
    const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    String twoD(int v) => v < 20 ? ones[v] : (v % 10 == 0 ? tens[v ~/ 10] : '${tens[v ~/ 10]} ${ones[v % 10]}');
    String threeD(int v) { if (v == 0) return ''; final h = v ~/ 100, r = v % 100; return h == 0 ? twoD(r) : r == 0 ? '${ones[h]} Hundred' : '${ones[h]} Hundred ${twoD(r)}'; }
    var rem = number; final parts = <String>[];
    if (rem >= 10000000) { parts.add('${threeD((rem ~/ 10000000).clamp(0, 999))} Crore'); rem %= 10000000; }
    if (rem >= 100000) { parts.add('${twoD(rem ~/ 100000)} Lakh'); rem %= 100000; }
    if (rem >= 1000) { parts.add('${twoD(rem ~/ 1000)} Thousand'); rem %= 1000; }
    if (rem > 0) parts.add(threeD(rem));
    return parts.join(' ');
  }
}
