import '../../../core/services/supabase_service.dart';
import '../models/product.dart';

class ProductRepository {
  Future<List<Product>> listProducts({String? search}) async {
    var query = sb.from('products').select().eq('is_active', true).order('name');
    final data = await query;
    var products = (data as List).map((e) => Product.fromMap(e)).toList();
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().toLowerCase();
      products = products.where((p) => p.name.toLowerCase().contains(s)).toList();
    }
    return products;
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
    });
  }

  Future<void> updateProduct(Product product, Map<String, dynamic> changes) async {
    await sb.from('products').update(changes).eq('id', product.id);
  }
}
