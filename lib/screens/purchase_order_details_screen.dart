import 'package:billeasy/modals/purchase_order.dart';
import 'package:flutter/material.dart';

class PurchaseOrderDetailsScreen extends StatelessWidget {
  const PurchaseOrderDetailsScreen({super.key, required this.order});

  final PurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(order.orderNumber)),
      body: const Center(child: Text('Purchase Order Details — coming soon')),
    );
  }
}
