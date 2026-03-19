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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Brand tokens ────────────────────────────────────────────────────────────
const _kPrimary     = Color(0xFF0F4A75);
const _kBackground  = Color(0xFFEFF6FF);
const _kBorder      = Color(0xFFBDD5F0);
const _kLabel       = Color(0xFF5B7A9A);
const _kTitle       = Color(0xFF0B234F);

const _kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B234F), Color(0xFF0F4A75), Color(0xFF0F7D83)],
);

BoxDecoration _cardDecoration({bool error = false}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(
    color: error ? const Color(0xFFEF4444) : const Color(0xFFBDD5F0),
    width: error ? 1.5 : 1.2,
  ),
  boxShadow: [
    BoxShadow(
      color: error ? const Color(0x10EF4444) : const Color(0x0E0F4A75),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ],
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
  static const Duration _defaultPaymentTerm = Duration(days: 14);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _discountController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  DateTime? selectedDate;
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

  @override
  void initState() {
    super.initState();
    _selectedClient = widget.initialClient;
    itemRows = [_createItemRowControllers()];
    _loadLastUsedGstSettings();
  }

  Future<void> _loadLastUsedGstSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _gstRate = prefs.getDouble('last_gst_rate') ?? 18.0;
      _gstType = prefs.getString('last_gst_type') ?? 'cgst_sgst';
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
        labelStyle: const TextStyle(color: _kLabel, fontSize: 13),
        suffixText: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F8FF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFBDD5F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
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
    final cgstAmount = (_gstEnabled && _gstType == 'cgst_sgst' && _gstRate > 0)
        ? taxableAmount * _gstRate / 200
        : 0.0;
    final sgstAmount = cgstAmount;
    final igstAmount = (_gstEnabled && _gstType == 'igst' && _gstRate > 0)
        ? taxableAmount * _gstRate / 100
        : 0.0;
    final totalTax = cgstAmount + sgstAmount + igstAmount;
    final grandTotal = taxableAmount + totalTax;

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _kGradient),
        ),
        title: Text(
          s.createTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // ── Customer ──────────────────────────────────────────────
              _buildCustomerSection(context),
              const SizedBox(height: 16),

              // ── Invoice Date ──────────────────────────────────────────
              _buildDateCard(context, s),
              if (selectedDate == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    s.createDateRequired,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // ── Section label – Items ─────────────────────────────────
              _sectionLabel('Items'),
              const SizedBox(height: 8),

              // ── Item rows ─────────────────────────────────────────────
              ...List.generate(itemRows.length, (index) {
                return _buildItemCard(context, index, s);
              }),

              // ── Add item button ───────────────────────────────────────
              TextButton.icon(
                onPressed: _addItemRow,
                icon: const Icon(Icons.add_circle_outline,
                    color: _kPrimary, size: 18),
                label: Text(
                  s.createAddItem,
                  style: const TextStyle(
                    color: _kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Status ────────────────────────────────────────────────
              _sectionLabel(s.createInvoiceStatus),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: InvoiceStatus.values.map((status) {
                    final isSelected = _selectedStatus == status;
                    return _StatusPill(
                      label: _statusLabel(status, s),
                      isSelected: isSelected,
                      selectedBg: _statusBackgroundColor(status),
                      selectedBorder: _statusBorderColor(status),
                      selectedText: _statusTextColor(status),
                      onTap: () =>
                          setState(() => _selectedStatus = status),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Discount ──────────────────────────────────────────────
              _sectionLabel(s.createDiscountTitle),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          InvoiceDiscountType.values.map((discountType) {
                        final isSelected =
                            _selectedDiscountType == discountType;
                        return _StatusPill(
                          label:
                              _discountTypeLabel(discountType, s),
                          isSelected: isSelected,
                          selectedBg: const Color(0xFFEFF6FF),
                          selectedBorder: const Color(0xFFBFDBFE),
                          selectedText: const Color(0xFF1D4ED8),
                          onTap: () => setState(
                              () => _selectedDiscountType = discountType),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _discountController,
                      decoration: _inputDecoration(
                        _selectedDiscountType ==
                                InvoiceDiscountType.percentage
                            ? s.createDiscountPctField
                            : s.createDiscountOverallField,
                        suffix: _selectedDiscountType ==
                                InvoiceDiscountType.percentage
                            ? '%'
                            : 'INR',
                      ).copyWith(
                        hintText: _selectedDiscountType ==
                                InvoiceDiscountType.percentage
                            ? s.createDiscountPctHint
                            : s.createDiscountOverallHint,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _discountPreviewText(subtotal, discountAmount, s),
                      style: const TextStyle(
                        color: _kLabel,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── GST ───────────────────────────────────────────────────
              _buildGstSection(taxableAmount, cgstAmount, sgstAmount, igstAmount),
              const SizedBox(height: 16),

              // ── Summary ───────────────────────────────────────────────
              _buildSummaryCard(subtotal, discountAmount, totalTax, cgstAmount, sgstAmount, igstAmount, grandTotal, s),
              const SizedBox(height: 24),

              // ── Save button ───────────────────────────────────────────
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveInvoice,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _isSaving
                        ? s.createSavingInvoice
                        : s.createSaveInvoice,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _kPrimary.withValues(alpha: 0.45),
                    disabledForegroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0x400F4A75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.createSaveHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kLabel,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section label helper ──────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF0B234F),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );

  // ── Date card ─────────────────────────────────────────────────────────────

  Widget _buildDateCard(BuildContext context, AppStrings s) {
    final hasDate = selectedDate != null;
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasDate
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 22,
                color: hasDate
                    ? _kPrimary
                    : const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.createInvoiceDate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kLabel,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasDate
                        ? DateFormat('dd MMM yyyy').format(selectedDate!)
                        : s.createPickDate,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: hasDate ? _kTitle : const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDate
                        ? s.createDateHintSelected
                        : s.createDateHintEmpty,
                    style: const TextStyle(fontSize: 12, color: _kLabel),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _kLabel, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Item card ─────────────────────────────────────────────────────────────

  Widget _buildItemCard(
      BuildContext context, int index, AppStrings s) {
    final row = itemRows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: _kPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.createItemNumber(index + 1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _kTitle,
                    ),
                  ),
                ),
                // ── From Products quick-fill ──────────────────────
                GestureDetector(
                  onTap: () => _pickProduct(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF0F4A75).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 13, color: _kPrimary),
                        SizedBox(width: 4),
                        Text(
                          'Products',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 8),
            // HSN / SAC code (optional)
            TextField(
              controller: row['hsn'],
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDecoration(s.hsnCodeLabel).copyWith(
                hintText: s.hsnCodeHint,
              ),
            ),
            const SizedBox(height: 12),
            // Qty / Unit / Price
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 360;

                final qtyField = TextFormField(
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
                );

                final unitField = DropdownButtonFormField<String>(
                  initialValue:
                      _normalizeItemUnit(row['unit']!.text),
                  isExpanded: true,
                  decoration: _inputDecoration(s.createUnitLabel),
                  items: _itemUnitOptions.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit,
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) {
                    row['unit']!.text =
                        _normalizeItemUnit(value);
                    setState(() {});
                  },
                );

                final priceField = TextFormField(
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
                );

                if (isCompact) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
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
    );
  }

  // ── GST section ───────────────────────────────────────────────────────────

  Widget _buildGstSection(
      double taxableAmount, double cgst, double sgst, double igst) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('GST'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle row
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _gstEnabled
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 18,
                      color:
                          _gstEnabled ? _kPrimary : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Apply GST',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kTitle),
                        ),
                        Text(
                          _gstEnabled
                              ? 'GST is included in grand total'
                              : 'Tap to enable GST on this invoice',
                          style: const TextStyle(
                              fontSize: 12, color: _kLabel),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _gstEnabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: _kPrimary,
                    onChanged: (v) => setState(() => _gstEnabled = v),
                  ),
                ],
              ),
              if (_gstEnabled) ...[
                const SizedBox(height: 14),
                Container(
                    height: 1, color: const Color(0xFFEFF6FF)),
                const SizedBox(height: 14),
                // Rate selector
                const Text(
                  'GST RATE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kLabel,
                      letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5.0, 12.0, 18.0, 28.0].map((rate) {
                    final selected = _gstRate == rate;
                    return GestureDetector(
                      onTap: () => setState(() => _gstRate = rate),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? _kPrimary
                              : const Color(0xFFF5F8FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? _kPrimary
                                : const Color(0xFFBDD5F0),
                          ),
                        ),
                        child: Text(
                          '${rate.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF374151),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                // Type selector
                const Text(
                  'GST TYPE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kLabel,
                      letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _GstTypeChip(
                      label: 'CGST + SGST',
                      subtitle: 'Intrastate',
                      selected: _gstType == 'cgst_sgst',
                      onTap: () =>
                          setState(() => _gstType = 'cgst_sgst'),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (_gstType == 'cgst_sgst') ...[
                        _taxPreviewRow(
                            'CGST (${(_gstRate / 2).toStringAsFixed(1)}%)',
                            _currencyFormat.format(cgst)),
                        const SizedBox(height: 4),
                        _taxPreviewRow(
                            'SGST (${(_gstRate / 2).toStringAsFixed(1)}%)',
                            _currencyFormat.format(sgst)),
                      ] else
                        _taxPreviewRow(
                            'IGST (${_gstRate.toStringAsFixed(0)}%)',
                            _currencyFormat.format(igst)),
                    ],
                  ),
                ),
              ],
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
              style: const TextStyle(
                  fontSize: 13, color: _kLabel, fontWeight: FontWeight.w500)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: _kTitle,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFE8F4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBDD5F0), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x0E0F4A75), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _summaryRow(
            s.createSummarySubtotal,
            _currencyFormat.format(subtotal),
            isTotal: false,
          ),
          if (discountAmount > 0) ...[
            const SizedBox(height: 6),
            _summaryRow(
              s.createSummaryDiscount,
              '-${_currencyFormat.format(discountAmount)}',
              valueColor: const Color(0xFFEF4444),
              isTotal: false,
            ),
          ],
          if (_gstEnabled && totalTax > 0) ...[
            const SizedBox(height: 6),
            if (_gstType == 'cgst_sgst') ...[
              _summaryRow(
                'CGST (${(_gstRate / 2).toStringAsFixed(1)}%)',
                '+${_currencyFormat.format(cgst)}',
                valueColor: const Color(0xFF059669),
                isTotal: false,
              ),
              const SizedBox(height: 4),
              _summaryRow(
                'SGST (${(_gstRate / 2).toStringAsFixed(1)}%)',
                '+${_currencyFormat.format(sgst)}',
                valueColor: const Color(0xFF059669),
                isTotal: false,
              ),
            ] else
              _summaryRow(
                'IGST (${_gstRate.toStringAsFixed(0)}%)',
                '+${_currencyFormat.format(igst)}',
                valueColor: const Color(0xFF059669),
                isTotal: false,
              ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFBDD5F0), height: 1),
          ),
          _summaryRow(
            s.createSummaryGrandTotal,
            _currencyFormat.format(grandTotal),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? valueColor,
    required bool isTotal,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight:
                isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? _kTitle : _kLabel,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? (isTotal ? _kPrimary : _kTitle),
          ),
        ),
      ],
    );
  }

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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(error: hasError),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  selectedClient?.initials ?? '+',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedClient?.name ??
                          s.createSelectCustomer,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: selectedClient == null
                            ? _kLabel
                            : _kTitle,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selectedClient == null
                          ? s.createCustomerHint
                          : selectedClient.subtitle,
                      style: const TextStyle(
                        color: _kLabel,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_selectedClient != null &&
            _selectedClient!.gstin.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBDD5F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 14, color: _kPrimary),
                const SizedBox(width: 6),
                Text(
                  '${s.customerGstinLabel}: ${_selectedClient!.gstin}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final shouldStackButtons = constraints.maxWidth < 360;

            final pickButton = OutlinedButton.icon(
              onPressed: _pickCustomer,
              icon: const Icon(Icons.groups_2_outlined, size: 18),
              label: Text(
                selectedClient == null
                    ? s.createPickCustomer
                    : s.createChangeCustomer,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary,
                side: const BorderSide(color: _kPrimary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );

            final addButton = ElevatedButton.icon(
              onPressed: _addCustomer,
              icon: const Icon(Icons.person_add_alt_1_rounded,
                  size: 18),
              label: Text(
                s.createAddNew,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: _kPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );

            if (shouldStackButtons) {
              return Column(
                children: [
                  SizedBox(width: double.infinity, child: pickButton),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: addButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: pickButton),
                const SizedBox(width: 10),
                Expanded(child: addButton),
              ],
            );
          },
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              s.createCustomerRequired,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  // ── Logic (unchanged) ─────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
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
      // Auto-enable GST and set rate if product has GST configured
      if (product.gstApplicable) {
        _gstEnabled = true;
        _gstRate = product.gstRate;
      }
    });
  }

  void _addItemRow() {
    setState(() {
      itemRows.add(_createItemRowControllers());
    });
  }

  void _removeItemRow(int index) {
    final row = itemRows[index];
    setState(() {
      itemRows.removeAt(index);
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

    if (selectedDate == null) {
      setState(() {});
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

    final invoiceDate = selectedDate!;
    final dueDate = invoiceDate.add(_defaultPaymentTerm);

    final items = itemRows.map((row) {
      return LineItem(
        description: row['desc']!.text.trim(),
        hsnCode: row['hsn']!.text.trim(),
        quantity: nu.parseDouble(row['qty']!.text.trim()) ?? 0,
        unitPrice:
            nu.parseDouble(row['price']!.text.trim()) ?? 0,
        unit: _normalizeItemUnit(row['unit']!.text),
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

  String _normalizeItemUnit(String? unit) {
    final normalized = unit?.trim().toLowerCase() ?? '';
    if (_itemUnitOptions.contains(normalized)) {
      return normalized;
    }

    return _defaultItemUnit;
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
          color: isSelected ? selectedBg : const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedBorder : const Color(0xFFBDD5F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? selectedText : _kLabel,
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
            color: selected ? _kPrimary : const Color(0xFFF5F8FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _kPrimary : const Color(0xFFBDD5F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _kTitle,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : _kLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
