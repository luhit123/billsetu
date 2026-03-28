import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvoiceCard extends StatelessWidget {
  InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
  });

  final Invoice invoice;
  final VoidCallback onTap;
  final void Function(InvoiceStatus) onStatusChange;
  final VoidCallback onDelete;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [kSubtleShadow],
        border: Border(
          left: BorderSide(color: _statusColor(invoice.effectiveStatus), width: 3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showActions(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: kPrimaryContainer,
                  foregroundColor: kPrimary,
                  child: Text(
                    _clientInitial(invoice.clientName, invoice.clientId),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kOnSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        invoice.clientName,
                        style: const TextStyle(
                          color: kOnSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_dateFormat.format(invoice.createdAt)} \u2022 ${_currencyFormat.format(invoice.grandTotal)}',
                        style: const TextStyle(
                          color: kOnSurfaceVariant,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (invoice.isPartiallyPaid) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Bal: ${_currencyFormat.format(invoice.balanceDue)}  |  Rcvd: ${_currencyFormat.format(invoice.amountReceived)}',
                          style: const TextStyle(color: Color(0xFFE65100), fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(
                      label: Text(_statusLabel(context, invoice.effectiveStatus)),
                      backgroundColor: _statusColor(invoice.effectiveStatus),
                      labelStyle: TextStyle(
                        color: _statusTextColor(invoice.effectiveStatus),
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide.none,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 32,
                      width: 32,
                      child: IconButton(
                        onPressed: () => _showActions(context),
                        icon: const Icon(Icons.more_horiz_rounded, size: 22),
                        color: kOnSurfaceVariant,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: kSurfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final s = AppStrings.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(s.cardMarkPaid),
                onTap: () {
                  Navigator.of(context).pop();
                  onStatusChange(InvoiceStatus.paid);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  s.cardDelete,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _clientInitial(String clientName, String clientId) {
    final value = clientName.isNotEmpty ? clientName : clientId;

    if (value.isEmpty) {
      return '?';
    }

    return value[0].toUpperCase();
  }

  String _statusLabel(BuildContext context, InvoiceStatus status) {
    final s = AppStrings.of(context);
    switch (status) {
      case InvoiceStatus.paid:
        return s.statusPaid;
      case InvoiceStatus.pending:
        return 'Unpaid';
      case InvoiceStatus.overdue:
        return s.statusOverdue;
      case InvoiceStatus.partiallyPaid:
        return 'Partial';
    }
  }

  Color _statusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return kPaidBg;
      case InvoiceStatus.pending:
        return const Color(0xFFFEE2E2);
      case InvoiceStatus.overdue:
        return kOverdueBg;
      case InvoiceStatus.partiallyPaid:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _statusTextColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return kPaid;
      case InvoiceStatus.pending:
        return const Color(0xFFEF4444);
      case InvoiceStatus.overdue:
        return kOverdue;
      case InvoiceStatus.partiallyPaid:
        return const Color(0xFFEAB308);
    }
  }
}
