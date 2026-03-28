import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundMaintenanceService {
  BackgroundMaintenanceService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  static const String _invoiceSearchBackfillKey =
      'maintenance.invoice_search_backfill.v3';

  final FirebaseFunctions _functions;

  Future<void> ensureInvoiceSearchBackfill() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_invoiceSearchBackfillKey) == true) {
      return;
    }

    await _functions.httpsCallable('backfillMyInvoiceData').call();
    await prefs.setBool(_invoiceSearchBackfillKey, true);
  }
}
