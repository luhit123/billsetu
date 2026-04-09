import 'dart:async';

import 'package:billeasy/modals/product.dart';
import 'package:billeasy/modals/stock_movement.dart';
import 'package:billeasy/screens/create_purchase_order_screen.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/services/inventory_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductMovementsScreen extends StatefulWidget {
  const ProductMovementsScreen({super.key, required this.product});
  final Product product;

  @override
  State<ProductMovementsScreen> createState() =>
      _ProductMovementsScreenState();
}

class _ProductMovementsScreenState extends State<ProductMovementsScreen> {
  final InventoryService _svc = InventoryService();
  StreamSubscription<List<StockMovement>>? _sub;
  List<StockMovement> _movements = [];
  bool _loading = true;
  Object? _error;

  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _sub = _svc.getMovementsForProduct(widget.product.id).listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _movements = list;
          _loading = false;
          _error = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _error = e;
          _loading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        foregroundColor: context.cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.name,
              style: TextStyle(
                color: context.cs.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Stock Movements',
              style: TextStyle(
                color: context.cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _StockSummaryBar(product: widget.product),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Purchase Order FAB — creates a PO pre-filled with this product
          FloatingActionButton.extended(
            heroTag: 'create-po',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreatePurchaseOrderScreen(
                  prefilledProduct: widget.product,
                ),
              ),
            ),
            backgroundColor: context.cs.surfaceContainerLowest,
            foregroundColor: context.cs.primary,
            elevation: 2,
            icon: const Icon(Icons.shopping_cart_outlined, size: 20),
            label: const Text('Create PO'),
          ),
          const SizedBox(height: 12),
          // Adjust Stock FAB
          FloatingActionButton.extended(
            heroTag: 'adjust-stock',
            onPressed: _showAdjustSheet,
            backgroundColor: context.cs.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Adjust Stock'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: kOverdue, size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to load movements',
              style: TextStyle(color: context.cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (_movements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.swap_vert_rounded,
                  size: 48, color: kPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              'No movements yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Stock adjustments will appear here',
              style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _movements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) =>
          _MovementTile(movement: _movements[i], dateFormat: _dateFormat),
    );
  }

  void _showAdjustSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AdjustStockSheet(
        product: widget.product,
        onSave: (qty, isAddition, notes) async {
          final delta = isAddition ? qty : -qty;
          await _svc.adjustStock(
            productId: widget.product.id,
            productName: widget.product.name,
            quantity: delta,
            reason: notes,
          );
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

// --- Stock summary bar ---

class _StockSummaryBar extends StatelessWidget {
  const _StockSummaryBar({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final isLow = product.minStockAlert > 0 &&
        product.currentStock <= product.minStockAlert;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [kWhisperShadow],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: 'Current Stock',
              value: _fmtQty(product.currentStock, product.unit),
              color: isLow ? kOverdue : kPrimary,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: context.cs.outlineVariant.withAlpha(51),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: _StatChip(
              label: 'Min Alert',
              value: product.minStockAlert > 0
                  ? _fmtQty(product.minStockAlert, product.unit)
                  : '\u2014',
              color: context.cs.onSurfaceVariant,
            ),
          ),
          if (isLow) ...[
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kOverdueBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: kOverdue),
                  const SizedBox(width: 4),
                  Text(
                    'Low',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kOverdue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtQty(double qty, String unit) {
    final s = qty == qty.truncateToDouble()
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(1);
    return '$s $unit';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: context.cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// --- Movement tile ---

class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.movement,
    required this.dateFormat,
  });
  final StockMovement movement;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final isIn = movement.isInbound;
    final color =
        isIn ? kPaid : kOverdue;
    final bgColor =
        isIn ? kPaidBg : kOverdueBg;
    final sign = isIn ? '+' : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [kSubtleShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(
              isIn
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.typeLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: context.cs.onSurface,
                  ),
                ),
                if (movement.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    movement.notes,
                    style:
                        TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  dateFormat.format(movement.createdAt),
                  style:
                      TextStyle(fontSize: 11, color: context.cs.onSurfaceVariant.withAlpha(153)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${_fmt(movement.quantity)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                'After: ${_fmt(movement.balanceAfter)}',
                style: TextStyle(
                    fontSize: 11, color: context.cs.onSurfaceVariant.withAlpha(153)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v == v.truncateToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1);
}

// --- Adjust stock bottom sheet ---

class _AdjustStockSheet extends StatefulWidget {
  const _AdjustStockSheet({
    required this.product,
    required this.onSave,
  });
  final Product product;
  final Future<void> Function(double qty, bool isAddition, String notes)
      onSave;

  @override
  State<_AdjustStockSheet> createState() => _AdjustStockSheetState();
}

class _AdjustStockSheetState extends State<_AdjustStockSheet> {
  final _qtyCtrl    = TextEditingController();
  final _notesCtrl  = TextEditingController();
  bool _isAddition  = true;
  bool _saving      = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Adjust Stock \u2014 ${widget.product.name}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TypeBtn(
                  label: 'Stock In',
                  icon: Icons.add_circle_outline_rounded,
                  selected: _isAddition,
                  color: kPaid,
                  onTap: () => setState(() => _isAddition = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TypeBtn(
                  label: 'Stock Out',
                  icon: Icons.remove_circle_outline_rounded,
                  selected: !_isAddition,
                  color: kOverdue,
                  onTap: () => setState(() => _isAddition = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _field(
            controller: _qtyCtrl,
            label: 'Quantity (${widget.product.unit})',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _field(
            controller: _notesCtrl,
            label: 'Notes (optional)',
            hint: 'e.g. Purchase received, Damaged\u2026',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.cs.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Adjustment',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 13),
          hintStyle: TextStyle(color: context.cs.onSurfaceVariant.withAlpha(153), fontSize: 12),
          filled: true,
          fillColor: context.cs.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kPrimary, width: 1.5),
          ),
        ),
      );

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(qty, _isAddition, _notesCtrl.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: kOverdue,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TypeBtn extends StatelessWidget {
  const _TypeBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : context.cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: color, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : context.cs.onSurfaceVariant, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : context.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
