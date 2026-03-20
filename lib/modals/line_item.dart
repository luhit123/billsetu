class LineItem {
  const LineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.unit = '',
    this.hsnCode = '',
    this.gstRate = 0,
  });

  final String description;
  final double quantity;
  final double unitPrice;
  final String unit;
  final String hsnCode;
  final double gstRate; // per-item GST rate (0, 5, 12, 18, 28)

  double get total => quantity * unitPrice;

  String get quantityText => _formatQuantity(quantity);

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
    };
  }

  static String _formatQuantity(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}
