import 'dart:io';

import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/services/invoice_link_service.dart';
import 'package:billeasy/services/payment_link_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/remote_config_service.dart';
import 'package:billeasy/services/usage_tracking_service.dart';
import 'package:billeasy/widgets/limit_reached_dialog.dart';

/// Bottom sheet for sharing an invoice via WhatsApp or SMS.
///
/// WhatsApp: shares the PDF file directly with a message that includes a
/// persistent download link so the customer can re-download anytime.
class WhatsAppShareSheet extends StatefulWidget {
  const WhatsAppShareSheet({
    super.key,
    required this.invoice,
    this.pdfFile,
    this.pdfBytes,
    required this.currencyFormat,
    this.clientPhone,
    this.upiId,
    this.businessName,
  });

  final Invoice invoice;
  final File? pdfFile;
  final Uint8List? pdfBytes;
  final NumberFormat currencyFormat;
  final String? clientPhone;
  final String? upiId;
  final String? businessName;

  @override
  State<WhatsAppShareSheet> createState() => _WhatsAppShareSheetState();
}

class _WhatsAppShareSheetState extends State<WhatsAppShareSheet> {
  bool _isLoadingSms = false;

  String get _formattedAmount =>
      widget.currencyFormat.format(widget.invoice.grandTotal);

  Future<String?> _buildUpiWebLink() async {
    if (widget.upiId == null || widget.upiId!.isEmpty) return null;
    // The "received" amount is what the customer is paying right now.
    // If received > 0, use that as the UPI link amount.
    // If nothing received yet, use grand total (collect full amount).
    final payAmount = widget.invoice.amountReceived > 0
        ? widget.invoice.amountReceived
        : widget.invoice.grandTotal;
    if (payAmount <= 0) return null;
    return PaymentLinkService.instance.createUpiWebPaymentLink(
      upiId: widget.upiId!,
      businessName: widget.businessName ?? '',
      amount: payAmount,
      invoiceNumber: widget.invoice.invoiceNumber,
    );
  }

  String _shareMessage({String? payLink}) {
    final name = widget.invoice.clientName.trim().isNotEmpty
        ? widget.invoice.clientName.trim()
        : 'Customer';
    final base =
        'Hi $name, your invoice *#${widget.invoice.invoiceNumber}* '
        'of *$_formattedAmount* is attached.';
    if (payLink != null) {
      return '$base\n\nPay now: $payLink';
    }
    return base;
  }

  String _smsMessage(String downloadUrl, {String? payLink}) {
    final name = widget.invoice.clientName.trim().isNotEmpty
        ? widget.invoice.clientName.trim()
        : 'Customer';
    final webLink = payLink;
    final payPart = webLink != null ? '\nPay: $webLink' : '';
    return 'Hi $name, invoice #${widget.invoice.invoiceNumber} '
        'of $_formattedAmount.\nDownload: $downloadUrl$payPart';
  }

  String? _normalizedPhone() {
    final raw = widget.clientPhone?.trim() ?? '';
    if (raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.length == 12 && digits.startsWith('91')) return digits;
    return '91$digits';
  }

  Future<String?> _uploadAndGetLink() async {
    try {
      return await InvoiceLinkService.shareLink(invoice: widget.invoice);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Share Invoice',
              style: TextStyle(
                color: context.cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.invoice.invoiceNumber}  •  $_formattedAmount',
              style: TextStyle(
                color: context.cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            // WhatsApp
            _OptionTile(
              iconWidget: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366),
                size: 22,
              ),
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'WhatsApp',
              subtitle: 'Send invoice as PDF',
              onTap: () => _shareWhatsApp(context),
            ),
            Divider(height: 1, color: context.cs.surfaceContainerLow),
            // SMS
            _OptionTile(
              icon: Icons.sms_rounded,
              iconColor: const Color(0xFFF97316),
              title: 'SMS',
              subtitle: _isLoadingSms
                  ? 'Preparing link…'
                  : 'Send invoice link via text message',
              isLoading: _isLoadingSms,
              onTap: _isLoadingSms ? null : () => _shareSms(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _shareWhatsApp(BuildContext context) async {
    // Plan gate
    final shareCount = await UsageTrackingService.instance
        .getWhatsAppShareCount();
    if (!PlanService.instance.canShareWhatsApp(shareCount)) {
      if (!context.mounted) return;
      final killSwitchOff = !RemoteConfigService.instance.featureWhatsAppShare;
      final max = PlanService.instance.currentLimits.maxWhatsAppSharesPerMonth;
      String msg;
      if (killSwitchOff) {
        msg =
            'WhatsApp sharing is temporarily unavailable. Please restart the app.';
      } else if (max == 0) {
        msg = 'WhatsApp sharing is available on Pro plan.';
      } else {
        msg = 'You\'ve used $shareCount/$max WhatsApp shares this month.';
      }
      await LimitReachedDialog.show(
        context,
        title: 'WhatsApp Share Limit',
        message: msg,
        featureName: 'WhatsApp sharing',
      );
      return;
    }

    if (kIsWeb) {
      // On web, generate download link and open wa.me with text
      final phone = _normalizedPhone() ?? '';
      final payLink = await _buildUpiWebLink();
      String? downloadLink;
      try {
        downloadLink = await InvoiceLinkService.shareLink(
          invoice: widget.invoice,
        );
      } catch (e) {
        debugPrint('[WhatsAppShare] Share link generation failed: $e');
      }

      final baseMsg = _shareMessage(payLink: payLink);
      final fullMsg = downloadLink != null
          ? '$baseMsg\n\nDownload: $downloadLink'
          : baseMsg;
      final waUri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(fullMsg)}',
      );
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
      await UsageTrackingService.instance.incrementWhatsAppShareCount();
      if (context.mounted) Navigator.pop(context);
      return;
    }

    if (widget.pdfFile == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF not available')));
      return;
    }

    final payLink = await _buildUpiWebLink();

    // Share the PDF file directly via the system share sheet (targets WhatsApp).
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.pdfFile!.path)],
        text: _shareMessage(payLink: payLink),
      ),
    );

    await UsageTrackingService.instance.incrementWhatsAppShareCount();
  }

  Future<void> _shareSms(BuildContext context) async {
    final phone = _normalizedPhone();
    if (phone == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number for this customer')),
      );
      return;
    }

    setState(() => _isLoadingSms = true);
    final url = await _uploadAndGetLink();
    if (!mounted) return;
    setState(() => _isLoadingSms = false);

    if (url == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not generate download link. Check your internet connection.',
          ),
        ),
      );
      return;
    }

    final payLink = await _buildUpiWebLink();
    final body = Uri.encodeComponent(_smsMessage(url, payLink: payLink));
    final uri = Uri.parse('sms:$phone?body=$body');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open SMS app')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// ── Reusable tile ──────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLoading = false,
    this.iconWidget,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLoading;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (iconWidget ?? Icon(icon, color: iconColor, size: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.cs.onSurfaceVariant.withAlpha(153),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
