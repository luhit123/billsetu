import 'dart:math';
import 'dart:typed_data';

import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/services/invoice_pdf_service.dart';
import 'package:billeasy/services/remote_config_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Simple LRU cache with a fixed maximum capacity (Issue #15).
class _LruCache<K, V> {
  final int maxSize;
  final _map = <K, V>{};

  _LruCache(this.maxSize);

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value; // Move to end (most recent)
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > maxSize) {
      _map.remove(_map.keys.first); // Evict oldest
    }
  }

  bool containsKey(K key) => _map.containsKey(key);
}

/// Uploads invoice PDFs to Firebase Storage, writes metadata to Firestore,
/// and returns a branded download URL.
class InvoiceLinkService {
  InvoiceLinkService._();

  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Issue #20: Base URL now reads from Remote Config with hardcoded fallback.
  static String get _baseUrl {
    try {
      final rcUrl = RemoteConfigService.instance.shareBaseUrl;
      if (rcUrl.isNotEmpty) return rcUrl;
    } catch (_) {}
    return 'https://invoice.billraja.online';
  }

  /// Returns the Storage path for an invoice PDF.
  static String _storagePath(
    String ownerId,
    String writerUid,
    Invoice invoice,
  ) {
    final fileName = InvoicePdfService().fileNameForInvoice(invoice);
    return 'invoices/$ownerId/$writerUid/${invoice.id}/$fileName';
  }

  /// LRU cache with 100-entry limit to prevent unbounded growth (Issue #15).
  static final _LruCache<String, String> _shortCodeCache = _LruCache(100);

  static final _secureRandom = Random.secure();

  /// Generates a cryptographically random short code for new links.
  /// Reuses existing codes from Firestore if one was already created for this invoice.
  static Future<String> _shortCode(Invoice invoice) async {
    final key = '${invoice.id}_${invoice.invoiceNumber}';
    final cached = _shortCodeCache.get(key);
    if (cached != null) return cached;

    // Check if a shared link already exists for this invoice.
    if (invoice.id.isNotEmpty) {
      final ownerId = TeamService.instance.getEffectiveOwnerId();
      final existing = await _firestore
          .collection('shared_invoices')
          .where('invoiceId', isEqualTo: invoice.id)
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        final code = existing.docs.first.id;
        _shortCodeCache.put(key, code);
        return code;
      }
    }

    // Generate cryptographically random 32-character hex string
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    final code = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _shortCodeCache.put(key, code);
    return code;
  }

  static Future<void> _saveSharedInvoiceMetadata({
    required String shortCode,
    required Invoice invoice,
    String? templateName,
    String? downloadUrl,
  }) async {
    final invoiceId = invoice.id.trim();
    if (invoiceId.isEmpty) {
      throw StateError('Please save the invoice before sharing it.');
    }

    await _functions.httpsCallable('saveSharedInvoiceLink', options: HttpsCallableOptions(timeout: const Duration(seconds: 15))).call({
      'shortCode': shortCode,
      'invoiceId': invoiceId,
      if (templateName != null && templateName.trim().isNotEmpty)
        'templateName': templateName.trim(),
      if (downloadUrl != null && downloadUrl.trim().isNotEmpty)
        'downloadUrl': downloadUrl.trim(),
    });
  }

  /// Uploads [pdfBytes] for [invoice], writes shared metadata to Firestore,
  /// and returns a branded download URL.
  ///
  /// Idempotent — skips re-upload and re-write if already done.
  static Future<String> uploadAndGetLink({
    required Invoice invoice,
    required Uint8List pdfBytes,
  }) async {
    if (invoice.id.trim().isEmpty) {
      throw StateError('Please save the invoice before sharing it.');
    }

    final ownerId = TeamService.instance.getEffectiveOwnerId();
    final actualUid = TeamService.instance.getActualUserId();

    final shortCode = await _shortCode(invoice);

    // Upload PDF to Storage (skip if already uploaded)
    final path = _storagePath(ownerId, actualUid, invoice);
    final ref = _storage.ref(path);

    String downloadUrl;
    try {
      downloadUrl = await ref.getDownloadURL();
    } on FirebaseException catch (_) {
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

    await _saveSharedInvoiceMetadata(
      shortCode: shortCode,
      invoice: invoice,
      downloadUrl: downloadUrl,
    );

    return '$_baseUrl/i/$shortCode';
  }

  /// Instant link generation — writes metadata to Firestore only,
  /// NO PDF upload. The web landing page renders the invoice from data.
  /// ~200ms vs 3-5 seconds for uploadAndGetLink.
  static Future<String> shareLink({
    required Invoice invoice,
    String? templateName,
  }) async {
    if (invoice.id.trim().isEmpty) {
      throw StateError('Please save the invoice before sharing it.');
    }

    final shortCode = await _shortCode(invoice);
    await _saveSharedInvoiceMetadata(
      shortCode: shortCode,
      invoice: invoice,
      templateName: templateName,
    );

    return '$_baseUrl/i/$shortCode';
  }

  /// Returns the existing branded link if metadata was previously written,
  /// or `null` if no shared link exists yet.
  static Future<String?> getExistingLink(Invoice invoice) async {
    if (invoice.id.trim().isEmpty) {
      return null;
    }

    final ownerId = TeamService.instance.getEffectiveOwnerId();
    final existing = await _firestore
        .collection('shared_invoices')
        .where('invoiceId', isEqualTo: invoice.id)
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return '$_baseUrl/i/${existing.docs.first.id}';
    }
    return null;
  }
}
