class Product {
  const Product({
    required this.id,
    required this.storeId,
    required this.name,
    required this.unit,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.minimumSellingPrice,
    required this.currentStock,
    required this.minimumStock,
    required this.isActive,
  });

  final String id;
  final String storeId;
  final String name;
  final String unit;
  final double buyingPrice;
  final double sellingPrice;
  final double minimumSellingPrice;
  final double currentStock;
  final double minimumStock;
  final bool isActive;

  bool get isLowStock => currentStock <= minimumStock;

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String,
        storeId: map['store_id'] as String,
        name: map['name'] as String,
        unit: map['unit'] as String,
        buyingPrice: (map['buying_price'] as num).toDouble(),
        sellingPrice: (map['selling_price'] as num).toDouble(),
        minimumSellingPrice: (map['minimum_selling_price'] as num).toDouble(),
        currentStock: (map['current_stock'] as num).toDouble(),
        minimumStock: (map['minimum_stock'] as num).toDouble(),
        isActive: map['is_active'] as bool,
      );
}
