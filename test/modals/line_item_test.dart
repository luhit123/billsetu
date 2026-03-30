import 'package:billeasy/modals/line_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LineItem — computed fields', () {
    test('rawTotal = quantity * unitPrice', () {
      const item = LineItem(description: 'Bolt', quantity: 10, unitPrice: 25);
      expect(item.rawTotal, 250);
    });

    test('discount reduces total', () {
      const item = LineItem(
        description: 'Widget',
        quantity: 1,
        unitPrice: 1000,
        discountPercent: 10,
      );
      expect(item.rawTotal, 1000);
      expect(item.discountAmount, 100);
      expect(item.total, 900);
    });

    test('GST computed on post-discount total', () {
      const item = LineItem(
        description: 'Service',
        quantity: 1,
        unitPrice: 1000,
        discountPercent: 10,
        gstRate: 18,
      );
      // total = 900, gst = 900*18/100 = 162
      expect(item.total, 900);
      expect(item.gstAmount, 162);
      expect(item.totalWithGst, 1062);
    });

    test('zero discount and zero GST', () {
      const item = LineItem(description: 'Basic', quantity: 3, unitPrice: 100);
      expect(item.discountAmount, 0);
      expect(item.gstAmount, 0);
      expect(item.total, 300);
      expect(item.totalWithGst, 300);
    });

    test('fractional quantity', () {
      const item = LineItem(description: 'Cloth', quantity: 2.5, unitPrice: 200);
      expect(item.rawTotal, 500);
    });

    test('quantityLabel includes unit', () {
      const item = LineItem(description: 'Rice', quantity: 5, unitPrice: 50, unit: 'kg');
      expect(item.quantityLabel, '5 kg');
    });

    test('quantityLabel without unit', () {
      const item = LineItem(description: 'Item', quantity: 3, unitPrice: 10);
      expect(item.quantityLabel, '3');
    });
  });

  group('LineItem — serialization', () {
    test('fromMap → toMap round-trip', () {
      const original = LineItem(
        description: 'Test Product',
        quantity: 2.5,
        unitPrice: 150,
        unit: 'kg',
        hsnCode: '1234',
        gstRate: 12,
        discountPercent: 5,
        productId: 'prod-1',
      );

      final map = original.toMap();
      final restored = LineItem.fromMap(map);

      expect(restored.description, 'Test Product');
      expect(restored.quantity, 2.5);
      expect(restored.unitPrice, 150);
      expect(restored.unit, 'kg');
      expect(restored.hsnCode, '1234');
      expect(restored.gstRate, 12);
      expect(restored.discountPercent, 5);
      expect(restored.productId, 'prod-1');
    });

    test('fromMap handles missing fields gracefully', () {
      final item = LineItem.fromMap({'description': 'Minimal'});
      expect(item.description, 'Minimal');
      expect(item.quantity, 0);
      expect(item.unitPrice, 0);
      expect(item.unit, '');
      expect(item.gstRate, 0);
    });
  });

  group('LineItem — formatQuantity', () {
    test('whole numbers have no decimals', () {
      expect(LineItem.formatQuantity(5.0), '5');
      expect(LineItem.formatQuantity(100.0), '100');
    });

    test('fractional values trimmed', () {
      expect(LineItem.formatQuantity(2.5), '2.5');
      expect(LineItem.formatQuantity(3.14), '3.14');
      expect(LineItem.formatQuantity(1.10), '1.1');
    });
  });
}
