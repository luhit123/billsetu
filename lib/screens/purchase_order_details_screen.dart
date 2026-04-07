import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/purchase_order.dart';
import 'package:billeasy/services/po_pdf_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/services/purchase_order_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:url_launcher/url_launcher.dart';

// Status colours (kept as semantic)
const _kDraft = Color(0xFF6B7280);
const _kDraftBg = Color(0xFFF3F4F6);
const _kConfirmed = Color(0xFFF59E0B);
const _kConfirmedBg = Color(0xFFFEF3C7);
const _kReceived = Color(0xFF22C55E);
const _kReceivedBg = Color(0xFFDCFCE7);
const _kCancelled = Color(0xFFEF4444);
const _kCancelledBg = Color(0xFFFEE2E2);

BoxDecoration _cardDeco(BuildContext context) => BoxDecoration(
      color: context.cs.surfaceContainerLowest,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      boxShadow: const [kSubtleShadow],
    );

// ────────────────────────────────────────────────────────────────────────────

class PurchaseOrderDetailsScreen extends StatefulWidget {
  const PurchaseOrderDetailsScreen({super.key, required this.order});

  final PurchaseOrder order;

  @override
  State<PurchaseOrderDetailsScreen> createState() =>
      _PurchaseOrderDetailsScreenState();
}

class _PurchaseOrderDetailsScreenState
    extends State<PurchaseOrderDetailsScreen> {
  late PurchaseOrder _order;
  bool _isUpdating = false;

  final _svc = PurchaseOrderService();
  final _profileSvc = ProfileService();

  final _dateFormat = DateFormat('dd MMM yyyy');
  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _markAsSent() async {
    final confirm = await _showConfirmDialog(
      title: 'Mark as Sent?',
      message: 'This will update the status to Confirmed (Sent).',
      confirmLabel: 'Mark Sent',
      confirmColor: _kConfirmed,
    );
    if (!confirm || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      final updated = _order.copyWith(status: PurchaseOrderStatus.confirmed);
      await _svc.savePurchaseOrder(updated);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _isUpdating = false;
      });
      _showSnackBar('Marked as Sent / Confirmed.', _kConfirmed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      _showSnackBar(userFriendlyError(e, fallback: 'Failed to mark as sent. Please try again.'), _kCancelled);
    }
  }

  Future<void> _markAsReceived() async {
    final confirm = await _showConfirmDialog(
      title: 'Mark as Received?',
      message:
          'This will update the status to Received and adjust stock for linked products.',
      confirmLabel: 'Mark Received',
      confirmColor: _kReceived,
    );
    if (!confirm || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      await _svc.markAsReceived(_order);
      if (!mounted) return;
      setState(() {
        _order = _order.copyWith(
          status: PurchaseOrderStatus.received,
          receivedAt: DateTime.now(),
        );
        _isUpdating = false;
      });
      _showSnackBar('Marked as Received. Stock updated.', _kReceived);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      _showSnackBar(userFriendlyError(e, fallback: 'Failed to mark as received. Please try again.'), _kCancelled);
    }
  }

  Future<void> _sendToSupplier() async {
    final phone = _order.supplierPhone.trim().replaceAll(RegExp(r'\D'), '');
    final amount = _currencyFormat.format(_order.grandTotal);
    final message =
        'Dear ${_order.supplierName}, here is our Purchase Order #${_order.orderNumber}. '
        'Total: $amount. Please confirm receipt.';

    final encoded = Uri.encodeComponent(message);

    Uri uri;
    if (phone.isNotEmpty) {
      final fullPhone = phone.length == 10 ? '91$phone' : phone;
      uri = Uri.parse('https://wa.me/$fullPhone?text=$encoded');
    } else {
      uri = Uri.parse('https://wa.me/?text=$encoded');
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showSnackBar('Could not open WhatsApp.', _kCancelled);
    }
  }

  Future<void> _downloadPdf(BusinessProfile? profile) async {
    setState(() => _isUpdating = true);
    try {
      await PoPdfService.instance.generateAndShare(_order, profile);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(userFriendlyError(e, fallback: 'Failed to generate PDF. Please try again.'), _kCancelled);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: context.cs.onSurface,
          ),
        ),
        content: Text(message, style: TextStyle(color: context.cs.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BusinessProfile?>(
      stream: _profileSvc.watchCurrentProfile(),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        return Scaffold(
          backgroundColor: context.cs.surface,
          appBar: _buildAppBar(profile),
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 12),
                      _buildSupplierCard(),
                      const SizedBox(height: 12),
                      _buildItemsCard(),
                      const SizedBox(height: 12),
                      _buildTotalsCard(),
                      if (_order.notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildNotesCard(),
                      ],
                      const SizedBox(height: 12),
                      _buildActionsCard(profile),
                    ],
                  ),
                ),
                if (_isUpdating)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55FFFFFF),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BusinessProfile? profile) {
    return AppBar(
      backgroundColor: context.cs.surface,
      foregroundColor: context.cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _order.orderNumber,
            style: TextStyle(
              color: context.cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          Text(
            _order.supplierName,
            style: TextStyle(
              color: context.cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _downloadPdf(profile),
          icon: Icon(Icons.picture_as_pdf_outlined, color: context.cs.onSurface),
          tooltip: 'Download / Share PDF',
        ),
      ],
    );
  }

  // ── Section cards ─────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    final (badgeColor, badgeBg, statusLabel) = switch (_order.status) {
      PurchaseOrderStatus.draft => (_kDraft, _kDraftBg, 'DRAFT'),
      PurchaseOrderStatus.confirmed => (_kConfirmed, _kConfirmedBg, 'CONFIRMED'),
      PurchaseOrderStatus.received => (_kReceived, _kReceivedBg, 'RECEIVED'),
      PurchaseOrderStatus.cancelled => (_kCancelled, _kCancelledBg, 'CANCELLED'),
    };

    return Container(
      decoration: _cardDeco(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  color: kPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _order.orderNumber,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Created ${_dateFormat.format(_order.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (_order.expectedDate != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: context.cs.surfaceContainerHighest),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: context.cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Expected delivery: ${_dateFormat.format(_order.expectedDate!)}',
                    style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (_order.receivedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: _kReceived,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Received on ${_dateFormat.format(_order.receivedAt!)}',
                    style: const TextStyle(fontSize: 13, color: _kReceived),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupplierCard() {
    return Container(
      decoration: _cardDeco(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Supplier Details', Icons.store_outlined),
          const SizedBox(height: 12),
          _infoRow(label: 'Name', value: _order.supplierName),
          if (_order.supplierPhone.isNotEmpty)
            _infoRow(label: 'Phone', value: _order.supplierPhone),
          if (_order.supplierAddress.isNotEmpty)
            _infoRow(label: 'Address', value: _order.supplierAddress),
          if (_order.supplierGstin.isNotEmpty)
            _infoRow(label: 'GSTIN', value: _order.supplierGstin),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return Container(
      decoration: _cardDeco(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Items (${_order.items.length})',
            Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 12),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Item',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    'Qty',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    'Rate',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Table rows
          ..._order.items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isEven = i.isEven;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isEven ? context.cs.surfaceContainerLowest : context.cs.surfaceContainerLow,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.cs.onSurface,
                          ),
                        ),
                        if (item.hsnCode.isNotEmpty)
                          Text(
                            'HSN: ${item.hsnCode}',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                      if (_order.gstEnabled && item.gstRate > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.cs.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'GST: ${item.gstRate.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: kPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      item.quantityLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: context.cs.onSurface),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '₹${item.unitPrice.toStringAsFixed(2)}',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      '₹${item.total.toStringAsFixed(2)}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    return Container(
      decoration: _cardDeco(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _totalsRow('Subtotal', _currencyFormat.format(_order.subtotal)),
          if (_order.hasDiscount) ...[
            const SizedBox(height: 6),
            _totalsRow(
                'Discount${_order.discountType == 'percentage' ? ' (${_order.discountValue.toStringAsFixed(0)}%)' : ''}',
                '- ${_currencyFormat.format(_order.discountAmount)}',
                color: Colors.red.shade600),
          ],
          if (_order.hasGst) ...[
            const SizedBox(height: 6),
            if (_order.gstType == 'cgst_sgst') ...[
              _totalsRow(
                  'CGST',
                  _currencyFormat.format(_order.cgstAmount),
                  color: kPrimary),
              const SizedBox(height: 4),
              _totalsRow(
                  'SGST',
                  _currencyFormat.format(_order.sgstAmount),
                  color: kPrimary),
            ] else
              _totalsRow(
                  'IGST',
                  _currencyFormat.format(_order.igstAmount),
                  color: kPrimary),
            const SizedBox(height: 4),
            _totalsRow('Total Tax', _currencyFormat.format(_order.totalTax)),
          ],
          const SizedBox(height: 8),
          Divider(color: context.cs.surfaceContainerHighest),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Grand Total',
                  style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w800, color: context.cs.onSurface)),
              Flexible(
                child: Text(_currencyFormat.format(_order.grandTotal),
                    style: const TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800, color: kPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalsRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 14, color: context.cs.onSurfaceVariant)),
        Flexible(
          child: Text(value,
              style: TextStyle(fontSize: 14,
                  color: color ?? context.cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Container(
      decoration: _cardDeco(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Notes', Icons.notes_outlined),
          const SizedBox(height: 10),
          Text(
            _order.notes,
            style: TextStyle(
              fontSize: 13,
              color: context.cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BusinessProfile? profile) {
    final status = _order.status;
    final isDraft = status == PurchaseOrderStatus.draft;
    final isConfirmed = status == PurchaseOrderStatus.confirmed;
    final isReceived = status == PurchaseOrderStatus.received;
    final isCancelled = status == PurchaseOrderStatus.cancelled;

    return Container(
      decoration: _cardDeco(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Actions', Icons.bolt_outlined),
          const SizedBox(height: 14),

          // Send to Supplier via WhatsApp
          _ActionButton(
            label: 'Send to Supplier via WhatsApp',
            icon: Icons.chat_outlined,
            color: const Color(0xFF25D366),
            onPressed: _sendToSupplier,
          ),
          const SizedBox(height: 10),

          // Download / Share PDF
          _ActionButton(
            label: 'Download / Share PDF',
            icon: Icons.picture_as_pdf_outlined,
            color: kPrimary,
            onPressed: () => _downloadPdf(profile),
          ),
          const SizedBox(height: 10),

          // Mark as Sent (only from draft)
          if (isDraft) ...[
            _ActionButton(
              label: 'Mark as Sent',
              icon: Icons.send_outlined,
              color: _kConfirmed,
              onPressed: _markAsSent,
            ),
            const SizedBox(height: 10),
          ],

          // Mark as Received (from draft or confirmed)
          if (isDraft || isConfirmed) ...[
            _ActionButton(
              label: 'Mark as Received',
              icon: Icons.check_circle_outline,
              color: _kReceived,
              onPressed: _markAsReceived,
            ),
            const SizedBox(height: 10),
          ],

          // Status-only indicator for terminal states
          if (isReceived)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kReceivedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 18, color: _kReceived),
                  SizedBox(width: 8),
                  Text(
                    'This order has been received',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kReceived,
                    ),
                  ),
                ],
              ),
            ),

          if (isCancelled)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kCancelledBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, size: 18, color: _kCancelled),
                  SizedBox(width: 8),
                  Text(
                    'This order has been cancelled',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kCancelled,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionTitle(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: kPrimary),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _infoRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: context.cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
    );
  }
}
