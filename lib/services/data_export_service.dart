import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'team_service.dart';
import '../modals/invoice.dart';
import '../modals/client.dart';
import '../modals/product.dart';

/// Random suffix generator to prevent predictable temp file paths (Issue #21).
String _randomSuffix() {
  final rng = Random.secure();
  return List.generate(8, (_) => rng.nextInt(16).toRadixString(16)).join();
}

class DataExportService {
  DataExportService._();
  static final DataExportService instance = DataExportService._();

  final _db = FirebaseFirestore.instance;

  Future<void> exportInvoicesCSV() async {
    final uid = TeamService.instance.getEffectiveOwnerId();

    final rows = <List<dynamic>>[
      [
        'Invoice #',
        'Date',
        'Customer',
        'Status',
        'Subtotal',
        'Tax',
        'Total',
        'Due Date',
      ],
    ];

    const pageSize = 500;
    DocumentSnapshot? lastDoc;

    while (true) {
      var query = _db
          .collection('invoices')
          .where('ownerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final inv = Invoice.fromMap(doc.data(), docId: doc.id);
        rows.add([
          inv.invoiceNumber,
          inv.createdAt.toIso8601String(),
          inv.clientName,
          inv.status.name,
          inv.subtotal,
          inv.totalTax,
          inv.grandTotal,
          inv.dueDate?.toIso8601String() ?? '',
        ]);
      }

      if (snap.docs.length < pageSize) break;
      lastDoc = snap.docs.last;
    }

    final csv = const ListToCsvConverter().convert(rows);
    await _shareAndCleanup(csv, 'invoices_export_${_randomSuffix()}.csv', 'Invoices Export');
  }

  Future<void> exportCustomersCSV() async {
    final uid = TeamService.instance.getEffectiveOwnerId();

    final rows = <List<dynamic>>[
      ['Name', 'Phone', 'Email', 'GSTIN', 'Address'],
    ];

    const pageSize = 500;
    DocumentSnapshot? lastDoc;

    while (true) {
      var query = _db
          .collection('users')
          .doc(uid)
          .collection('clients')
          .orderBy(FieldPath.documentId)
          .limit(pageSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final c = Client.fromMap(doc.data(), docId: doc.id);
        rows.add([c.name, c.phone, c.email, c.gstin, c.address]);
      }

      if (snap.docs.length < pageSize) break;
      lastDoc = snap.docs.last;
    }

    final csv = const ListToCsvConverter().convert(rows);
    await _shareAndCleanup(csv, 'customers_export_${_randomSuffix()}.csv', 'Customers Export');
  }

  Future<void> exportProductsCSV() async {
    final uid = TeamService.instance.getEffectiveOwnerId();

    final rows = <List<dynamic>>[
      [
        'Name',
        'Description',
        'Unit Price',
        'Unit',
        'Category',
        'HSN Code',
        'GST Rate',
        'GST Applicable',
        'Current Stock',
      ],
    ];

    const pageSize = 500;
    DocumentSnapshot? lastDoc;

    while (true) {
      var query = _db
          .collection('users')
          .doc(uid)
          .collection('products')
          .orderBy(FieldPath.documentId)
          .limit(pageSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      for (final doc in snap.docs) {
        final p = Product.fromMap(doc.data(), docId: doc.id);
        rows.add([
          p.name,
          p.description,
          p.unitPrice,
          p.unit,
          p.category,
          p.hsnCode,
          p.gstRate,
          p.gstApplicable ? 'Yes' : 'No',
          p.currentStock,
        ]);
      }

      if (snap.docs.length < pageSize) break;
      lastDoc = snap.docs.last;
    }

    final csv = const ListToCsvConverter().convert(rows);
    await _shareAndCleanup(csv, 'products_export_${_randomSuffix()}.csv', 'Products Export');
  }

  /// Write CSV to a temp file, share it, then delete the file.
  Future<void> _shareAndCleanup(
    String csv,
    String fileName,
    String subject,
  ) async {
    if (kIsWeb) {
      // On web, share from bytes directly (no temp file)
      final bytes = Uint8List.fromList(utf8.encode(csv));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
          text: subject,
        ),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    try {
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: subject),
      );
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('[DataExport] Temp file cleanup failed: $e');
      }
    }
  }
}
