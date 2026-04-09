import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/purchase_order.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PoPdfService {
  PoPdfService._();
  static final PoPdfService instance = PoPdfService._();

  // ── Monochrome palette ───────────────────────────────────────────────────
  static const PdfColor _black = PdfColors.black;
  static const PdfColor _darkGray = PdfColor(0.30, 0.30, 0.30);
  static const PdfColor _midGray = PdfColor(0.55, 0.55, 0.55);
  static const PdfColor _lightGray = PdfColor(0.94, 0.94, 0.94); // #F0F0F0
  static const PdfColor _borderColor = PdfColor(0.75, 0.75, 0.75);

  // ── Public API ─────────────────────────────────────────────────────────

  Future<void> generateAndShare(
    PurchaseOrder po,
    BusinessProfile? profile,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => _buildPage(po, profile),
      ),
    );

    final pdfBytes = await pdf.save();

    if (kIsWeb) {
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(Uint8List.fromList(pdfBytes), mimeType: 'application/pdf', name: 'PO_${po.orderNumber}.pdf')],
        text: 'Purchase Order #${po.orderNumber}',
      ));
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/PO_${po.orderNumber}.pdf');
      await file.writeAsBytes(pdfBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Purchase Order #${po.orderNumber}',
        ),
      );
    }
  }

  // ── Page builder ──────────────────────────────────────────────────────

  pw.Widget _buildPage(PurchaseOrder po, BusinessProfile? profile) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildHeader(po, profile),
        pw.SizedBox(height: 20),
        pw.Divider(color: _borderColor, thickness: 1),
        pw.SizedBox(height: 16),
        _buildSupplierSection(po),
        pw.SizedBox(height: 20),
        _buildItemsTable(po),
        pw.SizedBox(height: 16),
        _buildTotalsSection(po),
        if (po.notes.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          _buildNotesSection(po),
        ],
        pw.Spacer(),
        pw.Divider(color: _borderColor, thickness: 1),
        pw.SizedBox(height: 6),
        pw.Text(
          'This is a computer generated Purchase Order.',
          style: pw.TextStyle(fontSize: 9, color: _midGray),
        ),
      ],
    );
  }

  pw.Widget _buildHeader(PurchaseOrder po, BusinessProfile? profile) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: business info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              profile?.storeName ?? 'Your Business',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _black,
              ),
            ),
            if (profile?.gstin.isNotEmpty == true) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'GSTIN: ${profile!.gstin}',
                style: pw.TextStyle(fontSize: 10, color: _midGray),
              ),
            ],
            if (profile?.address.isNotEmpty == true) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                profile!.address,
                style: pw.TextStyle(fontSize: 10, color: _darkGray),
              ),
            ],
            if (profile?.phoneNumber.isNotEmpty == true) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                profile!.phoneNumber,
                style: pw.TextStyle(fontSize: 10, color: _darkGray),
              ),
            ],
          ],
        ),
        // Right: PO identity
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: pw.BoxDecoration(
                color: _black,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'PURCHASE ORDER',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '#${po.orderNumber}',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _black,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Date: ${_formatDate(po.createdAt)}',
              style: pw.TextStyle(fontSize: 10, color: _darkGray),
            ),
            if (po.expectedDate != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                'Expected: ${_formatDate(po.expectedDate!)}',
                style: pw.TextStyle(fontSize: 10, color: _midGray),
              ),
            ],
            pw.SizedBox(height: 3),
            pw.Text(
              _statusLabel(po.status),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSupplierSection(PurchaseOrder po) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _lightGray,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _borderColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUPPLIER',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _midGray,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            po.supplierName,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _black,
            ),
          ),
          if (po.supplierPhone.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Phone: ${po.supplierPhone}',
              style: pw.TextStyle(fontSize: 10, color: _darkGray),
            ),
          ],
          if (po.supplierAddress.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              po.supplierAddress,
              style: pw.TextStyle(fontSize: 10, color: _darkGray),
            ),
          ],
          if (po.supplierGstin.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'GSTIN: ${po.supplierGstin}',
              style: pw.TextStyle(fontSize: 10, color: _midGray),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(PurchaseOrder po) {
    final showGst = po.gstEnabled;
    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: showGst
          ? const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(1.5),
            }
          : const {
              0: pw.FlexColumnWidth(3.5),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
            },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _lightGray),
          children: [
            _tableHeaderCell('Item / Description'),
            _tableHeaderCell('Qty'),
            if (showGst) _tableHeaderCell('GST%'),
            _tableHeaderCell('Rate (Rs.)'),
            _tableHeaderCell('Amount (Rs.)'),
          ],
        ),
        // Data rows
        ...po.items.asMap().entries.map((entry) {
          final item = entry.value;
          return pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: PdfColors.white,
            ),
            children: [
              _tableDataCell(item.productName),
              _tableDataCell(item.quantityLabel),
              if (showGst)
                _tableDataCell('${item.gstRate.toStringAsFixed(0)}%'),
              _tableDataCell(item.unitPrice.toStringAsFixed(2)),
              _tableDataCell(item.total.toStringAsFixed(2)),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildTotalsSection(PurchaseOrder po) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 240,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _borderColor),
        ),
        child: pw.Column(
          children: [
            _totalsRow('Subtotal', 'Rs. ${po.subtotal.toStringAsFixed(2)}'),
            if (po.hasDiscount) ...[
              pw.SizedBox(height: 4),
              _totalsRow(
                  'Discount${po.discountType == 'percentage' ? ' (${po.discountValue.toStringAsFixed(0)}%)' : ''}',
                  '- Rs. ${po.discountAmount.toStringAsFixed(2)}'),
            ],
            if (po.hasGst) ...[
              pw.SizedBox(height: 4),
              if (po.gstType == 'cgst_sgst') ...[
                _totalsRow(
                    'CGST',
                    'Rs. ${po.cgstAmount.toStringAsFixed(2)}'),
                pw.SizedBox(height: 3),
                _totalsRow(
                    'SGST',
                    'Rs. ${po.sgstAmount.toStringAsFixed(2)}'),
              ] else
                _totalsRow(
                    'IGST',
                    'Rs. ${po.igstAmount.toStringAsFixed(2)}'),
              pw.SizedBox(height: 3),
              _totalsRow(
                  'Total Tax', 'Rs. ${po.totalTax.toStringAsFixed(2)}'),
            ],
            pw.SizedBox(height: 6),
            pw.Divider(color: _borderColor, thickness: 0.5),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'GRAND TOTAL',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _black,
                  ),
                ),
                pw.Text(
                  'Rs. ${po.grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _totalsRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _darkGray)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, color: _darkGray)),
      ],
    );
  }

  pw.Widget _buildNotesSection(PurchaseOrder po) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _lightGray,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _borderColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _midGray,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            po.notes,
            style: pw.TextStyle(fontSize: 10, color: _darkGray),
          ),
        ],
      ),
    );
  }

  // ── Table helpers ──────────────────────────────────────────────────────

  pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _black,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  pw.Widget _tableDataCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, color: _darkGray),
      ),
    );
  }

  // ── Utilities ─────────────────────────────────────────────────────────

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _statusLabel(PurchaseOrderStatus status) {
    return switch (status) {
      PurchaseOrderStatus.draft => 'DRAFT',
      PurchaseOrderStatus.confirmed => 'CONFIRMED',
      PurchaseOrderStatus.received => 'RECEIVED',
      PurchaseOrderStatus.cancelled => 'CANCELLED',
    };
  }
}
