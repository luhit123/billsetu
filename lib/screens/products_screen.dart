import 'dart:async';

import 'package:billeasy/modals/product.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/empty_state_widget.dart';
import 'package:billeasy/widgets/error_retry_widget.dart';
import 'package:billeasy/screens/product_form_screen.dart';
import 'package:billeasy/screens/product_movements_screen.dart';
import 'package:billeasy/services/product_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class ProductsScreen extends StatefulWidget {
  /// When [selectionMode] is true the screen returns a [Product] via
  /// `Navigator.pop` instead of opening the edit form on tap.
  const ProductsScreen({
    super.key,
    this.selectionMode = false,
    this.preselectedProductId,
  });

  final bool selectionMode;
  final String? preselectedProductId;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _svc = ProductService();
  final _searchCtrl = TextEditingController();
  final _currFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20b9',
    decimalDigits: 0,
  );

  bool _isSearching = false;
  String _query = '';
  Timer? _searchDebounce;

  // -- Stream-based state --
  List<Product> _allProducts = [];
  bool _isLoading = true;
  Object? _loadError;
  StreamSubscription<List<Product>>? _productSub;

  /// In-memory search filter -- zero network calls.
  List<Product> get _filtered {
    if (_query.isEmpty) return _allProducts;
    final q = _query.toLowerCase();
    return _allProducts
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _productSub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _productSub?.cancel();
    setState(() { _isLoading = true; _loadError = null; });
    _productSub = _svc.getProductsStream(limit: 200).listen(
      (products) {
        if (!mounted) return;
        setState(() { _allProducts = products; _isLoading = false; _loadError = null; });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() { _loadError = e; _isLoading = false; });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: _buildAppBar(),
      floatingActionButton: widget.selectionMode
          ? null
          : FloatingActionButton(
              heroTag: 'products-fab',
              onPressed: _openAddProduct,
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              elevation: 2,
              child: const Icon(Icons.add_rounded),
            ),
      body: RefreshIndicator(
        onRefresh: () async => _subscribe(),
        child: Builder(
          builder: (context) {
            if (_isLoading && _allProducts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_loadError != null && _allProducts.isEmpty) {
              return ErrorRetryWidget(
                message: 'Could not load products.\nCheck your connection and try again.',
                onRetry: _subscribe,
              );
            }

            final products = _filtered;
            if (products.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: _query.isEmpty ? 'No products yet' : 'No matching products',
                    subtitle: _query.isEmpty
                        ? 'Add products to use them in invoices'
                        : 'Try a different search term',
                    actionLabel: _query.isEmpty && !widget.selectionMode ? 'Add Product' : null,
                    iconColor: kPrimary,
                    onAction: _query.isEmpty && !widget.selectionMode ? _openAddProduct : null,
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: products.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final product = products[i];
                return _ProductCard(
                  product: product,
                  currFmt: _currFmt,
                  selectionMode: widget.selectionMode,
                  isPreselected: product.id == widget.preselectedProductId,
                  onTap: () => _handleProductTap(product),
                  onEdit: () => _openEditProduct(product),
                  onDelete: () => _confirmDelete(product),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // -- AppBar --

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kSurface,
      foregroundColor: kOnSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      title: _isSearching
          ? TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(
                  color: kOnSurface, fontWeight: FontWeight.w600),
              cursorColor: kPrimary,
              decoration: const InputDecoration(
                hintText: 'Search products\u2026',
                hintStyle: TextStyle(color: kTextTertiary),
                border: InputBorder.none,
              ),
              onChanged: _handleSearchChanged,
            )
          : Text(
              widget.selectionMode ? 'Select Product' : 'Products',
              style: const TextStyle(
                color: kOnSurface,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.search_rounded,
            color: kOnSurfaceVariant,
          ),
          onPressed: () {
            _searchDebounce?.cancel();
            setState(() {
              if (_isSearching) {
                _searchCtrl.clear();
                _query = '';
                _isSearching = false;
                // No reload -- in-memory filter clears instantly.
              } else {
                _isSearching = true;
              }
            });
          },
        ),
        if (!widget.selectionMode)
          IconButton(
            icon: const Icon(Icons.add_rounded, color: kOnSurfaceVariant),
            onPressed: _openAddProduct,
            tooltip: 'Add Product',
          ),
      ],
    );
  }

  // -- Logic --

  void _handleProductTap(Product product) {
    if (widget.selectionMode) {
      Navigator.of(context).pop(product);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductMovementsScreen(product: product),
        ),
      );
    }
  }

  Future<void> _openAddProduct() async {
    await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    // Stream auto-updates -- no manual reload needed.
  }

  Future<void> _openEditProduct(Product product) async {
    await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(initialProduct: product)),
    );
    // Stream auto-updates -- no manual reload needed.
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Delete "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: kOverdue)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _svc.deleteProduct(product.id);
      // Stream auto-updates -- list refreshes automatically.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      // Filter in-memory -- no Firestore round-trip on every keystroke.
      setState(() => _query = value.trim());
    });
  }

}

// -- Product card --

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.currFmt,
    required this.selectionMode,
    required this.isPreselected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final NumberFormat currFmt;
  final bool selectionMode;
  final bool isPreselected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPreselected ? kPrimaryContainer : kSurfaceLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [kSubtleShadow],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: kSurfaceContainerLow,
              child: Text(
                product.initials,
                style: const TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kOnSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _UnitPill(unit: product.unit),
                      const SizedBox(width: 8),
                      Text(
                        product.unitPrice > 0
                            ? currFmt.format(product.unitPrice)
                            : 'Price not set',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (product.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: const TextStyle(
                          fontSize: 12, color: kOnSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Stock badge
                  const SizedBox(height: 6),
                  _StockBadge(product: product),
                ],
              ),
            ),

            // Actions (hidden in selection mode)
            if (!selectionMode) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: kOnSurfaceVariant),
                onPressed: onEdit,
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: kOverdue),
                onPressed: onDelete,
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ] else
              const Icon(Icons.chevron_right_rounded,
                  color: kOnSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

// -- Stock badge --

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    if (product.currentStock <= 0) {
      bgColor = kOverdueBg;
      textColor = kOverdue;
      label = 'Out of Stock';
    } else if (product.minStockAlert > 0 &&
        product.currentStock <= product.minStockAlert) {
      bgColor = kPendingBg;
      textColor = kPending;
      final qty = product.currentStock == product.currentStock.truncateToDouble()
          ? product.currentStock.toStringAsFixed(0)
          : product.currentStock.toStringAsFixed(2);
      label = '\u26a0 Low Stock: $qty';
    } else {
      bgColor = kPaidBg;
      textColor = kPaid;
      final qty = product.currentStock == product.currentStock.truncateToDouble()
          ? product.currentStock.toStringAsFixed(0)
          : product.currentStock.toStringAsFixed(2);
      label = 'In Stock: $qty';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _UnitPill extends StatelessWidget {
  const _UnitPill({required this.unit});
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        unit,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kOnSurfaceVariant,
        ),
      ),
    );
  }
}
