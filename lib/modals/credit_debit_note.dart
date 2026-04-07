import 'package:cloud_firestore/cloud_firestore.dart';
import 'line_item.dart';

/// Type of adjustment note for GST compliance.
enum NoteType { credit, debit }

/// Reason for issuing a credit/debit note per GST rules.
enum NoteReason {
  salesReturn,
  postSaleDiscount,
  deficiency,
  correction,
  other,
}

/// Credit Note (CN) / Debit Note (DN) model for GST compliance.
///
/// As per GST law:
/// - **Credit Note**: Issued when taxable value or tax in the original invoice
///   needs to be reduced (e.g., goods returned, post-sale discount).
/// - **Debit Note**: Issued when taxable value or tax needs to be increased
///   (e.g., undercharging in original invoice).
///
/// Both CN and DN must be reported in GSTR-1 (Table 9) and affect
/// the net GST liability in GSTR-3B.
class CreditDebitNote {
  const CreditDebitNote({
    required this.id,
    required this.ownerId,
    required this.noteNumber,
    required this.noteType,
    required this.reason,
    required this.originalInvoiceId,
    required this.originalInvoiceNumber,
    required this.clientId,
    required this.clientName,
    required this.items,
    required this.createdAt,
    this.customerGstin = '',
    this.gstEnabled = false,
    this.gstType = 'cgst_sgst',
    this.notes,
  });

  final String id;
  final String ownerId;
  final String noteNumber; // Format: CN-YYYY-NNNNN or DN-YYYY-NNNNN
  final NoteType noteType;
  final NoteReason reason;
  final String originalInvoiceId;
  final String originalInvoiceNumber;
  final String clientId;
  final String clientName;
  final List<LineItem> items;
  final DateTime createdAt;
  final String customerGstin;
  final bool gstEnabled;
  final String gstType;
  final String? notes;

  /// Whether this is a B2B note (customer has valid GSTIN).
  /// A valid GSTIN is exactly 15 characters per GST format rules.
  bool get isB2B => customerGstin.trim().length >= 15;

  static double _roundCurrency(num value) {
    return (value * 100).roundToDouble() / 100;
  }

  double get subtotal =>
      _roundCurrency(items.fold(0.0, (acc, item) => acc + item.total));

  double get totalTax {
    if (!gstEnabled) return 0;
    double tax = 0;
    for (final item in items) {
      if (gstType == 'cgst_sgst') {
        tax += item.total * item.gstRate / 100; // CGST + SGST combined
      } else {
        tax += item.total * item.gstRate / 100; // IGST
      }
    }
    return _roundCurrency(tax);
  }

  double get grandTotal => _roundCurrency(subtotal + totalTax);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'noteNumber': noteNumber,
      'noteType': noteType.name,
      'reason': reason.name,
      'originalInvoiceId': originalInvoiceId,
      'originalInvoiceNumber': originalInvoiceNumber,
      'clientId': clientId,
      'clientName': clientName,
      'customerGstin': customerGstin,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'gstEnabled': gstEnabled,
      'gstType': gstType,
      'subtotal': subtotal,
      'totalTax': totalTax,
      'grandTotal': grandTotal,
      'isB2B': isB2B,
      if (notes != null) 'notes': notes,
    };
  }

  factory CreditDebitNote.fromMap(Map<String, dynamic> map,
      {String? docId}) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return CreditDebitNote(
      id: docId ?? (map['id'] as String? ?? ''),
      ownerId: map['ownerId'] as String? ?? '',
      noteNumber: map['noteNumber'] as String? ?? '',
      noteType: NoteType.values.firstWhere(
        (e) => e.name == (map['noteType'] as String? ?? ''),
        orElse: () => NoteType.credit,
      ),
      reason: NoteReason.values.firstWhere(
        (e) => e.name == (map['reason'] as String? ?? ''),
        orElse: () => NoteReason.other,
      ),
      originalInvoiceId: map['originalInvoiceId'] as String? ?? '',
      originalInvoiceNumber: map['originalInvoiceNumber'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      clientName: map['clientName'] as String? ?? '',
      customerGstin: map['customerGstin'] as String? ?? '',
      items: rawItems
          .map((item) => LineItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      createdAt: _dateTimeFromMapValue(map['createdAt']),
      gstEnabled: map['gstEnabled'] as bool? ?? false,
      gstType: map['gstType'] as String? ?? 'cgst_sgst',
      notes: map['notes'] as String?,
    );
  }

  static DateTime _dateTimeFromMapValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
