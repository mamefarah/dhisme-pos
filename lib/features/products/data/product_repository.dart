import '../../../core/services/supabase_service.dart';
import '../models/product.dart';

class ProductRepository {
  Future<List<Product>> listProducts({String? search}) async {
    final data = await sb
        .from('products')
        .select('*, categories(name)')
        .eq('is_active', true)
        .order('name') as List<dynamic>;

    var products = data.map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      products = products.where((p) => p.name.toLowerCase().contains(s)).toList();
    }
    return products;
  }

  Future<List<Map<String, dynamic>>> listCategories() async {
    final data = await sb
        .from('categories')
        .select('id, name')
        .order('name') as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> addCategory({required String storeId, required String name}) async {
    await sb.from('categories').insert({'store_id': storeId, 'name': name.trim()});
  }

  Future<void> updateCategory({required String id, required String name}) async {
    await sb.from('categories').update({'name': name.trim()}).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> listStockMovements(String productId) async {
    final data = await sb
        .from('stock_movements')
        .select('*, profiles!created_by(full_name)')
        .eq('product_id', productId)
        .order('created_at', ascending: false)
        .limit(50) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> addProduct({
    required String storeId,
    required String name,
    required String unit,
    required double buyingPrice,
    required double sellingPrice,
    required double minimumSellingPrice,
    required double currentStock,
    required double minimumStock,
    String? categoryId,
    String? notes,
  }) async {
    await sb.from('products').insert({
      'store_id': storeId,
      'name': name,
      'unit': unit,
      'buying_price': buyingPrice,
      'selling_price': sellingPrice,
      'minimum_selling_price': minimumSellingPrice,
      'current_stock': currentStock,
      'minimum_stock': minimumStock,
      if (categoryId != null) 'category_id': categoryId,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  Future<void> updateProduct(Product product, Map<String, dynamic> changes) async {
    await sb.from('products').update(changes).eq('id', product.id);
  }

  Future<void> adjustStock({
    required String productId,
    required double quantityChange,
    required String reason,
  }) async {
    await sb.rpc('adjust_stock', params: {
      'p_product_id': productId,
      'p_quantity_change': quantityChange,
      'p_reason': reason,
    });
  }
}
