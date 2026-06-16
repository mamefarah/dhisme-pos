class Product {
  const Product({
    required this.id,
    required this.storeId,
    this.categoryId,
    this.categoryName,
    required this.name,
    required this.unit,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.minimumSellingPrice,
    required this.currentStock,
    required this.minimumStock,
    required this.isActive,
    this.notes,
  });

  final String id;
  final String storeId;
  final String? categoryId;
  final String? categoryName;
  final String name;
  final String unit;
  final double buyingPrice;
  final double sellingPrice;
  final double minimumSellingPrice;
  final double currentStock;
  final double minimumStock;
  final bool isActive;
  final String? notes;

  bool get isLowStock => currentStock > 0 && currentStock <= minimumStock;
  bool get isOutOfStock => currentStock <= 0;

  factory Product.fromMap(Map<String, dynamic> map) {
    final cat = map['categories'] as Map<String, dynamic>?;
    return Product(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      categoryId: map['category_id'] as String?,
      categoryName: cat?['name'] as String?,
      name: map['name'] as String,
      unit: map['unit'] as String,
      buyingPrice: (map['buying_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      minimumSellingPrice: (map['minimum_selling_price'] as num).toDouble(),
      currentStock: (map['current_stock'] as num).toDouble(),
      minimumStock: (map['minimum_stock'] as num).toDouble(),
      isActive: map['is_active'] as bool,
      notes: map['notes'] as String?,
    );
  }
}
