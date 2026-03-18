import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/utils/number_utils.dart' as nu;
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/line_item.dart';
import 'package:billeasy/screens/customer_form_screen.dart';
import 'package:billeasy/screens/customers_screen.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedClient = widget.initialClient;
    itemRows = [_createItemRowControllers()];
  }

  @override
  void dispose() {
    _discountController.dispose();
    for (final row in itemRows) {
      _disposeRowControllers(row);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final subtotal = _calculateSubtotal();
    final discountAmount = _calculateDiscountAmount(subtotal);
    final grandTotal = subtotal - discountAmount;

    return Scaffold(
      appBar: AppBar(title: Text(s.createTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCustomerSection(context),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: selectedDate == null
                            ? [const Color(0xFFFFF6DA), const Color(0xFFFFFBEF)]
                            : [Colors.teal.shade100, Colors.teal.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selectedDate == null
                            ? const Color(0xFFF1C24F)
                            : Colors.teal.shade300,
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (selectedDate == null
                                      ? const Color(0xFFF1C24F)
                                      : Colors.teal)
                                  .withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: selectedDate == null
                                ? const Color(0xFFFFE8A3)
                                : Colors.teal.shade600,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            size: 22,
                            color: selectedDate == null
                                ? const Color(0xFF8A5A16)
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.createInvoiceDate,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF123C85),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedDate == null
                                    ? s.createPickDate
                                    : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(selectedDate!),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: selectedDate == null
                                          ? const Color(0xFF8A5A16)
                                          : Colors.teal.shade900,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedDate == null
                                    ? s.createDateHintEmpty
                                    : s.createDateHintSelected,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.blueGrey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: selectedDate == null
                              ? const Color(0xFF8A5A16)
                              : Colors.teal.shade700,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
              ...List.generate(itemRows.length, (index) {
                final row = itemRows[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.createItemNumber(index + 1),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.teal.shade900,
                                    ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeItemRow(index),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: s.createDeleteItem,
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: row['desc'],
                          decoration: InputDecoration(
                            labelText: s.createProductLabel,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return s.createEnterProduct;
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 360;

                            final qtyField = TextFormField(
                              controller: row['qty'],
                              decoration: InputDecoration(
                                labelText: s.createQtyLabel,
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                              initialValue: _normalizeItemUnit(
                                row['unit']!.text,
                              ),
                              isExpanded: true,
                              items: _itemUnitOptions.map((unit) {
                                return DropdownMenuItem(
                                  value: unit,
                                  child: Text(
                                    unit,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                row['unit']!.text = _normalizeItemUnit(value);
                                setState(() {});
                              },
                              decoration: InputDecoration(
                                labelText: s.createUnitLabel,
                                border: const OutlineInputBorder(),
                              ),
                            );

                            final priceField = TextFormField(
                              controller: row['price'],
                              decoration: InputDecoration(
                                labelText: s.createUnitPriceLabel,
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addItemRow,
                  icon: const Icon(Icons.add),
                  label: Text(s.createAddItem),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.createInvoiceStatus,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: InvoiceStatus.values.map((status) {
                        final isSelected = _selectedStatus == status;

                        return ChoiceChip(
                          label: Text(_statusLabel(status, s)),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedStatus = status;
                            });
                          },
                          selectedColor: _statusBackgroundColor(status),
                          backgroundColor: Colors.grey.shade100,
                          side: BorderSide(
                            color: isSelected
                                ? _statusBorderColor(status)
                                : Colors.grey.shade300,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? _statusTextColor(status)
                                : Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.createDiscountTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: InvoiceDiscountType.values.map((discountType) {
                        final isSelected =
                            _selectedDiscountType == discountType;

                        return ChoiceChip(
                          label: Text(_discountTypeLabel(discountType, s)),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedDiscountType = discountType;
                            });
                          },
                          selectedColor: Colors.blue.shade50,
                          backgroundColor: Colors.grey.shade100,
                          side: BorderSide(
                            color: isSelected
                                ? Colors.blue.shade200
                                : Colors.grey.shade300,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.blue.shade900
                                : Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _discountController,
                      decoration: InputDecoration(
                        labelText:
                            _selectedDiscountType ==
                                InvoiceDiscountType.percentage
                            ? s.createDiscountPctField
                            : s.createDiscountOverallField,
                        hintText:
                            _selectedDiscountType ==
                                InvoiceDiscountType.percentage
                            ? s.createDiscountPctHint
                            : s.createDiscountOverallHint,
                        suffixText:
                            _selectedDiscountType ==
                                InvoiceDiscountType.percentage
                            ? '%'
                            : 'INR',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _discountPreviewText(subtotal, discountAmount, s),
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.createSummarySubtotal,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(subtotal),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            s.createSummaryDiscount,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            discountAmount > 0
                                ? '-${_currencyFormat.format(discountAmount)}'
                                : _currencyFormat.format(0),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: discountAmount > 0
                                  ? Colors.red.shade700
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            s.createSummaryGrandTotal,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(grandTotal),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
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
                    _isSaving ? s.createSavingInvoice : s.createSaveInvoice,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.teal.shade300,
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(60),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.createSaveHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.blueGrey.shade600,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSection(BuildContext context) {
    final s = AppStrings.of(context);
    final selectedClient = _selectedClient;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _showClientValidationError && selectedClient == null
                  ? Theme.of(context).colorScheme.error
                  : Colors.teal.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE4F7F8),
                foregroundColor: const Color(0xFF0F7D83),
                child: Text(
                  selectedClient?.initials ?? '+',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.createCustomerLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF123C85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedClient?.name ?? s.createSelectCustomer,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selectedClient == null
                            ? const Color(0xFF8A5A16)
                            : Colors.teal.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedClient == null
                          ? s.createCustomerHint
                          : selectedClient.subtitle,
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final shouldStackButtons = constraints.maxWidth < 360;

            final pickButton = OutlinedButton.icon(
              onPressed: _pickCustomer,
              icon: const Icon(Icons.groups_2_outlined),
              label: Text(
                selectedClient == null
                    ? s.createPickCustomer
                    : s.createChangeCustomer,
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            );

            final addButton = FilledButton.tonalIcon(
              onPressed: _addCustomer,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(s.createAddNew),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
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
        if (_showClientValidationError && selectedClient == null)
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
    final rawDiscount = nu.parseDouble(_discountController.text.trim()) ?? 0;

    if (rawDiscount <= 0 || subtotal <= 0) {
      return 0;
    }

    switch (_selectedDiscountType) {
      case InvoiceDiscountType.percentage:
        return (subtotal * (rawDiscount / 100)).clamp(0, subtotal).toDouble();
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
        SnackBar(content: Text(AppStrings.of(context).createAddLineItem)),
      );
      return;
    }

    final subtotal = _calculateSubtotal();
    final discountValue = nu.parseDouble(_discountController.text.trim()) ?? 0;
    final discountError = _validateDiscount(subtotal, discountValue);

    if (discountError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(discountError)));
      return;
    }

    final items = itemRows.map((row) {
      return LineItem(
        description: row['desc']!.text.trim(),
        quantity: nu.parseDouble(row['qty']!.text.trim()) ?? 0,
        unitPrice: nu.parseDouble(row['price']!.text.trim()) ?? 0,
        unit: _normalizeItemUnit(row['unit']!.text),
      );
    }).toList();
    final selectedClient = _selectedClient!;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).createSignInRequired)),
      );
      return;
    }

    final invoice = Invoice(
      id: '',
      ownerId: currentUser.uid,
      invoiceNumber:
          'BE-${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}',
      clientId: selectedClient.id,
      clientName: selectedClient.name,
      items: items,
      createdAt: selectedDate!,
      status: _selectedStatus,
      discountType: discountValue > 0 ? _selectedDiscountType : null,
      discountValue: discountValue > 0 ? discountValue : 0,
    );

    setState(() {
      _isSaving = true;
    });

    try {
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
        items: invoice.items,
        createdAt: invoice.createdAt,
        status: invoice.status,
        discountType: invoice.discountType,
        discountValue: invoice.discountValue,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailsScreen(invoice: savedInvoice),
        ),
      );
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
        return Colors.green.shade100;
      case InvoiceStatus.pending:
        return Colors.amber.shade100;
      case InvoiceStatus.overdue:
        return Colors.red.shade100;
    }
  }

  Color _statusBorderColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return Colors.green.shade300;
      case InvoiceStatus.pending:
        return Colors.amber.shade300;
      case InvoiceStatus.overdue:
        return Colors.red.shade300;
    }
  }

  Color _statusTextColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return Colors.green.shade900;
      case InvoiceStatus.pending:
        return Colors.amber.shade900;
      case InvoiceStatus.overdue:
        return Colors.red.shade900;
    }
  }

  String _discountTypeLabel(InvoiceDiscountType discountType, AppStrings s) {
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
    final rawDiscount = nu.parseDouble(_discountController.text.trim()) ?? 0;

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
