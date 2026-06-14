import '../../../core/services/supabase_service.dart';
import '../models/customer.dart';

class CustomerRepository {
  Future<List<Customer>> listCustomers() async {
    final data = await sb.from('customers').select().order('name');
    return (data as List).map((e) => Customer.fromMap(e)).toList();
  }

  Future<void> addCustomer({required String storeId, required String name, String? phone, String? location}) async {
    await sb.from('customers').insert({'store_id': storeId, 'name': name, 'phone': phone, 'location': location});
  }
}
