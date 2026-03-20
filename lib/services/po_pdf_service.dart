import 'dart:io';

import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/purchase_order.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PoPdfService {
  PoPdfService._();
  static final PoPdfService instance = PoPdfService._();

  // ── Brand palette ──────────────────────────────────────────────────────────
  static const PdfColor _navy = PdfColor(0.07, 0.24, 0.52);
  static const PdfColor _navyLight = PdfColor(0.14, 0.34, 0.65);
  static const PdfColor _surface = PdfColor(0.97, 0.98, 1.00);
  static const PdfColor _border = PdfColor(0.87, 0.90, 0.95);
  static const PdfColor _mutedText = PdfColor(0.45, 0.51, 0.62);
  static const PdfColor _bodyText = PdfColor(0.20, 0.25, 0.35);
  static const PdfColor _headingText = PdfColor(0.08, 0.13, 0.22);
  static const PdfColor _headerBg = PdfColor(0.94, 0.97, 1.00);

  // ── Public API ─────────────────────────────────────────────────────────────

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

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/PO_${po.orderNumber}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Purchase Order #${po.orderNumber}',
    );
  }

  // ── Page builder ──────────────────────────────────────────────────────────

  pw.Widget _buildPage(PurchaseOrder po, BusinessProfile? profile) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildHeader(po, profile),
        pw.SizedBox(height: 20),
        pw.Divider(color: _border, thickness: 1),
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
        pw.Divider(color: _border, thickness: 1),
        pw.SizedBox(height: 6),
        pw.Text(
          'This is a computer generated Purchase Order.',
          style: pw.TextStyle(fontSize: 9, color: _mutedText),
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
                color: _headingText,
              ),
            ),
            if (profile?.gstin.isNotEmpty == true) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'GSTIN: ${profile!.gstin}',
                style: pw.TextStyle(fontSize: 10, color: _mutedText),
              ),
            ],
            if (profile?.address.isNotEmpty == true) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                profile!.address,
                style: pw.TextStyle(fontSize: 10, color: _bodyText),
              ),
            ],
            if (profile?.phoneNumber.isNotEmpty == true) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                profile!.phoneNumber,
                style: pw.TextStyle(fontSize: 10, color: _bodyText),
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
                color: _navy,
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
                color: _navyLight,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Date: ${_formatDate(po.createdAt)}',
              style: pw.TextStyle(fontSize: 10, color: _bodyText),
            ),
            if (po.expectedDate != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                'Expected: ${_formatDate(po.expectedDate!)}',
                style: pw.TextStyle(fontSize: 10, color: _mutedText),
              ),
            ],
            pw.SizedBox(height: 3),
            pw.Text(
              _statusLabel(po.status),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _statusColor(po.status),
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
        color: _headerBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUPPLIER',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _mutedText,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            po.supplierName,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _headingText,
            ),
          ),
          if (po.supplierPhone.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Phone: ${po.supplierPhone}',
              style: pw.TextStyle(fontSize: 10, color: _bodyText),
            ),
          ],
          if (po.supplierAddress.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              po.supplierAddress,
              style: pw.TextStyle(fontSize: 10, color: _bodyText),
            ),
          ],
          if (po.supplierGstin.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'GSTIN: ${po.supplierGstin}',
              style: pw.TextStyle(fontSize: 10, color: _mutedText),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(PurchaseOrder po) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.5),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _navy),
          children: [
            _tableHeaderCell('Item / Description'),
            _tableHeaderCell('Qty'),
            _tableHeaderCell('Rate (₹)'),
            _tableHeaderCell('Amount (₹)'),
          ],
        ),
        // Data rows
        ...po.items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isEven = i.isEven;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : _surface,
            ),
            children: [
              _tableDataCell(item.productName),
              _tableDataCell(item.quantityLabel),
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
        width: 220,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _border),
        ),
        child: pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Subtotal',
                  style: pw.TextStyle(fontSize: 10, color: _bodyText),
                ),
                pw.Text(
                  '₹${po.subtotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 10, color: _bodyText),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: _border, thickness: 0.5),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _headingText,
                  ),
                ),
                pw.Text(
                  '₹${po.subtotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildNotesSection(PurchaseOrder po) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _headerBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _mutedText,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            po.notes,
            style: pw.TextStyle(fontSize: 10, color: _bodyText),
          ),
        ],
      ),
    );
  }

  // ── Table helpers ──────────────────────────────────────────────────────────

  pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
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
        style: pw.TextStyle(fontSize: 10, color: _bodyText),
      ),
    );
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

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

  PdfColor _statusColor(PurchaseOrderStatus status) {
    return switch (status) {
      PurchaseOrderStatus.draft => _mutedText,
      PurchaseOrderStatus.confirmed => const PdfColor(0.72, 0.40, 0.04),
      PurchaseOrderStatus.received => const PdfColor(0.10, 0.52, 0.27),
      PurchaseOrderStatus.cancelled => const PdfColor(0.74, 0.13, 0.13),
    };
  }
}
