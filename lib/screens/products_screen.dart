import 'dart:async';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/product.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/empty_state_widget.dart';
import 'package:billeasy/widgets/error_retry_widget.dart';
import 'package:billeasy/screens/product_form_screen.dart';
import 'package:billeasy/screens/product_movements_screen.dart';
import 'package:billeasy/services/product_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:billeasy/utils/responsive.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/widgets/permission_denied_dialog.dart';
import 'package:billeasy/services/usage_tracking_service.dart';
import 'package:billeasy/widgets/limit_reached_dialog.dart';

class ProductsScreen extends StatefulWidget {
  /// When [selectionMode] is true the screen returns a [Product] via
  /// `Navigator.pop` instead of opening the edit form on tap.
  const ProductsScreen({
    super.key,
    this.selectionMode = false,
    this.preselectedProductId,
    this.embeddedInHomeShell = false,
  });

  final bool selectionMode;
  final String? preselectedProductId;
  final bool embeddedInHomeShell;

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
  static const _streamLimit = 200;
  List<Product> _allProducts = [];
  bool _isLoading = true;
  Object? _loadError;
  StreamSubscription<List<Product>>? _productSub;
  StreamSubscription<AppPlan>? _planSub;

  /// In-memory search filter -- zero network calls.
  List<Product> get _filtered {
    if (_query.isEmpty) return _allProducts;
    final q = _query.toLowerCase();
    return _allProducts.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
    _planSub = PlanService.instance.planStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _planSub?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _productSub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _productSub?.cancel();
    // Only show loading spinner if we have no cached data — prevents
    // the screen from blinking blank when re-subscribing with data on screen.
    if (_allProducts.isEmpty) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    } else {
      setState(() {
        _loadError = null;
      });
    }
    _productSub = _svc
        .getProductsStream(limit: _streamLimit)
        .listen(
          (products) {
            if (!mounted) return;
            setState(() {
              _allProducts = products;
              _isLoading = false;
              _loadError = null;
            });
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _loadError = e;
              _isLoading = false;
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final pageColor = widget.embeddedInHomeShell
        ? Colors.transparent
        : context.cs.surface;

    return Scaffold(
      backgroundColor: pageColor,
      appBar: _buildAppBar(),
      floatingActionButton:
          widget.selectionMode || !TeamService.instance.can.canAddProduct
          ? null
          : FloatingActionButton(
              heroTag: 'products-fab',
              onPressed: _openAddProduct,
              backgroundColor: context.cs.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              child: const Icon(Icons.add_rounded),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kWebContentMaxWidth),
          child: RefreshIndicator(
            onRefresh: () async => _subscribe(),
            child: Builder(
              builder: (context) {
                if (_isLoading && _allProducts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_loadError != null && _allProducts.isEmpty) {
                  final s = AppStrings.of(context);
                  return ErrorRetryWidget(
                    message: s.productsLoadError,
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
                        title: _query.isEmpty
                            ? 'No products yet'
                            : 'No matching products',
                        subtitle: _query.isEmpty
                            ? 'Add products to use them in invoices'
                            : 'Try a different search term',
                        actionLabel: _query.isEmpty && !widget.selectionMode
                            ? 'Add Product'
                            : null,
                        iconColor: kPrimary,
                        onAction: _query.isEmpty && !widget.selectionMode
                            ? _openAddProduct
                            : null,
                      ),
                    ],
                  );
                }

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _buildProductsCollection(products),
                    if (_allProducts.length >= _streamLimit)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: context.cs.surfaceContainerHighest.withAlpha(
                              80,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: context.cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Showing latest $_streamLimit products. Use search to find others.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // -- AppBar --

  PreferredSizeWidget _buildAppBar() {
    final pageColor = widget.embeddedInHomeShell
        ? Colors.transparent
        : context.cs.surface;

    return AppBar(
      backgroundColor: pageColor,
      foregroundColor: context.cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      title: _isSearching
          ? TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: TextStyle(
                color: context.cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: kPrimary,
              decoration: InputDecoration(
                hintText: 'Search products\u2026',
                hintStyle: TextStyle(
                  color: context.cs.onSurfaceVariant.withAlpha(153),
                ),
                border: InputBorder.none,
              ),
              onChanged: _handleSearchChanged,
            )
          : Text(
              widget.selectionMode ? 'Select Product' : 'Products',
              style: TextStyle(
                color: context.cs.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.search_rounded,
            color: context.cs.onSurfaceVariant,
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
            icon: Icon(Icons.add_rounded, color: context.cs.onSurfaceVariant),
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
    if (!PermissionDenied.check(
      context,
      TeamService.instance.can.canAddProduct,
      'add products',
    )) {
      return;
    }
    // Plan gate: check product limit
    final count = await UsageTrackingService.instance.getProductCount();
    if (!PlanService.instance.canAddProduct(count)) {
      if (!mounted) return;
      final max = PlanService.instance.currentLimits.maxProducts;
      await LimitReachedDialog.show(
        context,
        title: 'Product Limit Reached',
        message: 'You have $count/$max products. Upgrade to add more.',
        featureName: 'more products',
      );
      return;
    }

    if (!mounted) return;
    await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    // Stream auto-updates -- no manual reload needed.
  }

  Future<void> _openEditProduct(Product product) async {
    if (!PermissionDenied.check(
      context,
      TeamService.instance.can.canEditProduct,
      'edit products',
    )) {
      return;
    }
    await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(initialProduct: product),
      ),
    );
    // Stream auto-updates -- no manual reload needed.
  }

  Future<void> _confirmDelete(Product product) async {
    if (!PermissionDenied.check(
      context,
      TeamService.instance.can.canDeleteProduct,
      'delete products',
    )) {
      return;
    }
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.productsDeleteTitle(product.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              s.commonDelete,
              style: const TextStyle(color: kOverdue),
            ),
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
        SnackBar(
          content: Text(
            userFriendlyError(
              e,
              fallback: 'Failed to delete product. Please try again.',
            ),
          ),
        ),
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

  Widget _buildProductsCollection(List<Product> products) {
    final size = windowSizeOf(context);
    if (size == WindowSize.compact) {
      return Column(
        children: [
          for (final product in products)
            _ProductCard(
              product: product,
              currFmt: _currFmt,
              selectionMode: widget.selectionMode,
              isPreselected: product.id == widget.preselectedProductId,
              onTap: () => _handleProductTap(product),
              onEdit: () => _openEditProduct(product),
              onDelete: () => _confirmDelete(product),
            ),
        ],
      );
    }

    final crossAxisCount = size == WindowSize.expanded ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 10,
        mainAxisExtent: 130,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
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
          color: isPreselected
              ? context.cs.primaryContainer
              : context.cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [kSubtleShadow],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: context.cs.surfaceContainerLow,
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _UnitPill(unit: product.unit),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          product.unitPrice > 0
                              ? currFmt.format(product.unitPrice)
                              : 'Price not set',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (product.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.cs.onSurfaceVariant,
                      ),
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
              if (TeamService.instance.can.canEditProduct)
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: context.cs.onSurfaceVariant,
                  ),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              if (TeamService.instance.can.canDeleteProduct)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: kOverdue,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
            ] else
              Icon(
                Icons.chevron_right_rounded,
                color: context.cs.onSurfaceVariant,
                size: 20,
              ),
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
    if (!product.trackInventory) return const SizedBox.shrink();

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
      final qty =
          product.currentStock == product.currentStock.truncateToDouble()
          ? product.currentStock.toStringAsFixed(0)
          : product.currentStock.toStringAsFixed(2);
      label = '\u26a0 Low Stock: $qty';
    } else {
      bgColor = kPaidBg;
      textColor = kPaid;
      final qty =
          product.currentStock == product.currentStock.truncateToDouble()
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        unit,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
