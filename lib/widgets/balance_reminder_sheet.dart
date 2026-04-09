import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/services/payment_link_service.dart';
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
    this.upiId,
    this.businessName,
  });

  final Client client;
  final List<Invoice> unpaidInvoices;
  final double totalOutstanding;
  final String? upiId;
  final String? businessName;

  @override
  State<BalanceReminderSheet> createState() => _BalanceReminderSheetState();
}

class _BalanceReminderSheetState extends State<BalanceReminderSheet> {
  bool _isSendingWhatsApp = false;
  bool _isSendingSms = false;

  /// Pre-computed values populated in initState to avoid lag on tap.
  Future<String?>? _payLinkFuture;
  Future<int>? _shareCountFuture;

  @override
  void initState() {
    super.initState();
    // Pre-fetch network data eagerly so taps are near-instant.
    _payLinkFuture = _buildPayLink();
    _shareCountFuture =
        UsageTrackingService.instance.getWhatsAppShareCount();
  }

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );
  final DateFormat _dateFmt = DateFormat('dd MMM yyyy');

  // ── Message builders ──────────────────────────────────────────────────

  Future<String?> _buildPayLink() async {
    if (widget.upiId == null ||
        widget.upiId!.isEmpty ||
        widget.totalOutstanding <= 0) {
      return null;
    }

    return PaymentLinkService.instance.createUpiWebPaymentLink(
      upiId: widget.upiId!,
      businessName: widget.businessName ?? '',
      amount: widget.totalOutstanding,
      invoiceNumber: 'Balance',
    );
  }

  String _whatsAppMessage({String? payLink}) {
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
      ..writeln('*Total Outstanding: $total*');

    // Add UPI payment link if merchant has UPI configured
    if (payLink != null && payLink.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Pay now: $payLink');
    }

    buf
      ..writeln()
      ..writeln(
        'Please arrange payment at your earliest convenience. '
        'Thank you! 🙏',
      );

    return buf.toString();
  }

  String _smsMessage({String? payLink}) {
    final name = widget.client.name.trim().isNotEmpty
        ? widget.client.name.trim()
        : 'Customer';
    final total = _currency.format(widget.totalOutstanding);
    final count = widget.unpaidInvoices.length;

    String payPart = '';
    if (payLink != null && payLink.isNotEmpty) {
      payPart = ' Pay: $payLink';
    }
    return 'Hi $name, this is a reminder that you have $count unpaid '
        'invoice${count > 1 ? 's' : ''} totalling $total. '
        'Please arrange payment at your earliest convenience.$payPart';
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
              'Send Balance Reminder',
              style: TextStyle(
                color: context.cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count unpaid invoice${count > 1 ? 's' : ''}  •  $total outstanding',
              style: TextStyle(
                color: context.cs.onSurfaceVariant,
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
                itemCount: widget.unpaidInvoices.length > 6
                    ? 6
                    : widget.unpaidInvoices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  if (i == 5 && widget.unpaidInvoices.length > 6) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '+${widget.unpaidInvoices.length - 5} more invoices',
                        style: TextStyle(
                          color: context.cs.onSurfaceVariant.withAlpha(153),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? kOverdueBg
                          : context.cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            inv.invoiceNumber,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.cs.onSurface,
                            ),
                          ),
                        ),
                        if (inv.dueDate != null)
                          Text(
                            'Due ${_dateFmt.format(inv.dueDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isOverdue
                                  ? kOverdue
                                  : context.cs.onSurfaceVariant.withAlpha(153),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Text(
                          _currency.format(inv.grandTotal),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurface,
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
            Divider(height: 1, color: context.cs.surfaceContainerLow),
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
    setState(() => _isSendingWhatsApp = true);

    // Use pre-fetched share count (already started in initState).
    final shareCount = await _shareCountFuture!;
    if (!PlanService.instance.canShareWhatsApp(shareCount)) {
      if (!mounted) return;
      setState(() => _isSendingWhatsApp = false);
      final max = PlanService.instance.currentLimits.maxWhatsAppSharesPerMonth;
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
      setState(() => _isSendingWhatsApp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number for this customer')),
      );
      return;
    }

    // Use pre-fetched UPI link (already started in initState).
    final payLink = await _payLinkFuture;
    final message = Uri.encodeComponent(_whatsAppMessage(payLink: payLink));
    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Fire-and-forget — don't block UI for analytics write.
      UsageTrackingService.instance.incrementWhatsAppShareCount();
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

    // Use pre-fetched UPI link (already started in initState).
    final payLink = await _payLinkFuture;
    final body = Uri.encodeComponent(_smsMessage(payLink: payLink));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
