class LineItem {
  const LineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.unit = '',
    this.hsnCode = '',
    this.gstRate = 0,
    this.discountPercent = 0,
    this.productId = '',
  });

  final String description;
  final double quantity;
  final double unitPrice;
  final String unit;
  final String hsnCode;
  final double gstRate; // per-item GST rate (0, 5, 12, 18, 28)
  final double discountPercent; // per-item discount percentage (0-100)
  final String productId; // links to product for inventory tracking

  static double _round(num v) => (v * 100).roundToDouble() / 100;

  double get rawTotal => _round(quantity * unitPrice);
  double get discountAmount => _round(rawTotal * discountPercent / 100);
  double get total => _round(rawTotal - discountAmount);
  double get gstAmount => _round(total * gstRate / 100);
  double get totalWithGst => _round(total + gstAmount);

  String get quantityText => formatQuantity(quantity);

  String get quantityLabel {
    final trimmedUnit = unit.trim();
    if (trimmedUnit.isEmpty) {
      return quantityText;
    }

    return '$quantityText $trimmedUnit';
  }

  factory LineItem.fromMap(Map<String, dynamic> map) {
    return LineItem(
      description: map['description'] as String? ?? '',
      quantity: (map['quantity'] as num? ?? 0).toDouble(),
      unitPrice: (map['unitPrice'] as num? ?? 0).toDouble(),
      unit: map['unit'] as String? ?? '',
      hsnCode: map['hsnCode'] as String? ?? '',
      gstRate: (map['gstRate'] as num? ?? 0).toDouble(),
      discountPercent: (map['discountPercent'] as num? ?? 0).toDouble(),
      productId: map['productId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'unit': unit,
      'hsnCode': hsnCode,
      'gstRate': gstRate,
      'discountPercent': discountPercent,
      if (productId.isNotEmpty) 'productId': productId,
    };
  }

  static String formatQuantity(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}
