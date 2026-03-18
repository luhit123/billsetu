import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/line_item.dart';
import 'package:billeasy/screens/invoice_details_screen.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController clientNameController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  DateTime? selectedDate;
  bool _isSaving = false;
  InvoiceStatus _selectedStatus = InvoiceStatus.paid;
  InvoiceDiscountType _selectedDiscountType = InvoiceDiscountType.percentage;
  late List<Map<String, TextEditingController>> itemRows;

  @override
  void initState() {
    super.initState();
    itemRows = [_createItemRowControllers()];
  }

  @override
  void dispose() {
    clientNameController.dispose();
    _discountController.dispose();
    for (final row in itemRows) {
      _disposeRowControllers(row);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _calculateSubtotal();
    final discountAmount = _calculateDiscountAmount(subtotal);
    final grandTotal = subtotal - discountAmount;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Invoice')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: clientNameController,
                decoration: const InputDecoration(
                  labelText: 'Client Name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter client name';
                  }
                  return null;
                },
              ),
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
                                'Invoice Date',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF123C85),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedDate == null
                                    ? 'Pick Invoice Date'
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
                                    ? 'Tap here to choose the billing date before saving.'
                                    : 'Tap to change the selected billing date.',
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
                    'Select an invoice date',
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: row['desc'],
                          decoration: const InputDecoration(
                            labelText: 'Product / Description',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter product';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: row['qty'],
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final qty = int.tryParse(value ?? '');
                            if (qty == null || qty <= 0) {
                              return 'Qty';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: row['price'],
                          decoration: const InputDecoration(
                            labelText: 'Unit Price',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final price = double.tryParse(value ?? '');
                            if (price == null || price <= 0) {
                              return 'Price';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _removeItemRow(index),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete item',
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addItemRow,
                  icon: const Icon(Icons.add),
                  label: const Text('+ Add Item'),
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
                      'Invoice Status',
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
                          label: Text(_statusLabel(status)),
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
                      'Discount',
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
                          label: Text(_discountTypeLabel(discountType)),
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
                            ? 'Discount Percentage'
                            : 'Overall Discount',
                        hintText:
                            _selectedDiscountType ==
                                InvoiceDiscountType.percentage
                            ? 'Optional, e.g. 10'
                            : 'Optional, e.g. 500',
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
                      _discountPreviewText(subtotal, discountAmount),
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
                          const Text(
                            'Subtotal',
                            style: TextStyle(
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
                          const Text(
                            'Discount',
                            style: TextStyle(
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
                          const Text(
                            'Grand Total',
                            style: TextStyle(
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
                  label: Text(_isSaving ? 'Saving Invoice...' : 'Save Invoice'),
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
                'Review the invoice date and total, then save to generate the final bill.',
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
      final qty = int.tryParse(row['qty']!.text) ?? 0;
      final price = double.tryParse(row['price']!.text) ?? 0;
      total += qty * price;
    }

    return total;
  }

  double _calculateDiscountAmount(double subtotal) {
    final rawDiscount = double.tryParse(_discountController.text.trim()) ?? 0;

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

    if (selectedDate == null) {
      setState(() {});
      return;
    }

    if (itemRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item.')),
      );
      return;
    }

    final subtotal = _calculateSubtotal();
    final discountValue = double.tryParse(_discountController.text.trim()) ?? 0;
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
        quantity: int.parse(row['qty']!.text.trim()),
        unitPrice: double.parse(row['price']!.text.trim()),
      );
    }).toList();
    final clientName = clientNameController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in before saving invoices.')),
      );
      return;
    }

    final invoice = Invoice(
      id: '',
      ownerId: currentUser.uid,
      invoiceNumber:
          'BE-${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}',
      clientId: _buildClientId(clientName),
      clientName: clientName,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save invoice: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _buildClientId(String clientName) {
    final normalized = clientName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    return normalized.isEmpty ? 'client' : normalized;
  }

  String _statusLabel(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.overdue:
        return 'Overdue';
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

  String _discountTypeLabel(InvoiceDiscountType discountType) {
    switch (discountType) {
      case InvoiceDiscountType.percentage:
        return 'Percentage';
      case InvoiceDiscountType.overall:
        return 'Overall';
    }
  }

  String _discountPreviewText(double subtotal, double discountAmount) {
    final rawDiscount = double.tryParse(_discountController.text.trim()) ?? 0;

    if (rawDiscount <= 0 || subtotal <= 0) {
      return 'Leave discount empty to keep the invoice at full subtotal.';
    }

    if (_selectedDiscountType == InvoiceDiscountType.percentage) {
      return '${rawDiscount.toStringAsFixed(rawDiscount.truncateToDouble() == rawDiscount ? 0 : 2)}% discount will reduce ${_currencyFormat.format(subtotal)} by ${_currencyFormat.format(discountAmount)}.';
    }

    return 'Overall discount of ${_currencyFormat.format(discountAmount)} will be applied to ${_currencyFormat.format(subtotal)}.';
  }

  String? _validateDiscount(double subtotal, double discountValue) {
    if (discountValue <= 0) {
      return null;
    }

    if (_selectedDiscountType == InvoiceDiscountType.percentage &&
        discountValue > 100) {
      return 'Percentage discount cannot be more than 100.';
    }

    if (_selectedDiscountType == InvoiceDiscountType.overall &&
        discountValue > subtotal) {
      return 'Overall discount cannot be more than the subtotal.';
    }

    return null;
  }
}
