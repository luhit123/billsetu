import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerGroup {
  const CustomerGroup({
    required this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerGroup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CustomerGroup.fromMap(Map<String, dynamic> map, {String? docId}) {
    return CustomerGroup(
      id: docId ?? (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      createdAt: _dateTimeFromMapValue(map['createdAt']),
      updatedAt: _dateTimeFromMapValue(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'id': id,
      'name': name,
      'nameLower': _normalizeName(name),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };

    data.removeWhere((key, value) => value == null);
    return data;
  }

  static String _normalizeName(String value) {
    return value.trim().toLowerCase();
  }

  static DateTime? _dateTimeFromMapValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
