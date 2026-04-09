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

    try {
      await _functions
          .httpsCallable('backfillMyInvoiceData', options: HttpsCallableOptions(timeout: const Duration(seconds: 60)))
          .call()
          .timeout(const Duration(seconds: 30));
      // Only mark as complete after confirmed success.
      await prefs.setBool(_invoiceSearchBackfillKey, true);
    } catch (_) {
      // Don't set the flag — next app start will retry.
    }
  }
}
