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
import 'package:billeasy/widgets/limit_reached_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Brand tokens ────────────────────────────────────────────────────────────
const _kPrimary     = Color(0xFF4361EE);
const _kBackground  = Color(0xFFEFF6FF);
const _kBorder      = Color(0xFFBDD5F0);
const _kLabel       = Color(0xFF5B7A9A);
const _kTitle       = Color(0xFF1E3A8A);

const _kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1E3A8A), Color(0xFF4361EE), Color(0xFF6366F1)],
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFBDD5F0))),
          boxShadow: [BoxShadow(color: Color(0x120F4A75), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 11, color: Color(0xFF5B7A9A))),
                  Text(
                    _currencyFormat.format(grandTotal),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _isSaving ? null : const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF6366F1)],
                      ),
                      color: _isSaving ? const Color(0xFF5B7A9A) : null,
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
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // ── Customer ──────────────────────────────────────────────
              _buildCustomerSection(context),
              const SizedBox(height: 16),

              // ── Invoice Date ──────────────────────────────────────────
              _sectionLabel(s.createInvoiceDate, step: 2),
              _buildDateCard(context, s),
              const SizedBox(height: 16),

              // ── Section label – Items ─────────────────────────────────
              _sectionLabel('Items', step: 3),

              // ── Item rows ─────────────────────────────────────────────
              ...List.generate(itemRows.length, (index) {
                return _buildItemCard(context, index, s);
              }),

              // ── Add item button ───────────────────────────────────────
              GestureDetector(
                onTap: _addItemRow,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF4361EE), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_rounded, color: Color(0xFF4361EE), size: 20),
                      SizedBox(width: 8),
                      Text('Add Item', style: TextStyle(color: Color(0xFF4361EE), fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Status ────────────────────────────────────────────────
              _sectionLabel(s.createInvoiceStatus, step: 4),
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
              _sectionLabel(s.createDiscountTitle, step: 5),
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
              gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF6366F1)]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
        ] else ...[
          Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFF4361EE), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
        ],
        Text(text, style: const TextStyle(color: Color(0xFF1E3A8A), fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  // ── Date card ─────────────────────────────────────────────────────────────

  Widget _buildDateCard(BuildContext context, AppStrings s) {
    final dayName = DateFormat('EEEE').format(selectedDate);
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF4361EE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('dd').format(selectedDate),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1),
                  ),
                  Text(
                    DateFormat('MMM').format(selectedDate).toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.createInvoiceDate,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5B7A9A)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('dd MMM yyyy').format(selectedDate),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                  ),
                  Text(
                    dayName,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5B7A9A)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4361EE))),
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // Main card
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBDD5F0), width: 1.2),
              boxShadow: const [BoxShadow(color: Color(0x0E0F4A75), blurRadius: 16, offset: Offset(0, 4))],
            ),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
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
                              color: const Color(0xFF4361EE).withValues(alpha: 0.3)),
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
                // Live total row
                if (rowTotal > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Line total: ${_currencyFormat.format(rowTotal)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
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
          // Left accent bar
          Positioned(
            left: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF6366F1)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── GST section ───────────────────────────────────────────────────────────

  Widget _buildGstSection(
      double taxableAmount, double cgst, double sgst, double igst) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('GST', step: 6),
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF4361EE), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x300B234F), blurRadius: 20, offset: Offset(0, 8))],
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
                _summaryRowWhite('CGST (${(_gstRate / 2).toStringAsFixed(1)}%)', '+${_currencyFormat.format(cgst)}', valueColor: const Color(0xFF86EFAC)),
                const SizedBox(height: 6),
                _summaryRowWhite('SGST (${(_gstRate / 2).toStringAsFixed(1)}%)', '+${_currencyFormat.format(sgst)}', valueColor: const Color(0xFF86EFAC)),
              ] else
                _summaryRowWhite('IGST (${_gstRate.toStringAsFixed(0)}%)', '+${_currencyFormat.format(igst)}', valueColor: const Color(0xFF86EFAC)),
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
        _sectionLabel(s.createCustomerLabel, step: 1),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: selectedClient != null
                ? Border.all(color: const Color(0xFF6366F1), width: 1.5)
                : Border.all(color: hasError ? const Color(0xFFEF4444) : const Color(0xFFBDD5F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: hasError ? const Color(0x10EF4444) : const Color(0x0E0F4A75),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: _pickCustomer,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: selectedClient != null
                        ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                        : const Color(0xFFEFF6FF),
                    child: Text(
                      selectedClient?.initials ?? '+',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: selectedClient != null ? const Color(0xFF6366F1) : const Color(0xFF4361EE),
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedClient?.name ?? s.createSelectCustomer,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: selectedClient != null ? const Color(0xFF1E3A8A) : const Color(0xFF5B7A9A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selectedClient == null ? s.createCustomerHint : selectedClient.subtitle,
                          style: const TextStyle(color: Color(0xFF5B7A9A), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selectedClient != null ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                    color: selectedClient != null ? const Color(0xFF6366F1) : const Color(0xFF5B7A9A),
                  ),
                ],
              ),
            ),
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
