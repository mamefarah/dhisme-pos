import 'package:flutter/material.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../../auth/models/app_profile.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/models/customer.dart';
import '../../products/data/product_repository.dart';
import '../../products/models/product.dart';
import '../data/sales_repository.dart';
import 'receipt_screen.dart';

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
  bool _dataLoading = true;

  double get subtotal => _cart.fold(0, (sum, e) => sum + e.total);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _dataLoading = true);
    try {
      final products = await _productRepo.listProducts();
      final customers = await _customerRepo.listCustomers();
      if (mounted) {
        setState(() {
          _products = products;
          _customers = customers;
          _dataLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dataLoading = false);
        _showError('Could not load products. Check your connection and try again.');
      }
    }
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
      } else {
        _showError('Not enough stock for ${p.name}. Only ${p.currentStock.toInt()} ${p.unit} available.');
      }
    });
  }

  Future<void> _submit() async {
    if (_cart.isEmpty) {
      _showError('Your cart is empty. Please add items before completing a sale.');
      return;
    }
    final isCredit = _paymentMode == 'credit_request';
    if (isCredit && _customerId == null) {
      _showError('Credit sales require a customer. Please select a customer.');
      return;
    }
    if (isCredit && _reason.text.trim().length < 3) {
      _showError('Please enter a reason for the credit request (at least 3 characters).');
      return;
    }

    setState(() => _loading = true);
    try {
      final items = _cart
          .map((c) => {'product_id': c.product.id, 'quantity': c.quantity})
          .toList();

      if (isCredit) {
        await _salesRepo.requestCreditSale(
          items: items,
          customerId: _customerId!,
          reason: _reason.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('Credit request sent to owner for approval.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          setState(() {
            _cart.clear();
            _customerId = null;
            _reason.clear();
          });
          await _load();
        }
      } else {
        final saleId = await _salesRepo.createCashSale(
          items: items,
          customerId: _customerId,
          paymentMethod: _paymentMode,
        );
        if (mounted) {
          setState(() {
            _cart.clear();
            _customerId = null;
          });
          await _load();
          // Navigate to receipt automatically
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReceiptScreen(
                saleId: saleId,
                profile: widget.profile,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(friendlyError(
          e,
          fallback: 'Sale could not be completed. Please try again.',
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_dataLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller POS'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh products',
          ),
        ],
      ),
      body: Row(
        children: [
          // Products panel
          Expanded(
            flex: 3,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _products.length,
              itemBuilder: (context, i) {
                final p = _products[i];
                final outOfStock = p.currentStock <= 0;
                return Card(
                  child: ListTile(
                    title: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${money(p.sellingPrice)} • ${p.currentStock.toInt()} ${p.unit}',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: outOfStock ? null : () => _add(p),
                      child: Text(outOfStock ? 'Out' : 'Add'),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(width: 1, color: Colors.black12),
          // Cart panel
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Cart • ${money(subtotal)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _cart.isEmpty
                      ? const Center(
                          child: Text(
                            'Add items from\nthe left panel',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black38),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _cart.length,
                          itemBuilder: (context, i) {
                            final c = _cart[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                c.product.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${c.quantity.toInt()} ${c.product.unit}'
                                ' × ${money(c.product.sellingPrice)}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 20),
                                onPressed: () =>
                                    setState(() => _cart.removeAt(i)),
                                tooltip: 'Remove',
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String?>(
                        value: _customerId,
                        decoration: const InputDecoration(
                          labelText: 'Customer',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Walk-in customer'),
                          ),
                          ..._customers.map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _customerId = v),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _paymentMode,
                        decoration: const InputDecoration(
                          labelText: 'Payment mode',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(
                              value: 'bank', child: Text('Bank transfer')),
                          DropdownMenuItem(
                              value: 'mobile_money',
                              child: Text('Mobile money')),
                          DropdownMenuItem(
                              value: 'credit_request',
                              child: Text('Credit request')),
                        ],
                        onChanged: (v) =>
                            setState(() => _paymentMode = v ?? 'cash'),
                      ),
                      if (_paymentMode == 'credit_request') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _reason,
                          decoration: const InputDecoration(
                            labelText: 'Reason for credit',
                            isDense: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(
                          _paymentMode == 'credit_request'
                              ? 'Send for Approval'
                              : 'Complete Sale',
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
