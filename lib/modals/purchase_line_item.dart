class PurchaseLineItem {
  const PurchaseLineItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.unit = 'pcs',
    this.hsnCode = '',
  });

  final String productId; // empty string if not linked to product catalog
  final String productName;
  final double quantity;
  final double unitPrice; // PURCHASE / COST price per unit
  final String unit;
  final String hsnCode;

  double get total => quantity * unitPrice;

  String get quantityLabel {
    final qty = quantity == quantity.truncateToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    return unit.isEmpty ? qty : '$qty $unit';
  }

  PurchaseLineItem copyWith({
    String? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    String? unit,
    String? hsnCode,
  }) {
    return PurchaseLineItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      hsnCode: hsnCode ?? this.hsnCode,
    );
  }

  factory PurchaseLineItem.fromMap(Map<String, dynamic> map) {
    return PurchaseLineItem(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      quantity: (map['quantity'] as num? ?? 0).toDouble(),
      unitPrice: (map['unitPrice'] as num? ?? 0).toDouble(),
      unit: map['unit'] as String? ?? 'pcs',
      hsnCode: map['hsnCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'unit': unit,
        'hsnCode': hsnCode,
      };
}
