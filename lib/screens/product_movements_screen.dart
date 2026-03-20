import 'dart:async';

import 'package:billeasy/modals/product.dart';
import 'package:billeasy/modals/stock_movement.dart';
import 'package:billeasy/services/inventory_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/formatters.dart';
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

  final _dateFormat = kDateTimeFormat;

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
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kGradient),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const Text(
              'Stock Movements',
              style: TextStyle(
                color: Colors.white70,
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'adjust-stock',
        onPressed: _showAdjustSheet,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Adjust Stock'),
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
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to load movements',
              style: TextStyle(color: kTextSecondary),
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
              decoration: const BoxDecoration(
                color: Color(0xFFEEF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.swap_vert_rounded,
                  size: 48, color: kPrimary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No movements yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Stock adjustments will appear here',
              style: TextStyle(fontSize: 13, color: kTextSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _movements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) =>
          _MovementTile(movement: _movements[i], dateFormat: _dateFormat),
    );
  }

  void _showAdjustSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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

// ─── Stock summary bar ────────────────────────────────────────────────────────

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLow ? Colors.red.shade200 : kBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F4A75),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: 'Current Stock',
              value: _fmtQty(product.currentStock, product.unit),
              color: isLow ? Colors.red : kPrimary,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: kBorder,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: _StatChip(
              label: 'Min Alert',
              value: product.minStockAlert > 0
                  ? _fmtQty(product.minStockAlert, product.unit)
                  : '—',
              color: kTextSecondary,
            ),
          ),
          if (isLow) ...[
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Low',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
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
            style: const TextStyle(fontSize: 11, color: kTextSecondary)),
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

// ─── Movement tile ────────────────────────────────────────────────────────────

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
        isIn ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final bgColor =
        isIn ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final sign = isIn ? '+' : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: kTextPrimary,
                  ),
                ),
                if (movement.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    movement.notes,
                    style:
                        const TextStyle(fontSize: 12, color: kTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  dateFormat.format(movement.createdAt),
                  style:
                      const TextStyle(fontSize: 11, color: kTextSecondary),
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
                style: const TextStyle(
                    fontSize: 11, color: kTextSecondary),
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

// ─── Adjust stock bottom sheet ────────────────────────────────────────────────

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
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Adjust Stock — ${widget.product.name}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
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
                  color: const Color(0xFF22C55E),
                  onTap: () => setState(() => _isAddition = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TypeBtn(
                  label: 'Stock Out',
                  icon: Icons.remove_circle_outline_rounded,
                  selected: !_isAddition,
                  color: const Color(0xFFEF4444),
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
            hint: 'e.g. Purchase received, Damaged…',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
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
          labelStyle: const TextStyle(color: kTextSecondary, fontSize: 13),
          hintStyle: const TextStyle(color: kTextSecondary, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFFF5F8FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder),
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
            backgroundColor: Colors.red,
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
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : kTextSecondary, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
