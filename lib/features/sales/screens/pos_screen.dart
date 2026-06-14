import 'package:flutter/material.dart';
import '../../../core/utils/money.dart';
import '../../auth/models/app_profile.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/models/customer.dart';
import '../../products/data/product_repository.dart';
import '../../products/models/product.dart';
import '../data/sales_repository.dart';

class CartLine {
  CartLine(this.product, this.quantity);
  final Product product;
  double quantity;
  double get total => product.sellingPrice * quantity;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _productRepo = ProductRepository();
  final _customerRepo = CustomerRepository();
  final _salesRepo = SalesRepository();
  final List<CartLine> _cart = [];
  List<Product> _products = [];
  List<Customer> _customers = [];
  String _paymentMode = 'cash';
  String? _customerId;
  final _reason = TextEditingController();
  bool _loading = false;

  double get subtotal => _cart.fold(0, (sum, e) => sum + e.total);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await _productRepo.listProducts();
    final customers = await _customerRepo.listCustomers();
    if (mounted) setState(() { _products = products; _customers = customers; });
  }

  void _add(Product p) {
    CartLine? existing;
    for (final c in _cart) {
      if (c.product.id == p.id) {
        existing = c;
        break;
      }
    }
    setState(() {
      if (existing == null) {
        _cart.add(CartLine(p, 1));
      } else if (existing.quantity + 1 <= p.currentStock) {
        existing.quantity += 1;
      }
    });
  }

  Future<void> _submit() async {
    if (_cart.isEmpty) return;
    final isCredit = _paymentMode == 'credit_request';
    if (isCredit && _customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credit sale requires customer.')));
      return;
    }
    if (isCredit && _reason.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason is required for credit request.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final items = _cart.map((c) => {'product_id': c.product.id, 'quantity': c.quantity}).toList();
      if (isCredit) {
        await _salesRepo.requestCreditSale(items: items, customerId: _customerId!, reason: _reason.text.trim());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credit sale request sent to owner.')));
      } else {
        await _salesRepo.createCashSale(items: items, customerId: _customerId, paymentMethod: _paymentMode);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale completed.')));
      }
      setState(() { _cart.clear(); _customerId = null; _reason.clear(); });
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller POS')),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _products.length,
              itemBuilder: (context, i) {
                final p = _products[i];
                return Card(
                  child: ListTile(
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${money(p.sellingPrice)} • Stock ${p.currentStock} ${p.unit}'),
                    trailing: FilledButton.tonal(onPressed: p.currentStock <= 0 ? null : () => _add(p), child: const Text('Add')),
                  ),
                );
              },
            ),
          ),
          Container(width: 1, color: Colors.black12),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Cart • ${money(subtotal)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, i) {
                      final c = _cart[i];
                      return ListTile(
                        dense: true,
                        title: Text(c.product.name),
                        subtitle: Text('${c.quantity} ${c.product.unit} x ${money(c.product.sellingPrice)}'),
                        trailing: IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => _cart.removeAt(i))),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String?>(
                        value: _customerId,
                        decoration: const InputDecoration(labelText: 'Customer (required for credit)'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Walk-in customer')),
                          ..._customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (v) => setState(() => _customerId = v),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _paymentMode,
                        decoration: const InputDecoration(labelText: 'Payment mode'),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                          DropdownMenuItem(value: 'mobile_money', child: Text('Mobile money')),
                          DropdownMenuItem(value: 'credit_request', child: Text('Credit request approval')),
                        ],
                        onChanged: (v) => setState(() => _paymentMode = v ?? 'cash'),
                      ),
                      if (_paymentMode == 'credit_request') ...[
                        const SizedBox(height: 10),
                        TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason for credit')),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                          label: Text(_paymentMode == 'credit_request' ? 'Send Approval Request' : 'Complete Sale'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
