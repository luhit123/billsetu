import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_config_service.dart';

class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  static const _kSessionCount = 'session_count';
  static const _kReviewRequested = 'review_requested';
  static const _kInvoiceCount = 'review_invoice_trigger';

  Future<void> onAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool(_kReviewRequested) ?? false;
    if (alreadyRequested) return;

    final sessions = (prefs.getInt(_kSessionCount) ?? 0) + 1;
    await prefs.setInt(_kSessionCount, sessions);

    final threshold = RemoteConfigService.instance.reviewSessionThreshold;
    if (sessions >= threshold) {
      await _requestReview(prefs);
    }
  }

  Future<void> onInvoiceCreated() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool(_kReviewRequested) ?? false;
    if (alreadyRequested) return;

    final count = (prefs.getInt(_kInvoiceCount) ?? 0) + 1;
    await prefs.setInt(_kInvoiceCount, count);

    final threshold = RemoteConfigService.instance.reviewInvoiceThreshold;
    if (count >= threshold) {
      await _requestReview(prefs);
    }
  }

  Future<void> _requestReview(SharedPreferences prefs) async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
      await prefs.setBool(_kReviewRequested, true);
    }
  }
}
