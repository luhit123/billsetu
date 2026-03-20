import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modals/invoice.dart';
import '../modals/client.dart';
import '../modals/product.dart';

class DataExportService {
  DataExportService._();
  static final DataExportService instance = DataExportService._();

  final _db = FirebaseFirestore.instance;

  Future<void> exportInvoicesCSV() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await _db
        .collection('invoices')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

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

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/invoices_export.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Invoices Export');
  }

  Future<void> exportCustomersCSV() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await _db
        .collection('clients')
        .where('ownerId', isEqualTo: uid)
        .get();

    final rows = <List<dynamic>>[
      ['Name', 'Phone', 'Email', 'GSTIN', 'Address'],
    ];

    for (final doc in snap.docs) {
      final c = Client.fromMap(doc.data(), docId: doc.id);
      rows.add([
        c.name,
        c.phone,
        c.email,
        c.gstin,
        c.address,
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/customers_export.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Customers Export');
  }

  Future<void> exportProductsCSV() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await _db
        .collection('products')
        .where('ownerId', isEqualTo: uid)
        .get();

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

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/products_export.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Products Export');
  }
}
