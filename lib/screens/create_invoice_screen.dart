import 'dart:async';
import 'package:flutter/services.dart';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/product.dart';
import 'package:billeasy/utils/number_utils.dart' as nu;
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/line_item.dart';
import 'package:billeasy/modals/stock_movement.dart';
import 'package:billeasy/screens/customer_form_screen.dart';
import 'package:billeasy/screens/customers_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/screens/products_screen.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/product_service.dart';
import 'package:billeasy/services/inventory_service.dart';
import 'package:billeasy/services/invoice_number_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/usage_tracking_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/limit_reached_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key, this.initialClient, this.editingInvoice});

  final Client? initialClient;
  final Invoice? editingInvoice;

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
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _receivedController = TextEditingController();

  // Customer autocomplete state
  List<Client> _customerSuggestions = [];
  bool _showCustomerSuggestions = false;
  StreamSubscription<List<Client>>? _clientSearchSub;
  final FocusNode _customerNameFocus = FocusNode();
  final LayerLink _customerLayerLink = LayerLink();
  OverlayEntry? _customerOverlay;

  // Product auto-save debounce
  Timer? _productAutoSaveTimer;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  DateTime selectedDate = DateTime.now();
  Client? _selectedClient;
  bool _isSaving = false;
  // Pre-reserved invoice number — fetched in background on screen open
  Future<String>? _preReservedNumber;
  bool _showClientValidationError = false;
  bool _pulseButtons = false;
  InvoiceDiscountType _selectedDiscountType = InvoiceDiscountType.percentage;
  late List<Map<String, TextEditingController>> itemRows;
  final List<FocusNode> _itemDescFocusNodes = [];
  final List<FocusNode> _itemQtyFocusNodes = [];

  // GST state
  bool _gstEnabled = false;
  double _gstRate = 18.0;
  String _gstType = 'cgst_sgst'; // 'cgst_sgst' or 'igst'

  // UX: collapsible sections
  late List<bool> _showAdvanced;
  late List<bool> _itemConfirmed;
  bool _showDiscountSection = false;
  bool _showGstSection = false;
  bool _showSettingsSection = false;
  bool _showCustomerFields = true;

  bool get _isEditing => widget.editingInvoice != null;

  @override
  void initState() {
    super.initState();
    _selectedClient = widget.initialClient;
    if (widget.initialClient != null) {
      _customerNameController.text = widget.initialClient!.name;
      _customerPhoneController.text = widget.initialClient!.phone;
    }
    _customerNameController.addListener(_onCustomerNameChanged);
    _customerNameFocus.addListener(_onCustomerNameFocusChanged);
    itemRows = [];
    _showAdvanced = [];
    _itemConfirmed = [];

    final editInv = widget.editingInvoice;
    if (editInv != null) {
      _customerNameController.text = editInv.clientName;
      selectedDate = editInv.createdAt;
      _gstEnabled = editInv.gstEnabled;
      _gstRate = editInv.gstRate;
      _gstType = editInv.gstType;
      if (editInv.discountValue > 0) {
        _discountController.text = editInv.discountValue.toString();
        _showDiscountSection = true;
      }
      if (editInv.discountType != null) {
        _selectedDiscountType = editInv.discountType!;
      }
      if (_gstEnabled) _showGstSection = true;
      if (editInv.amountReceived > 0) {
        _receivedController.text = editInv.amountReceived.toString();
      }

      // Pre-fill item rows from invoice
      for (final item in editInv.items) {
        final row = _createItemRowControllers();
        row['desc']!.text = item.description;
        row['qty']!.text = LineItem.formatQuantity(item.quantity);
        row['price']!.text = item.unitPrice.toString();
        row['unit']!.text = item.unit;
        row['hsn']!.text = item.hsnCode;
        row['gstRate']!.text = item.gstRate.toStringAsFixed(0);
        row['discount']!.text = item.discountPercent > 0 ? item.discountPercent.toString() : '';
        row['productId']!.text = item.productId;
        itemRows.add(row);
        _showAdvanced.add(false);
        _itemConfirmed.add(true);
        _itemDescFocusNodes.add(FocusNode());
        _itemQtyFocusNodes.add(FocusNode());
      }

      // Resolve client
      if (editInv.clientId.isNotEmpty) {
        _selectedClient = Client(id: editInv.clientId, name: editInv.clientName);
      }
    } else {
      _loadLastUsedGstSettings();
    }

    if (widget.initialClient == null && editInv == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _customerNameFocus.requestFocus();
      });
    }

    // Pre-reserve invoice number in background (new invoices only)
    if (!_isEditing) {
      _preReservedNumber = InvoiceNumberService()
          .reserveNextInvoiceNumber(year: DateTime.now().year);
    }
  }

  void _loadLastUsedGstSettings() {
    // Fire-and-forget — screen renders instantly, settings update in background
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _gstRate = prefs.getDouble('last_gst_rate') ?? 18.0;
        _gstType = prefs.getString('last_gst_type') ?? 'cgst_sgst';
        _showGstSection = _gstEnabled;
      });
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
    _receivedController.dispose();
    _customerNameController.removeListener(_onCustomerNameChanged);
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerNameFocus.removeListener(_onCustomerNameFocusChanged);
    _customerNameFocus.dispose();
    _clientSearchSub?.cancel();
    _productAutoSaveTimer?.cancel();
    _removeCustomerOverlay();
    for (final row in itemRows) {
      _disposeRowControllers(row);
    }
    for (final fn in _itemDescFocusNodes) { fn.dispose(); }
    for (final fn in _itemQtyFocusNodes) { fn.dispose(); }
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
    // ── Currency rounding helper ──
    double rc(num v) => (v * 100).roundToDouble() / 100;

    // ── Live calculations ──
    double rawTotal = 0; // qty × price, no discounts
    double totalItemDiscount = 0; // sum of per-item discounts
    double cgstAmount = 0;
    double igstAmount = 0;
    int totalQty = 0;

    for (final row in itemRows) {
      final qty = nu.parseDouble(row['qty']!.text) ?? 0;
      final price = nu.parseDouble(row['price']!.text) ?? 0;
      final discPct = (nu.parseDouble(row['discount']?.text ?? '') ?? 0).clamp(0, 100);
      final itemRate = nu.parseDouble(row['gstRate']!.text) ?? _gstRate;
      final lineTotal = rc(qty * price);
      final lineDiscount = rc(lineTotal * discPct / 100);
      final itemTotal = rc(lineTotal - lineDiscount);

      rawTotal += lineTotal;
      totalItemDiscount += lineDiscount;
      if (qty > 0) totalQty += 1;

      if (_gstEnabled) {
        if (_gstType == 'cgst_sgst') {
          cgstAmount += rc(itemTotal * itemRate / 200);
        } else {
          igstAmount += rc(itemTotal * itemRate / 100);
        }
      }
    }

    rawTotal = rc(rawTotal);
    totalItemDiscount = rc(totalItemDiscount);
    cgstAmount = rc(cgstAmount);
    igstAmount = rc(igstAmount);
    final subtotal = rc(rawTotal - totalItemDiscount);
    final discountAmount = rc(_calculateDiscountAmount(subtotal));
    final taxableAmount = rc(subtotal - discountAmount);
    final totalDiscount = rc(totalItemDiscount + discountAmount);
    final sgstAmount = cgstAmount;
    final totalTax = rc(cgstAmount + sgstAmount + igstAmount);
    final grandTotal = rc(taxableAmount + totalTax);
    final amountReceived = (nu.parseDouble(_receivedController.text) ?? 0).clamp(0.0, double.infinity);
    final double balanceDue = rc((grandTotal - amountReceived).clamp(0.0, double.infinity));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kOnSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
        title: Text(
          _isEditing ? 'Edit Invoice' : s.createTitle,
          style: const TextStyle(
            color: kOnSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: const [],
      ),
      bottomNavigationBar: _buildSaveBar(),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Whole page scrollable ────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    // ── Customer details card ──
                    if (itemRows.isEmpty || _showCustomerFields)
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE0E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildInvoiceNoDateRow(s),
                            const Divider(height: 16, color: Color(0xFFEAEFF1)),
                            _buildCustomerSection(context),
                            const SizedBox(height: 10),
                            _buildPhoneField(),
                            if (itemRows.isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: TextButton.icon(
                                    onPressed: () => setState(() => _showCustomerFields = false),
                                    icon: const Icon(Icons.check_circle, size: 16),
                                    label: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF1565C0),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      // ── Collapsed customer card — clean Vyapar style ──
                      GestureDetector(
                        onTap: () => setState(() => _showCustomerFields = true),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE0E8F0)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Avatar circle
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.person, size: 18, color: Color(0xFF1565C0)),
                              ),
                              const SizedBox(width: 12),
                              // Name + phone
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _customerNameController.text.trim().isEmpty ? 'Customer' : _customerNameController.text.trim(),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kOnSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_customerPhoneController.text.trim().isNotEmpty)
                                      Text(
                                        _customerPhoneController.text.trim(),
                                        style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant),
                                      ),
                                  ],
                                ),
                              ),
                              // Date + invoice
                              Text(
                                DateFormat('dd MMM yyyy').format(selectedDate),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kOnSurfaceVariant),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF90A4AE)),
                            ],
                          ),
                        ),
                      ),
                    // ── Billed Items header ──
                    if (itemRows.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF42A5F5),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text('Billed Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                            const Spacer(),
                            Text('${itemRows.length} items', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                      ),
                    // ── Item cards — scrollable box that also moves outer page ──
                    if (itemRows.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                          borderRadius: BorderRadius.circular(0),
                        ),
                        constraints: BoxConstraints(
                          maxHeight: itemRows.length <= 2
                              ? double.infinity // show all for 1-2 items
                              : MediaQuery.of(context).size.height * 0.35,
                        ),
                        child: itemRows.length <= 2
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int i = 0; i < itemRows.length; i++)
                                    _buildItemCard(context, i, s),
                                ],
                              )
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: itemRows.length,
                                itemBuilder: (context, i) => _buildItemCard(context, i, s),
                              ),
                      ),
                    // ── Summary + Add Items (card bottom) ──
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFB),
                        borderRadius: itemRows.isEmpty
                            ? BorderRadius.circular(8)
                            : const BorderRadius.vertical(bottom: Radius.circular(8)),
                        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (itemRows.isNotEmpty) ...[
                            Row(
                              children: [
                                Expanded(child: _summaryChip('Total Disc: ${_currencyFormat.format(totalDiscount)}', const Color(0xFFE65100))),
                                const SizedBox(width: 8),
                                Expanded(child: _summaryChip('Total Tax Amt: ${_currencyFormat.format(totalTax)}', const Color(0xFF2E7D32))),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(child: _summaryChip('Total Qty: ${itemRows.length}', const Color(0xFF546E7A))),
                                const SizedBox(width: 8),
                                Expanded(child: _summaryChip('Subtotal: ${_currencyFormat.format(subtotal)}', kOnSurface)),
                              ],
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
                            child: _buildAddItemButtons(),
                          ),
                        ],
                      ),
                    ),
                    // ── Total Amount / Received / Balance Due ──
                    if (itemRows.isNotEmpty)
                      _buildPinnedTotalStrip(grandTotal, amountReceived, balanceDue),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Khata-style Total Section ──
  bool _isReceived = false;

  Widget _buildPinnedTotalStrip(double grandTotal, double amountReceived, double balanceDue) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Total Amount row ──
          Row(
            children: [
              const Text('Total Amount', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kOnSurface)),
              const Spacer(),
              const Text('\u20b9', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kOnSurfaceVariant)),
              const SizedBox(width: 8),
              Text(
                _currencyFormat.format(grandTotal),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kOnSurface),
              ),
            ],
          ),
          // Dashed divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dashCount = (constraints.maxWidth / 8).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(dashCount, (_) =>
                    const SizedBox(width: 4, height: 1, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFBDBDBD)))),
                  ),
                );
              },
            ),
          ),
          // ── Received row with checkbox ──
          Row(
            children: [
              SizedBox(
                width: 22, height: 22,
                child: Checkbox(
                  value: _isReceived,
                  onChanged: (v) {
                    setState(() {
                      _isReceived = v ?? false;
                      if (_isReceived) {
                        // Only auto-fill full amount if field is empty/zero
                        final current = nu.parseDouble(_receivedController.text) ?? 0;
                        if (current <= 0) {
                          _receivedController.text = grandTotal.toStringAsFixed(2);
                        }
                      } else {
                        _receivedController.clear();
                      }
                    });
                  },
                  activeColor: const Color(0xFF1565C0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Received', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kOnSurface)),
              const Spacer(),
              const Text('\u20b9', style: TextStyle(fontSize: 13, color: kOnSurfaceVariant)),
              const SizedBox(width: 6),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _receivedController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      final amt = double.tryParse(val) ?? 0;
                      _isReceived = amt >= grandTotal;
                    });
                  },
                ),
              ),
            ],
          ),
          // Dashed divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dashCount = (constraints.maxWidth / 8).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(dashCount, (_) =>
                    const SizedBox(width: 4, height: 1, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFBDBDBD)))),
                  ),
                );
              },
            ),
          ),
          // ── Balance Due row ──
          Row(
            children: [
              Text(
                balanceDue <= 0 ? 'Paid' : balanceDue < grandTotal ? 'Balance Due' : 'Balance Due',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: balanceDue <= 0
                      ? const Color(0xFF2E7D32)
                      : balanceDue < grandTotal
                          ? const Color(0xFFF57F17)
                          : const Color(0xFFD32F2F),
                ),
              ),
              const Spacer(),
              const Text('\u20b9', style: TextStyle(fontSize: 14, color: kOnSurfaceVariant)),
              const SizedBox(width: 8),
              Text(
                _currencyFormat.format(balanceDue),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: balanceDue <= 0
                      ? const Color(0xFF2E7D32)
                      : balanceDue < grandTotal
                          ? const Color(0xFFF57F17)
                          : const Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
          // ── Payment status badge ──
          if (amountReceived > 0 && balanceDue > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Partially Paid (\u20b9${_currencyFormat.format(amountReceived)} received)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF57F17)),
                ),
              ),
            ),
          if (balanceDue <= 0 && grandTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Fully Paid',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Pinned Save bar ──────────────────────────────────────────────────────

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveInvoice,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 20),
            label: Text(_isEditing ? 'Update' : 'Save & Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              disabledBackgroundColor: kSurfaceDim,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  // ── Vyapar-style total section (scrollable) ────────────────────────────

  Widget _dashedLine() {
    return LayoutBuilder(builder: (context, constraints) {
      const dashWidth = 4.0;
      const dashSpace = 3.0;
      final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(count, (_) => Container(
          width: dashWidth, height: 1,
          margin: const EdgeInsets.only(left: dashSpace),
          color: const Color(0xFFBDBDBD),
        )),
      );
    });
  }

  Widget _vyaparRow(String label, String value, {Color? valueColor, bool bold = false, double fontSize = 15}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? kOnSurface : const Color(0xFF546E7A),
          )),
          const SizedBox(width: 16),
          const Text('₹', style: TextStyle(fontSize: 15, color: Color(0xFF546E7A))),
          const SizedBox(width: 4),
          Expanded(child: _dashedLine()),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? kOnSurface,
          )),
        ],
      ),
    );
  }

  // ── Invoice No. + Date row ────────────────────────────────────────────────

  Widget _summaryChip(String text, Color color) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color));
  }

  Widget _buildInvoiceNoDateRow(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Invoice No.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice No.',
                  style: TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Auto',
                      style: const TextStyle(fontSize: 15, color: kOnSurface, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 18, color: kOnSurfaceVariant),
                  ],
                ),
              ],
            ),
          ),
          // Vertical divider
          Container(width: 1, height: 36, color: const Color(0xFFDDE3E6)),
          const SizedBox(width: 16),
          // Date
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date',
                    style: TextStyle(fontSize: 12, color: kOnSurfaceVariant, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                        style: const TextStyle(fontSize: 15, color: kOnSurface, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 18, color: kOnSurfaceVariant),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phone field (editable) ───────────────────────────────────────────────

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _customerPhoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        labelStyle: const TextStyle(fontSize: 14, color: kTextTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1565C0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1565C0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
      style: const TextStyle(fontSize: 14, color: kOnSurface),
    );
  }

  // ── Customer section ──────────────────────────────────────────────────────

  Widget _buildCustomerSection(BuildContext context) {
    final s = AppStrings.of(context);
    final hasError =
        _showClientValidationError && _customerNameController.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _customerLayerLink,
          child: TextFormField(
            controller: _customerNameController,
            focusNode: _customerNameFocus,
            decoration: InputDecoration(
              labelText: '${s.createCustomerLabel} *',
              hintText: 'Customer name',
              hintStyle: const TextStyle(fontSize: 14, color: kTextTertiary, fontWeight: FontWeight.w400),
              labelStyle: TextStyle(
                fontSize: 14,
                color: hasError ? const Color(0xFFEF4444) : kTextTertiary,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasError ? const Color(0xFFEF4444) : const Color(0xFF1565C0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasError ? const Color(0xFFEF4444) : const Color(0xFF1565C0),
                  width: hasError ? 1.5 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kPrimary, width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 14, color: kOnSurface),
            onChanged: (_) {
              if (_showClientValidationError) {
                setState(() => _showClientValidationError = false);
              }
            },
          ),
        ),
        if (hasError)
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 4),
            child: Text('Customer name is required', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
          ),
      ],
    );
  }

  // ── Vyapar-style item card ──────────────────────────────────────────────────

  Widget _buildConfirmedItemCard(int index, AppStrings s) {
    final row = itemRows[index];
    final name = row['desc']!.text.trim();
    final qty = nu.parseDouble(row['qty']!.text) ?? 0;
    final price = nu.parseDouble(row['price']!.text) ?? 0;
    final unit = row['unit']!.text.trim().isEmpty ? _defaultItemUnit : row['unit']!.text.trim();
    final itemDiscountPct = (nu.parseDouble(row['discount']?.text ?? '') ?? 0).clamp(0, 100);
    final rawTotal = qty * price;
    final discAmt = rawTotal * itemDiscountPct / 100;
    final total = rawTotal - discAmt;
    final gstRate = nu.parseDouble(row['gstRate']!.text) ?? 0;
    final qtyStr = qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();

    return GestureDetector(
      onTap: () => _editItem(index),
      onLongPress: () => _removeItemRow(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8ECF0), width: 0.8),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: #index  Name                    ₹ total
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('#${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kOnSurface), overflow: TextOverflow.ellipsis),
                ),
                Text(_currencyFormat.format(total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kOnSurface)),
              ],
            ),
            const SizedBox(height: 4),
            // Row 2: Item Subtotal    qty Unit x price = rawTotal
            Row(
              children: [
                const Text('Item Subtotal', style: TextStyle(fontSize: 12, color: kOnSurfaceVariant)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$qtyStr $unit x ${price.toStringAsFixed(0)} = ${_currencyFormat.format(rawTotal)}',
                      style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant),
                      textAlign: TextAlign.end, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            // Row 3: Discount (if any)
            if (itemDiscountPct > 0) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  Text('Discount (%): ${itemDiscountPct.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFE65100))),
                  const Spacer(),
                  Text(_currencyFormat.format(discAmt),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100))),
                ],
              ),
            ],
            // Row 4: Tax (only if GST is enabled and rate > 0)
            if (_gstEnabled && gstRate > 0) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  Text('Tax : ${gstRate.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant)),
                  const Spacer(),
                  Text(_currencyFormat.format(total * gstRate / 100),
                      style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Item card ─────────────────────────────────────────────────────────────

  Widget _buildItemCard(
      BuildContext context, int index, AppStrings s) {
    // All items show as confirmed cards — editing happens in bottom sheet
    return _buildConfirmedItemCard(index, s);
  }




  // ── Add Item button ──────────────────────────────────────────────────────

  Widget _buildAddItemButtons() {
    return GestureDetector(
      onTap: _addItemRow,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE3E6)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, color: Color(0xFF43A047), size: 20),
            SizedBox(width: 6),
            Text('Add Items', style: TextStyle(color: Color(0xFF43A047), fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }


  // ── Summary card ──────────────────────────────────────────────────────────



  // ── Customer autocomplete helpers ──────────────────────────────────────────

  void _onCustomerNameChanged() {
    final query = _customerNameController.text.trim();
    // If user edits the name after selecting a client, detach the client
    if (_selectedClient != null && query != _selectedClient!.name) {
      _selectedClient = null;
    }
    _showClientValidationError = false;

    _clientSearchSub?.cancel();
    if (query.isEmpty) {
      _removeCustomerOverlay();
      setState(() {
        _customerSuggestions = [];
        _showCustomerSuggestions = false;
      });
      return;
    }

    _clientSearchSub = ClientService()
        .getClientsStream(searchQuery: query, limit: 5)
        .listen((clients) {
      if (!mounted) return;
      setState(() {
        _customerSuggestions = clients;
        _showCustomerSuggestions = clients.isNotEmpty && _customerNameFocus.hasFocus;
      });
      if (_showCustomerSuggestions) {
        _showCustomerOverlay();
      } else {
        _removeCustomerOverlay();
      }
    });
  }

  void _onCustomerNameFocusChanged() {
    if (!_customerNameFocus.hasFocus) {
      // Small delay so tap on suggestion registers before overlay is removed
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _removeCustomerOverlay();
      });
    } else if (_customerSuggestions.isNotEmpty) {
      _showCustomerOverlay();
    }
  }

  void _showCustomerOverlay() {
    _removeCustomerOverlay();
    final overlay = Overlay.of(context);
    _customerOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 64, // match card padding
        child: CompositedTransformFollower(
          link: _customerLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _customerSuggestions.length,
                itemBuilder: (context, index) {
                  final client = _customerSuggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      client.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: client.phone.isNotEmpty
                        ? Text(client.phone, style: const TextStyle(fontSize: 12))
                        : null,
                    onTap: () => _selectSuggestion(client),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_customerOverlay!);
  }

  void _removeCustomerOverlay() {
    _customerOverlay?.remove();
    _customerOverlay = null;
  }

  void _selectSuggestion(Client client) {
    _removeCustomerOverlay();
    setState(() {
      _selectedClient = client;
      _customerNameController.text = client.name;
      _customerPhoneController.text = client.phone;
      _showCustomerSuggestions = false;
      _showClientValidationError = false;
    });
    _customerNameFocus.unfocus();
  }

  // ── Logic ──────────────────────────────────────────────────────────────────

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

  Future<void> _pickPhoneContact() async {
    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;

      // Get full details
      Contact? fullContact;
      if (await FlutterContacts.requestPermission()) {
        fullContact = await FlutterContacts.getContact(contact.id,
            withProperties: true, withAccounts: false, withPhoto: false);
      }
      if (!mounted) return;

      final source = fullContact ?? contact;
      final phone = source.phones.isNotEmpty
          ? source.phones.first.number.replaceAll(RegExp(r'[\s\-()]'), '')
          : '';

      setState(() {
        _customerNameController.text = source.displayName;
        _customerPhoneController.text = phone;
        _selectedClient = null; // typed-in, not a saved client
        _showClientValidationError = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access contacts: $e')),
      );
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
      _customerNameController.text = selectedClient.name;
      _customerPhoneController.text = selectedClient.phone;
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
      _customerNameController.text = savedClient.name;
      _customerPhoneController.text = savedClient.phone;
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
      row['productId']!.text = product.id;
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
    // Focus on quantity field after product selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowIndex < _itemQtyFocusNodes.length) {
        _itemQtyFocusNodes[rowIndex].requestFocus();
      }
    });
  }

  void _addItemRow() {
    _openItemPage();
  }

  void _removeItemRow(int index) {
    final row = itemRows[index];
    setState(() {
      itemRows.removeAt(index);
      _showAdvanced.removeAt(index);
      _itemConfirmed.removeAt(index);
      if (index < _itemDescFocusNodes.length) {
        _itemDescFocusNodes[index].dispose();
        _itemDescFocusNodes.removeAt(index);
      }
      if (index < _itemQtyFocusNodes.length) {
        _itemQtyFocusNodes[index].dispose();
        _itemQtyFocusNodes.removeAt(index);
      }
      _disposeRowControllers(row);
    });
  }

  void _confirmItem(int index) {
    final row = itemRows[index];
    final name = row['desc']!.text.trim();
    final price = nu.parseDouble(row['price']!.text.trim()) ?? 0;
    final qty = nu.parseDouble(row['qty']!.text.trim()) ?? 0;

    if (name.isEmpty || price <= 0 || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill item name, quantity and price')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _itemConfirmed[index] = true;
    });
    _autoSaveRowAsProduct(row);
  }

  void _editItem(int index) {
    _openItemPage(index);
  }

  /// Opens the Add/Edit item as a full page. If [index] is null, adds a new item.
  Future<void> _openItemPage([int? index]) async {
    final isNew = index == null;
    if (isNew) {
      final focusNode = FocusNode();
      final qtyFocusNode = FocusNode();
      itemRows.add(_createItemRowControllers());
      _showAdvanced.add(false);
      _itemConfirmed.add(true);
      _itemDescFocusNodes.add(focusNode);
      _itemQtyFocusNodes.add(qtyFocusNode);
      index = itemRows.length - 1;
    }

    final row = itemRows[index!];
    final s = AppStrings.of(context);

    final confirmed = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _ItemFormPage(
          row: row,
          index: index!,
          itemUnitOptions: _itemUnitOptions,
          defaultItemUnit: _defaultItemUnit,
          customUnitValue: _customUnitValue,
          gstRate: _gstRate,
          currencyFormat: _currencyFormat,
          s: s,
          // Product picking is handled inside _ItemFormPage directly
        ),
        transitionsBuilder: (_, anim, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: FadeTransition(opacity: anim, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    );

    // Unfocus everything after navigation settles — prevent phone field from stealing focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });

    if (confirmed == true) {
      // Auto-enable GST if the item has a GST rate set
      final itemGstRate = nu.parseDouble(row['gstRate']!.text) ?? 0;
      setState(() {
        _itemConfirmed[index!] = true;
        _pulseButtons = true;
        _showCustomerFields = false;
        if (itemGstRate > 0) _gstEnabled = true;
      });
      _autoSaveRowAsProduct(row);
      // Stop pulse after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _pulseButtons = false);
      });
    } else if (isNew) {
      _removeItemRow(index);
    } else {
      setState(() {}); // refresh card with any changes
    }
  }

  Map<String, TextEditingController> _createItemRowControllers() {
    return {
      'desc': TextEditingController(),
      'hsn': TextEditingController(),
      'qty': TextEditingController(),
      'unit': TextEditingController(text: _defaultItemUnit),
      'price': TextEditingController(),
      'gstRate': TextEditingController(text: '0'),
      'discount': TextEditingController(),
      'productId': TextEditingController(), // tracks linked product for inventory
    };
  }

  void _disposeRowControllers(Map<String, TextEditingController> row) {
    for (final controller in row.values) {
      controller.dispose();
    }
  }

  /// Auto-saves a single item row as a product (skips if name already exists).
  Future<void> _autoSaveRowAsProduct(Map<String, TextEditingController> row) async {
    try {
      final name = row['desc']!.text.trim();
      if (name.isEmpty) return;
      final price = nu.parseDouble(row['price']!.text.trim()) ?? 0;
      if (price <= 0) return; // wait until price is filled

      final productService = ProductService();
      final existing = await productService
          .getProductsStream(searchQuery: name, limit: 5)
          .first;
      final alreadyExists = existing.any(
        (p) => p.name.trim().toLowerCase() == name.toLowerCase(),
      );
      if (alreadyExists) return;

      final unit = row['unit']!.text.trim().isEmpty
          ? _defaultItemUnit
          : row['unit']!.text.trim();
      final gstRate = nu.parseDouble(row['gstRate']!.text.trim()) ?? 0;

      await productService.saveProduct(Product(
        id: '',
        name: name,
        unitPrice: price,
        unit: unit,
        hsnCode: row['hsn']!.text.trim(),
        gstRate: gstRate,
        gstApplicable: gstRate > 0,
      ));
    } catch (_) {
      // Silent — don't block UI for auto-save failures
    }
  }

  double _calculateSubtotal() {
    var total = 0.0;

    for (final row in itemRows) {
      final qty = nu.parseDouble(row['qty']!.text) ?? 0;
      final price = nu.parseDouble(row['price']!.text) ?? 0;
      final discPct = (nu.parseDouble(row['discount']?.text ?? '') ?? 0).clamp(0, 100);
      final lineTotal = qty * price;
      total += lineTotal - (lineTotal * discPct / 100);
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

    final customerName = _customerNameController.text.trim();
    if (customerName.isEmpty) {
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
        gstRate: _clampGstRate(nu.parseDouble(row['gstRate']!.text.trim()) ?? _gstRate),
        discountPercent: (nu.parseDouble(row['discount']?.text ?? '') ?? 0).clamp(0, 100).toDouble(),
        productId: row['productId']!.text.trim(),
      );
    }).toList();
    final selectedClient = _selectedClient;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppStrings.of(context).createSignInRequired)),
      );
      return;
    }

    // ── Plan gate: check invoice limit (skip for edits) ──
    if (!_isEditing) {
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
    }

    setState(() {
      _isSaving = true;
    });

    // Auto-determine payment status (including GST)
    final received = (nu.parseDouble(_receivedController.text.trim()) ?? 0).clamp(0.0, double.infinity);
    final computedSubtotal = _calculateSubtotal();
    final computedDiscount = _calculateDiscountAmount(computedSubtotal);
    final computedTaxable = computedSubtotal - computedDiscount;
    // Recalculate tax for status check
    double computedTax = 0;
    if (_gstEnabled) {
      for (final row in itemRows) {
        final qty = nu.parseDouble(row['qty']!.text) ?? 0;
        final price = nu.parseDouble(row['price']!.text) ?? 0;
        final discPct = (nu.parseDouble(row['discount']?.text ?? '') ?? 0).clamp(0, 100);
        final itemRate = nu.parseDouble(row['gstRate']!.text) ?? _gstRate;
        final lineTotal = qty * price;
        final itemTotal = lineTotal - (lineTotal * discPct / 100);
        if (_gstType == 'cgst_sgst') {
          computedTax += itemTotal * itemRate / 100; // CGST + SGST
        } else {
          computedTax += itemTotal * itemRate / 100; // IGST
        }
      }
    }
    final computedGrand = ((computedTaxable + computedTax) * 100).roundToDouble() / 100;
    InvoiceStatus resolvedStatus;
    if (received >= computedGrand && computedGrand > 0) {
      resolvedStatus = InvoiceStatus.paid;
    } else if (received > 0) {
      resolvedStatus = InvoiceStatus.partiallyPaid;
    } else {
      resolvedStatus = InvoiceStatus.pending;
    }

    try {
      _saveLastUsedGstSettings(); // fire-and-forget

      // Run client save and invoice number reservation in parallel
      final clientFuture = (selectedClient == null && customerName.isNotEmpty)
          ? ClientService().saveClient(Client(
              id: '',
              name: customerName,
              phone: _customerPhoneController.text.trim(),
            ))
          : Future.value(selectedClient);

      var resolvedClient = await clientFuture;
      if (resolvedClient != null) _selectedClient = resolvedClient;

      String invoiceId;
      String invoiceNumber;

      if (_isEditing) {
        // Edit mode — update existing invoice, keep same number
        final editInv = widget.editingInvoice!;
        invoiceNumber = editInv.invoiceNumber;

        final updatedInvoice = Invoice(
          id: editInv.id,
          ownerId: editInv.ownerId,
          invoiceNumber: invoiceNumber,
          clientId: resolvedClient?.id ?? editInv.clientId,
          clientName: customerName,
          customerGstin: resolvedClient?.gstin ?? '',
          items: items,
          createdAt: editInv.createdAt,
          dueDate: dueDate,
          status: resolvedStatus,
          discountType:
              discountValue > 0 ? _selectedDiscountType : null,
          discountValue: discountValue > 0 ? discountValue : 0,
          gstEnabled: _gstEnabled,
          gstRate: _gstRate,
          gstType: _gstType,
          amountReceived: received,
        );

        await FirebaseService().updateInvoice(updatedInvoice);
        invoiceId = editInv.id;

        // Reverse old stock and deduct new stock on edit
        final inventoryService = InventoryService();
        // 1. Reverse old items
        for (final oldItem in editInv.items) {
          if (oldItem.productId.isNotEmpty) {
            await inventoryService.adjustStock(
              productId: oldItem.productId,
              productName: oldItem.description,
              quantity: oldItem.quantity, // positive = restore
              reason: 'Edit reversal: $invoiceNumber',
              unitPrice: oldItem.unitPrice,
              movementType: StockMovementType.manualIn,
              referenceId: invoiceId,
              referenceNumber: invoiceNumber,
            );
          }
        }
        // 2. Deduct new items
        for (final newItem in items) {
          if (newItem.productId.isNotEmpty) {
            await inventoryService.adjustStock(
              productId: newItem.productId,
              productName: newItem.description,
              quantity: -newItem.quantity, // negative = deduct
              reason: 'Sale (edited): $invoiceNumber',
              unitPrice: newItem.unitPrice,
              movementType: StockMovementType.saleOut,
              referenceId: invoiceId,
              referenceNumber: invoiceNumber,
            );
          }
        }
      } else {
        // New invoice — use pre-reserved number (already fetched in background)
        invoiceNumber = await (_preReservedNumber ??
            InvoiceNumberService().reserveNextInvoiceNumber(year: invoiceDate.year));

        final savedInvoice = Invoice(
          id: '',
          ownerId: currentUser.uid,
          invoiceNumber: invoiceNumber,
          clientId: resolvedClient?.id ?? '',
          clientName: customerName,
          customerGstin: resolvedClient?.gstin ?? '',
          items: items,
          createdAt: invoiceDate,
          dueDate: dueDate,
          status: resolvedStatus,
          discountType:
              discountValue > 0 ? _selectedDiscountType : null,
          discountValue: discountValue > 0 ? discountValue : 0,
          gstEnabled: _gstEnabled,
          gstRate: _gstRate,
          gstType: _gstType,
          amountReceived: received,
        );

        invoiceId = await FirebaseService().addInvoice(savedInvoice);
        UsageTrackingService.instance.incrementInvoiceCount(); // fire-and-forget

        // Deduct stock for all items in parallel (fire-and-forget for speed)
        final inventoryService = InventoryService();
        final stockFutures = items.where((i) => i.productId.isNotEmpty).map((item) =>
          inventoryService.adjustStock(
            productId: item.productId,
            productName: item.description,
            quantity: -item.quantity,
            reason: 'Sale: $invoiceNumber',
            unitPrice: item.unitPrice,
            movementType: StockMovementType.saleOut,
            referenceId: invoiceId,
            referenceNumber: invoiceNumber,
          ),
        );
        // Don't await — let stock sync in background while we navigate
        Future.wait(stockFutures).catchError((e) => debugPrint('[Stock] Error: $e'));
      }

      HapticFeedback.mediumImpact();

      final finalInvoice = Invoice(
        id: invoiceId,
        ownerId: currentUser.uid,
        invoiceNumber: invoiceNumber,
        clientId: resolvedClient?.id ?? '',
        clientName: customerName,
        customerGstin: resolvedClient?.gstin ?? '',
        items: items,
        createdAt: _isEditing ? widget.editingInvoice!.createdAt : invoiceDate,
        dueDate: dueDate,
        status: resolvedStatus,
        discountType: discountValue > 0 ? _selectedDiscountType : null,
        discountValue: discountValue > 0 ? discountValue : 0,
        gstEnabled: _gstEnabled,
        gstRate: _gstRate,
        gstType: _gstType,
        amountReceived: received,
      );

      if (!mounted) return;

      if (_isEditing) {
        Navigator.pop(context, finalInvoice);
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => InvoiceDetailsScreen(invoice: finalInvoice),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
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

  /// Clamp GST rate to nearest valid Indian rate [0, 5, 12, 18, 28].
  static const _validGstRates = [0.0, 5.0, 12.0, 18.0, 28.0];
  double _clampGstRate(double rate) {
    if (_validGstRates.contains(rate)) return rate;
    // Find nearest valid rate
    double nearest = 0;
    double minDiff = double.infinity;
    for (final valid in _validGstRates) {
      final diff = (rate - valid).abs();
      if (diff < minDiff) { minDiff = diff; nearest = valid; }
    }
    return nearest;
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
      case InvoiceStatus.partiallyPaid:
        return 'Partial';
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
      case InvoiceStatus.partiallyPaid:
        return const Color(0xFFFFF3E0);
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
      case InvoiceStatus.partiallyPaid:
        return const Color(0xFFFFCC80);
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
      case InvoiceStatus.partiallyPaid:
        return const Color(0xFFE65100);
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

// ── Dashed line painter for total amount ─────────────────────────────────────

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;
    final y = size.height;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ItemFormPage extends StatefulWidget {
  const _ItemFormPage({
    required this.row,
    required this.index,
    required this.itemUnitOptions,
    required this.defaultItemUnit,
    required this.customUnitValue,
    required this.gstRate,
    required this.currencyFormat,
    required this.s,
    this.onPickProduct,
  });

  final Map<String, TextEditingController> row;
  final int index;
  final List<String> itemUnitOptions;
  final String defaultItemUnit;
  final String customUnitValue;
  final double gstRate;
  final NumberFormat currencyFormat;
  final AppStrings s;
  final VoidCallback? onPickProduct;

  @override
  State<_ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<_ItemFormPage> {
  bool _showAdvanced = false;

  // Local controllers — copies of the row data, written back on save
  late final TextEditingController _desc;
  late final TextEditingController _hsn;
  late final TextEditingController _qty;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late final TextEditingController _gstRate;
  late final TextEditingController _discount;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _desc = TextEditingController(text: row['desc']!.text);
    _hsn = TextEditingController(text: row['hsn']!.text);
    _qty = TextEditingController(text: row['qty']!.text);
    _unit = TextEditingController(text: row['unit']!.text);
    _price = TextEditingController(text: row['price']!.text);
    _gstRate = TextEditingController(text: row['gstRate']!.text);
    _discount = TextEditingController(text: row['discount']?.text ?? '');

    // Show advanced if any advanced field has data
    if (_hsn.text.isNotEmpty || _discount.text.isNotEmpty ||
        (nu.parseDouble(row['gstRate']!.text) ?? 0) > 0) {
      _showAdvanced = true;
    }
  }

  @override
  void dispose() {
    _desc.dispose();
    _hsn.dispose();
    _qty.dispose();
    _unit.dispose();
    _price.dispose();
    _gstRate.dispose();
    _discount.dispose();
    super.dispose();
  }

  void _saveItem() {
    final name = _desc.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter item name')),
      );
      return;
    }
    _writeBack();
    Navigator.pop(context, true);
  }

  /// Write local values back to the shared row controllers.
  void _writeBack() {
    final row = widget.row;
    row['desc']!.text = _desc.text;
    row['hsn']!.text = _hsn.text;
    row['qty']!.text = _qty.text;
    row['unit']!.text = _unit.text;
    row['price']!.text = _price.text;
    row['gstRate']!.text = _gstRate.text;
    if (row.containsKey('discount')) {
      row['discount']!.text = _discount.text;
    }
  }

  Widget _calcRow(String label, String value, {bool bold = false, bool isNeg = false, bool isPos = false}) {
    final color = isNeg ? const Color(0xFFE53935) : isPos ? const Color(0xFF2E7D32) : kOnSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: kOnSurfaceVariant, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 13, color: bold ? kPrimary : color, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

  double get _total {
    final qty = nu.parseDouble(_qty.text) ?? 0;
    final price = nu.parseDouble(_price.text) ?? 0;
    final disc = (nu.parseDouble(_discount.text) ?? 0).clamp(0, 100);
    final raw = qty * price;
    return raw - (raw * disc / 100);
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kOnSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Row(
          children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text('#${widget.index + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _desc.text.trim().isEmpty ? 'New Item' : _desc.text.trim(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kOnSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saveItem,
            child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kPrimary)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Save button at bottom
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveItem,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: const Text(
                'Save Item',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item name
                  TextField(
                    controller: _desc,
                    autofocus: _desc.text.isEmpty,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      label: RichText(text: TextSpan(
                        style: const TextStyle(fontSize: 14, color: kTextTertiary),
                        children: [
                          const TextSpan(text: 'Item Name '),
                          TextSpan(text: '*', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w700)),
                        ],
                      )),
                      hintText: 'e.g. Notebook, Rice...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kPrimary, width: 1.5),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.inventory_2_rounded, color: kPrimary, size: 20),
                        tooltip: 'Pick from products',
                        onPressed: () async {
                          final product = await Navigator.push<Product>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProductsScreen(selectionMode: true),
                            ),
                          );
                          if (product == null || !mounted) return;
                          setState(() {
                            _desc.text = product.name;
                            _price.text = product.unitPrice > 0 ? product.unitPrice.toString() : '';
                            _unit.text = product.unit.isNotEmpty ? product.unit : widget.defaultItemUnit;
                            _hsn.text = product.hsnCode;
                            if (product.gstApplicable) {
                              _gstRate.text = product.gstRate.toStringAsFixed(0);
                              _showAdvanced = true;
                            }
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  // Qty + Unit + Price in a row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Qty
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _qty,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: kPrimary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Unit
                      Expanded(
                        flex: 2,
                        child: Builder(builder: (_) {
                          final currentUnit = _unit.text.isEmpty
                              ? widget.defaultItemUnit
                              : _unit.text;
                          final isCustom = !widget.itemUnitOptions.contains(currentUnit.toLowerCase());
                          return DropdownButtonFormField<String>(
                            value: isCustom ? widget.customUnitValue : currentUnit.toLowerCase(),
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: kPrimary, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            items: [
                              ...widget.itemUnitOptions.map((u) =>
                                DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))),
                              DropdownMenuItem(
                                value: widget.customUnitValue,
                                child: Text(isCustom ? 'Custom: $currentUnit' : 'Custom...',
                                  style: TextStyle(color: kPrimary, fontWeight: isCustom ? FontWeight.w600 : FontWeight.w400),
                                  overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == widget.customUnitValue) {
                                // TODO: show custom unit dialog
                              } else {
                                _unit.text = v ?? widget.defaultItemUnit;
                                setState(() {});
                              }
                            },
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      // Price
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Price (₹)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: kPrimary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Discount — always visible ──
                  TextField(
                    controller: _discount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Discount (%)',
                      hintText: 'e.g. 10',
                      suffixText: '%',
                      prefixIcon: const Icon(Icons.discount_outlined, size: 18, color: kOnSurfaceVariant),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kPrimary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  // ── GST — always visible ──
                  Builder(builder: (_) {
                    final gstOn = (nu.parseDouble(_gstRate.text) ?? 0) > 0;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: gstOn ? kPrimary.withValues(alpha: 0.3) : const Color(0xFFDDE3E6)),
                        borderRadius: BorderRadius.circular(12),
                        color: gstOn ? kPrimary.withValues(alpha: 0.03) : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.percent_rounded, color: kOnSurfaceVariant, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('GST',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kOnSurface))),
                              Switch.adaptive(
                                value: gstOn,
                                activeTrackColor: kPrimary,
                                activeThumbColor: Colors.white,
                                onChanged: (_) => setState(() {
                                  _gstRate.text = gstOn ? '0' : widget.gstRate.toStringAsFixed(0);
                                }),
                              ),
                            ],
                          ),
                          if (gstOn) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8, runSpacing: 6,
                              children: [5.0, 12.0, 18.0, 28.0].map((rate) {
                                final current = nu.parseDouble(_gstRate.text) ?? 0;
                                final selected = current == rate;
                                return GestureDetector(
                                  onTap: () => setState(() => _gstRate.text = rate.toStringAsFixed(0)),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected ? kPrimary : kSurfaceContainerLow,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('${rate.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: selected ? Colors.white : kOnSurface,
                                        fontWeight: FontWeight.w700, fontSize: 13)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  // ── Live calculation summary ──
                  Builder(builder: (_) {
                    final qty = nu.parseDouble(_qty.text) ?? 0;
                    final price = nu.parseDouble(_price.text) ?? 0;
                    final rawTotal = qty * price;
                    final discPct = (nu.parseDouble(_discount.text) ?? 0).clamp(0.0, 100.0);
                    final discAmt = rawTotal * discPct / 100;
                    final afterDisc = rawTotal - discAmt;
                    final gstPct = nu.parseDouble(_gstRate.text) ?? 0;
                    final gstAmt = afterDisc * gstPct / 100;
                    final finalTotal = afterDisc + gstAmt;
                    if (rawTotal <= 0) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          _calcRow('Base Amount', '₹${rawTotal.toStringAsFixed(2)}'),
                          if (discPct > 0) ...[
                            _calcRow('Discount (${ discPct.toStringAsFixed(0)}%)', '- ₹${discAmt.toStringAsFixed(2)}', isNeg: true),
                            _calcRow('After Discount', '₹${afterDisc.toStringAsFixed(2)}'),
                          ],
                          if (gstPct > 0)
                            _calcRow('GST (${gstPct.toStringAsFixed(0)}%)', '+ ₹${gstAmt.toStringAsFixed(2)}', isPos: true),
                          const Divider(height: 12),
                          _calcRow('Item Total', '₹${finalTotal.toStringAsFixed(2)}', bold: true),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  // ── More options — only HSN ──
                  GestureDetector(
                    onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 16, color: kPrimary),
                          const SizedBox(width: 4),
                          Text(_showAdvanced ? 'Hide HSN code' : 'Add HSN / SAC code',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimary)),
                        ],
                      ),
                    ),
                  ),
                  if (_showAdvanced) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _hsn,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'HSN / SAC Code',
                        hintText: 'e.g. 4820',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF48FB1))),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kPrimary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ],
          ],
        ),
      ),
    );
  }
}

