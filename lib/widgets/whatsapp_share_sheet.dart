import 'dart:io';

import 'package:billeasy/modals/invoice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/usage_tracking_service.dart';
import 'package:billeasy/widgets/limit_reached_dialog.dart';

/// Bottom sheet for sharing an invoice via WhatsApp, SMS, or plain sharing.
///
/// [clientPhone] must be provided separately (fetched from the Client model)
/// because [Invoice] does not store a phone number directly.
class WhatsAppShareSheet extends StatelessWidget {
  const WhatsAppShareSheet({
    super.key,
    required this.invoice,
    this.pdfFile,
    required this.currencyFormat,
    this.clientPhone,
  });

  final Invoice invoice;
  final File? pdfFile;
  final NumberFormat currencyFormat;

  /// Phone number of the client (digits only, without country code prefix).
  /// Sourced from [Client.phone] before opening this sheet.
  final String? clientPhone;

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _formattedAmount => currencyFormat.format(invoice.grandTotal);

  String _shareMessage() {
    final name = invoice.clientName.trim().isNotEmpty
        ? invoice.clientName.trim()
        : 'Customer';
    return 'Hi $name, please find your invoice #${invoice.invoiceNumber} '
        'for $_formattedAmount. Thank you!';
  }

  String _textSummary() {
    return 'Invoice: ${invoice.invoiceNumber}\n'
        'Customer: ${invoice.clientName}\n'
        'Amount: $_formattedAmount\n'
        'Status: ${invoice.status.name}';
  }

  String? _normalizedPhone() {
    final raw = clientPhone?.trim() ?? '';
    if (raw.isEmpty) return null;
    // Strip non-digit characters
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    // Remove leading country code if already present (91xxxxxxxxxx)
    if (digits.length == 12 && digits.startsWith('91')) return digits;
    return '91$digits';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
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
                  color: const Color(0xFFBDD5F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Share Invoice',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              invoice.invoiceNumber,
              style: const TextStyle(
                color: Color(0xFF5B7A9A),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            // Option tiles
            _OptionTile(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'WhatsApp',
              subtitle: 'Send invoice message directly',
              onTap: () => _shareWhatsApp(context),
            ),
            if (pdfFile != null) ...[
              const Divider(height: 1, color: Color(0xFFEFF6FF)),
              _OptionTile(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: const Color(0xFF1A73E8),
                title: 'Share PDF',
                subtitle: 'Share invoice PDF via any app',
                onTap: () => _sharePdf(context),
              ),
            ],
            const Divider(height: 1, color: Color(0xFFEFF6FF)),
            _OptionTile(
              icon: Icons.sms_rounded,
              iconColor: const Color(0xFFF97316),
              title: 'SMS',
              subtitle: 'Send invoice details via text message',
              onTap: () => _shareSms(context),
            ),
            const Divider(height: 1, color: Color(0xFFEFF6FF)),
            _OptionTile(
              icon: Icons.copy_rounded,
              iconColor: const Color(0xFF7C3AED),
              title: 'Copy Invoice Link',
              subtitle: 'Copy a text summary to clipboard',
              onTap: () => _copyToClipboard(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _shareWhatsApp(BuildContext context) async {
    // ── Plan gate: check WhatsApp share limit ──
    final shareCount = await UsageTrackingService.instance.getWhatsAppShareCount();
    if (!PlanService.instance.canShareWhatsApp(shareCount)) {
      if (!context.mounted) return;
      final max = PlanService.instance.currentLimits.maxWhatsAppSharesPerMonth;
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

    final phone = _normalizedPhone();
    if (phone == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number for this customer')),
      );
      return;
    }
    final message = Uri.encodeComponent(_shareMessage());
    final uri = Uri.parse('https://wa.me/$phone?text=$message');
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await UsageTrackingService.instance.incrementWhatsAppShareCount();
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.scheme}')),
      );
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    if (pdfFile == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(pdfFile!.path)],
        subject: 'Invoice ${invoice.invoiceNumber}',
      ),
    );
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
    final body = Uri.encodeComponent(_shareMessage());
    final uri = Uri.parse('sms:$phone?body=$body');
    await _openUri(context, uri);
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _textSummary()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied!')),
    );
  }

  Future<void> _openUri(BuildContext context, Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${uri.scheme}')),
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
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF5B7A9A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFBDD5F0), size: 20),
          ],
        ),
      ),
    );
  }
}
