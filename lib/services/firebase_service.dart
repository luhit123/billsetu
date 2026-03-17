import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:billeasy/modals/invoice.dart';

class FirebaseService {
  FirebaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _invoicesCollection {
    return _firestore.collection('invoices');
  }

  Stream<List<Invoice>> getInvoicesStream() {
    return _invoicesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Invoice.fromMap(doc.data(), docId: doc.id))
              .toList();
        });
  }

  Future<void> addInvoice(Invoice inv) async {
    final docRef = inv.id.isNotEmpty
        ? _invoicesCollection.doc(inv.id)
        : _invoicesCollection.doc();

    final data = inv.toMap()..['id'] = docRef.id;
    await docRef.set(data);
  }

  Future<void> updateInvoiceStatus(String id, InvoiceStatus status) async {
    await _invoicesCollection.doc(id).update({'status': status.name});
  }

  Future<void> deleteInvoice(String id) async {
    await _invoicesCollection.doc(id).delete();
  }
}
