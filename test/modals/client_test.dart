import 'package:billeasy/modals/client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Client — initials', () {
    test('two-word name gives two initials', () {
      const client = Client(id: '1', name: 'Akash Traders');
      expect(client.initials, 'AT');
    });

    test('single-word name gives one initial', () {
      const client = Client(id: '1', name: 'Walmart');
      expect(client.initials, 'W');
    });

    test('empty name gives ?', () {
      const client = Client(id: '1', name: '');
      expect(client.initials, '?');
    });

    test('lowercase converted to uppercase', () {
      const client = Client(id: '1', name: 'john doe');
      expect(client.initials, 'JD');
    });
  });

  group('Client — subtitle', () {
    test('prefers phone', () {
      const client = Client(id: '1', name: 'A', phone: '+919876543210', email: 'a@b.com');
      expect(client.subtitle, '+919876543210');
    });

    test('falls back to email', () {
      const client = Client(id: '1', name: 'A', email: 'a@b.com');
      expect(client.subtitle, 'a@b.com');
    });

    test('falls back to address', () {
      const client = Client(id: '1', name: 'A', address: 'Mumbai');
      expect(client.subtitle, 'Mumbai');
    });

    test('falls back to group', () {
      const client = Client(id: '1', name: 'A', groupName: 'VIP');
      expect(client.subtitle, 'Group: VIP');
    });

    test('default message when empty', () {
      const client = Client(id: '1', name: 'A');
      expect(client.subtitle, 'No contact details added yet');
    });
  });

  group('Client — serialization', () {
    test('fromMap → toMap round-trip', () {
      final now = DateTime(2026, 3, 28);
      final original = Client(
        id: 'c-1',
        name: 'Test Corp',
        phone: '+911234567890',
        email: 'test@corp.com',
        address: '123 Main St, Mumbai',
        gstin: '27AADCT1234A1Z5',
        groupId: 'g-1',
        groupName: 'Premium',
        notes: 'Important client',
        createdAt: now,
      );

      final map = original.toMap();
      final restored = Client.fromMap(map, docId: 'c-1');

      expect(restored.name, 'Test Corp');
      expect(restored.phone, '+911234567890');
      expect(restored.gstin, '27AADCT1234A1Z5');
      expect(restored.groupName, 'Premium');
    });

    test('fromMap handles missing fields', () {
      final client = Client.fromMap({'name': 'Minimal'}, docId: 'c-min');
      expect(client.id, 'c-min');
      expect(client.name, 'Minimal');
      expect(client.phone, '');
      expect(client.gstin, '');
    });

    test('nameLower is normalized in toMap', () {
      const client = Client(id: '1', name: '  Akash Traders  ');
      final map = client.toMap();
      expect(map['nameLower'], 'akash traders');
    });
  });

  group('Client — copyWith', () {
    test('copies with overrides', () {
      const original = Client(id: '1', name: 'Old Name', phone: '123');
      final updated = original.copyWith(name: 'New Name');
      expect(updated.name, 'New Name');
      expect(updated.phone, '123'); // preserved
    });
  });
}
