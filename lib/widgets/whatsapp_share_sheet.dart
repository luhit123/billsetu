import 'dart:io';

import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/services/invoice_link_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:billeasy/services/plan_service.dart';
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
  });

  final Invoice invoice;
  final File? pdfFile;
  final Uint8List? pdfBytes;
  final NumberFormat currencyFormat;
  final String? clientPhone;

  @override
  State<WhatsAppShareSheet> createState() => _WhatsAppShareSheetState();
}

class _WhatsAppShareSheetState extends State<WhatsAppShareSheet> {
  bool _isLoadingWhatsApp = false;
  bool _isLoadingSms = false;

  String get _formattedAmount =>
      widget.currencyFormat.format(widget.invoice.grandTotal);

  String _shareMessageWithLink(String downloadUrl) {
    final name = widget.invoice.clientName.trim().isNotEmpty
        ? widget.invoice.clientName.trim()
        : 'Customer';
    return 'Hi $name!\n\n'
        'Your invoice *#${widget.invoice.invoiceNumber}* for '
        '*$_formattedAmount* is attached.\n\n'
        'You can also download it anytime here:\n$downloadUrl\n\n'
        'Thank you for your business!';
  }

  String _shareMessageWithoutLink() {
    final name = widget.invoice.clientName.trim().isNotEmpty
        ? widget.invoice.clientName.trim()
        : 'Customer';
    return 'Hi $name!\n\n'
        'Your invoice *#${widget.invoice.invoiceNumber}* for '
        '*$_formattedAmount* is attached.\n\n'
        'Thank you for your business!';
  }

  String _smsMessage(String downloadUrl) {
    final name = widget.invoice.clientName.trim().isNotEmpty
        ? widget.invoice.clientName.trim()
        : 'Customer';
    return 'Hi $name, your invoice #${widget.invoice.invoiceNumber} '
        'for $_formattedAmount is ready.\n'
        'Download: $downloadUrl';
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
    final bytes = widget.pdfBytes;
    if (bytes == null) return null;
    try {
      return await InvoiceLinkService.uploadAndGetLink(
        invoice: widget.invoice,
        pdfBytes: bytes,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kSurfaceLowest,
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
                  color: kSurfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Share Invoice',
              style: TextStyle(
                color: kOnSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.invoice.invoiceNumber}  •  $_formattedAmount',
              style: const TextStyle(
                color: kOnSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            // WhatsApp
            _OptionTile(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'WhatsApp',
              subtitle: _isLoadingWhatsApp
                  ? 'Preparing PDF…'
                  : 'Send PDF with download link',
              isLoading: _isLoadingWhatsApp,
              onTap: _isLoadingWhatsApp ? null : () => _shareWhatsApp(context),
            ),
            const Divider(height: 1, color: kSurfaceContainerLow),
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
    final shareCount =
        await UsageTrackingService.instance.getWhatsAppShareCount();
    if (!PlanService.instance.canShareWhatsApp(shareCount)) {
      if (!context.mounted) return;
      final max =
          PlanService.instance.currentLimits.maxWhatsAppSharesPerMonth;
      await LimitReachedDialog.show(
        context,
        title: 'WhatsApp Share Limit',
        message: max == 0
            ? 'WhatsApp sharing is available on Raja plan and above.'
            : 'You\'ve used $shareCount/$max WhatsApp shares this month.',
        featureName: 'WhatsApp sharing',
      );
      return;
    }

    if (widget.pdfFile == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF not available')),
      );
      return;
    }

    setState(() => _isLoadingWhatsApp = true);

    // Upload for a download link in the background — don't block if it fails.
    final downloadUrl = await _uploadAndGetLink();

    if (!mounted) return;
    setState(() => _isLoadingWhatsApp = false);

    final message = downloadUrl != null
        ? _shareMessageWithLink(downloadUrl)
        : _shareMessageWithoutLink();

    // Share the PDF file directly via the system share sheet (targets WhatsApp).
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.pdfFile!.path)],
        text: message,
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
        const SnackBar(content: Text('Could not generate download link. Check your internet connection.')),
      );
      return;
    }

    final body = Uri.encodeComponent(_smsMessage(url));
    final uri = Uri.parse('sms:$phone?body=$body');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open SMS app')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

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
                  : Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: kOnSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: kTextTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
