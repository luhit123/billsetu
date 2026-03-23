import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/usage_tracking_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/limit_reached_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bottom sheet that composes and sends a balance reminder to a customer
/// summarising all their unpaid invoices and total outstanding amount.
class BalanceReminderSheet extends StatefulWidget {
  const BalanceReminderSheet({
    super.key,
    required this.client,
    required this.unpaidInvoices,
    required this.totalOutstanding,
  });

  final Client client;
  final List<Invoice> unpaidInvoices;
  final double totalOutstanding;

  @override
  State<BalanceReminderSheet> createState() => _BalanceReminderSheetState();
}

class _BalanceReminderSheetState extends State<BalanceReminderSheet> {
  bool _isSendingWhatsApp = false;
  bool _isSendingSms = false;

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );
  final DateFormat _dateFmt = DateFormat('dd MMM yyyy');

  // ── Message builders ──────────────────────────────────────────────────

  String _whatsAppMessage() {
    final name = widget.client.name.trim().isNotEmpty
        ? widget.client.name.trim()
        : 'Customer';
    final total = _currency.format(widget.totalOutstanding);
    final count = widget.unpaidInvoices.length;

    final buf = StringBuffer()
      ..writeln('Hi $name,')
      ..writeln()
      ..writeln(
        'This is a friendly reminder that you have '
        '*$count unpaid invoice${count > 1 ? 's' : ''}* '
        'totalling *$total*.',
      )
      ..writeln();

    // List each unpaid invoice (cap at 10 to keep message manageable)
    final invoicesToShow = widget.unpaidInvoices.take(10).toList();
    for (final inv in invoicesToShow) {
      final status = inv.status == InvoiceStatus.overdue ? ' (OVERDUE)' : '';
      buf.writeln(
        '• #${inv.invoiceNumber} — ${_currency.format(inv.grandTotal)}'
        '${inv.dueDate != null ? ', due ${_dateFmt.format(inv.dueDate!)}' : ''}'
        '$status',
      );
    }
    if (widget.unpaidInvoices.length > 10) {
      buf.writeln('• ...and ${widget.unpaidInvoices.length - 10} more');
    }

    buf
      ..writeln()
      ..writeln('*Total Outstanding: $total*')
      ..writeln()
      ..writeln('Please arrange payment at your earliest convenience. '
          'Thank you! 🙏');

    return buf.toString();
  }

  String _smsMessage() {
    final name = widget.client.name.trim().isNotEmpty
        ? widget.client.name.trim()
        : 'Customer';
    final total = _currency.format(widget.totalOutstanding);
    final count = widget.unpaidInvoices.length;

    return 'Hi $name, this is a reminder that you have $count unpaid '
        'invoice${count > 1 ? 's' : ''} totalling $total. '
        'Please arrange payment at your earliest convenience. Thank you!';
  }

  String? _normalizedPhone() {
    final raw = widget.client.phone.trim();
    if (raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.length == 12 && digits.startsWith('91')) return digits;
    return '91$digits';
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final count = widget.unpaidInvoices.length;
    final total = _currency.format(widget.totalOutstanding);

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
              'Send Balance Reminder',
              style: TextStyle(
                color: kOnSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count unpaid invoice${count > 1 ? 's' : ''}  •  $total outstanding',
              style: const TextStyle(
                color: kOnSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),

            // Invoice summary list (scrollable if many)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount:
                    widget.unpaidInvoices.length > 6 ? 6 : widget.unpaidInvoices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  if (i == 5 && widget.unpaidInvoices.length > 6) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '+${widget.unpaidInvoices.length - 5} more invoices',
                        style: const TextStyle(
                          color: kTextTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final inv = widget.unpaidInvoices[i];
                  final isOverdue = inv.status == InvoiceStatus.overdue;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? kOverdueBg
                          : kSurfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            inv.invoiceNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kOnSurface,
                            ),
                          ),
                        ),
                        if (inv.dueDate != null)
                          Text(
                            'Due ${_dateFmt.format(inv.dueDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isOverdue ? kOverdue : kTextTertiary,
                            ),
                          ),
                        const SizedBox(width: 10),
                        Text(
                          _currency.format(inv.grandTotal),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kOnSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // WhatsApp option
            _OptionTile(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'WhatsApp',
              subtitle: _isSendingWhatsApp
                  ? 'Opening WhatsApp…'
                  : 'Send reminder with invoice list',
              isLoading: _isSendingWhatsApp,
              onTap: _isSendingWhatsApp ? null : _sendWhatsApp,
            ),
            const Divider(height: 1, color: kSurfaceContainerLow),
            // SMS option
            _OptionTile(
              icon: Icons.sms_rounded,
              iconColor: const Color(0xFFF97316),
              title: 'SMS',
              subtitle: _isSendingSms
                  ? 'Opening SMS…'
                  : 'Send short reminder via text',
              isLoading: _isSendingSms,
              onTap: _isSendingSms ? null : _sendSms,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> _sendWhatsApp() async {
    // Plan gate — reuse existing WhatsApp share limits
    final shareCount =
        await UsageTrackingService.instance.getWhatsAppShareCount();
    if (!PlanService.instance.canShareWhatsApp(shareCount)) {
      if (!mounted) return;
      final max =
          PlanService.instance.currentLimits.maxWhatsAppSharesPerMonth;
      await LimitReachedDialog.show(
        context,
        title: 'WhatsApp Share Limit',
        message: max == 0
            ? 'WhatsApp sharing is available on Pro plan.'
            : 'You\'ve used $shareCount/$max WhatsApp shares this month.',
        featureName: 'WhatsApp sharing',
      );
      return;
    }

    final phone = _normalizedPhone();
    if (phone == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number for this customer')),
      );
      return;
    }

    setState(() => _isSendingWhatsApp = true);

    final message = Uri.encodeComponent(_whatsAppMessage());
    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await UsageTrackingService.instance.incrementWhatsAppShareCount();
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }

    if (mounted) setState(() => _isSendingWhatsApp = false);
  }

  Future<void> _sendSms() async {
    final phone = _normalizedPhone();
    if (phone == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number for this customer')),
      );
      return;
    }

    setState(() => _isSendingSms = true);

    final body = Uri.encodeComponent(_smsMessage());
    final uri = Uri.parse('sms:$phone?body=$body');

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open SMS app')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) setState(() => _isSendingSms = false);
  }
}

// ── Reusable tile (matches existing WhatsAppShareSheet style) ────────────

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
                color: iconColor.withAlpha(30),
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
