import 'package:billeasy/modals/product.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/services/product_service.dart';
import 'package:flutter/material.dart';

const _kUnits = [
  'pcs', 'kg', 'g', 'ltr', 'ml',
  'box', 'pack', 'dozen', 'meter',
];

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.initialProduct});

  /// Pass an existing product to edit; `null` -> create new.
  final Product? initialProduct;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _svc = ProductService();

  final _nameCtrl        = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _priceCtrl       = TextEditingController();
  final _categoryCtrl    = TextEditingController();
  final _hsnCtrl         = TextEditingController();
  final _currentStockCtrl = TextEditingController();
  final _minStockCtrl     = TextEditingController();

  String _unit = 'pcs';
  bool   _isSaving = false;
  bool   _gstApplicable = false;
  double _gstRate = 18.0;
  final bool _trackInventory = true;

  bool get _isEditing => widget.initialProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    if (p != null) {
      _nameCtrl.text     = p.name;
      _descCtrl.text     = p.description;
      _priceCtrl.text    = p.unitPrice > 0 ? p.unitPrice.toString() : '';
      _categoryCtrl.text = p.category;
      _unit              = _kUnits.contains(p.unit) ? p.unit : 'pcs';
      _hsnCtrl.text      = p.hsnCode;
      _gstApplicable     = p.gstApplicable;
      _gstRate           = p.gstRate;
      _currentStockCtrl.text = p.currentStock > 0 ? p.currentStock.toString() : '';
      _minStockCtrl.text     = p.minStockAlert > 0 ? p.minStockAlert.toString() : '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    _hsnCtrl.dispose();
    _currentStockCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon, String? helperText}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        labelStyle: const TextStyle(color: kOnSurfaceVariant, fontSize: 13),
        hintStyle:  const TextStyle(color: kTextTertiary),
        helperStyle: const TextStyle(color: kTextTertiary, fontSize: 11),
        prefixIcon: icon != null
            ? Icon(icon, color: kOnSurfaceVariant, size: 20)
            : null,
        filled: true,
        fillColor: kSurfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kOverdue),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: kOverdue, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final title =
        _isEditing ? 'Edit Product' : 'Add Product';

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: kOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: const TextStyle(
            color: kOnSurface,
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
              // -- Avatar preview --
              Center(
                child: AnimatedBuilder(
                  animation: _nameCtrl,
                  builder: (context, child) {
                    final initials = _nameCtrl.text.trim().isEmpty
                        ? '?'
                        : _nameCtrl.text
                            .trim()
                            .split(' ')
                            .where((w) => w.isNotEmpty)
                            .take(2)
                            .map((w) => w[0].toUpperCase())
                            .join();
                    return CircleAvatar(
                      radius: 34,
                      backgroundColor: kPrimaryContainer,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // -- Product details card --
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Product Details'),
                    const SizedBox(height: 14),

                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec(
                        'Product Name',
                        hint: 'e.g. Rice, Notebook, Service\u2026',
                        icon: Icons.inventory_2_outlined,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Product name is required'
                              : null,
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _dec(
                        'Description (optional)',
                        hint: 'Brief product description',
                        icon: Icons.notes_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category
                    TextFormField(
                      controller: _categoryCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec(
                        'Category (optional)',
                        hint: 'e.g. Food, Stationery\u2026',
                        icon: Icons.label_outline_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -- Pricing card --
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Pricing & Unit'),
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _priceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: _dec(
                              'Unit Price (\u20b9)',
                              hint: '0',
                              icon: Icons.currency_rupee_rounded,
                            ),
                            validator: (v) {
                              final n = double.tryParse(
                                  v?.trim().replaceAll(',', '') ?? '');
                              if (n == null || n < 0) {
                                return 'Enter a valid price';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Unit dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _unit,
                            isExpanded: true,
                            decoration: _dec('Unit'),
                            items: _kUnits
                                .map((u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _unit = v ?? 'pcs'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Unit pills (quick select)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kUnits.map((u) {
                        final sel = u == _unit;
                        return GestureDetector(
                          onTap: () => setState(() => _unit = u),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel
                                  ? kPrimaryContainer
                                  : kSurfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              u,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: sel ? kPrimary : kOnSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -- GST & Compliance card --
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('GST & Compliance'),
                    const SizedBox(height: 14),

                    // HSN / SAC Code
                    TextFormField(
                      controller: _hsnCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _dec(
                        'HSN / SAC Code (optional)',
                        hint: 'e.g. 8471, 9983\u2026',
                        icon: Icons.tag_rounded,
                        helperText: 'Required for GST invoice compliance',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // GST Applicable toggle
                    Row(
                      children: [
                        Icon(Icons.percent_rounded, color: kOnSurfaceVariant, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'GST Applicable',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kOnSurface,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _gstApplicable,
                          activeTrackColor: kPrimary,
                          activeThumbColor: Colors.white,
                          onChanged: (_) =>
                              setState(() => _gstApplicable = !_gstApplicable),
                        ),
                      ],
                    ),

                    // GST Rate pills -- only when GST is applicable
                    if (_gstApplicable) ...[
                      const SizedBox(height: 10),
                      Text(
                        'GST Rate',
                        style: const TextStyle(
                          fontSize: 13,
                          color: kOnSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [0.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
                          final sel = rate == _gstRate;
                          return GestureDetector(
                            onTap: () => setState(() => _gstRate = rate),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: sel
                                    ? kPrimary
                                    : kSurfaceContainerLow,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${rate.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: sel ? Colors.white : kOnSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -- Inventory Tracking card --
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Inventory Tracking'),
                    const SizedBox(height: 14),

                    // Track Inventory toggle
                    Row(
                      children: [
                        Icon(Icons.inventory_rounded,
                            color: kPrimary, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventory',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: kOnSurface,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Stock levels & movement tracking',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: kOnSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                      TextFormField(
                        controller: _currentStockCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: _dec(
                          'Current Stock',
                          hint: '0',
                          icon: Icons.numbers_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _minStockCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: _dec(
                          'Min Stock Alert',
                          hint: '0',
                          icon: Icons.warning_amber_rounded,
                          helperText:
                              'Get alerted when stock falls below this level',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // -- Save button --
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.1,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving
                        ? 'Saving\u2026'
                        : _isEditing
                            ? 'Save Changes'
                            : 'Add Product',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        kPrimary.withValues(alpha: 0.45),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // -- Helpers --

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [kWhisperShadow],
        ),
        child: child,
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: kOnSurface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );

  // -- Logic --

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      final price =
          double.tryParse(_priceCtrl.text.trim().replaceAll(',', '')) ?? 0;
      final saved = await _svc.saveProduct(
        Product(
          id: widget.initialProduct?.id ?? '',
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          unitPrice: price,
          unit: _unit,
          category: _categoryCtrl.text.trim(),
          createdAt: widget.initialProduct?.createdAt,
          hsnCode: _hsnCtrl.text.trim(),
          gstRate: _gstRate,
          gstApplicable: _gstApplicable,
          trackInventory: true,
          currentStock: double.tryParse(_currentStockCtrl.text.trim()) ?? 0,
          minStockAlert: double.tryParse(_minStockCtrl.text.trim()) ?? 0,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save product: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
