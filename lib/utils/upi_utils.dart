import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:qr_flutter/qr_flutter.dart';

/// Builds a UPI deep link URI from invoice and merchant data.
/// Returns a fully encoded UPI intent string following NPCI specification.
///
/// Example output:
/// `upi://pay?pa=luhit@okicici&pn=Luhit%20Clinic&am=1500.00&tn=BR-2026-00042&cu=INR`
String buildUpiPaymentLink({
  required String upiId,
  required String businessName,
  required double amount,
  required String invoiceNumber,
}) {
  assert(upiId.contains('@'), 'Invalid UPI ID format');
  assert(amount > 0, 'Amount must be positive');

  // Truncate business name to 50 chars to avoid URI length issues
  final name = businessName.length > 50
      ? businessName.substring(0, 50)
      : businessName;

  return 'upi://pay?'
      'pa=$upiId&'
      'pn=${Uri.encodeComponent(name)}&'
      'am=${amount.toStringAsFixed(2)}&'
      'tn=$invoiceNumber&'
      'cu=INR';
}

/// Validates UPI ID format.
/// Returns `null` if valid, error message string if invalid.
///
/// Valid formats: `name@bankhandle`, `9876543210@ybl`, `dr.luhit@okicici`
String? validateUpiId(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'UPI ID is required';
  }
  final trimmed = value.trim();
  final regex = RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$');
  if (!regex.hasMatch(trimmed)) {
    return 'Invalid format (e.g., name@bankhandle)';
  }
  return null;
}

/// Builds a clickable HTTPS payment link that redirects to UPI app.
/// This URL is clickable in WhatsApp (unlike upi:// deep links).
///
/// The link points to the `pay` Cloud Function which serves a
/// mobile-friendly "Pay Now" page that auto-opens the UPI app.
String buildUpiWebPaymentLink({
  required String upiId,
  required String businessName,
  required double amount,
  required String invoiceNumber,
}) {
  return 'https://invoice.billraja.online/p'
      '?pa=${Uri.encodeComponent(upiId)}'
      '&pn=${Uri.encodeComponent(businessName)}'
      '&am=${amount.toStringAsFixed(2)}'
      '&tn=${Uri.encodeComponent(invoiceNumber)}';
}

/// Generates QR code image bytes (PNG) on-device for PDF embedding.
/// Works offline — pure computation, no network required.
Future<Uint8List> generateQrImageBytes(String data, {double size = 200}) async {
  final qrPainter = QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: true,
    color: const ui.Color(0xFF000000),
    emptyColor: const ui.Color(0xFFFFFFFF),
  );

  final image = await qrPainter.toImage(size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
