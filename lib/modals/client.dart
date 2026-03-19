import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  const Client({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.groupId = '',
    this.groupName = '',
    this.gstin = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final String groupId;
  final String groupName;
  final String gstin;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get initials {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return '?';
    }

    final parts = trimmedName.split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final value = '$first$second'.trim();
    return value.isEmpty ? '?' : value.toUpperCase();
  }

  String get subtitle {
    if (phone.trim().isNotEmpty) {
      return phone.trim();
    }

    if (email.trim().isNotEmpty) {
      return email.trim();
    }

    if (address.trim().isNotEmpty) {
      return address.trim();
    }

    if (groupName.trim().isNotEmpty) {
      return 'Group: ${groupName.trim()}';
    }

    return 'No contact details added yet';
  }

  Client copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    String? groupId,
    String? groupName,
    String? gstin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      gstin: gstin ?? this.gstin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Client.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Client(
      id: docId ?? (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      groupName: map['groupName'] as String? ?? '',
      gstin: map['gstin'] as String? ?? '',
      createdAt: _dateTimeFromMapValue(map['createdAt']),
      updatedAt: _dateTimeFromMapValue(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'id': id,
      'name': name,
      'nameLower': _normalizeName(name),
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'groupId': groupId,
      'groupName': groupName,
      'gstin': gstin,
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
