import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/product.dart';
import 'package:billeasy/utils/number_utils.dart' as nu;
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/line_item.dart';
import 'package:billeasy/screens/customer_form_screen.dart';
import 'package:billeasy/screens/customers_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/screens/products_screen.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/invoice_number_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/usage_tracking_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/limit_reached_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

BoxDecoration _cardDecoration() => BoxDecoration(
  color: kSurfaceLowest,
  borderRadius: BorderRadius.circular(20),
  boxShadow: const [kWhisperShadow],
);

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key, this.initialClient});

  final Client? initialClient;

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  static const List<String> _itemUnitOptions = [
    'pcs',
    'kg',
    'g',
    'ltr',
    'ml',
    'box',
    'pack',
    'dozen',
    'meter',
  ];
  static const String _defaultItemUnit = 'pcs';
  static const String _customUnitValue = '__custom__';
  static const Duration _defaultPaymentTerm = Duration(days: 14);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _discountController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  DateTime selectedDate = DateTime.now();
  Client? _selectedClient;
  bool _isSaving = false;
  bool _showClientValidationError = false;
  InvoiceStatus _selectedStatus = InvoiceStatus.paid;
  InvoiceDiscountType _selectedDiscountType = InvoiceDiscountType.percentage;
  late List<Map<String, TextEditingController>> itemRows;

  // GST state
  bool _gstEnabled = false;
  double _gstRate = 18.0;
  String _gstType = 'cgst_sgst'; // 'cgst_sgst' or 'igst'

  // UX: collapsible sections
  late List<bool> _showAdvanced;
  bool _showDiscountSection = false;
  bool _showGstSection = false;

  @override
  void initState() {
    super.initState();
    _selectedClient = widget.initialClient;
    itemRows = [_createItemRowControllers()];
    _showAdvanced = [false];
    _loadLastUsedGstSettings();
  }

  Future<void> _loadLastUsedGstSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _gstRate = prefs.getDouble('last_gst_rate') ?? 18.0;
      _gstType = prefs.getString('last_gst_type') ?? 'cgst_sgst';
      _showGstSection = _gstEnabled;
    });
  }

  Future<void> _saveLastUsedGstSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_gst_rate', _gstRate);
    await prefs.setString('last_gst_type', _gstType);
  }

  @override
  void dispose() {
    _discountController.dispose();
    for (final row in itemRows) {
      _disposeRowControllers(row);
    }
    super.dispose();
  }

  // ── Input decoration ──────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label, {String? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kOnSurfaceVariant, fontSize: 13),
        suffixText: suffix,
        filled: true,
        fillColor: kSurfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kOutlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kOutlineVariant),
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
          borderSide:
              const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final subtotal = _calculateSubtotal();
    final discountAmount = _calculateDiscountAmount(subtotal);
    final taxableAmount = subtotal - discountAmount;
    final discountRatio = subtotal > 0 ? (subtotal - discountAmount) / subtotal : 0.0;
    double cgstAmount = 0;
    double igstAmount = 0;
    if (_gstEnabled) {
      for (final row in itemRows) {
        final qty = nu.parseDouble(row['qty']!.text) ?? 0;
        final price = nu.parseDouble(row['price']!.text) ?? 0;
        final itemRate = nu.parseDouble(row['gstRate']!.text) ?? _gstRate;
        final itemTotal = qty * price;
        if (_gstType == 'cgst_sgst') {
          cgstAmount += itemTotal * discountRatio * itemRate / 200;
        } else {
          igstAmount += itemTotal * discountRatio * itemRate / 100;
        }
      }
    }
    final sgstAmount = cgstAmount;
    final totalTax = cgstAmount + sgstAmount + igstAmount;
    final grandTotal = taxableAmount + totalTax;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: kOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          s.createTitle,
          style: const TextStyle(
            color: kOnSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: const BoxDecoration(
          color: kSurfaceLowest,
          boxShadow: [kWhisperShadow],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 11, color: kOnSurfaceVariant)),
                  Text(
                    _currencyFormat.format(grandTotal),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kOnSurface),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _isSaving ? null : kSignatureGradient,
                      color: _isSaving ? kSurfaceDim : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveInvoice,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(_isSaving ? s.createSavingInvoice : s.createSaveInvoice),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: Colors.white70,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // ── Customer ──────────────────────────────────────────────
              _buildCustomerSection(context),
              const SizedBox(height: 12),

              // ── Date ──────────────────────────────────────────────────
              _buildDateCard(context, s),
              const SizedBox(height: 16),

              // ── Items ─────────────────────────────────────────────────
              _sectionLabel('Items'),
              ...List.generate(itemRows.length, (index) => _buildItemCard(context, index, s)),

              // ── Add Item + From Products ──────────────────────────────
              _buildAddItemButtons(),
              const SizedBox(height: 16),

              // ── Invoice Settings (Status + Discount + GST) ────────────
              _sectionLabel('Invoice Settings'),
              _buildInvoiceSettings(s, subtotal, discountAmount, taxableAmount, cgstAmount, sgstAmount, igstAmount),
              const SizedBox(height: 16),

              // ── Summary ───────────────────────────────────────────────
              _buildSummaryCard(subtotal, discountAmount, totalTax, cgstAmount, sgstAmount, igstAmount, grandTotal, s),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section label helper ──────────────────────────────────────────────────

  Widget _sectionLabel(String text, {int? step}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        if (step != null) ...[
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: kPrimary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
        ] else ...[
          Container(width: 3, height: 16, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
        ],
        Text(text, style: const TextStyle(color: kOnSurface, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  // ── Date card ─────────────────────────────────────────────────────────────

  Widget _buildDateCard(BuildContext context, AppStrings s) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: kPrimary),
            const SizedBox(width: 10),
            Text(
              DateFormat('dd MMM yyyy, EEEE').format(selectedDate),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kOnSurface),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 20, color: kOnSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── Item card ─────────────────────────────────────────────────────────────

  Widget _buildItemCard(
      BuildContext context, int index, AppStrings s) {
    final row = itemRows[index];
    final qty = nu.parseDouble(row['qty']!.text) ?? 0;
    final price = nu.parseDouble(row['price']!.text) ?? 0;
    final rowTotal = qty * price;
    final advanced = index < _showAdvanced.length && _showAdvanced[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: const BoxDecoration(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: [kWhisperShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: simple "#1" text + delete icon
            Row(
              children: [
                Text(
                  '#${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kOnSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeItemRow(index),
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFEF4444), size: 20),
                  tooltip: s.createDeleteItem,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 36, minHeight: 36),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Description
            TextFormField(
              controller: row['desc'],
              decoration: _inputDecoration(s.createProductLabel),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.createEnterProduct;
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            // Qty / Unit / Price — always in one row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row['qty'],
                    decoration: _inputDecoration(s.createQtyLabel),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final qty = nu.parseDouble(value);
                      if (qty == null || qty <= 0) {
                        return s.createQtyLabel;
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Builder(builder: (context) {
                    final currentUnit = row['unit']!.text.isEmpty
                        ? _defaultItemUnit
                        : row['unit']!.text;
                    final isCustomUnit =
                        !_itemUnitOptions.contains(currentUnit.toLowerCase());
                    return DropdownButtonFormField<String>(
                      initialValue: isCustomUnit ? _customUnitValue : currentUnit.toLowerCase(),
                      isExpanded: true,
                      decoration: _inputDecoration(s.createUnitLabel),
                      items: [
                        ..._itemUnitOptions.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit,
                                overflow: TextOverflow.ellipsis),
                          );
                        }),
                        DropdownMenuItem(
                          value: _customUnitValue,
                          child: Text(isCustomUnit ? 'Custom: $currentUnit' : 'Custom...',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: kPrimary,
                                fontWeight: isCustomUnit ? FontWeight.w600 : FontWeight.w400,
                              )),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == _customUnitValue) {
                          _showCustomUnitDialog(row);
                        } else {
                          row['unit']!.text = value ?? _defaultItemUnit;
                          setState(() {});
                        }
                      },
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: row['price'],
                    decoration:
                        _inputDecoration(s.createUnitPriceLabel),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final price = nu.parseDouble(value);
                      if (price == null || price <= 0) {
                        return s.createUnitPriceLabel;
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            // Line total — subtle right-aligned text
            if (rowTotal > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '= ${_currencyFormat.format(rowTotal)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: kOnSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            // "More options" toggle for HSN + GST rate
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() {
                if (index < _showAdvanced.length) {
                  _showAdvanced[index] = !_showAdvanced[index];
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      advanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16, color: kPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      advanced ? 'Less options' : 'More options',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (advanced) ...[
              const SizedBox(height: 8),
              // HSN / SAC code
              TextField(
                controller: row['hsn'],
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(s.hsnCodeLabel).copyWith(
                  hintText: s.hsnCodeHint,
                ),
              ),
              if (_gstEnabled) ...[
                const SizedBox(height: 10),
                const Text('GST Rate',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: kOnSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [0.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
                    final currentRate = nu.parseDouble(row['gstRate']!.text) ?? _gstRate;
                    final selected = currentRate == rate;
                    return GestureDetector(
                      onTap: () => setState(() => row['gstRate']!.text = rate.toStringAsFixed(0)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected ? kPrimary : kSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${rate.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: selected ? Colors.white : kOnSurface,
                            fontWeight: FontWeight.w600, fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── Add Item buttons row ─────────────────────────────────────────────────

  Widget _buildAddItemButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _addItemRow,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: kSurfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimary, width: 1.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_rounded, color: kPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Add Item', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _addItemRow();
                _pickProduct(itemRows.length - 1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: kSurfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kOutlineVariant, width: 1.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, color: kOnSurfaceVariant, size: 18),
                    SizedBox(width: 8),
                    Text('From Products', style: TextStyle(color: kOnSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Invoice Settings (merged Status + Discount + GST) ──────────────────

  Widget _buildInvoiceSettings(
    AppStrings s,
    double subtotal,
    double discountAmount,
    double taxableAmount,
    double cgstAmount,
    double sgstAmount,
    double igstAmount,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status pills ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: InvoiceStatus.values.map((status) {
              final isSelected = _selectedStatus == status;
              return _StatusPill(
                label: _statusLabel(status, s),
                isSelected: isSelected,
                selectedBg: _statusBackgroundColor(status),
                selectedBorder: _statusBorderColor(status),
                selectedText: _statusTextColor(status),
                onTap: () => setState(() => _selectedStatus = status),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: kSurfaceContainerLow),

          // ── Add Discount (expandable) ──
          InkWell(
            onTap: () => setState(() => _showDiscountSection = !_showDiscountSection),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.discount_outlined, size: 18, color: kOnSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    discountAmount > 0
                        ? 'Discount: -${_currencyFormat.format(discountAmount)}'
                        : 'Add Discount',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kOnSurface),
                  ),
                  const Spacer(),
                  Icon(_showDiscountSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: kOnSurfaceVariant),
                ],
              ),
            ),
          ),
          if (_showDiscountSection) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                ...InvoiceDiscountType.values.map((discountType) {
                  final isSelected = _selectedDiscountType == discountType;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _StatusPill(
                      label: _discountTypeLabel(discountType, s),
                      isSelected: isSelected,
                      selectedBg: kSurfaceContainerLow,
                      selectedBorder: kPrimaryContainer,
                      selectedText: kPrimary,
                      onTap: () => setState(() => _selectedDiscountType = discountType),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                Expanded(
                  child: TextFormField(
                    controller: _discountController,
                    decoration: _inputDecoration(
                      _selectedDiscountType == InvoiceDiscountType.percentage
                          ? s.createDiscountPctField
                          : s.createDiscountOverallField,
                      suffix: _selectedDiscountType == InvoiceDiscountType.percentage ? '%' : 'INR',
                    ).copyWith(
                      hintText: _selectedDiscountType == InvoiceDiscountType.percentage
                          ? s.createDiscountPctHint
                          : s.createDiscountOverallHint,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (discountAmount > 0) ...[
              const SizedBox(height: 6),
              Text(
                _discountPreviewText(subtotal, discountAmount, s),
                style: const TextStyle(
                  color: kOnSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
          Container(height: 1, color: kSurfaceContainerLow),

          // ── GST Settings (expandable) ──
          InkWell(
            onTap: () => setState(() => _showGstSection = !_showGstSection),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 18, color: kOnSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    _gstEnabled ? 'GST: Enabled' : 'GST Settings',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kOnSurface),
                  ),
                  const Spacer(),
                  Icon(_showGstSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: kOnSurfaceVariant),
                ],
              ),
            ),
          ),
          if (_showGstSection) ...[
            const SizedBox(height: 4),
            // Toggle row
            Row(
              children: [
                Expanded(
                  child: Text(
                    _gstEnabled
                        ? 'GST is included in grand total'
                        : 'Tap to enable GST on this invoice',
                    style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant),
                  ),
                ),
                Switch.adaptive(
                  value: _gstEnabled,
                  activeThumbColor: Colors.white,
                  activeTrackColor: kPrimary,
                  onChanged: (v) => setState(() => _gstEnabled = v),
                ),
              ],
            ),
            if (_gstEnabled) ...[
              const SizedBox(height: 10),
              // Type selector
              const Text('GST TYPE',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: kOnSurfaceVariant, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _GstTypeChip(
                    label: 'CGST + SGST',
                    subtitle: 'Intrastate',
                    selected: _gstType == 'cgst_sgst',
                    onTap: () => setState(() => _gstType = 'cgst_sgst'),
                  ),
                  const SizedBox(width: 10),
                  _GstTypeChip(
                    label: 'IGST',
                    subtitle: 'Interstate',
                    selected: _gstType == 'igst',
                    onTap: () => setState(() => _gstType = 'igst'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Tax preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (_gstType == 'cgst_sgst') ...[
                      _taxPreviewRow('CGST', _currencyFormat.format(cgstAmount)),
                      const SizedBox(height: 4),
                      _taxPreviewRow('SGST', _currencyFormat.format(sgstAmount)),
                    ] else
                      _taxPreviewRow('IGST', _currencyFormat.format(igstAmount)),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _taxPreviewRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: kOnSurfaceVariant, fontWeight: FontWeight.w500)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: kOnSurface,
                  fontWeight: FontWeight.w600)),
        ],
      );

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(
      double subtotal,
      double discountAmount,
      double totalTax,
      double cgst,
      double sgst,
      double igst,
      double grandTotal,
      AppStrings s) {
    return Container(
      decoration: BoxDecoration(
        gradient: kSignatureGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Grand total at top (big)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(
                  _currencyFormat.format(grandTotal),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Divider
            Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            // Breakdown rows
            _summaryRowWhite(s.createSummarySubtotal, _currencyFormat.format(subtotal)),
            if (discountAmount > 0) ...[
              const SizedBox(height: 8),
              _summaryRowWhite(s.createSummaryDiscount, '-${_currencyFormat.format(discountAmount)}', valueColor: const Color(0xFFFFB3B3)),
            ],
            if (_gstEnabled && totalTax > 0) ...[
              const SizedBox(height: 8),
              if (_gstType == 'cgst_sgst') ...[
                _summaryRowWhite('CGST', '+${_currencyFormat.format(cgst)}', valueColor: const Color(0xFF86EFAC)),
                const SizedBox(height: 6),
                _summaryRowWhite('SGST', '+${_currencyFormat.format(sgst)}', valueColor: const Color(0xFF86EFAC)),
              ] else
                _summaryRowWhite('IGST', '+${_currencyFormat.format(igst)}', valueColor: const Color(0xFF86EFAC)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRowWhite(String label, String value, {Color? valueColor}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    ],
  );

  // ── Customer section ──────────────────────────────────────────────────────

  Widget _buildCustomerSection(BuildContext context) {
    final s = AppStrings.of(context);
    final selectedClient = _selectedClient;
    final hasError =
        _showClientValidationError && selectedClient == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(s.createCustomerLabel),
        // Show selected customer card if one is picked
        if (selectedClient != null) ...[
          Container(
            decoration: BoxDecoration(
              color: kSurfaceLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPrimary, width: 1.5),
              boxShadow: const [kWhisperShadow],
            ),
            child: InkWell(
              onTap: _pickCustomer,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: kPrimaryContainer,
                      child: Text(
                        selectedClient.initials,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: kPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedClient.name,
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: kOnSurface,
                            ),
                          ),
                          if (selectedClient.gstin.isNotEmpty)
                            Text(
                              '${s.customerGstinLabel}: ${selectedClient.gstin}',
                              style: const TextStyle(fontSize: 11, color: kPrimary, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.swap_horiz_rounded, size: 18, color: kOnSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          // Two action cards: Customers + Add New
          Row(
            children: [
              Expanded(
                child: _customerActionCard(
                  icon: Icons.groups_2_outlined,
                  label: s.createPickCustomer,
                  onTap: _pickCustomer,
                  hasError: hasError,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _customerActionCard(
                  icon: Icons.person_add_alt_1_rounded,
                  label: s.createAddNew,
                  onTap: _addCustomer,
                  hasError: false,
                ),
              ),
            ],
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                s.createCustomerRequired,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _customerActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool hasError,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.circular(14),
          border: hasError
              ? Border.all(color: const Color(0xFFEF4444), width: 1.2)
              : null,
          boxShadow: const [kWhisperShadow],
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: kPrimary),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: kOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logic (unchanged) ─────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickCustomer() async {
    final selectedClient = await Navigator.push<Client>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomersScreen(
          selectionMode: true,
          preselectedClientId: _selectedClient?.id,
        ),
      ),
    );

    if (!mounted || selectedClient == null) {
      return;
    }

    setState(() {
      _selectedClient = selectedClient;
      _showClientValidationError = false;
    });
  }

  Future<void> _addCustomer() async {
    final savedClient = await Navigator.push<Client>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
    );

    if (!mounted || savedClient == null) {
      return;
    }

    setState(() {
      _selectedClient = savedClient;
      _showClientValidationError = false;
    });
  }

  /// Opens the Products screen in selection mode and auto-fills
  /// the description, price, unit, HSN code, and GST fields for the given item row.
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
      row['desc']!.text  = product.name;
      row['price']!.text = product.unitPrice > 0 ? product.unitPrice.toString() : '';
      row['unit']!.text  = _normalizeItemUnit(product.unit);
      // Auto-fill HSN code from product
      if (product.hsnCode.isNotEmpty) {
        row['hsn']!.text = product.hsnCode;
      }
      // Auto-enable GST and set per-item rate if product has GST configured
      if (product.gstApplicable) {
        _gstEnabled = true;
        row['gstRate']!.text = product.gstRate.toStringAsFixed(0);
      }
    });
  }

  void _addItemRow() {
    setState(() {
      itemRows.add(_createItemRowControllers());
      _showAdvanced.add(false);
    });
  }

  void _removeItemRow(int index) {
    final row = itemRows[index];
    setState(() {
      itemRows.removeAt(index);
      _showAdvanced.removeAt(index);
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

    if (rawDiscount <= 0 || subtotal <= 0) {
      return 0;
    }

    switch (_selectedDiscountType) {
      case InvoiceDiscountType.percentage:
        return (subtotal * (rawDiscount / 100))
            .clamp(0, subtotal)
            .toDouble();
      case InvoiceDiscountType.overall:
        return rawDiscount.clamp(0, subtotal).toDouble();
    }
  }

  Future<void> _saveInvoice() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;

    if (!isFormValid) {
      return;
    }

    if (_selectedClient == null) {
      setState(() {
        _showClientValidationError = true;
      });
      return;
    }

    if (itemRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppStrings.of(context).createAddLineItem)),
      );
      return;
    }

    final subtotal = _calculateSubtotal();
    final discountValue =
        nu.parseDouble(_discountController.text.trim()) ?? 0;
    final discountError = _validateDiscount(subtotal, discountValue);

    if (discountError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(discountError)));
      return;
    }

    final invoiceDate = selectedDate;
    final dueDate = invoiceDate.add(_defaultPaymentTerm);

    final items = itemRows.map((row) {
      return LineItem(
        description: row['desc']!.text.trim(),
        hsnCode: row['hsn']!.text.trim(),
        quantity: nu.parseDouble(row['qty']!.text.trim()) ?? 0,
        unitPrice:
            nu.parseDouble(row['price']!.text.trim()) ?? 0,
        unit: _normalizeItemUnit(row['unit']!.text),
        gstRate: nu.parseDouble(row['gstRate']!.text.trim()) ?? _gstRate,
      );
    }).toList();
    final selectedClient = _selectedClient!;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppStrings.of(context).createSignInRequired)),
      );
      return;
    }

    // ── Plan gate: check invoice limit ──
    final invoiceCount = await UsageTrackingService.instance.getInvoiceCount();
    if (!PlanService.instance.canCreateInvoice(invoiceCount)) {
      if (!mounted) return;
      await LimitReachedDialog.show(
        context,
        title: 'Invoice Limit Reached',
        message: 'You\'ve used $invoiceCount/${PlanService.instance.currentLimits.maxInvoicesPerMonth} invoices this month. Upgrade to create more.',
        featureName: 'more invoices',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _saveLastUsedGstSettings();

      final invoiceNumber = await InvoiceNumberService()
          .reserveNextInvoiceNumber(year: invoiceDate.year);

      final invoice = Invoice(
        id: '',
        ownerId: currentUser.uid,
        invoiceNumber: invoiceNumber,
        clientId: selectedClient.id,
        clientName: selectedClient.name,
        customerGstin: _selectedClient?.gstin ?? '',
        items: items,
        createdAt: invoiceDate,
        dueDate: dueDate,
        status: _selectedStatus,
        discountType:
            discountValue > 0 ? _selectedDiscountType : null,
        discountValue: discountValue > 0 ? discountValue : 0,
        gstEnabled: _gstEnabled,
        gstRate: _gstRate,
        gstType: _gstType,
      );

      final invoiceId = await FirebaseService().addInvoice(invoice);
      await UsageTrackingService.instance.incrementInvoiceCount();
      if (!mounted) {
        return;
      }
      final savedInvoice = Invoice(
        id: invoiceId,
        ownerId: invoice.ownerId,
        invoiceNumber: invoice.invoiceNumber,
        clientId: invoice.clientId,
        clientName: invoice.clientName,
        customerGstin: invoice.customerGstin,
        items: invoice.items,
        createdAt: invoice.createdAt,
        dueDate: invoice.dueDate,
        status: invoice.status,
        discountType: invoice.discountType,
        discountValue: invoice.discountValue,
        gstEnabled: invoice.gstEnabled,
        gstRate: invoice.gstRate,
        gstType: invoice.gstType,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              InvoiceDetailsScreen(invoice: savedInvoice),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context)
                .createFailedSave(error.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showCustomUnitDialog(Map<String, TextEditingController> row) async {
    final controller = TextEditingController(text:
        _itemUnitOptions.contains(row['unit']!.text.toLowerCase()) ? '' : row['unit']!.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Unit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          decoration: _inputDecoration('e.g. bag, roll, ft, sqft'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      row['unit']!.text = result;
      setState(() {});
    }
  }

  String _normalizeItemUnit(String? unit) {
    final trimmed = unit?.trim() ?? '';
    if (trimmed.isEmpty) return _defaultItemUnit;
    final lower = trimmed.toLowerCase();
    if (_itemUnitOptions.contains(lower)) return lower;
    // Allow custom units as-is
    return trimmed;
  }

  String _statusLabel(InvoiceStatus status, AppStrings s) {
    switch (status) {
      case InvoiceStatus.paid:
        return s.statusPaid;
      case InvoiceStatus.pending:
        return s.statusPending;
      case InvoiceStatus.overdue:
        return s.statusOverdue;
    }
  }

  Color _statusBackgroundColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return const Color(0xFFDCFCE7);
      case InvoiceStatus.pending:
        return const Color(0xFFFEF3C7);
      case InvoiceStatus.overdue:
        return const Color(0xFFFEE2E2);
    }
  }

  Color _statusBorderColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return const Color(0xFF86EFAC);
      case InvoiceStatus.pending:
        return const Color(0xFFFCD34D);
      case InvoiceStatus.overdue:
        return const Color(0xFFFCA5A5);
    }
  }

  Color _statusTextColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return const Color(0xFF15803D);
      case InvoiceStatus.pending:
        return const Color(0xFFB45309);
      case InvoiceStatus.overdue:
        return const Color(0xFFB91C1C);
    }
  }

  String _discountTypeLabel(
      InvoiceDiscountType discountType, AppStrings s) {
    switch (discountType) {
      case InvoiceDiscountType.percentage:
        return s.createDiscountPctLabel;
      case InvoiceDiscountType.overall:
        return s.createDiscountOverallLabel;
    }
  }

  String _discountPreviewText(
    double subtotal,
    double discountAmount,
    AppStrings s,
  ) {
    final rawDiscount =
        nu.parseDouble(_discountController.text.trim()) ?? 0;

    if (rawDiscount <= 0 || subtotal <= 0) {
      return s.createDiscountEmptyHint;
    }

    if (_selectedDiscountType == InvoiceDiscountType.percentage) {
      final pct = rawDiscount.toStringAsFixed(
        rawDiscount.truncateToDouble() == rawDiscount ? 0 : 2,
      );
      return s.createDiscountPreviewPct(
        pct,
        _currencyFormat.format(subtotal),
        _currencyFormat.format(discountAmount),
      );
    }

    return s.createDiscountPreviewOverall(
      _currencyFormat.format(discountAmount),
      _currencyFormat.format(subtotal),
    );
  }

  String? _validateDiscount(
      double subtotal, double discountValue) {
    if (discountValue <= 0) {
      return null;
    }

    final s = AppStrings.of(context);

    if (_selectedDiscountType == InvoiceDiscountType.percentage &&
        discountValue > 100) {
      return s.createErrorPctMax;
    }

    if (_selectedDiscountType == InvoiceDiscountType.overall &&
        discountValue > subtotal) {
      return s.createErrorOverallMax;
    }

    return null;
  }
}

// ── Status / type pill chip ───────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.isSelected,
    required this.selectedBg,
    required this.selectedBorder,
    required this.selectedText,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color selectedBg;
  final Color selectedBorder;
  final Color selectedText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(
            color: selectedBorder,
            width: 1.5,
          ) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? selectedText : kOnSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── GST type chip ─────────────────────────────────────────────────────────────

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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? kPrimary : kSurfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : kOnSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : kOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
