class Purchase {
  const Purchase({
    required this.id,
    required this.storeId,
    this.supplierId,
    this.supplierName,
    this.invoiceRef,
    required this.purchaseDate,
    required this.paymentStatus,
    required this.totalAmount,
    this.notes,
    this.recordedByName,
    required this.createdAt,
  });

  final String id;
  final String storeId;
  final String? supplierId;
  final String? supplierName;
  final String? invoiceRef;
  final DateTime purchaseDate;
  final String paymentStatus;
  final double totalAmount;
  final String? notes;
  final String? recordedByName;
  final DateTime createdAt;

  factory Purchase.fromMap(Map<String, dynamic> m) {
    final supplier = m['suppliers'] as Map<String, dynamic>?;
    final recorder = m['profiles'] as Map<String, dynamic>?;
    return Purchase(
      id: m['id'] as String,
      storeId: m['store_id'] as String,
      supplierId: m['supplier_id'] as String?,
      supplierName: supplier?['name'] as String?,
      invoiceRef: m['invoice_ref'] as String?,
      purchaseDate: DateTime.parse(m['purchase_date'] as String),
      paymentStatus: m['payment_status'] as String,
      totalAmount: (m['total_amount'] as num).toDouble(),
      notes: m['notes'] as String?,
      recordedByName: recorder?['full_name'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
  });

  final String id;
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final double unitCost;
  final double totalCost;

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
        id: m['id'] as String,
        productId: m['product_id'] as String,
        productName: m['product_name'] as String,
        unit: m['unit'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unitCost: (m['unit_cost'] as num).toDouble(),
        totalCost: (m['total_cost'] as num).toDouble(),
      );
}
