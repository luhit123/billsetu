import 'package:cloud_functions/cloud_functions.dart';

class InvoiceNumberService {
  InvoiceNumberService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<String> reserveNextInvoiceNumber({int? year}) async {
    final payload = year == null
        ? const <String, dynamic>{}
        : <String, dynamic>{'year': year};
    final result = await _functions
        .httpsCallable('reserveInvoiceNumber')
        .call(payload);

    final data = result.data;
    if (data is Map && data['invoiceNumber'] is String) {
      final invoiceNumber = (data['invoiceNumber'] as String).trim();
      if (invoiceNumber.isNotEmpty) {
        return invoiceNumber;
      }
    }

    throw StateError('Unable to reserve the next invoice number.');
  }
}
