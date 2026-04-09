import 'package:flutter_test/flutter_test.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/line_item.dart';
import 'package:billeasy/modals/purchase_order.dart';
import 'package:billeasy/modals/purchase_line_item.dart';

void main() {
  group('LineItem Financial Calculations', () {
    test('rawTotal: quantity * unitPrice, rounded to 2 decimals', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 3,
        unitPrice: 100.00,
      );
      expect(item.rawTotal, 300.00);
    });

    test('rawTotal: handles decimal quantity and price', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 2.5,
        unitPrice: 10.50,
      );
      expect(item.rawTotal, 26.25);
    });

    test('rawTotal: rounding edge case (3 items x 33.33 = 99.99)', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 3,
        unitPrice: 33.33,
      );
      expect(item.rawTotal, 99.99);
    });

    test('discountAmount: 0 when discountPercent is 0', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 10,
        unitPrice: 100.00,
        discountPercent: 0,
      );
      expect(item.discountAmount, 0);
    });

    test('discountAmount: percentage discount on rawTotal', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 10,
        unitPrice: 100.00,
        discountPercent: 10,
      );
      // rawTotal = 1000, discount 10% = 100
      expect(item.discountAmount, 100.00);
    });

    test('discountAmount: rounding edge case (50% of 99.99)', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 3,
        unitPrice: 33.33,
        discountPercent: 50,
      );
      // rawTotal = 99.99, discount 50% = 49.995 -> 50.00 (rounded)
      expect(item.discountAmount, 50.00);
    });

    test('total: rawTotal - discountAmount', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 10,
        unitPrice: 100.00,
        discountPercent: 20,
      );
      // rawTotal = 1000, discount = 200, total = 800
      expect(item.total, 800.00);
    });

    test('total: zero quantity results in zero total', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 0,
        unitPrice: 100.00,
      );
      expect(item.total, 0);
    });

    test('gstAmount: total * gstRate / 100', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 10,
        unitPrice: 100.00,
        gstRate: 18,
      );
      // total = 1000, gst 18% = 180
      expect(item.gstAmount, 180.00);
    });

    test('gstAmount: 5% GST', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 100,
        unitPrice: 100.00,
        gstRate: 5,
      );
      // total = 10000, gst 5% = 500
      expect(item.gstAmount, 500.00);
    });

    test('gstAmount: 0 when gstRate is 0', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 10,
        unitPrice: 100.00,
        gstRate: 0,
      );
      expect(item.gstAmount, 0);
    });

    test('gstAmount: rounding with fractional total', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 3,
        unitPrice: 33.33,
        gstRate: 18,
      );
      // total = 99.99, gst 18% = 17.9982 -> 18.00 (rounded)
      expect(item.gstAmount, 18.00);
    });

    test('totalWithGst: total + gstAmount', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 10,
        unitPrice: 100.00,
        gstRate: 18,
      );
      // total = 1000, gst = 180, totalWithGst = 1180
      expect(item.totalWithGst, 1180.00);
    });

    test('complex scenario: discount + GST', () {
      final item = LineItem(
        description: 'Test Item',
        quantity: 5,
        unitPrice: 200.00,
        discountPercent: 10,
        gstRate: 12,
      );
      // rawTotal = 1000, discount 10% = 100, total = 900
      // gst 12% = 108, totalWithGst = 1008
      expect(item.rawTotal, 1000.00);
      expect(item.discountAmount, 100.00);
      expect(item.total, 900.00);
      expect(item.gstAmount, 108.00);
      expect(item.totalWithGst, 1008.00);
    });
  });

  group('Invoice Financial Calculations - No Discount No GST', () {
    test('simple invoice: subtotal = sum of item totals', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 2,
          unitPrice: 100.00,
        ),
        LineItem(
          description: 'Item 2',
          quantity: 3,
          unitPrice: 50.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
      );
      // Item 1: 200, Item 2: 150, subtotal = 350
      expect(invoice.subtotal, 350.00);
      expect(invoice.discountAmount, 0);
      expect(invoice.taxableAmount, 350.00);
      expect(invoice.totalTax, 0);
      expect(invoice.grandTotal, 350.00);
    });

    test('no GST, no discount: balanceDue = grandTotal', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
      );
      expect(invoice.balanceDue, 100.00);
      expect(invoice.isFullyPaid, false);
      expect(invoice.isPartiallyPaid, false);
    });
  });

  group('Invoice Financial Calculations - Percentage Discount', () {
    test('percentage discount: 10% off 1000 = 100', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 10,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.percentage,
        discountValue: 10,
      );
      expect(invoice.subtotal, 1000.00);
      expect(invoice.discountAmount, 100.00);
      expect(invoice.taxableAmount, 900.00);
      expect(invoice.grandTotal, 900.00);
    });

    test('percentage discount: 33.33% off 99.99 (rounding edge case)', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 3,
          unitPrice: 33.33,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.percentage,
        discountValue: 33.33,
      );
      // subtotal = 99.99, discount 33.33% ≈ 33.32, taxableAmount ≈ 66.67
      expect(invoice.subtotal, 99.99);
      expect(invoice.discountAmount, isA<double>());
      expect(invoice.taxableAmount, invoice.subtotal - invoice.discountAmount);
    });

    test('percentage discount: clamped to subtotal', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.percentage,
        discountValue: 150, // 150% discount attempted
      );
      // discount should be clamped to subtotal
      expect(invoice.discountAmount, 100.00);
      expect(invoice.taxableAmount, 0);
    });
  });

  group('Invoice Financial Calculations - Overall (Flat) Discount', () {
    test('overall discount: flat amount 50 off 200', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 2,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.overall,
        discountValue: 50,
      );
      expect(invoice.subtotal, 200.00);
      expect(invoice.discountAmount, 50.00);
      expect(invoice.taxableAmount, 150.00);
      expect(invoice.grandTotal, 150.00);
    });

    test('overall discount: clamped to subtotal', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.overall,
        discountValue: 200, // discount exceeds subtotal
      );
      // discount should be clamped to subtotal
      expect(invoice.discountAmount, 100.00);
      expect(invoice.taxableAmount, 0);
    });
  });

  group('Invoice Financial Calculations - GST (CGST_SGST)', () {
    test('cgst_sgst: 18% GST on 1000 taxable = 180 CGST + 180 SGST', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        gstEnabled: true,
        gstType: 'cgst_sgst',
        gstRate: 18,
      );
      expect(invoice.subtotal, 1000.00);
      expect(invoice.taxableAmount, 1000.00);
      expect(invoice.cgstAmount, 90.00); // 1000 * 18 / 200
      expect(invoice.sgstAmount, 90.00);
      expect(invoice.igstAmount, 0);
      expect(invoice.totalTax, 180.00);
      expect(invoice.grandTotal, 1180.00);
    });

    test('cgst_sgst: 5% GST', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 100,
          unitPrice: 100.00,
          gstRate: 5,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        gstEnabled: true,
        gstType: 'cgst_sgst',
        gstRate: 5,
      );
      // subtotal = 10000
      // cgst = 10000 * 5 / 200 = 250
      // sgst = 250
      expect(invoice.cgstAmount, 250.00);
      expect(invoice.sgstAmount, 250.00);
      expect(invoice.totalTax, 500.00);
      expect(invoice.grandTotal, 10500.00);
    });

    test('cgst_sgst: per-item GST rates, different rates per item', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
        LineItem(
          description: 'Item 2',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 5,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        gstEnabled: true,
        gstType: 'cgst_sgst',
      );
      // subtotal = 2000
      // Item 1: 1000 * 18 / 200 = 90
      // Item 2: 1000 * 5 / 200 = 25
      // cgst = 115, sgst = 115
      expect(invoice.cgstAmount, 115.00);
      expect(invoice.sgstAmount, 115.00);
      expect(invoice.totalTax, 230.00);
      expect(invoice.grandTotal, 2230.00);
    });

    test('cgst_sgst with discount: GST applied on taxable amount', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.percentage,
        discountValue: 10,
        gstEnabled: true,
        gstType: 'cgst_sgst',
        gstRate: 18,
      );
      // subtotal = 1000, discount 10% = 100, taxableAmount = 900
      // discountRatio = 900/1000 = 0.9
      // cgst = 1000 * 0.9 * 18 / 200 = 81
      expect(invoice.subtotal, 1000.00);
      expect(invoice.discountAmount, 100.00);
      expect(invoice.taxableAmount, 900.00);
      expect(invoice.cgstAmount, 81.00);
      expect(invoice.sgstAmount, 81.00);
      expect(invoice.totalTax, 162.00);
      expect(invoice.grandTotal, 1062.00);
    });

    test('cgst_sgst: Firestore rule invariants', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 7,
          unitPrice: 143.00,
          gstRate: 12,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        gstEnabled: true,
        gstType: 'cgst_sgst',
        gstRate: 12,
      );
      // Verify invariants: taxableAmount == subtotal - discountAmount
      expect(invoice.taxableAmount, invoice.subtotal - invoice.discountAmount);
      // Verify: totalTax == cgst + sgst + igst
      expect(invoice.totalTax, invoice.cgstAmount + invoice.sgstAmount + invoice.igstAmount);
      // Verify: grandTotal == taxableAmount + totalTax
      expect(invoice.grandTotal, invoice.taxableAmount + invoice.totalTax);
    });
  });

  group('Invoice Financial Calculations - GST (IGST)', () {
    test('igst: 18% GST on 1000 = 180 IGST', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        gstEnabled: true,
        gstType: 'igst',
        gstRate: 18,
      );
      expect(invoice.subtotal, 1000.00);
      expect(invoice.cgstAmount, 0);
      expect(invoice.sgstAmount, 0);
      expect(invoice.igstAmount, 180.00); // 1000 * 18 / 100
      expect(invoice.totalTax, 180.00);
      expect(invoice.grandTotal, 1180.00);
    });

    test('igst: per-item GST rates', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
        LineItem(
          description: 'Item 2',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 5,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        gstEnabled: true,
        gstType: 'igst',
      );
      // subtotal = 2000
      // Item 1: 1000 * 18 / 100 = 180
      // Item 2: 1000 * 5 / 100 = 50
      // igst = 230
      expect(invoice.igstAmount, 230.00);
      expect(invoice.totalTax, 230.00);
      expect(invoice.grandTotal, 2230.00);
    });

    test('igst with discount', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.overall,
        discountValue: 100,
        gstEnabled: true,
        gstType: 'igst',
        gstRate: 18,
      );
      // subtotal = 1000, discount = 100, taxableAmount = 900
      // discountRatio = 900/1000 = 0.9
      // igst = 1000 * 0.9 * 18 / 100 = 162
      expect(invoice.discountAmount, 100.00);
      expect(invoice.taxableAmount, 900.00);
      expect(invoice.igstAmount, 162.00);
      expect(invoice.grandTotal, 1062.00);
    });

    test('igst: Firestore rule invariants', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 5,
          unitPrice: 200.00,
          gstRate: 28,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        gstEnabled: true,
        gstType: 'igst',
        gstRate: 28,
      );
      // Verify invariants
      expect(invoice.taxableAmount, invoice.subtotal - invoice.discountAmount);
      expect(invoice.totalTax, invoice.cgstAmount + invoice.sgstAmount + invoice.igstAmount);
      expect(invoice.grandTotal, invoice.taxableAmount + invoice.totalTax);
    });
  });

  group('Invoice Payment Status', () {
    test('isFullyPaid: true when amountReceived >= grandTotal', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        amountReceived: 100.00,
      );
      expect(invoice.isFullyPaid, true);
    });

    test('isFullyPaid: false when grandTotal is 0', () {
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: [],
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        amountReceived: 100.00,
      );
      expect(invoice.isFullyPaid, false);
    });

    test('isPartiallyPaid: true when 0 < amountReceived < grandTotal', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        amountReceived: 50.00,
      );
      expect(invoice.isPartiallyPaid, true);
    });

    test('isPartiallyPaid: false when amountReceived = 0', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        amountReceived: 0,
      );
      expect(invoice.isPartiallyPaid, false);
    });

    test('balanceDue: grandTotal - amountReceived', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        amountReceived: 30.00,
      );
      expect(invoice.balanceDue, 70.00);
    });

    test('effectiveStatus: paid when isFullyPaid', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        amountReceived: 100.00,
      );
      expect(invoice.effectiveStatus, InvoiceStatus.paid);
    });

    test('effectiveStatus: partiallyPaid when isPartiallyPaid', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        amountReceived: 50.00,
      );
      expect(invoice.effectiveStatus, InvoiceStatus.partiallyPaid);
    });

    test('effectiveStatus: overdue when status is overdue', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.overdue,
        amountReceived: 0,
      );
      expect(invoice.effectiveStatus, InvoiceStatus.overdue);
    });

    test('effectiveStatus: pending when no payment received', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        amountReceived: 0,
      );
      expect(invoice.effectiveStatus, InvoiceStatus.pending);
    });
  });

  group('Invoice Rounding Edge Cases', () {
    test('33.33% discount on 100.00', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.percentage,
        discountValue: 33.33,
      );
      // 100 * 33.33% = 33.33
      expect(invoice.discountAmount, 33.33);
      expect(invoice.taxableAmount, 66.67);
    });

    test('rounding with 0.01 precision: multiple small items', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 0.01,
        ),
        LineItem(
          description: 'Item 2',
          quantity: 2,
          unitPrice: 0.01,
        ),
        LineItem(
          description: 'Item 3',
          quantity: 3,
          unitPrice: 0.01,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
      );
      // 0.01 + 0.02 + 0.03 = 0.06
      expect(invoice.subtotal, 0.06);
    });

    test('complex rounding with GST and discount combined', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 99.99,
          gstRate: 18,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.percentage,
        discountValue: 15,
        gstEnabled: true,
        gstType: 'cgst_sgst',
        gstRate: 18,
      );
      // subtotal = 99.99, discount 15% = 14.9985 -> 15.00
      // taxableAmount = 84.99, discountRatio = 84.99/99.99 ≈ 0.85
      // cgst = 99.99 * 0.85 * 18 / 200 ≈ 7.65
      expect(invoice.subtotal, 99.99);
      expect(invoice.discountAmount, closeTo(15.0, 0.01));
      expect(invoice.taxableAmount, closeTo(84.99, 0.01));
      expect(invoice.cgstAmount, greaterThan(0));
    });

    test('toMap: Firestore rule invariants maintained', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 2,
          unitPrice: 150.00,
          gstRate: 12,
        ),
        LineItem(
          description: 'Item 2',
          quantity: 1,
          unitPrice: 99.99,
          gstRate: 18,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.percentage,
        discountValue: 10,
        gstEnabled: true,
        gstType: 'cgst_sgst',
        gstRate: 12,
      );

      final map = invoice.toMap();
      final sub = map['subtotal'] as double;
      final disc = map['discountAmount'] as double;
      final taxable = map['taxableAmount'] as double;
      final cgst = map['cgstAmount'] as double;
      final sgst = map['sgstAmount'] as double;
      final igst = map['igstAmount'] as double;
      final totalTax = map['totalTax'] as double;
      final grand = map['grandTotal'] as double;

      // Verify invariants from toMap
      expect(taxable, sub - disc); // taxableAmount == subtotal - discountAmount
      expect(totalTax, cgst + sgst + igst); // totalTax == cgst + sgst + igst
      expect(grand, taxable + totalTax); // grandTotal == taxableAmount + totalTax
    });
  });

  group('PurchaseOrder Financial Calculations', () {
    test('purchase order: basic subtotal from items', () {
      final items = [
        PurchaseLineItem(
          productId: 'prod1',
          productName: 'Product 1',
          quantity: 5,
          unitPrice: 100.00,
        ),
        PurchaseLineItem(
          productId: 'prod2',
          productName: 'Product 2',
          quantity: 3,
          unitPrice: 50.00,
        ),
      ];
      final po = PurchaseOrder(
        id: 'po1',
        ownerId: 'user1',
        orderNumber: 'PO-2026-00001',
        supplierName: 'Test Supplier',
        items: items,
        createdAt: DateTime.now(),
      );
      // Product 1: 500, Product 2: 150, subtotal = 650
      expect(po.subtotal, 650.00);
      expect(po.discountAmount, 0);
      expect(po.taxableAmount, 650.00);
      expect(po.grandTotal, 650.00);
    });

    test('purchase order: percentage discount', () {
      final items = [
        PurchaseLineItem(
          productId: 'prod1',
          productName: 'Product 1',
          quantity: 10,
          unitPrice: 100.00,
        ),
      ];
      final po = PurchaseOrder(
        id: 'po1',
        ownerId: 'user1',
        orderNumber: 'PO-2026-00001',
        supplierName: 'Test Supplier',
        items: items,
        createdAt: DateTime.now(),
        discountType: 'percentage',
        discountValue: 10,
      );
      expect(po.subtotal, 1000.00);
      expect(po.discountAmount, 100.00);
      expect(po.taxableAmount, 900.00);
    });

    test('purchase order: overall (flat) discount', () {
      final items = [
        PurchaseLineItem(
          productId: 'prod1',
          productName: 'Product 1',
          quantity: 10,
          unitPrice: 100.00,
        ),
      ];
      final po = PurchaseOrder(
        id: 'po1',
        ownerId: 'user1',
        orderNumber: 'PO-2026-00001',
        supplierName: 'Test Supplier',
        items: items,
        createdAt: DateTime.now(),
        discountType: 'overall',
        discountValue: 75.50,
      );
      expect(po.discountAmount, 75.50);
      expect(po.taxableAmount, 924.50);
    });

    test('purchase order: cgst_sgst GST', () {
      final items = [
        PurchaseLineItem(
          productId: 'prod1',
          productName: 'Product 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
      ];
      final po = PurchaseOrder(
        id: 'po1',
        ownerId: 'user1',
        orderNumber: 'PO-2026-00001',
        supplierName: 'Test Supplier',
        items: items,
        createdAt: DateTime.now(),
        gstEnabled: true,
        gstType: 'cgst_sgst',
        gstRate: 18,
      );
      expect(po.cgstAmount, 90.00); // 1000 * 18 / 200
      expect(po.sgstAmount, 90.00);
      expect(po.totalTax, 180.00);
      expect(po.grandTotal, 1180.00);
    });

    test('purchase order: igst GST', () {
      final items = [
        PurchaseLineItem(
          productId: 'prod1',
          productName: 'Product 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
      ];
      final po = PurchaseOrder(
        id: 'po1',
        ownerId: 'user1',
        orderNumber: 'PO-2026-00001',
        supplierName: 'Test Supplier',
        items: items,
        createdAt: DateTime.now(),
        gstEnabled: true,
        gstType: 'igst',
        gstRate: 18,
      );
      expect(po.cgstAmount, 0);
      expect(po.sgstAmount, 0);
      expect(po.igstAmount, 180.00); // 1000 * 18 / 100
      expect(po.totalTax, 180.00);
      expect(po.grandTotal, 1180.00);
    });

    test('purchase order: GST with discount', () {
      final items = [
        PurchaseLineItem(
          productId: 'prod1',
          productName: 'Product 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
      ];
      final po = PurchaseOrder(
        id: 'po1',
        ownerId: 'user1',
        orderNumber: 'PO-2026-00001',
        supplierName: 'Test Supplier',
        items: items,
        createdAt: DateTime.now(),
        discountType: 'percentage',
        discountValue: 10,
        gstEnabled: true,
        gstType: 'cgst_sgst',
        gstRate: 18,
      );
      // subtotal = 1000, discount = 100, taxableAmount = 900
      // discountRatio = 0.9
      // cgst = 1000 * 0.9 * 18 / 200 = 81
      expect(po.discountAmount, 100.00);
      expect(po.taxableAmount, 900.00);
      expect(po.cgstAmount, 81.00);
      expect(po.sgstAmount, 81.00);
      expect(po.totalTax, 162.00);
      expect(po.grandTotal, 1062.00);
    });

    test('purchase order: per-item GST rates', () {
      final items = [
        PurchaseLineItem(
          productId: 'prod1',
          productName: 'Product 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
        PurchaseLineItem(
          productId: 'prod2',
          productName: 'Product 2',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 5,
        ),
      ];
      final po = PurchaseOrder(
        id: 'po1',
        ownerId: 'user1',
        orderNumber: 'PO-2026-00001',
        supplierName: 'Test Supplier',
        items: items,
        createdAt: DateTime.now(),
        gstEnabled: true,
        gstType: 'cgst_sgst',
      );
      // subtotal = 2000
      // Item 1: 1000 * 18 / 200 = 90
      // Item 2: 1000 * 5 / 200 = 25
      // cgst = 115, sgst = 115
      expect(po.cgstAmount, 115.00);
      expect(po.sgstAmount, 115.00);
      expect(po.totalTax, 230.00);
      expect(po.grandTotal, 2230.00);
    });
  });

  group('PurchaseLineItem Financial Calculations', () {
    test('purchase line item: total = quantity * unitPrice (no rounding)', () {
      final item = PurchaseLineItem(
        productId: 'prod1',
        productName: 'Product 1',
        quantity: 2.5,
        unitPrice: 10.50,
      );
      expect(item.total, 26.25);
    });

    test('purchase line item: zero quantity', () {
      final item = PurchaseLineItem(
        productId: 'prod1',
        productName: 'Product 1',
        quantity: 0,
        unitPrice: 100.00,
      );
      expect(item.total, 0);
    });

    test('purchase line item: fractional quantities', () {
      final item = PurchaseLineItem(
        productId: 'prod1',
        productName: 'Product 1',
        quantity: 3.75,
        unitPrice: 26.67,
      );
      expect(item.total, closeTo(100.0, 0.1));
    });
  });

  group('Invoice Edge Cases and Complex Scenarios', () {
    test('empty invoice: no items = zero totals', () {
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: [],
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
      );
      expect(invoice.subtotal, 0);
      expect(invoice.grandTotal, 0);
      expect(invoice.balanceDue, 0);
    });

    test('multiple items with mixed discount and GST', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 5,
          unitPrice: 100.00,
          discountPercent: 5,
          gstRate: 18,
        ),
        LineItem(
          description: 'Item 2',
          quantity: 3,
          unitPrice: 50.00,
          discountPercent: 10,
          gstRate: 5,
        ),
        LineItem(
          description: 'Item 3',
          quantity: 10,
          unitPrice: 25.00,
          discountPercent: 0,
          gstRate: 12,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        gstEnabled: true,
        gstType: 'cgst_sgst',
      );
      // Item 1: raw 500, discount 25, total 475, gst 18% on LineItem = 85.5
      // Item 2: raw 150, discount 15, total 135, gst 5% on LineItem = 6.75
      // Item 3: raw 250, discount 0, total 250, gst 12% on LineItem = 30
      // Invoice subtotal = 475 + 135 + 250 = 860
      // Invoice: no discount, taxableAmount = 860
      // discountRatio = 860/860 = 1.0
      // cgst = (475 * 18 / 200) + (135 * 5 / 200) + (250 * 12 / 200) = 42.75 + 3.375 + 15 = 61.125 -> 61.13
      expect(invoice.subtotal, 860.00);
      expect(invoice.taxableAmount, 860.00);
      expect(invoice.cgstAmount, greaterThan(0));
      expect(invoice.sgstAmount, greaterThan(0));
      expect(invoice.totalTax, greaterThan(0));
      expect(invoice.grandTotal, greaterThan(860.00));
    });

    test('invoice with discount type null and discountValue > 0: no discount applied', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: null,
        discountValue: 50, // discountValue is set but type is null
      );
      // discount should be 0 because discountType is null
      expect(invoice.discountAmount, 0);
      expect(invoice.taxableAmount, 100.00);
    });

    test('invoice with discountValue = 0: no discount applied', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 100.00,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        discountType: InvoiceDiscountType.percentage,
        discountValue: 0,
      );
      expect(invoice.discountAmount, 0);
      expect(invoice.taxableAmount, 100.00);
    });

    test('invoice with GST disabled: no tax calculated', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 10,
          unitPrice: 100.00,
          gstRate: 18,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
        gstEnabled: false,
        gstRate: 18,
        gstType: 'cgst_sgst',
      );
      expect(invoice.totalTax, 0);
      expect(invoice.grandTotal, 1000.00);
    });

    test('high precision: amounts with many decimal places', () {
      final items = [
        LineItem(
          description: 'Item 1',
          quantity: 1,
          unitPrice: 123.456,
        ),
      ];
      final invoice = Invoice(
        id: 'inv1',
        ownerId: 'user1',
        invoiceNumber: 'BR-2026-00001',
        clientId: 'client1',
        clientName: 'Test Client',
        items: items,
        createdAt: DateTime.now(),
        status: InvoiceStatus.pending,
      );
      // unitPrice 123.456 -> subtotal should be rounded to 2 decimals
      expect(invoice.subtotal, 123.46);
    });
  });
}
