import 'package:billeasy/modals/product.dart';
import 'package:billeasy/modals/purchase_line_item.dart';
import 'package:billeasy/modals/purchase_order.dart';
import 'package:billeasy/screens/purchase_order_details_screen.dart';
import 'package:billeasy/screens/products_screen.dart';
import 'package:billeasy/services/purchase_order_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:billeasy/utils/number_utils.dart' as nu;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: context.cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [kWhisperShadow],
    );

class CreatePurchaseOrderScreen extends StatefulWidget {
  const CreatePurchaseOrderScreen({super.key, this.prefilledProduct});

  /// When non-null the first item row is pre-populated with this product.
  final Product? prefilledProduct;

  @override
  State<CreatePurchaseOrderScreen> createState() =>
      _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  static const List<String> _itemUnitOptions = [
    'pcs', 'kg', 'g', 'ltr', 'ml', 'box', 'pack', 'dozen', 'meter',
  ];
  static const String _defaultItemUnit = 'pcs';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN', symbol: '₹', decimalDigits: 0,
  );

  // Supplier fields
  final _supplierNameCtrl = TextEditingController();
  final _supplierPhoneCtrl = TextEditingController();
  final _supplierAddressCtrl = TextEditingController();
  final _supplierGstinCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _expectedDate;
  bool _isSaving = false;

  // Discount state
  final _discountController = TextEditingController();
  String _selectedDiscountType = 'percentage'; // 'percentage' or 'overall'

  // GST state (per-item: each item has its own gstRate chip)
  final double _gstRate = 18.0;
  String _gstType = 'cgst_sgst'; // 'cgst_sgst' or 'igst'

  late List<Map<String, TextEditingController>> itemRows;
  // Track linked product IDs per row
  late List<String> _linkedProductIds;

  @override
  void initState() {
    super.initState();
    final p = widget.prefilledProduct;
    if (p != null) {
      // Pre-fill the first item row from the product
      final row = _createItemRowControllers();
      row['desc']!.text = p.name;
      row['hsn']!.text = p.hsnCode;
      row['unit']!.text = _itemUnitOptions.contains(p.unit) ? p.unit : _defaultItemUnit;
      row['price']!.text = p.unitPrice > 0 ? p.unitPrice.toString() : '';
      row['gstRate']!.text = p.gstApplicable ? p.gstRate.toStringAsFixed(0) : '0';
      itemRows = [row];
      _linkedProductIds = [p.id];
    } else {
      itemRows = [_createItemRowControllers()];
      _linkedProductIds = [''];
    }
  }

  @override
  void dispose() {
    _supplierNameCtrl.dispose();
    _supplierPhoneCtrl.dispose();
    _supplierAddressCtrl.dispose();
    _supplierGstinCtrl.dispose();
    _notesCtrl.dispose();
    _discountController.dispose();
    for (final row in itemRows) {
      _disposeRowControllers(row);
    }
    super.dispose();
  }

  // ── Input decoration ────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label, {String? suffix, String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 13),
        suffixText: suffix,
        filled: true,
        fillColor: context.cs.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      );

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final subtotal = _calculateSubtotal();
    final discountAmount = _calculateDiscountAmount(subtotal);
    final taxableAmount = subtotal - discountAmount;
    final discountRatio = subtotal > 0 ? (subtotal - discountAmount) / subtotal : 0.0;

    double cgstAmount = 0;
    double igstAmount = 0;
    // Per-item GST: each item can have its own rate (0 = no GST for that item)
    for (final row in itemRows) {
      final qty = nu.parseDouble(row['qty']!.text) ?? 0;
      final price = nu.parseDouble(row['price']!.text) ?? 0;
      final itemRate = nu.parseDouble(row['gstRate']!.text) ?? 0;
      if (itemRate <= 0) continue;
      final itemTotal = qty * price;
      if (_gstType == 'cgst_sgst') {
        cgstAmount += itemTotal * discountRatio * itemRate / 200;
      } else {
        igstAmount += itemTotal * discountRatio * itemRate / 100;
      }
    }
    final sgstAmount = cgstAmount;
    final totalTax = cgstAmount + sgstAmount + igstAmount;
    final grandTotal = taxableAmount + totalTax;

    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        foregroundColor: context.cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'New Purchase Order',
          style: TextStyle(
            color: context.cs.onSurface, fontWeight: FontWeight.w700, fontSize: 18,
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(grandTotal),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // ── Supplier ──────────────────────────────────────────────
              _sectionLabel('Supplier Details', step: 1),
              _buildSupplierSection(),
              const SizedBox(height: 16),

              // ── Expected Delivery ─────────────────────────────────────
              _sectionLabel('Expected Delivery', step: 2),
              _buildExpectedDateCard(),
              const SizedBox(height: 16),

              // ── Items ─────────────────────────────────────────────────
              _sectionLabel('Items', step: 3),
              ...List.generate(itemRows.length, (index) {
                return _buildItemCard(context, index);
              }),
              _buildAddItemButton(),
              const SizedBox(height: 16),

              // ── Discount ───────────────────────────────────────────────
              _sectionLabel('Discount', step: 4),
              _buildDiscountSection(subtotal, discountAmount),
              const SizedBox(height: 16),

              // ── GST (Input Tax) ───────────────────────────────────────
              _buildGstSection(taxableAmount, cgstAmount, sgstAmount, igstAmount),
              const SizedBox(height: 16),

              // ── Notes ─────────────────────────────────────────────────
              _sectionLabel('Notes', step: 6),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(context),
                child: TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    'Additional notes',
                    hint: 'Payment terms, delivery instructions, etc.',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Summary ───────────────────────────────────────────────
              _buildSummaryCard(subtotal, discountAmount, totalTax, cgstAmount, sgstAmount, igstAmount, grandTotal),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section label ───────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, {int? step}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            if (step != null) ...[
              Container(
                width: 24, height: 24,
                decoration: const BoxDecoration(
                  color: kPrimary, shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$step',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
            ] else ...[
              Container(
                  width: 3, height: 16,
                  decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
            ],
            Text(text,
                style: TextStyle(
                    color: context.cs.onSurface, fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  // ── Supplier section ────────────────────────────────────────────────────────

  Widget _buildSupplierSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          TextFormField(
            controller: _supplierNameCtrl,
            decoration: _inputDecoration('Supplier Name *'),
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter supplier name';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _supplierPhoneCtrl,
                  decoration: _inputDecoration('Phone'),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _supplierGstinCtrl,
                  decoration: _inputDecoration('GSTIN'),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supplierAddressCtrl,
            decoration: _inputDecoration('Address'),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  // ── Expected delivery date ──────────────────────────────────────────────────

  Widget _buildExpectedDateCard() {
    final hasDate = _expectedDate != null;
    final displayDate = _expectedDate ?? DateTime.now().add(const Duration(days: 7));

    return InkWell(
      onTap: _pickExpectedDate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: hasDate ? kPrimary : context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('dd').format(displayDate),
                    style: TextStyle(
                        color: hasDate ? Colors.white : context.cs.onSurfaceVariant,
                        fontSize: 18, fontWeight: FontWeight.w800, height: 1),
                  ),
                  Text(
                    DateFormat('MMM').format(displayDate).toUpperCase(),
                    style: TextStyle(
                        color: hasDate ? Colors.white70 : context.cs.onSurfaceVariant.withAlpha(153),
                        fontSize: 9, fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expected Delivery',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: context.cs.onSurfaceVariant)),
                  const SizedBox(height: 3),
                  Text(
                    hasDate
                        ? DateFormat('dd MMM yyyy').format(_expectedDate!)
                        : 'Tap to set date',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: hasDate ? context.cs.onSurface : context.cs.onSurfaceVariant.withAlpha(153)),
                  ),
                  if (hasDate)
                    Text(DateFormat('EEEE').format(_expectedDate!),
                        style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(hasDate ? 'Change' : 'Set',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: kPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Item card ───────────────────────────────────────────────────────────────

  Widget _buildItemCard(BuildContext context, int index) {
    final row = itemRows[index];
    final qty = nu.parseDouble(row['qty']!.text) ?? 0;
    final price = nu.parseDouble(row['price']!.text) ?? 0;
    final rowTotal = qty * price;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerLowest,
              borderRadius: BorderRadius.all(Radius.circular(20)),
              boxShadow: [kWhisperShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text('${index + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Item ${index + 1}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13,
                              color: context.cs.onSurface)),
                    ),
                    // Pick from products
                    GestureDetector(
                      onTap: () => _pickProduct(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 13, color: kPrimary),
                            SizedBox(width: 4),
                            Text('Products',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700,
                                    color: kPrimary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _removeItemRow(index),
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFEF4444), size: 20),
                      tooltip: 'Remove item',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
                // Line total
                if (rowTotal > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Line total: ${_currencyFormat.format(rowTotal)}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: Color(0xFFFF9500)),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Product name
                TextFormField(
                  controller: row['desc'],
                  decoration: _inputDecoration('Product / Item Name *'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter item name';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                // HSN code
                TextField(
                  controller: row['hsn'],
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration('HSN / SAC Code',
                      hint: 'e.g. 8471'),
                ),
                ...[
                  const SizedBox(height: 10),
                  Text('GST Rate',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: context.cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [0.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
                      final currentRate = nu.parseDouble(row['gstRate']!.text) ?? 18;
                      final selected = currentRate == rate;
                      return GestureDetector(
                        onTap: () => setState(() => row['gstRate']!.text = rate.toStringAsFixed(0)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected ? Color(0xFFFF9500) : context.cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${rate.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: selected ? Colors.white : context.cs.onSurface,
                              fontWeight: FontWeight.w600, fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                // Qty / Unit / Price
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 360;

                    final qtyField = TextFormField(
                      controller: row['qty'],
                      decoration: _inputDecoration('Qty *'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) {
                        final qty = nu.parseDouble(v);
                        if (qty == null || qty <= 0) return 'Qty';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    );

                    final unitField = DropdownButtonFormField<String>(
                      initialValue: _normalizeItemUnit(row['unit']!.text),
                      isExpanded: true,
                      decoration: _inputDecoration('Unit'),
                      items: _itemUnitOptions.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        row['unit']!.text = _normalizeItemUnit(value);
                        setState(() {});
                      },
                    );

                    final priceField = TextFormField(
                      controller: row['price'],
                      decoration: _inputDecoration('Unit Price *'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) {
                        final price = nu.parseDouble(v);
                        if (price == null || price <= 0) return 'Price';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    );

                    if (isCompact) {
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: qtyField),
                              const SizedBox(width: 8),
                              Expanded(child: unitField),
                            ],
                          ),
                          const SizedBox(height: 12),
                          priceField,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: qtyField),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: unitField),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: priceField),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Left accent bar (orange for purchase)
          Positioned(
            left: 0, top: 8, bottom: 8,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add item button ─────────────────────────────────────────────────────────

  Widget _buildAddItemButton() {
    return GestureDetector(
      onTap: _addItemRow,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF9500), width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_rounded, color: Color(0xFFFF9500), size: 20),
            SizedBox(width: 8),
            Text('Add Item',
                style: TextStyle(color: Color(0xFFFF9500),
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── Summary card ────────────────────────────────────────────────────────────

  // ── Discount section ─────────────────────────────────────────────────────

  Widget _buildDiscountSection(double subtotal, double discountAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['percentage', 'overall'].map((type) {
              final isSelected = _selectedDiscountType == type;
              final label = type == 'percentage' ? 'Percentage (%)' : 'Flat Amount (₹)';
              return GestureDetector(
                onTap: () => setState(() => _selectedDiscountType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimary : context.cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(color: kPrimary)
                        : Border.all(color: context.cs.outlineVariant),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : context.cs.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _discountController,
            decoration: _inputDecoration(
              _selectedDiscountType == 'percentage'
                  ? 'Discount %'
                  : 'Discount Amount',
              suffix: _selectedDiscountType == 'percentage' ? '%' : 'INR',
            ).copyWith(
              hintText: _selectedDiscountType == 'percentage'
                  ? 'e.g. 10'
                  : 'e.g. 500',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          if (discountAmount > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Discount: ${_currencyFormat.format(discountAmount)}',
              style: TextStyle(
                color: context.cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── GST section ──────────────────────────────────────────────────────────

  Widget _buildGstSection(
      double taxableAmount, double cgst, double sgst, double igst) {
    final hasAnyGst = cgst > 0 || sgst > 0 || igst > 0;
    if (!hasAnyGst) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('GST (Input Tax)', step: 5),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // GST type selector
              Text('GST TYPE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: context.cs.onSurfaceVariant, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _GstTypeChip(
                      label: 'CGST + SGST', subtitle: 'Intrastate',
                      selected: _gstType == 'cgst_sgst',
                      onTap: () => setState(() => _gstType = 'cgst_sgst'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GstTypeChip(
                      label: 'IGST', subtitle: 'Interstate',
                      selected: _gstType == 'igst',
                      onTap: () => setState(() => _gstType = 'igst'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Tax preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (_gstType == 'cgst_sgst') ...[
                      _taxPreviewRow('CGST', _currencyFormat.format(cgst)),
                      const SizedBox(height: 4),
                      _taxPreviewRow('SGST', _currencyFormat.format(sgst)),
                    ] else
                      _taxPreviewRow('IGST', _currencyFormat.format(igst)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _taxPreviewRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(fontSize: 13, color: context.cs.onSurface,
                  fontWeight: FontWeight.w600)),
        ],
      );

  // ── Summary card ────────────────────────────────────────────────────────

  Widget _buildSummaryCard(double subtotal, double discountAmount, double totalTax, double cgst,
      double sgst, double igst, double grandTotal) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFFF9500), Color(0xFFE8850A)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total',
                    style: TextStyle(color: Colors.white70, fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Text(_currencyFormat.format(grandTotal),
                    style: const TextStyle(color: Colors.white, fontSize: 28,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            _summaryRow('Items', '${itemRows.length}'),
            const SizedBox(height: 8),
            _summaryRow('Subtotal', _currencyFormat.format(subtotal)),
            if (discountAmount > 0) ...[
              const SizedBox(height: 8),
              _summaryRow('Discount', '-${_currencyFormat.format(discountAmount)}'),
            ],
            if (totalTax > 0) ...[
              const SizedBox(height: 8),
              if (_gstType == 'cgst_sgst') ...[
                _summaryRow('CGST',
                    '+${_currencyFormat.format(cgst)}'),
                const SizedBox(height: 6),
                _summaryRow('SGST',
                    '+${_currencyFormat.format(sgst)}'),
              ] else
                _summaryRow('IGST',
                    '+${_currencyFormat.format(igst)}'),
            ],
            if (_expectedDate != null) ...[
              const SizedBox(height: 8),
              _summaryRow('Expected', DateFormat('dd MMM yyyy').format(_expectedDate!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      );

  // ── Bottom bar ──────────────────────────────────────────────────────────────

  Widget _buildBottomBar(double subtotal) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        boxShadow: [kWhisperShadow],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total',
                    style: TextStyle(fontSize: 11, color: context.cs.onSurfaceVariant)),
                Text(_currencyFormat.format(subtotal),
                    style: TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w800, color: context.cs.onSurface)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _isSaving
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Color(0xFFFF9500), Color(0xFFE8850A)]),
                    color: _isSaving ? context.cs.surfaceContainerHighest : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _savePurchaseOrder,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(_isSaving ? 'Saving...' : 'Create PO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      disabledForegroundColor: Colors.white70,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logic ───────────────────────────────────────────────────────────────────

  Future<void> _pickExpectedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _expectedDate = picked);
    }
  }

  Future<void> _pickProduct(int rowIndex) async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductsScreen(selectionMode: true),
      ),
    );
    if (!mounted || product == null) return;
    final row = itemRows[rowIndex];
    setState(() {
      row['desc']!.text = product.name;
      row['price']!.text =
          product.unitPrice > 0 ? product.unitPrice.toString() : '';
      row['unit']!.text = _normalizeItemUnit(product.unit);
      if (product.hsnCode.isNotEmpty) {
        row['hsn']!.text = product.hsnCode;
      }
      _linkedProductIds[rowIndex] = product.id;
      // Set per-item GST rate from product
      if (product.gstApplicable) {
        row['gstRate']!.text = product.gstRate.toStringAsFixed(0);
      }
    });
  }

  void _addItemRow() {
    setState(() {
      itemRows.add(_createItemRowControllers());
      _linkedProductIds.add('');
    });
  }

  void _removeItemRow(int index) {
    if (itemRows.length <= 1) return;
    final row = itemRows[index];
    setState(() {
      itemRows.removeAt(index);
      _linkedProductIds.removeAt(index);
      _disposeRowControllers(row);
    });
  }

  Map<String, TextEditingController> _createItemRowControllers() {
    return {
      'desc': TextEditingController(),
      'hsn': TextEditingController(),
      'qty': TextEditingController(),
      'unit': TextEditingController(text: _defaultItemUnit),
      'price': TextEditingController(),
      'gstRate': TextEditingController(text: '18'),
    };
  }

  void _disposeRowControllers(Map<String, TextEditingController> row) {
    for (final controller in row.values) {
      controller.dispose();
    }
  }

  String _normalizeItemUnit(String? unit) {
    final normalized = unit?.trim().toLowerCase() ?? '';
    if (_itemUnitOptions.contains(normalized)) return normalized;
    return _defaultItemUnit;
  }

  double _calculateSubtotal() {
    var total = 0.0;
    for (final row in itemRows) {
      final qty = nu.parseDouble(row['qty']!.text) ?? 0;
      final price = nu.parseDouble(row['price']!.text) ?? 0;
      total += qty * price;
    }
    return total;
  }

  double _calculateDiscountAmount(double subtotal) {
    final rawDiscount =
        nu.parseDouble(_discountController.text.trim()) ?? 0;
    if (rawDiscount <= 0 || subtotal <= 0) return 0;
    if (_selectedDiscountType == 'percentage') {
      return (subtotal * (rawDiscount / 100)).clamp(0, subtotal).toDouble();
    }
    return rawDiscount.clamp(0, subtotal).toDouble();
  }

  Future<void> _savePurchaseOrder() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) return;

    if (!TeamService.instance.can.canManagePurchaseOrders) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You don\'t have permission to create purchase orders.'),
        ),
      );
      return;
    }

    if (itemRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in required')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final items = List.generate(itemRows.length, (i) {
        final row = itemRows[i];
        return PurchaseLineItem(
          productId: _linkedProductIds[i],
          productName: row['desc']!.text.trim(),
          quantity: nu.parseDouble(row['qty']!.text.trim()) ?? 0,
          unitPrice: nu.parseDouble(row['price']!.text.trim()) ?? 0,
          unit: _normalizeItemUnit(row['unit']!.text),
          hsnCode: row['hsn']!.text.trim(),
          gstRate: nu.parseDouble(row['gstRate']!.text.trim()) ?? _gstRate,
        );
      });

      final discountValue =
          nu.parseDouble(_discountController.text.trim()) ?? 0;

      final order = PurchaseOrder(
        id: '',
        ownerId: currentUser.uid,
        orderNumber: '', // auto-generated by service
        supplierName: _supplierNameCtrl.text.trim(),
        supplierPhone: _supplierPhoneCtrl.text.trim(),
        supplierAddress: _supplierAddressCtrl.text.trim(),
        supplierGstin: _supplierGstinCtrl.text.trim(),
        items: items,
        status: PurchaseOrderStatus.draft,
        createdAt: DateTime.now(),
        expectedDate: _expectedDate,
        notes: _notesCtrl.text.trim(),
        discountType: discountValue > 0 ? _selectedDiscountType : null,
        discountValue: discountValue > 0 ? discountValue : 0,
        gstEnabled: items.any((item) => item.gstRate > 0),
        gstRate: _gstRate,
        gstType: _gstType,
      );

      final saved = await PurchaseOrderService().savePurchaseOrder(order);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PurchaseOrderDetailsScreen(order: saved),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFriendlyError(error, fallback: 'Failed to save purchase order. Please try again.'))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── GST Type Chip ─────────────────────────────────────────────────────────────

class _GstTypeChip extends StatelessWidget {
  const _GstTypeChip({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kPrimary : context.cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : context.cs.onSurface)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 10,
                    color: selected ? Colors.white70 : context.cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
