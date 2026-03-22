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
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  label: Text(_statusLabel(context, invoice.status)),
                  backgroundColor: _statusColor(invoice.status),
                  labelStyle: TextStyle(
                    color: _statusTextColor(invoice.status),
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide.none,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
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
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text(s.cardMarkOverdue),
                onTap: () {
                  Navigator.of(context).pop();
                  onStatusChange(InvoiceStatus.overdue);
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
        return s.statusPending;
      case InvoiceStatus.overdue:
        return s.statusOverdue;
    }
  }

  Color _statusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return kPaidBg;
      case InvoiceStatus.pending:
        return kPendingBg;
      case InvoiceStatus.overdue:
        return kOverdueBg;
    }
  }

  Color _statusTextColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return kPaid;
      case InvoiceStatus.pending:
        return kPending;
      case InvoiceStatus.overdue:
        return kOverdue;
    }
  }
}
