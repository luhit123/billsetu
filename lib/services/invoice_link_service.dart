import 'dart:math';
import 'dart:typed_data';

import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/invoice_pdf_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

/// Uploads invoice PDFs to Firebase Storage, writes metadata to Firestore,
/// and returns a branded download URL.
class InvoiceLinkService {
  InvoiceLinkService._();

  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _baseUrl = 'https://invoice.billraja.online';

  /// Returns the Storage path for an invoice PDF.
  static String _storagePath(String ownerId, Invoice invoice) {
    final fileName = InvoicePdfService().fileNameForInvoice(invoice);
    return 'invoices/$ownerId/${invoice.id}/$fileName';
  }

  static const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  static final _rng = Random.secure();

  /// Cache to ensure same invoice always gets same shortcode within a session.
  static final Map<String, String> _shortCodeCache = {};

  /// Generates a deterministic short code from invoice ID + number.
  /// Falls back to a random code only if invoice ID is empty.
  static String _shortCode(Invoice invoice) {
    final key = '${invoice.id}_${invoice.invoiceNumber}';
    if (_shortCodeCache.containsKey(key)) return _shortCodeCache[key]!;

    final String code;
    if (invoice.id.isNotEmpty) {
      // Deterministic: same invoice always produces same code
      final hash = sha256.convert('${invoice.id}${invoice.invoiceNumber}'.codeUnits).toString();
      code = hash.substring(0, 16);
    } else {
      // Fallback for unsaved invoices — random but cached
      final hash = sha256.convert('${invoice.invoiceNumber}${DateTime.now().millisecondsSinceEpoch}'.codeUnits).toString();
      code = hash.substring(0, 16);
    }
    _shortCodeCache[key] = code;
    return code;
  }

  /// Uploads [pdfBytes] for [invoice], writes shared metadata to Firestore,
  /// and returns a branded download URL.
  ///
  /// Idempotent — skips re-upload and re-write if already done.
  static Future<String> uploadAndGetLink({
    required Invoice invoice,
    required Uint8List pdfBytes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('User not authenticated');

    final shortCode = _shortCode(invoice);

    // Check if branded link already exists
    final existingDoc =
        await _firestore.collection('shared_invoices').doc(shortCode).get();
    if (existingDoc.exists) {
      return '$_baseUrl/i/$shortCode';
    }

    // Upload PDF to Storage
    final path = _storagePath(uid, invoice);
    final ref = _storage.ref(path);

    String downloadUrl;
    try {
      downloadUrl = await ref.getDownloadURL();
    } on FirebaseException catch (_) {
      // Not found — upload
      await ref.putData(
        pdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'invoiceNumber': invoice.invoiceNumber,
            'clientName': invoice.clientName,
            'createdAt': invoice.createdAt.toIso8601String(),
          },
        ),
      );
      downloadUrl = await ref.getDownloadURL();
    }

    // Write metadata for the landing page (includes item details)
    final data = <String, dynamic>{
      'invoiceNumber': invoice.invoiceNumber,
      'clientId': invoice.clientId,
      'clientName': invoice.clientName,
      'amount': invoice.grandTotal,
      'subtotal': invoice.subtotal,
      'date': DateFormat('dd MMM yyyy').format(invoice.createdAt),
      'status': invoice.status.name,
      'downloadUrl': downloadUrl,
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 90))),
      // Item details for the landing page
      'items': invoice.items
          .map((item) => {
                'description': item.description,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'unit': item.unit,
                'hsnCode': item.hsnCode,
                'gstRate': item.gstRate,
                'total': item.total,
              })
          .toList(),
      // Tax & discount breakdown
      'discountAmount': invoice.discountAmount,
      'gstEnabled': invoice.gstEnabled,
      'gstType': invoice.gstType,
      'cgstAmount': invoice.cgstAmount,
      'sgstAmount': invoice.sgstAmount,
      'igstAmount': invoice.igstAmount,
      'totalTax': invoice.totalTax,
    };

    // Include UPI payment details if configured
    final profile = await ProfileService().getCurrentProfile();
    if (profile != null) {
      if (profile.upiId.isNotEmpty) data['upiId'] = profile.upiId;
      if (profile.upiNumber.isNotEmpty) data['upiNumber'] = profile.upiNumber;
      if (profile.upiQrUrl.isNotEmpty) data['upiQrUrl'] = profile.upiQrUrl;
      if (profile.storeName.isNotEmpty) data['storeName'] = profile.storeName;
    }

    // NOTE: clientPhone intentionally NOT stored in shared_invoices
    // to avoid exposing customer PII in a publicly readable collection.
    // OTP verification should be handled via an authenticated Cloud Function.

    await _firestore.collection('shared_invoices').doc(shortCode).set(data);

    return '$_baseUrl/i/$shortCode';
  }

  /// Instant link generation — writes metadata to Firestore only,
  /// NO PDF upload. The web landing page renders the invoice from data.
  /// ~200ms vs 3-5 seconds for uploadAndGetLink.
  static Future<String> shareLink({
    required Invoice invoice,
    String? templateName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('User not authenticated');

    final shortCode = _shortCode(invoice);

    // Check if link already exists (idempotent)
    final existingDoc =
        await _firestore.collection('shared_invoices').doc(shortCode).get();
    if (existingDoc.exists) {
      return '$_baseUrl/i/$shortCode';
    }

    // Build metadata — everything the landing page needs to render
    final data = <String, dynamic>{
      'invoiceNumber': invoice.invoiceNumber,
      'clientId': invoice.clientId,
      'clientName': invoice.clientName,
      'amount': invoice.grandTotal,
      'subtotal': invoice.subtotal,
      'date': DateFormat('dd MMM yyyy').format(invoice.createdAt),
      'status': invoice.status.name,
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'items': invoice.items
          .map((item) => {
                'description': item.description,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'unit': item.unit,
                'hsnCode': item.hsnCode,
                'gstRate': item.gstRate,
                'total': item.total,
                'discountPercent': item.discountPercent,
              })
          .toList(),
      'discountAmount': invoice.discountAmount,
      'discountType': invoice.discountType?.name,
      'discountValue': invoice.discountValue,
      'gstEnabled': invoice.gstEnabled,
      'gstType': invoice.gstType,
      'cgstAmount': invoice.cgstAmount,
      'sgstAmount': invoice.sgstAmount,
      'igstAmount': invoice.igstAmount,
      'totalTax': invoice.totalTax,
      'customerGstin': invoice.customerGstin,
      if (invoice.dueDate != null)
        'dueDate': DateFormat('dd MMM yyyy').format(invoice.dueDate!),
      if (templateName != null) 'templateName': templateName,
    };

    // Seller details for the landing page
    final profile = await ProfileService().getCurrentProfile();
    if (profile != null) {
      data['storeName'] = profile.storeName;
      data['sellerPhone'] = profile.phoneNumber;
      data['sellerAddress'] = profile.address;
      data['sellerGstin'] = profile.gstin;
      if (profile.upiId.isNotEmpty) data['upiId'] = profile.upiId;
      if (profile.upiNumber.isNotEmpty) data['upiNumber'] = profile.upiNumber;
      if (profile.upiQrUrl.isNotEmpty) data['upiQrUrl'] = profile.upiQrUrl;
    }

    // Client phone for bill history
    if (invoice.clientId.isNotEmpty) {
      try {
        final client = await ClientService().getClient(invoice.clientId);
        if (client != null && client.phone.trim().isNotEmpty) {
          data['clientPhone'] = client.phone.trim();
        }
      } catch (_) {}
    }

    await _firestore.collection('shared_invoices').doc(shortCode).set(data);
    return '$_baseUrl/i/$shortCode';
  }

  /// Returns the existing branded link if metadata was previously written,
  /// or `null` if no shared link exists yet.
  static Future<String?> getExistingLink(Invoice invoice) async {
    final shortCode = _shortCode(invoice);
    final doc =
        await _firestore.collection('shared_invoices').doc(shortCode).get();
    if (doc.exists) {
      return '$_baseUrl/i/$shortCode';
    }
    return null;
  }
}
