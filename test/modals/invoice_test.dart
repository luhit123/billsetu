import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/line_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Invoice — computed fields', () {
    final now = DateTime(2026, 3, 28);

    Invoice makeInvoice({
      List<LineItem> items = const [],
      bool gstEnabled = false,
      double gstRate = 18.0,
      String gstType = 'cgst_sgst',
      InvoiceDiscountType? discountType,
      double discountValue = 0,
      double amountReceived = 0,
    }) {
      return Invoice(
        id: 'inv-1',
        ownerId: 'uid-1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'c-1',
        clientName: 'Test Client',
        items: items,
        createdAt: now,
        status: InvoiceStatus.pending,
        gstEnabled: gstEnabled,
        gstRate: gstRate,
        gstType: gstType,
        discountType: discountType,
        discountValue: discountValue,
        amountReceived: amountReceived,
      );
    }

    test('subtotal sums line item totals', () {
      final inv = makeInvoice(items: const [
        LineItem(description: 'A', quantity: 2, unitPrice: 100),
        LineItem(description: 'B', quantity: 3, unitPrice: 50),
      ]);
      expect(inv.subtotal, 350);
    });

    test('no-GST invoice: grandTotal == subtotal', () {
      final inv = makeInvoice(items: const [
        LineItem(description: 'Widget', quantity: 1, unitPrice: 500),
      ]);
      expect(inv.gstEnabled, false);
      expect(inv.totalTax, 0);
      expect(inv.grandTotal, 500);
    });

    test('CGST/SGST split at 18%', () {
      final inv = makeInvoice(
        items: const [
          LineItem(description: 'Service', quantity: 1, unitPrice: 1000, gstRate: 18),
        ],
        gstEnabled: true,
        gstRate: 18,
        gstType: 'cgst_sgst',
      );
      // Tax = 1000 * 18% = 180 split into CGST 90 + SGST 90
      expect(inv.cgstAmount, 90);
      expect(inv.sgstAmount, 90);
      expect(inv.totalTax, 180);
      expect(inv.grandTotal, 1180);
    });

    test('IGST at 18%', () {
      final inv = makeInvoice(
        items: const [
          LineItem(description: 'Service', quantity: 1, unitPrice: 1000, gstRate: 18),
        ],
        gstEnabled: true,
        gstRate: 18,
        gstType: 'igst',
      );
      expect(inv.igstAmount, 180);
      expect(inv.cgstAmount, 0);
      expect(inv.totalTax, 180);
      expect(inv.grandTotal, 1180);
    });

    test('percentage discount applied before GST', () {
      final inv = makeInvoice(
        items: const [
          LineItem(description: 'Item', quantity: 1, unitPrice: 1000, gstRate: 18),
        ],
        gstEnabled: true,
        gstType: 'cgst_sgst',
        discountType: InvoiceDiscountType.percentage,
        discountValue: 10, // 10%
      );
      // Subtotal 1000, discount 100, taxable 900
      expect(inv.subtotal, 1000);
      expect(inv.discountAmount, 100);
      expect(inv.taxableAmount, 900);
      // GST on 900 = 162 (81 + 81)
      expect(inv.totalTax, 162);
      expect(inv.grandTotal, 1062);
    });

    test('overall (flat) discount', () {
      final inv = makeInvoice(
        items: const [
          LineItem(description: 'Item', quantity: 2, unitPrice: 500),
        ],
        discountType: InvoiceDiscountType.overall,
        discountValue: 200,
      );
      expect(inv.subtotal, 1000);
      expect(inv.discountAmount, 200);
      expect(inv.grandTotal, 800);
    });

    test('balanceDue and effectiveStatus', () {
      final unpaid = makeInvoice(
        items: const [LineItem(description: 'X', quantity: 1, unitPrice: 1000)],
      );
      expect(unpaid.balanceDue, 1000);
      expect(unpaid.effectiveStatus, InvoiceStatus.pending);

      final partial = makeInvoice(
        items: const [LineItem(description: 'X', quantity: 1, unitPrice: 1000)],
        amountReceived: 400,
      );
      expect(partial.balanceDue, 600);
      expect(partial.effectiveStatus, InvoiceStatus.partiallyPaid);

      final paid = makeInvoice(
        items: const [LineItem(description: 'X', quantity: 1, unitPrice: 1000)],
        amountReceived: 1000,
      );
      expect(paid.balanceDue, 0);
      expect(paid.effectiveStatus, InvoiceStatus.paid);
    });
  });

  group('Invoice — serialization', () {
    test('fromMap → toMap round-trip preserves data', () {
      final now = DateTime(2026, 3, 28, 10, 30);
      final original = Invoice(
        id: 'inv-rt',
        ownerId: 'uid-rt',
        invoiceNumber: 'BR-2026-00099',
        clientId: 'c-rt',
        clientName: 'Round Trip Corp',
        items: const [
          LineItem(description: 'Paper', quantity: 5, unitPrice: 80, unit: 'pcs'),
        ],
        createdAt: now,
        status: InvoiceStatus.paid,
        amountReceived: 400,
        notes: 'Test note',
      );

      final map = original.toMap();
      final restored = Invoice.fromMap(map, docId: 'inv-rt');

      expect(restored.invoiceNumber, original.invoiceNumber);
      expect(restored.clientName, original.clientName);
      expect(restored.items.length, 1);
      expect(restored.items.first.description, 'Paper');
      expect(restored.subtotal, 400);
      expect(restored.notes, 'Test note');
    });
  });
}
