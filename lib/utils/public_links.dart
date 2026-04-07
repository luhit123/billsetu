import 'package:url_launcher/url_launcher.dart';

class PublicLinks {
  const PublicLinks._();

  static const String _baseUrl = 'https://billraja.com';

  static const String pricing = '$_baseUrl/pricing.html';
  static const String security = '$_baseUrl/security.html';
  static const String support = '$_baseUrl/support.html';

  static Future<void> open(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened) {
      throw StateError('Could not open $url');
    }
  }
}
