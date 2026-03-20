import 'package:billeasy/modals/product.dart';
import 'package:billeasy/services/product_service.dart';
import 'package:flutter/material.dart';

// ── Brand tokens ─────────────────────────────────────────────────────────────
const _kPrimary    = Color(0xFF4361EE);
const _kBackground = Color(0xFFEFF6FF);
const _kBorder     = Color(0xFFBDD5F0);
const _kCardBg     = Colors.white;
const _kLabel      = Color(0xFF5B7A9A);
const _kTitle      = Color(0xFF1E3A8A);

const _kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1E3A8A), Color(0xFF4361EE), Color(0xFF6366F1)],
);

const _kUnits = [
  'pcs', 'kg', 'g', 'ltr', 'ml',
  'box', 'pack', 'dozen', 'meter',
];

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.initialProduct});

  /// Pass an existing product to edit; `null` → create new.
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
  bool   _trackInventory = false;

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
      _trackInventory    = p.trackInventory;
      if (p.trackInventory) {
        _currentStockCtrl.text = p.currentStock > 0 ? p.currentStock.toString() : '';
        _minStockCtrl.text     = p.minStockAlert > 0 ? p.minStockAlert.toString() : '';
      }
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
        labelStyle: const TextStyle(color: _kLabel, fontSize: 13),
        hintStyle:  const TextStyle(color: _kLabel),
        helperStyle: const TextStyle(color: _kLabel, fontSize: 11),
        prefixIcon: icon != null
            ? Icon(icon, color: _kLabel, size: 20)
            : null,
        filled: true,
        fillColor: const Color(0xFFF5F8FF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
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

  @override
  Widget build(BuildContext context) {
    final title =
        _isEditing ? 'Edit Product' : 'Add Product';

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
          title,
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
              // ── Avatar preview ─────────────────────────────────────────
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
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // ── Product details card ───────────────────────────────────
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
                        hint: 'e.g. Rice, Notebook, Service…',
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
                        hint: 'e.g. Food, Stationery…',
                        icon: Icons.label_outline_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Pricing card ───────────────────────────────────────────
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
                              'Unit Price (₹)',
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
                                  ? const Color(0xFFEEF2FF)
                                  : const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? _kPrimary.withValues(alpha: 0.35)
                                    : _kBorder,
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              u,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: sel ? _kPrimary : _kLabel,
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

              // ── GST & Compliance card ──────────────────────────────────
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
                        hint: 'e.g. 8471, 9983…',
                        icon: Icons.tag_rounded,
                        helperText: 'Required for GST invoice compliance',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // GST Applicable toggle
                    Row(
                      children: [
                        Icon(Icons.percent_rounded, color: _kLabel, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'GST Applicable',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _kTitle,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _gstApplicable,
                          activeTrackColor: _kPrimary,
                          activeThumbColor: Colors.white,
                          onChanged: (_) =>
                              setState(() => _gstApplicable = !_gstApplicable),
                        ),
                      ],
                    ),

                    // GST Rate pills — only when GST is applicable
                    if (_gstApplicable) ...[
                      const SizedBox(height: 10),
                      Text(
                        'GST Rate',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kLabel,
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
                                    ? _kPrimary
                                    : const Color(0xFFF0F6FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel ? _kPrimary : _kBorder,
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                '${rate.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: sel ? Colors.white : _kLabel,
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

              // ── Inventory Tracking card ────────────────────────────────
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
                            color: _kPrimary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Track Inventory',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _kTitle,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Monitor stock levels & movements',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _kLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _trackInventory,
                          onChanged: (v) =>
                              setState(() => _trackInventory = v),
                          activeColor: _kPrimary,
                        ),
                      ],
                    ),

                    // Stock fields — only shown when tracking is on
                    if (_trackInventory) ...[
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Save button ────────────────────────────────────────────
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
                        ? 'Saving…'
                        : _isEditing
                            ? 'Save Changes'
                            : 'Add Product',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _kPrimary.withValues(alpha: 0.45),
                    disabledForegroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0x402563EB),
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0E2563EB),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: _kTitle,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );

  // ── Logic ────────────────────────────────────────────────────────────────

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
          trackInventory: _trackInventory,
          currentStock: _trackInventory
              ? (double.tryParse(_currentStockCtrl.text.trim()) ?? 0)
              : 0,
          minStockAlert: _trackInventory
              ? (double.tryParse(_minStockCtrl.text.trim()) ?? 0)
              : 0,
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
