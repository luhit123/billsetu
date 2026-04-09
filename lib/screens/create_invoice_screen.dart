import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/services/review_service.dart';
import 'package:billeasy/widgets/connectivity_banner.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/product.dart';
import 'package:billeasy/utils/number_utils.dart' as nu;
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/line_item.dart';
import 'package:billeasy/screens/customers_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/screens/products_screen.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/product_service.dart';
import 'package:billeasy/services/invoice_number_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/services/usage_tracking_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/limit_reached_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:billeasy/utils/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billeasy/utils/error_helpers.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({
    super.key,
    this.initialClient,
    this.editingInvoice,
  });

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
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _customerAddressController =
      TextEditingController();
  final TextEditingController _customerEmailController =
      TextEditingController();
  final TextEditingController _customerGstinController =
      TextEditingController();
  bool _showMoreCustomerFields = false;
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
  late DateTime _dueDate;
  Client? _selectedClient;
  bool _isSaving = false;
  // Pre-reserved invoice number — fetched in background on screen open
  Future<String>? _preReservedNumber;
  bool _showClientValidationError = false;
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
  bool _showCustomerFields = true;

  // Web two-panel layout: index of item being edited inline
  // null = not editing, -1 = new item (unused, we use actual index)
  int? _webEditingItemIndex;
  bool _webEditingCustomer = false;
  StreamSubscription<AppPlan>? _planSub;

  bool get _isEditing => widget.editingInvoice != null;

  @override
  void initState() {
    super.initState();
    _selectedClient = widget.initialClient;
    if (widget.initialClient != null) {
      _customerNameController.text = widget.initialClient!.name;
      _customerPhoneController.text = widget.initialClient!.phone;
      _customerAddressController.text = widget.initialClient!.address;
      _customerEmailController.text = widget.initialClient!.email;
      _customerGstinController.text = widget.initialClient!.gstin;
      if (widget.initialClient!.address.isNotEmpty ||
          widget.initialClient!.email.isNotEmpty ||
          widget.initialClient!.gstin.isNotEmpty) {
        _showMoreCustomerFields = true;
      }
    }
    _customerNameController.addListener(_onCustomerNameChanged);
    _customerNameFocus.addListener(_onCustomerNameFocusChanged);
    itemRows = [];
    _showAdvanced = [];
    _itemConfirmed = [];

    final editInv = widget.editingInvoice;
    _dueDate = selectedDate.add(_defaultPaymentTerm);
    if (editInv != null) {
      _customerNameController.text = editInv.clientName;
      selectedDate = editInv.createdAt;
      _dueDate = editInv.dueDate ?? selectedDate.add(_defaultPaymentTerm);
      _gstEnabled = editInv.gstEnabled;
      _gstRate = editInv.gstRate;
      _gstType = editInv.gstType;
      if (editInv.discountValue > 0) {
        _discountController.text = editInv.discountValue.toString();
      }
      if (editInv.discountType != null) {
        _selectedDiscountType = editInv.discountType!;
      }
      if (editInv.amountReceived > 0) {
        _receivedController.text = editInv.amountReceived.toString();
      }
      if (editInv.paymentMethod.isNotEmpty) {
        _selectedPaymentMethod = editInv.paymentMethod;
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
        row['discount']!.text = item.discountPercent > 0
            ? item.discountPercent.toString()
            : '';
        row['productId']!.text = item.productId;
        itemRows.add(row);
        _showAdvanced.add(false);
        _itemConfirmed.add(true);
        _itemDescFocusNodes.add(FocusNode());
        _itemQtyFocusNodes.add(FocusNode());
      }

      // Set GSTIN from invoice
      if (editInv.customerGstin.isNotEmpty) {
        _customerGstinController.text = editInv.customerGstin;
        _showMoreCustomerFields = true;
      }

      // Resolve client — fetch full details for address/email
      if (editInv.clientId.isNotEmpty) {
        _selectedClient = Client(
          id: editInv.clientId,
          name: editInv.clientName,
        );
        // Load full client details async
        ClientService().getClient(editInv.clientId).then((client) {
          if (client != null && mounted) {
            setState(() {
              _selectedClient = client;
              if (_customerPhoneController.text.isEmpty) {
                _customerPhoneController.text = client.phone;
              }
              if (_customerAddressController.text.isEmpty) {
                _customerAddressController.text = client.address;
              }
              if (_customerEmailController.text.isEmpty) {
                _customerEmailController.text = client.email;
              }
              if (_customerGstinController.text.isEmpty) {
                _customerGstinController.text = client.gstin;
              }
              if (client.address.isNotEmpty ||
                  client.email.isNotEmpty ||
                  client.gstin.isNotEmpty) {
                _showMoreCustomerFields = true;
              }
            });
          }
        });
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
      _preReservedNumber = InvoiceNumberService().reserveNextInvoiceNumber(
        year: DateTime.now().year,
      );
    }
    _planSub = PlanService.instance.planStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _loadLastUsedGstSettings() {
    // Fire-and-forget — screen renders instantly, settings update in background
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _gstRate = prefs.getDouble('last_gst_rate') ?? 18.0;
        _gstType = prefs.getString('last_gst_type') ?? 'cgst_sgst';
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
    _planSub?.cancel();
    _discountController.dispose();
    _receivedController.dispose();
    _customerNameController.removeListener(_onCustomerNameChanged);
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _customerEmailController.dispose();
    _customerGstinController.dispose();
    _customerNameFocus.removeListener(_onCustomerNameFocusChanged);
    _customerNameFocus.dispose();
    _clientSearchSub?.cancel();
    _productAutoSaveTimer?.cancel();
    _removeCustomerOverlay();
    for (final row in itemRows) {
      _disposeRowControllers(row);
    }
    for (final fn in _itemDescFocusNodes) {
      fn.dispose();
    }
    for (final fn in _itemQtyFocusNodes) {
      fn.dispose();
    }
    super.dispose();
  }

  // ── Input decoration ──────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String label, {String? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 13),
        suffixText: suffix,
        filled: true,
        fillColor: context.cs.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
          borderSide: BorderSide(color: context.cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.cs.error, width: 1.5),
        ),
      );

  Color _mobileCardColor(BuildContext context, {bool muted = false}) {
    final base = muted
        ? context.cs.surfaceContainerLow
        : context.cs.surfaceContainerLowest;
    return base.withValues(alpha: context.isDark ? (muted ? 0.78 : 0.94) : 1);
  }

  Color _mobileBorderColor(BuildContext context, {bool strong = false}) {
    return context.cs.outlineVariant.withValues(
      alpha: strong
          ? (context.isDark ? 0.58 : 0.9)
          : (context.isDark ? 0.38 : 0.72),
    );
  }

  List<BoxShadow> _mobileCardShadow(
    BuildContext context, {
    bool emphasized = false,
  }) {
    return [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: context.isDark
              ? (emphasized ? 0.2 : 0.14)
              : (emphasized ? 0.06 : 0.04),
        ),
        blurRadius: emphasized ? 16 : 8,
        offset: Offset(0, emphasized ? 4 : 2),
      ),
    ];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    // ── Currency rounding helper ──
    double rc(num v) => (v * 100).roundToDouble() / 100;

    // ── Build lightweight LineItems from form state for computeFinancials ──
    int totalQty = 0;
    double totalItemDiscount = 0;
    final liveItems = <LineItem>[];
    for (final row in itemRows) {
      final qty = nu.parseDouble(row['qty']!.text) ?? 0;
      final price = nu.parseDouble(row['price']!.text) ?? 0;
      final discPct = (nu.parseDouble(row['discount']?.text ?? '') ?? 0)
          .clamp(0, 100)
          .toDouble();
      final itemRate = nu.parseDouble(row['gstRate']!.text) ?? _gstRate;
      if (qty > 0) totalQty += 1;
      final li = LineItem(
        description: '',
        quantity: qty,
        unitPrice: price,
        gstRate: itemRate,
        discountPercent: discPct,
      );
      totalItemDiscount += li.discountAmount;
      liveItems.add(li);
    }
    totalItemDiscount = rc(totalItemDiscount);

    // ── FIX G-1: Use the single canonical computeFinancials() path ──
    // This is the SAME function that toMap() calls, guaranteeing the preview
    // numbers match what gets saved to Firestore byte-for-byte.
    final discountValue = nu.parseDouble(_discountController.text.trim()) ?? 0;
    final f = Invoice.computeFinancials(
      items: liveItems,
      discountType: discountValue > 0 ? _selectedDiscountType : null,
      discountValue: discountValue > 0 ? discountValue : 0,
      gstEnabled: _gstEnabled,
      gstType: _gstType,
      amountReceived: nu.parseDouble(_receivedController.text) ?? 0,
    );

    final subtotal = f.subtotal;
    final discountAmount = f.discountAmount;
    final taxableAmount = f.taxableAmount;
    final cgstAmount = f.cgstAmount;
    final sgstAmount = f.sgstAmount;
    final igstAmount = f.igstAmount;
    final totalTax = f.totalTax;
    final grandTotal = f.grandTotal;
    final totalDiscount = rc(totalItemDiscount + discountAmount);
    final amountReceived = (nu.parseDouble(_receivedController.text) ?? 0)
        .clamp(0.0, grandTotal);
    final double balanceDue = rc(grandTotal - amountReceived);
    final cs = context.cs;
    final isDark = context.isDark;
    final mobileCardColor = _mobileCardColor(context);
    final mobileMutedCardColor = _mobileCardColor(context, muted: true);
    final mobileBorderColor = _mobileBorderColor(context);
    final mobileStrongBorderColor = _mobileBorderColor(context, strong: true);
    final billedStripColor = isDark
        ? kPrimary.withValues(alpha: 0.18)
        : const Color(0xFF42A5F5);
    final billedStripTextColor = isDark
        ? const Color(0xFFE5EEFF)
        : Colors.white;

    // ── Adaptive web layout for medium + expanded screens ──
    final windowSize = windowSizeOf(context);
    if (kIsWeb && windowSize != WindowSize.compact) {
      return _buildWebLayout(
        s,
        grandTotal,
        subtotal,
        totalDiscount,
        totalTax,
        taxableAmount,
        cgstAmount,
        sgstAmount,
        igstAmount,
        amountReceived,
        balanceDue,
        totalQty,
        windowSize,
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _isEditing ? 'Edit Invoice' : s.createTitle,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: const [],
      ),
      bottomNavigationBar: itemRows.isEmpty ? null : _buildSaveBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kWebFormMaxWidth),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 20),
                      children: [
                        if (itemRows.isEmpty || _showCustomerFields)
                          Container(
                            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            decoration: BoxDecoration(
                              color: mobileCardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: mobileBorderColor),
                              boxShadow: _mobileCardShadow(context),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildInvoiceNoDateRow(s),
                                Divider(height: 16, color: mobileBorderColor),
                                _buildCustomerSection(context),
                                const SizedBox(height: 10),
                                _buildPhoneField(),
                                const SizedBox(height: 6),
                                _buildMoreCustomerToggle(),
                                if (_showMoreCustomerFields) ...[
                                  const SizedBox(height: 10),
                                  _buildCustomerAddressField(),
                                  const SizedBox(height: 10),
                                  _buildCustomerEmailField(),
                                  const SizedBox(height: 10),
                                  _buildCustomerGstinField(),
                                ],
                                if (itemRows.isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: TextButton.icon(
                                        onPressed: () => setState(
                                          () => _showCustomerFields = false,
                                        ),
                                        icon: const Icon(
                                          Icons.check_circle,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Done',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: kPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () =>
                                setState(() => _showCustomerFields = true),
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: mobileCardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: mobileBorderColor),
                                boxShadow: _mobileCardShadow(context),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: kPrimary.withValues(
                                        alpha: isDark ? 0.22 : 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: kPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _customerNameController.text
                                                  .trim()
                                                  .isEmpty
                                              ? 'Customer'
                                              : _customerNameController.text
                                                    .trim(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurface,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (_customerPhoneController.text
                                            .trim()
                                            .isNotEmpty)
                                          Text(
                                            _customerPhoneController.text
                                                .trim(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(selectedDate),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (itemRows.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: billedStripColor,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Billed Items',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: billedStripTextColor,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${itemRows.length} items',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: billedStripTextColor.withValues(
                                      alpha: 0.78,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (itemRows.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: mobileCardColor,
                              border: Border.all(
                                color: mobileBorderColor,
                                width: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(0),
                            ),
                            constraints: BoxConstraints(
                              maxHeight: itemRows.length <= 2
                                  ? double.infinity
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
                                    itemBuilder: (context, i) =>
                                        _buildItemCard(context, i, s),
                                  ),
                          ),
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                          decoration: BoxDecoration(
                            color: mobileMutedCardColor,
                            borderRadius: itemRows.isEmpty
                                ? BorderRadius.circular(8)
                                : const BorderRadius.vertical(
                                    bottom: Radius.circular(8),
                                  ),
                            border: Border.all(
                              color: mobileStrongBorderColor,
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (itemRows.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _summaryChip(
                                        'Total Disc: ${_currencyFormat.format(totalDiscount)}',
                                        const Color(0xFFE65100),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _summaryChip(
                                        'Total Tax Amt: ${_currencyFormat.format(totalTax)}',
                                        const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _summaryChip(
                                        'Total Qty: ${itemRows.length}',
                                        cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _summaryChip(
                                        'Subtotal: ${_currencyFormat.format(subtotal)}',
                                        cs.onSurface,
                                      ),
                                    ),
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
                        if (itemRows.isNotEmpty)
                          _buildPinnedTotalStrip(
                            grandTotal,
                            amountReceived,
                            balanceDue,
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Premium Two-Panel Web Layout ─────────────────────────────────────────

  Widget _buildWebLayout(
    AppStrings s,
    double grandTotal,
    double subtotal,
    double totalDiscount,
    double totalTax,
    double taxableAmount,
    double cgstAmount,
    double sgstAmount,
    double igstAmount,
    double amountReceived,
    double balanceDue,
    int totalQty,
    WindowSize windowSize,
  ) {
    final isExpanded = windowSize == WindowSize.expanded;
    final headerCustomerName = _customerNameController.text.trim();

    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        foregroundColor: context.cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 56,
        title: Text(
          _isEditing ? 'Edit Invoice' : s.createTitle,
          style: TextStyle(
            color: context.cs.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          // Info chips (customer, date) — tappable
          if (itemRows.isNotEmpty) ...[
            _webInfoChip(
              icon: Icons.person_outline_rounded,
              label: headerCustomerName.isNotEmpty
                  ? headerCustomerName
                  : 'Add customer',
              onTap: () => setState(
                () => _webEditingCustomer = !_webEditingCustomer,
              ),
            ),
            const SizedBox(width: 6),
            _webInfoChip(
              icon: Icons.calendar_today_rounded,
              label: DateFormat('dd MMM').format(selectedDate),
              onTap: _pickDate,
            ),
            const SizedBox(width: 6),
            _webInfoChip(
              icon: Icons.event_rounded,
              label: 'Due ${DateFormat('dd MMM').format(_dueDate)}',
              onTap: _pickDueDate,
            ),
            const SizedBox(width: 12),
          ],
          // Save button
          if (_itemConfirmed.any((c) => c))
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveInvoice,
                  icon: _isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.cs.surface,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_isEditing ? 'Update' : 'Save & Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.cs.primary,
                    foregroundColor: context.cs.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            _webEditingCustomer ? 72 : 1,
          ),
          child: _webEditingCustomer
              ? Container(
                  color: context.cs.surfaceContainerLowest,
                  padding: EdgeInsets.fromLTRB(
                    isExpanded ? 20 : 16,
                    8,
                    isExpanded ? 20 : 16,
                    10,
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: isExpanded ? 260 : 200,
                        height: 40,
                        child: _buildCustomerSection(context),
                      ),
                      SizedBox(
                        width: isExpanded ? 180 : 160,
                        height: 40,
                        child: _buildPhoneField(),
                      ),
                      _buildMoreCustomerToggle(),
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _webEditingCustomer = false,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 15),
                        label: const Text('Done'),
                        style: TextButton.styleFrom(
                          foregroundColor: context.cs.primary,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(height: 1, color: context.cs.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // Keep a clean, professional canvas width on web.
                // Full-bleed ultra-wide layouts feel noisy for billing screens.
                maxWidth: isExpanded ? 1440 : kWebFormMaxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isExpanded ? 20 : 16,
                  0,
                  isExpanded ? 20 : 16,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: itemRows.isEmpty
                          ? Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 720,
                                ),
                                child: _buildWebInitialView(s),
                              ),
                            )
                          : isExpanded
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // 1: Item form
                                    Expanded(
                                      flex: 33,
                                      child: Container(
                                        decoration: _webPanelDecoration(
                                          emphasized:
                                              _webEditingItemIndex != null,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: _buildWebItemFormSection(),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // 2: Line items
                                    Expanded(
                                      flex: 42,
                                      child: Container(
                                        decoration: _webPanelDecoration(),
                                        clipBehavior: Clip.antiAlias,
                                        child: _buildWebRightPanelInner(s),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // 3: Summary
                                    Expanded(
                                      flex: 25,
                                      child: Container(
                                        decoration: _webPanelDecoration(),
                                        clipBehavior: Clip.antiAlias,
                                        child: _buildWebSummarySection(
                                          s,
                                          grandTotal,
                                          subtotal,
                                          totalDiscount,
                                          totalTax,
                                          taxableAmount,
                                          cgstAmount,
                                          sgstAmount,
                                          igstAmount,
                                          amountReceived,
                                          balanceDue,
                                          totalQty,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : _buildWebMediumLayout(
                                  s,
                                  grandTotal,
                                  subtotal,
                                  totalDiscount,
                                  totalTax,
                                  taxableAmount,
                                  cgstAmount,
                                  sgstAmount,
                                  igstAmount,
                                  amountReceived,
                                  balanceDue,
                                  totalQty,
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Single-column layout for medium (tablet) screens.
  /// Stacks: item form → confirmed items → summary vertically.
  Widget _buildWebMediumLayout(
    AppStrings s,
    double grandTotal,
    double subtotal,
    double totalDiscount,
    double totalTax,
    double taxableAmount,
    double cgstAmount,
    double sgstAmount,
    double igstAmount,
    double amountReceived,
    double balanceDue,
    int totalQty,
  ) {
    final confirmedIndices = <int>[
      for (int i = 0; i < itemRows.length; i++)
        if (_itemConfirmed[i]) i,
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Add / Edit Item Form ──
          Container(
            decoration: _webPanelDecoration(
              emphasized: _webEditingItemIndex != null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: context.cs.surfaceContainerHigh,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? const Color(0xFF16A34A).withAlpha(30)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 15,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _webEditingItemIndex != null
                            ? 'Edit Item'
                            : 'Add New Item',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _buildWebAlwaysVisibleItemForm(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Confirmed Items ──
          if (confirmedIndices.isNotEmpty)
            Container(
              decoration: _webPanelDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: context.cs.surfaceContainerHigh,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: context.isDark
                                ? const Color(0xFF16A34A).withAlpha(30)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 15,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${confirmedIndices.length} Line Item${confirmedIndices.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Column(
                      children: [
                        for (final i in confirmedIndices)
                          _buildWebItemCard(i, s),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (confirmedIndices.isNotEmpty) const SizedBox(height: 14),

          // ── Summary ──
          _buildWebSummaryPanel(
            s,
            grandTotal,
            subtotal,
            totalDiscount,
            totalTax,
            taxableAmount,
            cgstAmount,
            sgstAmount,
            igstAmount,
            amountReceived,
            balanceDue,
            totalQty,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _webInfoChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.cs.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: kPrimary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _webPanelDecoration({bool emphasized = false}) {
    return BoxDecoration(
      color: context.cs.surface.withValues(alpha: context.isDark ? 0.92 : 0.96),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: emphasized
            ? kPrimary.withValues(alpha: context.isDark ? 0.26 : 0.16)
            : context.cs.outlineVariant.withValues(
                alpha: context.isDark ? 0.82 : 1,
              ),
      ),
      boxShadow: [
        BoxShadow(
          color: context.isDark
              ? Colors.black.withValues(alpha: emphasized ? 0.26 : 0.2)
              : const Color(0x12163245),
          blurRadius: emphasized ? 30 : 24,
          offset: Offset(0, emphasized ? 18 : 14),
        ),
      ],
    );
  }

  Widget _buildWebInitialView(AppStrings s) {
    return ListView(
      children: [
        // Centered card with max width for clean look
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                // ── Customer & Invoice Info Card ──
                Container(
                  decoration: _webPanelDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: context.cs.surfaceContainerHigh,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: context.cs.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 18,
                                color: kPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Customer & Invoice',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: context.cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Invoice no + date row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invoice No.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.cs.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: context.cs.outlineVariant,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.tag,
                                          size: 14,
                                          color: kPrimary,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Auto-generated',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: context.cs.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invoice Date',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: _pickDate,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              context.cs.surfaceContainerLowest,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: context.cs.outlineVariant,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_rounded,
                                              size: 14,
                                              color: kPrimary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              DateFormat(
                                                'dd MMM yyyy',
                                              ).format(selectedDate),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: context.cs.onSurface,
                                              ),
                                            ),
                                            const Spacer(),
                                            Icon(
                                              Icons.unfold_more_rounded,
                                              size: 16,
                                              color:
                                                  context.cs.onSurfaceVariant,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Customer name + phone
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildCustomerSection(context),
                            ),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: _buildPhoneField()),
                            const SizedBox(width: 8),
                            _buildMoreCustomerToggle(),
                          ],
                        ),
                      ),
                      if (_showMoreCustomerFields)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              SizedBox(
                                width: 220,
                                child: _buildCustomerAddressField(),
                              ),
                              SizedBox(
                                width: 200,
                                child: _buildCustomerEmailField(),
                              ),
                              SizedBox(
                                width: 180,
                                child: _buildCustomerGstinField(),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Add First Item CTA ──
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _addItemRow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: _webPanelDecoration(emphasized: true)
                          .copyWith(
                            border: Border.all(
                              color: context.isDark
                                  ? const Color(0xFF16A34A).withAlpha(80)
                                  : const Color(0xFFBBF7D0),
                              width: 1.5,
                            ),
                          ),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: context.isDark
                                  ? Color(0xFF16A34A).withAlpha(30)
                                  : Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: context.isDark
                                    ? Color(0xFF16A34A).withAlpha(60)
                                    : Color(0xFFBBF7D0),
                              ),
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart_rounded,
                              color: Color(0xFF16A34A),
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Add Your First Item',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap here to add products or services to this invoice',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Item form section (no outer decoration) for unified 3-column layout.
  Widget _buildWebItemFormSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: context.isDark
                      ? const Color(0xFF16A34A).withAlpha(30)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.add_shopping_cart_rounded,
                  size: 15,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _webEditingItemIndex != null ? 'Edit Item' : 'Add Item',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildWebAlwaysVisibleItemForm(),
        ],
      ),
    );
  }

  /// Line items section (no outer decoration) for unified 3-column layout.
  Widget _buildWebRightPanelInner(AppStrings s) {
    final confirmedIndices = <int>[
      for (int i = 0; i < itemRows.length; i++)
        if (_itemConfirmed[i]) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: context.isDark
                      ? const Color(0xFF16A34A).withAlpha(30)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 15,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${confirmedIndices.length} Item${confirmedIndices.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: confirmedIndices.isEmpty
              ? Center(
                  child: Text(
                    'Items will appear here',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: confirmedIndices.length,
                  itemBuilder: (context, i) =>
                      _buildWebItemCard(confirmedIndices[i], s),
                ),
        ),
      ],
    );
  }

  /// Summary section (no outer decoration) for unified 3-column layout.
  Widget _buildWebSummarySection(
    AppStrings s,
    double grandTotal,
    double subtotal,
    double totalDiscount,
    double totalTax,
    double taxableAmount,
    double cgstAmount,
    double sgstAmount,
    double igstAmount,
    double amountReceived,
    double balanceDue,
    int totalQty,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildWebSummaryContent(
        s,
        grandTotal,
        subtotal,
        totalDiscount,
        totalTax,
        taxableAmount,
        cgstAmount,
        sgstAmount,
        igstAmount,
        amountReceived,
        balanceDue,
        totalQty,
      ),
    );
  }



  /// Always-visible item form on web left panel.
  /// When editing an existing item (_webEditingItemIndex != null), it shows that item.
  /// Otherwise, it ensures a blank draft row exists at the end for adding a new item.
  Widget _buildWebAlwaysVisibleItemForm() {
    // Ensure there's always a blank draft row at the end for "add new"
    final int editIndex;
    if (_webEditingItemIndex != null) {
      editIndex = _webEditingItemIndex!;
    } else {
      // Find or create a blank draft row
      final lastIdx = itemRows.length - 1;
      final lastIsBlank =
          lastIdx >= 0 &&
          itemRows[lastIdx]['desc']!.text.trim().isEmpty &&
          !_itemConfirmed[lastIdx];
      if (lastIsBlank) {
        editIndex = lastIdx;
      } else {
        // Add a new blank row
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _addItemRow();
        });
        return const SizedBox.shrink();
      }
    }
    return _buildWebInlineItemForm(editIndex);
  }


  Widget _buildWebItemCard(int index, AppStrings s) {
    final row = itemRows[index];
    final name = row['desc']!.text.trim();
    final qty = nu.parseDouble(row['qty']!.text) ?? 0;
    final price = nu.parseDouble(row['price']!.text) ?? 0;
    final unit = row['unit']!.text.trim().isEmpty
        ? _defaultItemUnit
        : row['unit']!.text.trim();
    final itemDiscountPct = (nu.parseDouble(row['discount']?.text ?? '') ?? 0)
        .clamp(0, 100);
    final rawTotal = qty * price;
    final discAmt = rawTotal * itemDiscountPct / 100;
    final afterDisc = rawTotal - discAmt;
    final gstRate = nu.parseDouble(row['gstRate']!.text) ?? 0;
    final gstAmt = afterDisc * gstRate / 100;
    final lineTotal = afterDisc + gstAmt;
    final qtyStr = qty == qty.truncateToDouble()
        ? qty.toInt().toString()
        : qty.toString();
    final isEditing = _webEditingItemIndex == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _editItem(index),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isEditing
                ? kPrimary.withValues(alpha: context.isDark ? 0.12 : 0.06)
                : context.cs.surface.withValues(
                    alpha: context.isDark ? 0.92 : 0.98,
                  ),
            border: Border.all(
              color: isEditing
                  ? kPrimary.withValues(alpha: 0.28)
                  : context.cs.surfaceContainerHigh,
            ),
            boxShadow: [
              BoxShadow(
                color: context.isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : const Color(0x0D163245),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: index + name + total + delete
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Unnamed item' : name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$qtyStr $unit  ×  ₹${price.toStringAsFixed(price == price.truncateToDouble() ? 0 : 2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: context.cs.surfaceContainerHigh,
                      ),
                    ),
                    child: Text(
                      _currencyFormat.format(lineTotal),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _removeItemRow(index),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: context.cs.errorContainer,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: context.cs.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _webItemBadge('$qtyStr $unit', context.cs.onSurfaceVariant),
                  _webItemBadge(
                    'Rate ₹${price.toStringAsFixed(price == price.truncateToDouble() ? 0 : 2)}',
                    const Color(0xFF2563EB),
                  ),
                  if (itemDiscountPct > 0)
                    _webItemBadge(
                      'Disc ${itemDiscountPct.toStringAsFixed(0)}%',
                      const Color(0xFFE65100),
                    ),
                  if (gstRate > 0)
                    _webItemBadge(
                      'GST ${gstRate.toStringAsFixed(0)}%',
                      const Color(0xFF16A34A),
                    ),
                ],
              ),
              // Detail row: price breakdown
              if (itemDiscountPct > 0 || gstRate > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 36, top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: context.cs.surfaceContainerHigh,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 0,
                          runSpacing: 6,
                          children: [
                            _webItemDetailChip(
                              'Subtotal',
                              '₹${rawTotal.toStringAsFixed(0)}',
                              context.cs.onSurfaceVariant,
                            ),
                            if (itemDiscountPct > 0) ...[
                              _webItemDetailDot(),
                              _webItemDetailChip(
                                'Disc ${itemDiscountPct.toStringAsFixed(0)}%',
                                '−₹${discAmt.toStringAsFixed(0)}',
                                const Color(0xFFE65100),
                              ),
                            ],
                            if (gstRate > 0) ...[
                              _webItemDetailDot(),
                              _webItemDetailChip(
                                'GST ${gstRate.toStringAsFixed(0)}%',
                                '+₹${gstAmt.toStringAsFixed(0)}',
                                const Color(0xFF16A34A),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Line total ${_currencyFormat.format(lineTotal)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _webItemDetailChip(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _webItemDetailDot() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '•',
        style: TextStyle(fontSize: 10, color: context.cs.outline),
      ),
    );
  }

  Widget _webItemBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildWebInlineItemForm(int index) {
    final row = itemRows[index];
    final qty = nu.parseDouble(row['qty']!.text) ?? 0;
    final price = nu.parseDouble(row['price']!.text) ?? 0;
    final discPct = (nu.parseDouble(row['discount']?.text ?? '') ?? 0).clamp(
      0,
      100,
    );
    final rawTotal = qty * price;
    final discAmt = rawTotal * discPct / 100;
    final afterDisc = rawTotal - discAmt;
    final gstPct = nu.parseDouble(row['gstRate']!.text) ?? 0;
    final gstAmt = afterDisc * gstPct / 100;
    final lineTotal = afterDisc + gstAmt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _webItemBadge(
              _webEditingItemIndex != null
                  ? 'Editing selected line item'
                  : 'New draft item',
              _webEditingItemIndex != null ? kPrimary : const Color(0xFF2563EB),
            ),
            if (lineTotal > 0)
              _webItemBadge(
                'Live total ${_currencyFormat.format(lineTotal)}',
                const Color(0xFF16A34A),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Live total badge
        if (lineTotal > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.isDark
                    ? Color(0xFF16A34A).withAlpha(30)
                    : Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.isDark
                      ? Color(0xFF16A34A).withAlpha(60)
                      : Color(0xFFBBF7D0),
                ),
              ),
              child: Text(
                'Total: ${_currencyFormat.format(lineTotal)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
          ),
        // Row 1: Name + HSN
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: row['desc'],
                autofocus: row['desc']!.text.isEmpty,
                textCapitalization: TextCapitalization.words,
                decoration: _webInputDecoration(
                  'Item Name *',
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: kPrimary,
                    ),
                    tooltip: 'Pick from products',
                    onPressed: () => _pickProduct(index),
                  ),
                ),
                style: TextStyle(fontSize: 14, color: context.cs.onSurface),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: row['hsn'],
                decoration: _webInputDecoration('HSN / SAC'),
                style: TextStyle(fontSize: 14, color: context.cs.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2a: Qty + Unit
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: row['qty'],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: _webInputDecoration('Qty *'),
                style: TextStyle(fontSize: 14, color: context.cs.onSurface),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue:
                    _itemUnitOptions.contains(row['unit']!.text.toLowerCase())
                    ? row['unit']!.text.toLowerCase()
                    : (row['unit']!.text.trim().isNotEmpty
                          ? _customUnitValue
                          : _defaultItemUnit),
                decoration: _webInputDecoration('Unit'),
                isExpanded: true,
                items: [
                  ..._itemUnitOptions.map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(u, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: '__custom__',
                    child: Text(
                      'Custom...',
                      style: TextStyle(fontSize: 13, color: kPrimary),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val == _customUnitValue) {
                    _showCustomUnitDialog(row);
                  } else if (val != null) {
                    setState(() => row['unit']!.text = val);
                  }
                },
                style: TextStyle(fontSize: 13, color: context.cs.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2b: Price + Discount
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: row['price'],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: _webInputDecoration('Price (₹) *'),
                style: TextStyle(fontSize: 14, color: context.cs.onSurface),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: row['discount'],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: _webInputDecoration('Disc %'),
                style: TextStyle(fontSize: 14, color: context.cs.onSurface),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<double>(
                initialValue: _clampGstRate(nu.parseDouble(row['gstRate']!.text) ?? 0),
                decoration: _webInputDecoration('GST'),
                isExpanded: true,
                items: _validGstRates
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(
                          r == 0 ? 'No GST' : '${r.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      row['gstRate']!.text = val.toStringAsFixed(0);
                      if (val > 0) _gstEnabled = true;
                    });
                  }
                },
                style: TextStyle(fontSize: 13, color: context.cs.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Action row
        Row(
          children: [
            // Mini calculation summary
            if (rawTotal > 0) ...[
              Text(
                '₹${rawTotal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              if (discPct > 0) ...[
                Text(
                  ' − ${discPct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE65100),
                  ),
                ),
              ],
              if (gstPct > 0) ...[
                Text(
                  ' + GST ${gstPct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
              Text(
                ' = ',
                style: TextStyle(
                  fontSize: 12,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              Text(
                '₹${lineTotal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ),
            ],
            const Spacer(),
            TextButton(
              onPressed: () {
                if (_webEditingItemIndex != null) {
                  // Editing existing: just cancel edit mode
                  final name = row['desc']!.text.trim();
                  final wasNew =
                      name.isEmpty &&
                      (nu.parseDouble(row['price']!.text) ?? 0) <= 0;
                  if (wasNew) _removeItemRow(index);
                  setState(() => _webEditingItemIndex = null);
                } else {
                  // Adding new: clear the draft fields
                  row['desc']!.clear();
                  row['qty']!.text = '1';
                  row['price']!.clear();
                  row['hsn']!.clear();
                  row['unit']!.text = _defaultItemUnit;
                  row['discount']!.clear();
                  row['gstRate']!.text = '0';
                  setState(() {});
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: context.cs.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: Text(
                _webEditingItemIndex != null ? 'Cancel' : 'Clear',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                final name = row['desc']!.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter item name')),
                  );
                  return;
                }
                _autoSaveRowAsProduct(row);
                setState(() {
                  _itemConfirmed[index] = true;
                  _showCustomerFields = false;
                  final itemGstRate = nu.parseDouble(row['gstRate']!.text) ?? 0;
                  if (itemGstRate > 0) _gstEnabled = true;
                  if (_webEditingItemIndex != null) {
                    // Was editing existing item, go back to add mode
                    _webEditingItemIndex = null;
                  }
                  // A new blank row will be auto-created by _buildWebAlwaysVisibleItemForm
                });
              },
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text(
                _webEditingItemIndex != null ? 'Update Item' : 'Add to Invoice',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: context.cs.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _webInputDecoration(
    String label, {
    String? prefix,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: context.cs.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixText: prefix,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: context.cs.surfaceContainerLowest.withValues(
        alpha: context.isDark ? 0.65 : 1,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.cs.error, width: 1.5),
      ),
    );
  }

  Widget _buildWebSummaryPanel(
    AppStrings s,
    double grandTotal,
    double subtotal,
    double totalDiscount,
    double totalTax,
    double taxableAmount,
    double cgstAmount,
    double sgstAmount,
    double igstAmount,
    double amountReceived,
    double balanceDue,
    int totalQty,
  ) {
    return Container(
      decoration: _webPanelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: _buildWebSummaryContent(
        s, grandTotal, subtotal, totalDiscount, totalTax,
        taxableAmount, cgstAmount, sgstAmount, igstAmount,
        amountReceived, balanceDue, totalQty,
      ),
    );
  }

  Widget _buildWebSummaryContent(
    AppStrings s,
    double grandTotal,
    double subtotal,
    double totalDiscount,
    double totalTax,
    double taxableAmount,
    double cgstAmount,
    double sgstAmount,
    double igstAmount,
    double amountReceived,
    double balanceDue,
    int totalQty,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.cs.surfaceContainerHigh),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calculate_outlined,
                    size: 18,
                    color: kPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.cs.outlineVariant),
                  ),
                  child: Text(
                    'Live totals',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildWebMiniMetricCard(
                    label: 'Lines',
                    value: totalQty.toString(),
                    accent: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildWebMiniMetricCard(
                    label: 'Discount',
                    value: totalDiscount > 0
                        ? _currencyFormat.format(totalDiscount)
                        : '₹0',
                    accent: const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildWebMiniMetricCard(
                    label: 'Collected',
                    value: amountReceived > 0
                        ? _currencyFormat.format(amountReceived)
                        : '₹0',
                    accent: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),

          // Summary rows
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                _webSummaryRow('Subtotal', _currencyFormat.format(subtotal)),
                if (totalDiscount > 0) ...[
                  const SizedBox(height: 8),
                  _webSummaryRow(
                    'Discount',
                    '- ${_currencyFormat.format(totalDiscount)}',
                    valueColor: const Color(0xFFE65100),
                  ),
                ],
                if (_gstEnabled) ...[
                  const SizedBox(height: 8),
                  _webSummaryRow(
                    'Taxable Amount',
                    _currencyFormat.format(taxableAmount),
                  ),
                  const SizedBox(height: 6),
                  if (_gstType == 'cgst_sgst') ...[
                    _webSummaryRow(
                      'CGST',
                      _currencyFormat.format(cgstAmount),
                      valueColor: context.cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    _webSummaryRow(
                      'SGST',
                      _currencyFormat.format(sgstAmount),
                      valueColor: context.cs.onSurfaceVariant,
                    ),
                  ] else
                    _webSummaryRow(
                      'IGST',
                      _currencyFormat.format(igstAmount),
                      valueColor: context.cs.onSurfaceVariant,
                    ),
                  const SizedBox(height: 6),
                  _webSummaryRow(
                    'Total Tax',
                    _currencyFormat.format(totalTax),
                    valueColor: const Color(0xFF16A34A),
                  ),
                ],
              ],
            ),
          ),

          // Grand Total
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  kPrimary.withValues(alpha: 0.06),
                  kPrimary.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimary.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'INR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  _currencyFormat.format(grandTotal),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: kPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Divider(height: 1, color: context.cs.surfaceContainerHigh),
          ),

          // Received toggle + amount
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isReceived = !_isReceived;
                      if (_isReceived) {
                        _receivedController.text = grandTotal.toStringAsFixed(2);
                      } else {
                        _receivedController.clear();
                      }
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _isReceived,
                            onChanged: (v) {
                              setState(() {
                                _isReceived = v ?? false;
                                if (_isReceived) {
                                  _receivedController.text = grandTotal.toStringAsFixed(2);
                                } else {
                                  _receivedController.clear();
                                }
                              });
                            },
                            activeColor: const Color(0xFF16A34A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Received',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _receivedController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      prefixText: '\u20b9 ',
                      prefixStyle: TextStyle(
                        fontSize: 12,
                        color: context.cs.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: context.cs.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(
                          color: context.cs.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(
                          color: context.cs.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: const BorderSide(
                          color: kPrimary,
                          width: 1.5,
                        ),
                      ),
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: context.cs.outline,
                        fontSize: 13,
                      ),
                    ),
                    onChanged: (val) => _onReceivedAmountChanged(val, grandTotal),
                  ),
                ),
              ],
            ),
          ),

          // Status bar
          () {
            final isPaid = balanceDue <= 0 && grandTotal > 0;
            final isPartial = amountReceived > 0 && balanceDue > 0;
            final sColor = isPaid
                ? const Color(0xFF16A34A)
                : isPartial
                ? const Color(0xFFD97706)
                : context.cs.error;
            final sBg = isPaid
                ? context.isDark
                      ? Color(0xFF16A34A).withAlpha(30)
                      : Color(0xFFF0FDF4)
                : isPartial
                ? const Color(0xFFFFFBEB)
                : context.cs.errorContainer;
            final sLabel = isPaid
                ? 'Paid'
                : isPartial
                ? 'Partial'
                : 'Unpaid';

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: sBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: sColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!isPaid) ...[
                    Text(
                      'Balance: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: sColor.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      _currencyFormat.format(balanceDue),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: sColor,
                      ),
                    ),
                  ] else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: sColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Fully Paid',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sColor,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }(),

          // Payment method chips (show when received amount > 0)
          if (amountReceived > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode of Payment',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _paymentMethods
                        .map(
                          (m) => ChoiceChip(
                            label: Text(
                              m,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedPaymentMethod == m
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedPaymentMethod == m
                                    ? Colors.white
                                    : context.cs.onSurface,
                              ),
                            ),
                            selected: _selectedPaymentMethod == m,
                            selectedColor: kPrimary,
                            backgroundColor: context.cs.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(
                              color: _selectedPaymentMethod == m
                                  ? kPrimary
                                  : context.cs.outlineVariant,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedPaymentMethod =
                                    _selectedPaymentMethod == m ? '' : m;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

          // Save button
          if (itemRows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveInvoice,
                  icon: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.cs.surface,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _isEditing ? 'Update Invoice' : 'Save & Share Invoice',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.cs.primary,
                    foregroundColor: context.cs.onPrimary,
                    disabledBackgroundColor: context.cs.surfaceContainerHighest,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          if (itemRows.isEmpty) const SizedBox(height: 12),
        ],
      );
  }

  Widget _webSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.cs.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildWebMiniMetricCard({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment method ──
  String _selectedPaymentMethod = '';
  static const List<String> _paymentMethods = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque',
    'Other',
  ];

  // ── Khata-style Total Section ──
  bool _isReceived = false;

  Widget _buildPinnedTotalStrip(
    double grandTotal,
    double amountReceived,
    double balanceDue,
  ) {
    final cs = context.cs;
    final cardColor = _mobileCardColor(context);
    final borderColor = _mobileBorderColor(context);
    final isPaid = balanceDue <= 0 && grandTotal > 0;
    final isPartial = amountReceived > 0 && balanceDue > 0;
    final statusColor = isPaid
        ? const Color(0xFF16A34A)
        : isPartial
        ? const Color(0xFFD97706)
        : const Color(0xFFDC2626);
    final statusBg = isPaid
        ? (context.isDark
              ? const Color(0xFF16A34A).withAlpha(28)
              : const Color(0xFFF0FDF4))
        : isPartial
        ? (context.isDark
              ? const Color(0xFFD97706).withAlpha(28)
              : const Color(0xFFFFFBEB))
        : (context.isDark
              ? const Color(0xFFDC2626).withAlpha(28)
              : const Color(0xFFFEF2F2));
    final statusLabel = isPaid
        ? 'Paid'
        : isPartial
        ? 'Partial'
        : 'Unpaid';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: _mobileCardShadow(context, emphasized: true),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: context.isDark ? 0.14 : 0.03),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Grand Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  _currencyFormat.format(grandTotal),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isReceived = !_isReceived;
                      if (_isReceived) {
                        _receivedController.text = grandTotal.toStringAsFixed(2);
                      } else {
                        _receivedController.clear();
                      }
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _isReceived,
                            onChanged: (v) {
                              setState(() {
                                _isReceived = v ?? false;
                                if (_isReceived) {
                                  _receivedController.text = grandTotal.toStringAsFixed(2);
                                } else {
                                  _receivedController.clear();
                                }
                              });
                            },
                            activeColor: const Color(0xFF16A34A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Received',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _receivedController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      prefixText: '\u20b9 ',
                      prefixStyle: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerLow.withValues(
                        alpha: context.isDark ? 0.7 : 0.85,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: kPrimary,
                          width: 1.5,
                        ),
                      ),
                      hintText: '0',
                      hintStyle: const TextStyle(
                        color: Color(0xFFBDBDBD),
                        fontSize: 13,
                      ),
                    ),
                    onChanged: (val) => _onReceivedAmountChanged(val, grandTotal),
                  ),
                ),
              ],
            ),
          ),
          if (amountReceived > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode of Payment',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _paymentMethods
                        .map(
                          (m) => ChoiceChip(
                            label: Text(
                              m,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _selectedPaymentMethod == m
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedPaymentMethod == m
                                    ? Colors.white
                                    : cs.onSurface,
                              ),
                            ),
                            selected: _selectedPaymentMethod == m,
                            selectedColor: kPrimary,
                            backgroundColor: cs.surfaceContainerLow.withValues(
                              alpha: context.isDark ? 0.82 : 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(
                              color: _selectedPaymentMethod == m
                                  ? kPrimary
                                  : borderColor,
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onSelected: (_) {
                              setState(() {
                                _selectedPaymentMethod =
                                    _selectedPaymentMethod == m ? '' : m;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (!isPaid) ...[
                  Text(
                    'Balance: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    _currencyFormat.format(balanceDue),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Fully Paid',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
              ],
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
        color: _mobileCardColor(context),
        border: Border(
          top: BorderSide(color: _mobileBorderColor(context, strong: true)),
        ),
        boxShadow: _mobileCardShadow(context, emphasized: true),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveInvoice,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 20),
            label: Text(_isEditing ? 'Update' : 'Save & Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              disabledBackgroundColor: kSurfaceDim,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Vyapar-style total section (scrollable) ────────────────────────────

  // ── Invoice No. + Date row ────────────────────────────────────────────────

  Widget _summaryChip(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    );
  }

  Widget _buildInvoiceNoDateRow(AppStrings s) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice No.',
                  style: TextStyle(
                    fontSize: 12,
                    color: kPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Auto',
                      style: TextStyle(
                        fontSize: 15,
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: _mobileBorderColor(context)),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yy').format(selectedDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 36, color: _mobileBorderColor(context)),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _pickDueDate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yy').format(_dueDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
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
    final cs = context.cs;
    return TextFormField(
      controller: _customerPhoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        labelStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerLow.withValues(
          alpha: context.isDark ? 0.65 : 0.7,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _mobileBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _mobileBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
      style: TextStyle(fontSize: 14, color: cs.onSurface),
    );
  }

  // ── More customer fields toggle ────────────────────────────────────────────

  Widget _buildMoreCustomerToggle() {
    return InkWell(
      onTap: () =>
          setState(() => _showMoreCustomerFields = !_showMoreCustomerFields),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showMoreCustomerFields
                  ? Icons.expand_less_rounded
                  : Icons.more_horiz_rounded,
              size: 18,
              color: kPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              _showMoreCustomerFields ? 'Less' : 'More',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerAddressField() {
    final cs = context.cs;
    return TextFormField(
      controller: _customerAddressController,
      maxLines: 1,
      decoration: InputDecoration(
        labelText: 'Address',
        labelStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerLow.withValues(
          alpha: context.isDark ? 0.65 : 0.7,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _mobileBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _mobileBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
      style: TextStyle(fontSize: 14, color: cs.onSurface),
    );
  }

  Widget _buildCustomerEmailField() {
    final cs = context.cs;
    return TextFormField(
      controller: _customerEmailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerLow.withValues(
          alpha: context.isDark ? 0.65 : 0.7,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _mobileBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _mobileBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
      style: TextStyle(fontSize: 14, color: cs.onSurface),
    );
  }

  Widget _buildCustomerGstinField() {
    final cs = context.cs;
    return TextFormField(
      controller: _customerGstinController,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: 'GSTIN',
        labelStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        filled: true,
        fillColor: cs.surfaceContainerLow.withValues(
          alpha: context.isDark ? 0.65 : 0.7,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _mobileBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _mobileBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
      style: TextStyle(fontSize: 14, color: cs.onSurface),
    );
  }

  // ── Customer section ──────────────────────────────────────────────────────

  Widget _buildCustomerSection(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = context.cs;
    final hasError =
        _showClientValidationError &&
        _customerNameController.text.trim().isEmpty;

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
              hintStyle: const TextStyle(
                fontSize: 14,
                color: kTextTertiary,
                fontWeight: FontWeight.w400,
              ),
              labelStyle: TextStyle(
                fontSize: 14,
                color: hasError ? const Color(0xFFEF4444) : cs.onSurfaceVariant,
              ),
              filled: true,
              fillColor: cs.surfaceContainerLow.withValues(
                alpha: context.isDark ? 0.65 : 0.7,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFEF4444)
                      : _mobileBorderColor(context),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFEF4444)
                      : _mobileBorderColor(context),
                  width: hasError ? 1.5 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kPrimary, width: 1.5),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!kIsWeb)
                    IconButton(
                      icon: Icon(
                        Icons.contacts_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      tooltip: 'Pick from phone contacts',
                      onPressed: _pickPhoneContact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.person_search_rounded,
                      size: 20,
                      color: kPrimary,
                    ),
                    tooltip: 'Pick from saved customers',
                    onPressed: _pickCustomer,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
              ),
            ),
            style: TextStyle(fontSize: 14, color: cs.onSurface),
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
            child: Text(
              'Customer name is required',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ── Vyapar-style item card ──────────────────────────────────────────────────

  Widget _buildConfirmedItemCard(int index, AppStrings s) {
    final cs = context.cs;
    final row = itemRows[index];
    final name = row['desc']!.text.trim();
    final qty = nu.parseDouble(row['qty']!.text) ?? 0;
    final price = nu.parseDouble(row['price']!.text) ?? 0;
    final unit = row['unit']!.text.trim().isEmpty
        ? _defaultItemUnit
        : row['unit']!.text.trim();
    final itemDiscountPct = (nu.parseDouble(row['discount']?.text ?? '') ?? 0)
        .clamp(0, 100);
    final rawTotal = qty * price;
    final discAmt = rawTotal * itemDiscountPct / 100;
    final total = rawTotal - discAmt;
    final gstRate = nu.parseDouble(row['gstRate']!.text) ?? 0;
    final qtyStr = qty == qty.truncateToDouble()
        ? qty.toInt().toString()
        : qty.toString();

    return GestureDetector(
      onTap: () => _editItem(index),
      onLongPress: () => _removeItemRow(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _mobileCardColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _mobileBorderColor(context), width: 0.8),
          boxShadow: _mobileCardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _currencyFormat.format(total),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Item Subtotal',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$qtyStr $unit x ${price.toStringAsFixed(0)} = ${_currencyFormat.format(rawTotal)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (itemDiscountPct > 0) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    'Discount (%): ${itemDiscountPct.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _currencyFormat.format(discAmt),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
            ],
            if (_gstEnabled && gstRate > 0) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    'Tax : ${gstRate.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    _currencyFormat.format(total * gstRate / 100),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Item card ─────────────────────────────────────────────────────────────

  Widget _buildItemCard(BuildContext context, int index, AppStrings s) {
    return _buildConfirmedItemCard(index, s);
  }

  // ── Add Item button ──────────────────────────────────────────────────────

  Widget _buildAddItemButtons() {
    return GestureDetector(
      onTap: _addItemRow,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: context.isDark ? 0.14 : 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: kPrimary.withValues(alpha: context.isDark ? 0.32 : 0.18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle, color: Color(0xFF43A047), size: 20),
            const SizedBox(width: 6),
            Text(
              'Add Items',
              style: TextStyle(
                color: context.isDark
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFF43A047),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  // ── Received amount validation ─────────────────────────────────────────────

  void _onReceivedAmountChanged(String val, double grandTotal) {
    final amt = double.tryParse(val) ?? 0;
    if (amt > grandTotal && grandTotal > 0) {
      _receivedController.text = grandTotal.toStringAsFixed(2);
      _receivedController.selection = TextSelection.fromPosition(
        TextPosition(offset: _receivedController.text.length),
      );
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Amount received cannot exceed ₹${grandTotal.toStringAsFixed(2)}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
    }
    setState(() {
      final clamped = amt.clamp(0.0, grandTotal);
      _isReceived = clamped >= grandTotal && grandTotal > 0;
    });
  }

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
            _showCustomerSuggestions =
                clients.isNotEmpty && _customerNameFocus.hasFocus;
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: client.phone.isNotEmpty
                        ? Text(
                            client.phone,
                            style: const TextStyle(fontSize: 12),
                          )
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
      _customerAddressController.text = client.address;
      _customerEmailController.text = client.email;
      _customerGstinController.text = client.gstin;
      _showCustomerSuggestions = false;
      _showClientValidationError = false;
      if (client.address.isNotEmpty ||
          client.email.isNotEmpty ||
          client.gstin.isNotEmpty) {
        _showMoreCustomerFields = true;
      }
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
        // Keep the same gap between invoice date and due date.
        final gap = _dueDate.difference(selectedDate);
        selectedDate = pickedDate;
        _dueDate = pickedDate.add(gap.isNegative ? _defaultPaymentTerm : gap);
      });
    }
  }

  Future<void> _pickDueDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: selectedDate,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _dueDate = pickedDate;
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
        fullContact = await FlutterContacts.getContact(
          contact.id,
          withProperties: true,
          withAccounts: false,
          withPhoto: false,
        );
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
        SnackBar(
          content: Text(
            userFriendlyError(e, fallback: 'Could not access contacts.'),
          ),
        ),
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
      _customerAddressController.text = selectedClient.address;
      _customerEmailController.text = selectedClient.email;
      _customerGstinController.text = selectedClient.gstin;
      _showClientValidationError = false;
      if (selectedClient.address.isNotEmpty ||
          selectedClient.email.isNotEmpty ||
          selectedClient.gstin.isNotEmpty) {
        _showMoreCustomerFields = true;
      }
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
      row['desc']!.text = product.name;
      row['price']!.text = product.unitPrice > 0
          ? product.unitPrice.toString()
          : '';
      row['unit']!.text = _normalizeItemUnit(product.unit);
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

  void _editItem(int index) {
    _openItemPage(index);
  }

  /// Opens the Add/Edit item as a full page. If [index] is null, adds a new item.
  /// On web expanded layout, shows inline form instead of navigating.
  Future<void> _openItemPage([int? index]) async {
    final isNew = index == null;
    if (isNew) {
      final focusNode = FocusNode();
      final qtyFocusNode = FocusNode();
      itemRows.add(_createItemRowControllers());
      _showAdvanced.add(false);
      // On web, new draft rows are unconfirmed until user clicks "Add to Invoice"
      final isWebWide =
          kIsWeb && windowSizeOf(context) != WindowSize.compact;
      _itemConfirmed.add(!isWebWide);
      _itemDescFocusNodes.add(focusNode);
      _itemQtyFocusNodes.add(qtyFocusNode);
      index = itemRows.length - 1;
    }

    // Web layout: show inline form instead of navigating
    if (kIsWeb && windowSizeOf(context) != WindowSize.compact) {
      setState(() => _webEditingItemIndex = index);
      return;
    }

    final rowIndex = index;
    final row = itemRows[rowIndex];
    final s = AppStrings.of(context);

    final confirmed = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => _ItemFormPage(
          row: row,
          index: rowIndex,
          itemUnitOptions: _itemUnitOptions,
          defaultItemUnit: _defaultItemUnit,
          customUnitValue: _customUnitValue,
          gstRate: _gstRate,
          currencyFormat: _currencyFormat,
          s: s,
        ),
        transitionsBuilder: (_, anim, _, child) {
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
        _itemConfirmed[rowIndex] = true;
        _showCustomerFields = false;
        if (itemGstRate > 0) _gstEnabled = true;
      });
      _autoSaveRowAsProduct(row);
    } else if (isNew) {
      _removeItemRow(rowIndex);
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
      'productId':
          TextEditingController(), // tracks linked product for inventory
    };
  }

  void _disposeRowControllers(Map<String, TextEditingController> row) {
    for (final controller in row.values) {
      controller.dispose();
    }
  }

  /// Auto-saves a single item row as a product (skips if name already exists).
  Future<void> _autoSaveRowAsProduct(
    Map<String, TextEditingController> row,
  ) async {
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

      await productService.saveProduct(
        Product(
          id: '',
          name: name,
          unitPrice: price,
          unit: unit,
          hsnCode: row['hsn']!.text.trim(),
          gstRate: gstRate,
          gstApplicable: gstRate > 0,
          trackInventory: false,
        ),
      );
    } catch (_) {
      // Silent — don't block UI for auto-save failures
    }
  }

  double _calculateSubtotal() {
    var total = 0.0;

    for (final row in itemRows) {
      final qty = nu.parseDouble(row['qty']!.text) ?? 0;
      final price = nu.parseDouble(row['price']!.text) ?? 0;
      final discPct = (nu.parseDouble(row['discount']?.text ?? '') ?? 0).clamp(
        0,
        100,
      );
      final lineTotal = qty * price;
      total += lineTotal - (lineTotal * discPct / 100);
    }

    return total;
  }


  Future<void> _saveInvoice() async {
    // FIX S-1: Guard against double-tap immediately, before any async work.
    // Previous location was after multiple awaits, leaving a race window.
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    final isFormValid = _formKey.currentState?.validate() ?? false;

    if (!isFormValid) {
      setState(() { _isSaving = false; });
      return;
    }

    final customerName = _customerNameController.text.trim();
    if (customerName.isEmpty) {
      setState(() {
        _showClientValidationError = true;
        _isSaving = false;
      });
      return;
    }

    if (itemRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).createAddLineItem)),
      );
      setState(() { _isSaving = false; });
      return;
    }

    final subtotal = _calculateSubtotal();
    final discountValue = nu.parseDouble(_discountController.text.trim()) ?? 0;
    final discountError = _validateDiscount(subtotal, discountValue);

    if (discountError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(discountError)));
      setState(() { _isSaving = false; });
      return;
    }

    final invoiceDate = selectedDate;

    final items = itemRows.map((row) {
      return LineItem(
        description: row['desc']!.text.trim(),
        hsnCode: row['hsn']!.text.trim(),
        quantity: nu.parseDouble(row['qty']!.text.trim()) ?? 0,
        unitPrice: nu.parseDouble(row['price']!.text.trim()) ?? 0,
        unit: _normalizeItemUnit(row['unit']!.text),
        gstRate: _clampGstRate(
          nu.parseDouble(row['gstRate']!.text.trim()) ?? _gstRate,
        ),
        discountPercent: (nu.parseDouble(row['discount']?.text ?? '') ?? 0)
            .clamp(0, 100)
            .toDouble(),
        productId: row['productId']!.text.trim(),
      );
    }).toList();
    final selectedClient = _selectedClient;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).createSignInRequired)),
      );
      setState(() { _isSaving = false; });
      return;
    }

    // ── Role permission gate ──
    if (!_isEditing && !TeamService.instance.can.canCreateInvoice) {
      if (!mounted) { setState(() { _isSaving = false; }); return; }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You don\'t have permission to create invoices.'),
        ),
      );
      setState(() { _isSaving = false; });
      return;
    }
    if (_isEditing && !TeamService.instance.can.canEditInvoice) {
      if (!mounted) { setState(() { _isSaving = false; }); return; }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You don\'t have permission to edit invoices.'),
        ),
      );
      setState(() { _isSaving = false; });
      return;
    }

    // ── Plan gate: check invoice limit (skip for edits) ──
    if (!_isEditing) {
      try {
        final invoiceCount = await UsageTrackingService.instance
            .getInvoiceCount();
        if (!PlanService.instance.canCreateInvoice(invoiceCount)) {
          if (!mounted) { setState(() { _isSaving = false; }); return; }
          await LimitReachedDialog.show(
            context,
            title: 'Invoice Limit Reached',
            message:
                'You\'ve used $invoiceCount/${PlanService.instance.currentLimits.maxInvoicesPerMonth} invoices this month. Upgrade to create more.',
            featureName: 'more invoices',
          );
          setState(() { _isSaving = false; });
          return;
        }
      } catch (e) {
        // If usage check fails (e.g. Firestore unavailable), allow the
        // invoice to be created rather than blocking the user.
        debugPrint('[PlanGate] Usage check failed, allowing save: $e');
      }
    }

    // Auto-determine payment status using the Invoice model's own computation.
    // This avoids duplicating the GST/discount calculation logic —
    // the Invoice model is the single source of truth for financials.
    final receivedRaw = (nu.parseDouble(_receivedController.text.trim()) ?? 0)
        .clamp(0.0, double.infinity);
    final statusCheckInvoice = Invoice(
      id: '',
      ownerId: '',
      invoiceNumber: '',
      clientId: '',
      clientName: customerName,
      items: items,
      createdAt: invoiceDate,
      status: InvoiceStatus.pending,
      discountType: discountValue > 0 ? _selectedDiscountType : null,
      discountValue: discountValue > 0 ? discountValue : 0,
      gstEnabled: _gstEnabled,
      gstRate: _gstRate,
      gstType: _gstType,
      amountReceived: receivedRaw,
    );
    final computedGrand = statusCheckInvoice.grandTotal;
    final received = receivedRaw.clamp(0.0, computedGrand);
    InvoiceStatus resolvedStatus;
    if (received >= computedGrand && computedGrand > 0) {
      resolvedStatus = InvoiceStatus.paid;
    } else if (received > 0) {
      resolvedStatus = InvoiceStatus.partiallyPaid;
    } else {
      resolvedStatus = InvoiceStatus.pending;
    }

    final dueDate = _dueDate;

    try {
      _saveLastUsedGstSettings(); // fire-and-forget

      // Run client save and invoice number reservation in parallel
      // Update existing client with any changed fields, or create new one
      final Future<Client?> clientFuture =
          (selectedClient == null && customerName.isNotEmpty)
          ? ClientService().saveClient(
              Client(
                id: '',
                name: customerName,
                phone: _customerPhoneController.text.trim(),
                address: _customerAddressController.text.trim(),
                email: _customerEmailController.text.trim(),
                gstin: _customerGstinController.text.trim(),
              ),
            )
          : selectedClient != null
          ? ClientService().saveClient(
              selectedClient.copyWith(
                phone: _customerPhoneController.text.trim(),
                address: _customerAddressController.text.trim(),
                email: _customerEmailController.text.trim(),
                gstin: _customerGstinController.text.trim(),
              ),
            )
          : Future.value(selectedClient);

      var resolvedClient = await clientFuture;
      if (resolvedClient != null) {
        _selectedClient = resolvedClient;
      }

      String invoiceId;
      String invoiceNumber;

      // Resolve creator identity for team tracking
      final ts = TeamService.instance;
      final actualUid = ts.getActualUserId();
      final profile = ProfileService.instance.cachedProfile;
      final isTeamMember = ts.isTeamMember;
      // For owner: use signatoryName from profile (if set), else displayName.
      // For team members: use the name given by the owner during invitation
      // (stored in userTeamMap.displayName), falling back to Auth displayName.
      final creatorName = isTeamMember
          ? (ts.memberDisplayName.isNotEmpty
              ? ts.memberDisplayName
              : (currentUser.displayName ??
                  currentUser.phoneNumber ??
                  ''))
          : ((profile?.signatoryName.isNotEmpty == true
                  ? profile!.signatoryName
                  : null) ??
              currentUser.displayName ??
              profile?.storeName ??
              currentUser.phoneNumber ??
              '');
      // Signature URL no longer used — text-based signatory name replaces image.
      const creatorSigUrl = '';

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
          customerGstin: _customerGstinController.text.trim().isNotEmpty
              ? _customerGstinController.text.trim().toUpperCase()
              : (resolvedClient?.gstin ?? ''),
          items: items,
          createdAt: editInv.createdAt,
          dueDate: dueDate,
          status: resolvedStatus,
          discountType: discountValue > 0 ? _selectedDiscountType : null,
          discountValue: discountValue > 0 ? discountValue : 0,
          gstEnabled: _gstEnabled,
          gstRate: _gstRate,
          gstType: _gstType,
          amountReceived: received,
          paymentMethod: _selectedPaymentMethod,
          // Preserve original creator identity on edit
          createdByUid: editInv.createdByUid.isNotEmpty
              ? editInv.createdByUid
              : actualUid,
          createdByName: editInv.createdByName.isNotEmpty
              ? editInv.createdByName
              : creatorName,
          createdBySignatureUrl: editInv.createdBySignatureUrl.isNotEmpty
              ? editInv.createdBySignatureUrl
              : creatorSigUrl,
        );

        // Atomic update: invoice + stock reversal + stock deduction in one batch.
        final oldDeductions = StockDeduction.fromLineItems(editInv.items);
        final newDeductions = StockDeduction.fromLineItems(items);
        await FirebaseService().updateInvoiceWithStock(
          updatedInvoice,
          oldDeductions: oldDeductions,
          newDeductions: newDeductions,
        );
        invoiceId = editInv.id;
      } else {
        // New invoice — use pre-reserved number (already fetched in background)
        invoiceNumber =
            await (_preReservedNumber ??
                InvoiceNumberService().reserveNextInvoiceNumber(
                  year: invoiceDate.year,
                ));

        final savedInvoice = Invoice(
          id: '',
          ownerId: TeamService.instance.getEffectiveOwnerId(),
          invoiceNumber: invoiceNumber,
          clientId: resolvedClient?.id ?? '',
          clientName: customerName,
          customerGstin: _customerGstinController.text.trim().isNotEmpty
              ? _customerGstinController.text.trim().toUpperCase()
              : (resolvedClient?.gstin ?? ''),
          items: items,
          createdAt: invoiceDate,
          dueDate: dueDate,
          status: resolvedStatus,
          discountType: discountValue > 0 ? _selectedDiscountType : null,
          discountValue: discountValue > 0 ? discountValue : 0,
          gstEnabled: _gstEnabled,
          gstRate: _gstRate,
          gstType: _gstType,
          amountReceived: received,
          paymentMethod: _selectedPaymentMethod,
          createdByUid: actualUid,
          createdByName: creatorName,
          createdBySignatureUrl: creatorSigUrl,
        );

        // Atomic write: invoice + client upsert + stock deductions in one batch.
        final stockDeductions = StockDeduction.fromLineItems(items);
        invoiceId = await FirebaseService().addInvoiceWithStock(
          savedInvoice,
          stockDeductions: stockDeductions,
        );
        UsageTrackingService.instance
            .invalidateCache(); // refreshed by server-side reconciliation
        ReviewService.instance.onInvoiceCreated(); // fire-and-forget
      }

      HapticFeedback.mediumImpact();

      // Let the user know if their save is queued (no network right now)
      if (ConnectivityService.instance.isOffline && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.cloud_queue_rounded,
                  color: context.cs.surface,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved locally — will sync when you reconnect',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFB45309),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      final finalInvoice = Invoice(
        id: invoiceId,
        ownerId: TeamService.instance.getEffectiveOwnerId(),
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
        // Preserve original creator on edit; set on new
        createdByUid: _isEditing
            ? (widget.editingInvoice!.createdByUid.isNotEmpty
                  ? widget.editingInvoice!.createdByUid
                  : actualUid)
            : actualUid,
        createdByName: _isEditing
            ? (widget.editingInvoice!.createdByName.isNotEmpty
                  ? widget.editingInvoice!.createdByName
                  : creatorName)
            : creatorName,
        createdBySignatureUrl: _isEditing
            ? (widget.editingInvoice!.createdBySignatureUrl)
            : creatorSigUrl,
      );

      if (!mounted) return;

      if (_isEditing) {
        Navigator.pop(context, finalInvoice);
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) =>
                InvoiceDetailsScreen(invoice: finalInvoice),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (_, anim, _, child) =>
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
            AppStrings.of(context).createFailedSave(error.toString()),
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

  Future<void> _showCustomUnitDialog(
    Map<String, TextEditingController> row,
  ) async {
    final controller = TextEditingController(
      text: _itemUnitOptions.contains(row['unit']!.text.toLowerCase())
          ? ''
          : row['unit']!.text,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Custom Unit',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
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
      if (diff < minDiff) {
        minDiff = diff;
        nearest = valid;
      }
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

  String? _validateDiscount(double subtotal, double discountValue) {
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
  });

  final Map<String, TextEditingController> row;
  final int index;
  final List<String> itemUnitOptions;
  final String defaultItemUnit;
  final String customUnitValue;
  final double gstRate;
  final NumberFormat currencyFormat;
  final AppStrings s;

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

  // Product autocomplete
  final FocusNode _descFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final LayerLink _descLayerLink = LayerLink();
  OverlayEntry? _descOverlay;
  List<Product> _productSuggestions = [];
  StreamSubscription<List<Product>>? _productSearchSub;
  Timer? _productSearchTimer;

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

    _desc.addListener(_onDescChanged);
    _descFocusNode.addListener(_onDescFocusChanged);

    // Show advanced if any advanced field has data
    if (_hsn.text.isNotEmpty ||
        _discount.text.isNotEmpty ||
        (nu.parseDouble(row['gstRate']!.text) ?? 0) > 0) {
      _showAdvanced = true;
    }
  }

  @override
  void dispose() {
    _desc.removeListener(_onDescChanged);
    _descFocusNode.removeListener(_onDescFocusChanged);
    _descFocusNode.dispose();
    _qtyFocusNode.dispose();
    _productSearchSub?.cancel();
    _productSearchTimer?.cancel();
    _removeProductOverlay();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter item name')));
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

  Widget _calcRow(
    String label,
    String value, {
    bool bold = false,
    bool isNeg = false,
    bool isPos = false,
  }) {
    final color = isNeg
        ? context.cs.error
        : isPos
        ? Color(0xFF2E7D32)
        : context.cs.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.cs.onSurfaceVariant,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: bold ? kPrimary : color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _onDescChanged() {
    final query = _desc.text.trim();
    _productSearchTimer?.cancel();
    if (query.isEmpty) {
      _removeProductOverlay();
      _productSearchSub?.cancel();
      setState(() => _productSuggestions = []);
      return;
    }
    _productSearchTimer = Timer(const Duration(milliseconds: 280), () {
      _productSearchSub?.cancel();
      _productSearchSub = ProductService()
          .getProductsStream(searchQuery: query, limit: 6)
          .listen((products) {
            if (!mounted) return;
            // Filter: only show if not an exact match already selected
            final filtered = products
                .where(
                  (p) =>
                      p.name.trim().toLowerCase() != query.toLowerCase() ||
                      _price.text.isEmpty,
                )
                .toList();
            setState(() => _productSuggestions = filtered);
            if (filtered.isNotEmpty && _descFocusNode.hasFocus) {
              _showProductOverlay();
            } else {
              _removeProductOverlay();
            }
          });
    });
  }

  void _onDescFocusChanged() {
    if (!_descFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _removeProductOverlay();
      });
    } else if (_productSuggestions.isNotEmpty) {
      _showProductOverlay();
    }
  }

  void _showProductOverlay() {
    _removeProductOverlay();
    final overlay = Overlay.of(context);
    _descOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        width: MediaQuery.of(ctx).size.width - 32,
        child: CompositedTransformFollower(
          link: _descLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 54),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: context.cs.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: _productSuggestions.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 12, endIndent: 12),
                itemBuilder: (ctx, i) {
                  final p = _productSuggestions[i];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.initials,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kPrimary,
                        ),
                      ),
                    ),
                    title: Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      p.priceLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: p.gstApplicable
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.cs.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'GST ${p.gstRate.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: kPrimary,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => _selectProduct(p),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_descOverlay!);
  }

  void _removeProductOverlay() {
    _descOverlay?.remove();
    _descOverlay = null;
  }

  void _selectProduct(Product product) {
    _removeProductOverlay();
    setState(() {
      _desc.text = product.name;
      widget.row['productId']!.text = product.id;
      if (product.unitPrice > 0) _price.text = product.unitPrice.toString();
      if (product.unit.isNotEmpty) _unit.text = product.unit;
      if (product.hsnCode.isNotEmpty) {
        _hsn.text = product.hsnCode;
        _showAdvanced = true;
      }
      if (product.gstApplicable && product.gstRate > 0) {
        _gstRate.text = product.gstRate.toStringAsFixed(0);
        _showAdvanced = true;
      }
      _productSuggestions = [];
    });
    _descFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _qtyFocusNode.requestFocus();
    });
  }

  OutlineInputBorder _editorBorder(
    BuildContext context, {
    Color? color,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color:
            color ??
            context.cs.outlineVariant.withValues(
              alpha: context.isDark ? 0.42 : 0.74,
            ),
        width: width,
      ),
    );
  }

  InputDecoration _editorInputDecoration(
    BuildContext context, {
    String? labelText,
    Widget? label,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    final cs = context.cs;
    return InputDecoration(
      labelText: labelText,
      label: label,
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 14,
        color: cs.onSurfaceVariant.withValues(alpha: 0.78),
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
      filled: true,
      fillColor: cs.surfaceContainerLow.withValues(
        alpha: context.isDark ? 0.72 : 0.8,
      ),
      border: _editorBorder(context),
      enabledBorder: _editorBorder(context),
      focusedBorder: _editorBorder(context, color: kPrimary, width: 1.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final cardColor = cs.surfaceContainerLowest.withValues(
      alpha: context.isDark ? 0.94 : 1,
    );
    final borderColor = cs.outlineVariant.withValues(
      alpha: context.isDark ? 0.4 : 0.72,
    );
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
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
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${widget.index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _desc.text.trim().isEmpty ? 'New Item' : _desc.text.trim(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saveItem,
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kPrimary,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.16 : 0.06,
              ),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
            CompositedTransformTarget(
              link: _descLayerLink,
              child: TextField(
                controller: _desc,
                focusNode: _descFocusNode,
                autofocus: _desc.text.isEmpty,
                textCapitalization: TextCapitalization.words,
                decoration: _editorInputDecoration(
                  context,
                  label: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'Item Name '),
                        TextSpan(
                          text: '*',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  hintText: 'e.g. Notebook, Rice...',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_productSuggestions.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.inventory_2_rounded,
                          color: kPrimary,
                          size: 20,
                        ),
                        tooltip: 'Pick from products',
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: () async {
                          _removeProductOverlay();
                          final product = await Navigator.push<Product>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ProductsScreen(selectionMode: true),
                            ),
                          );
                          if (product == null || !mounted) return;
                          _selectProduct(product);
                        },
                      ),
                    ],
                  ),
                ),
                style: TextStyle(color: cs.onSurface),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qty,
                    focusNode: _qtyFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: _editorInputDecoration(
                      context,
                      labelText: 'Qty',
                    ),
                    style: TextStyle(color: cs.onSurface),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Builder(
                    builder: (_) {
                      final currentUnit = _unit.text.isEmpty
                          ? widget.defaultItemUnit
                          : _unit.text;
                      final isCustom = !widget.itemUnitOptions.contains(
                        currentUnit.toLowerCase(),
                      );
                      return DropdownButtonFormField<String>(
                        initialValue: isCustom
                            ? widget.customUnitValue
                            : currentUnit.toLowerCase(),
                        isExpanded: true,
                        decoration: _editorInputDecoration(
                          context,
                          labelText: 'Unit',
                        ),
                        items: [
                          ...widget.itemUnitOptions.map(
                            (u) => DropdownMenuItem(
                              value: u,
                              child: Text(u, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          DropdownMenuItem(
                            value: widget.customUnitValue,
                            child: Text(
                              isCustom ? 'Custom: $currentUnit' : 'Custom...',
                              style: TextStyle(
                                color: kPrimary,
                                fontWeight: isCustom
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _editorInputDecoration(
                      context,
                      labelText: 'Price (₹)',
                    ),
                    style: TextStyle(color: cs.onSurface),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _discount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _editorInputDecoration(
                context,
                labelText: 'Discount (%)',
                hintText: 'e.g. 10',
                suffixText: '%',
                prefixIcon: Icon(
                  Icons.discount_outlined,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ),
              style: TextStyle(color: cs.onSurface),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Builder(
              builder: (_) {
                final gstOn = (nu.parseDouble(_gstRate.text) ?? 0) > 0;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: gstOn
                          ? kPrimary.withValues(alpha: 0.3)
                          : borderColor,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: gstOn
                        ? kPrimary.withValues(
                            alpha: context.isDark ? 0.14 : 0.03,
                          )
                        : cardColor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.percent_rounded,
                            color: cs.onSurfaceVariant,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'GST',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: gstOn,
                            activeTrackColor: kPrimary,
                            activeThumbColor: Colors.white,
                            onChanged: (_) => setState(() {
                              _gstRate.text = gstOn
                                  ? '0'
                                  : widget.gstRate.toStringAsFixed(0);
                            }),
                          ),
                        ],
                      ),
                      if (gstOn) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [5.0, 12.0, 18.0, 28.0].map((rate) {
                            final current = nu.parseDouble(_gstRate.text) ?? 0;
                            final selected = current == rate;
                            return GestureDetector(
                              onTap: () => setState(
                                () => _gstRate.text = rate.toStringAsFixed(0),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? kPrimary
                                      : cs.surfaceContainerHigh.withValues(
                                          alpha: context.isDark ? 0.75 : 1,
                                        ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${rate.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : cs.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            Builder(
              builder: (_) {
                final qty = nu.parseDouble(_qty.text) ?? 0;
                final price = nu.parseDouble(_price.text) ?? 0;
                final rawTotal = qty * price;
                final discPct = (nu.parseDouble(_discount.text) ?? 0).clamp(
                  0.0,
                  100.0,
                );
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
                    color: kPrimary.withValues(
                      alpha: context.isDark ? 0.14 : 0.04,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kPrimary.withValues(
                        alpha: context.isDark ? 0.28 : 0.15,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      _calcRow(
                        'Base Amount',
                        '₹${rawTotal.toStringAsFixed(2)}',
                      ),
                      if (discPct > 0) ...[
                        _calcRow(
                          'Discount (${discPct.toStringAsFixed(0)}%)',
                          '- ₹${discAmt.toStringAsFixed(2)}',
                          isNeg: true,
                        ),
                        _calcRow(
                          'After Discount',
                          '₹${afterDisc.toStringAsFixed(2)}',
                        ),
                      ],
                      if (gstPct > 0)
                        _calcRow(
                          'GST (${gstPct.toStringAsFixed(0)}%)',
                          '+ ₹${gstAmt.toStringAsFixed(2)}',
                          isPos: true,
                        ),
                      const Divider(height: 12),
                      _calcRow(
                        'Item Total',
                        '₹${finalTotal.toStringAsFixed(2)}',
                        bold: true,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAdvanced
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: kPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showAdvanced ? 'Hide HSN code' : 'Add HSN / SAC code',
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
            if (_showAdvanced) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _hsn,
                textCapitalization: TextCapitalization.characters,
                decoration: _editorInputDecoration(
                  context,
                  labelText: 'HSN / SAC Code',
                  hintText: 'e.g. 4820',
                ),
                style: TextStyle(color: cs.onSurface),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
