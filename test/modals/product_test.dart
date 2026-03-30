import 'package:billeasy/modals/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product — computed fields', () {
    test('initials from two-word name', () {
      const p = Product(id: '1', name: 'Thermal Paper');
      expect(p.initials, 'TP');
    });

    test('initials from single-word name', () {
      const p = Product(id: '1', name: 'Bolts');
      expect(p.initials, 'B');
    });

    test('priceLabel formats whole number', () {
      const p = Product(id: '1', name: 'Widget', unitPrice: 500, unit: 'pcs');
      expect(p.priceLabel, '\u20b9500 / pcs');
    });

    test('priceLabel formats decimal', () {
      const p = Product(id: '1', name: 'Cloth', unitPrice: 99.50, unit: 'meter');
      expect(p.priceLabel, '\u20b999.50 / meter');
    });
  });

  group('Product — serialization', () {
    test('fromMap → toMap round-trip', () {
      final now = DateTime(2026, 3, 28);
      final original = Product(
        id: 'p-1',
        name: 'A4 Paper',
        description: 'Premium quality',
        unitPrice: 350,
        unit: 'ream',
        category: 'Stationery',
        hsnCode: '4802',
        gstRate: 12,
        gstApplicable: true,
        currentStock: 50,
        minStockAlert: 10,
        trackInventory: true,
        createdAt: now,
      );

      final map = original.toMap();
      final restored = Product.fromMap(map, docId: 'p-1');

      expect(restored.name, 'A4 Paper');
      expect(restored.unitPrice, 350);
      expect(restored.hsnCode, '4802');
      expect(restored.gstRate, 12);
      expect(restored.gstApplicable, true);
      expect(restored.currentStock, 50);
      expect(restored.minStockAlert, 10);
    });

    test('fromMap defaults', () {
      final p = Product.fromMap({'name': 'Minimal'}, docId: 'p-min');
      expect(p.id, 'p-min');
      expect(p.unit, 'pcs');
      expect(p.gstRate, 18.0);
      expect(p.gstApplicable, false);
      expect(p.trackInventory, true);
      expect(p.currentStock, 0);
    });

    test('nameLower in toMap', () {
      const p = Product(id: '1', name: '  Thermal Paper  ');
      final map = p.toMap();
      expect(map['nameLower'], 'thermal paper');
    });
  });

  group('Product — copyWith', () {
    test('preserves unmodified fields', () {
      const original = Product(
        id: '1',
        name: 'Old',
        unitPrice: 100,
        currentStock: 50,
      );
      final updated = original.copyWith(name: 'New', unitPrice: 200);
      expect(updated.name, 'New');
      expect(updated.unitPrice, 200);
      expect(updated.currentStock, 50); // unchanged
      expect(updated.id, '1'); // unchanged
    });
  });
}
