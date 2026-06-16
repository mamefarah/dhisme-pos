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

  // Loaded data
  final List<CartLine> _cart = [];
  List<Product> _products = [];
  List<Customer> _customers = [];
  List<Map<String, dynamic>> _categories = [];

  // Product panel filters
  final _searchCtrl = TextEditingController();
  String? _selectedCategoryId;

  // Cart / checkout options
  String _paymentMode = 'cash';
  String? _customerId;
  final _reason = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();

  bool _loading = false;
  bool _dataLoading = true;

  // ── Computed ─────────────────────────────────────────────────────

  List<Product> get _visible {
    var list = _products;
    if (_selectedCategoryId != null) {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  double get _subtotal => _cart.fold(0.0, (s, e) => s + e.total);
  double get _discount => double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
  double get _grandTotal => (_subtotal - _discount).clamp(0.0, double.infinity);

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _reason.dispose();
    _referenceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _dataLoading = true);
    try {
      final results = await Future.wait([
        _productRepo.listProducts(),
        _customerRepo.listCustomers(),
        _productRepo.listCategories(),
      ]);
      if (mounted) {
        setState(() {
          _products = (results[0] as List).cast<Product>();
          _customers = (results[1] as List).cast<Customer>();
          _categories = (results[2] as List).cast<Map<String, dynamic>>();
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

  // ── Cart actions ─────────────────────────────────────────────────

  void _addToCart(Product p) {
    CartLine? existing;
    for (final c in _cart) {
      if (c.product.id == p.id) { existing = c; break; }
    }
    setState(() {
      if (existing == null) {
        _cart.add(CartLine(p, 1));
      } else if (existing.quantity + 1 <= p.currentStock) {
        existing.quantity += 1;
      } else {
        _showError('Not enough stock for ${p.name}. Only ${_fmt(p.currentStock)} ${p.unit} available.');
      }
    });
  }

  void _increment(int i) {
    final c = _cart[i];
    if (c.quantity + 1 > c.product.currentStock) {
      _showError('Max stock: ${_fmt(c.product.currentStock)} ${c.product.unit}.');
      return;
    }
    setState(() => c.quantity += 1);
  }

  void _decrement(int i) {
    final c = _cart[i];
    if (c.quantity <= 1) {
      setState(() => _cart.removeAt(i));
    } else {
      setState(() => c.quantity -= 1);
    }
  }

  void _editQty(int i) {
    final c = _cart[i];
    final ctrl = TextEditingController(text: _fmt(c.quantity));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(c.product.name, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Quantity',
            helperText: 'Max: ${_fmt(c.product.currentStock)} ${c.product.unit}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(ctrl.text.trim());
              if (qty == null || qty <= 0) return;
              if (qty > c.product.currentStock) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Max available: ${_fmt(c.product.currentStock)} ${c.product.unit}.'),
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              setState(() => c.quantity = qty);
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _customerId = null;
      _paymentMode = 'cash';
      _reason.clear();
      _referenceCtrl.clear();
      _discountCtrl.clear();
    });
  }

  // ── Submit ───────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_cart.isEmpty) {
      _showError('Your cart is empty. Add items before completing a sale.');
      return;
    }
    final isCredit = _paymentMode == 'credit_request';
    if (isCredit && _customerId == null) {
      _showError('Credit sales require a customer. Please select one.');
      return;
    }
    if (isCredit && _reason.text.trim().length < 3) {
      _showError('Enter a reason for the credit request (at least 3 characters).');
      return;
    }
    if (_discount < 0) {
      _showError('Discount cannot be negative.');
      return;
    }
    if (_discount > _subtotal && _subtotal > 0) {
      _showError('Discount (${money(_discount)}) cannot exceed the cart total (${money(_subtotal)}).');
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
          discount: _discount,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(const SnackBar(
              content: Text('Credit request sent to owner for approval.'),
              behavior: SnackBarBehavior.floating,
            ));
          _clearCart();
          await _load();
        }
      } else {
        final saleId = await _salesRepo.createCashSale(
          items: items,
          customerId: _customerId,
          paymentMethod: _paymentMode,
          referenceNo: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
          discount: _discount,
        );
        if (mounted) {
          _clearCart();
          await _load();
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ReceiptScreen(saleId: saleId, profile: widget.profile),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(friendlyError(e, fallback: 'Sale could not be completed. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_dataLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Products panel ──────────────────────────────────────
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search products…',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        _CatChip(
                          label: 'All',
                          selected: _selectedCategoryId == null,
                          onTap: () => setState(() => _selectedCategoryId = null),
                        ),
                        for (final cat in _categories) ...[
                          const SizedBox(width: 6),
                          _CatChip(
                            label: cat['name'] as String,
                            selected: _selectedCategoryId == cat['id'],
                            onTap: () => setState(
                                () => _selectedCategoryId = cat['id'] as String),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Expanded(
                  child: _visible.isEmpty
                      ? const Center(
                          child: Text('No products found.',
                              style: TextStyle(color: Colors.black38)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemCount: _visible.length,
                          itemBuilder: (context, i) {
                            final p = _visible[i];
                            final outOfStock = p.isOutOfStock;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                title: Text(p.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  '${money(p.sellingPrice)}  •  ${_fmt(p.currentStock)} ${p.unit}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: outOfStock
                                        ? Colors.red.shade700
                                        : p.isLowStock
                                            ? Colors.orange.shade700
                                            : null,
                                  ),
                                ),
                                trailing: FilledButton.tonal(
                                  onPressed: outOfStock ? null : () => _addToCart(p),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(40, 32),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    textStyle: const TextStyle(fontSize: 20),
                                  ),
                                  child: Text(outOfStock ? 'Out' : '+'),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          Container(width: 1, color: Colors.black12),

          // ── Cart panel ──────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _cart.isEmpty
                            ? 'Cart'
                            : 'Cart (${_cart.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_cart.isNotEmpty)
                      TextButton(
                        onPressed: _clearCart,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Clear', style: TextStyle(fontSize: 12)),
                      ),
                  ]),
                ),

                // Cart items
                Expanded(
                  child: _cart.isEmpty
                      ? const Center(
                          child: Text(
                            'Add items\nfrom the left',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black38, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                          itemCount: _cart.length,
                          itemBuilder: (context, i) => _CartItem(
                            line: _cart[i],
                            onIncrement: () => _increment(i),
                            onDecrement: () => _decrement(i),
                            onEditQty: () => _editQty(i),
                            fmt: _fmt,
                          ),
                        ),
                ),

                // Checkout area
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Totals summary
                      if (_cart.isNotEmpty) ...[
                        const Divider(height: 12),
                        _TotalRow(label: 'Subtotal', value: money(_subtotal)),
                        if (_discount > 0)
                          _TotalRow(
                            label: 'Discount',
                            value: '− ${money(_discount)}',
                            color: Colors.red.shade700,
                          ),
                        _TotalRow(
                          label: 'Total',
                          value: money(_grandTotal),
                          bold: true,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Customer
                      DropdownButtonFormField<String?>(
                        value: _customerId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Customer',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Walk-in customer',
                                overflow: TextOverflow.ellipsis),
                          ),
                          ..._customers.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name,
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) => setState(() => _customerId = v),
                      ),
                      const SizedBox(height: 8),

                      // Payment mode
                      DropdownButtonFormField<String>(
                        value: _paymentMode,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Payment mode',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(
                              value: 'bank', child: Text('Bank transfer')),
                          DropdownMenuItem(
                              value: 'mobile_money',
                              child: Text('Mobile money')),
                          DropdownMenuItem(
                              value: 'credit_request',
                              child: Text('Credit request')),
                        ],
                        onChanged: (v) => setState(() {
                          _paymentMode = v ?? 'cash';
                          _referenceCtrl.clear();
                          _reason.clear();
                        }),
                      ),

                      // Reference no (bank / mobile money)
                      if (_paymentMode == 'bank' ||
                          _paymentMode == 'mobile_money') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _referenceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Reference / transaction no.',
                            isDense: true,
                            prefixIcon: Icon(Icons.tag_outlined, size: 18),
                          ),
                        ),
                      ],

                      // Credit reason
                      if (_paymentMode == 'credit_request') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _reason,
                          decoration: const InputDecoration(
                            labelText: 'Reason for credit *',
                            isDense: true,
                          ),
                        ),
                      ],

                      // Discount
                      const SizedBox(height: 8),
                      TextField(
                        controller: _discountCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Discount ETB (optional)',
                          isDense: true,
                          prefixIcon: Icon(Icons.discount_outlined, size: 18),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),

                      FilledButton.icon(
                        onPressed: (_loading || _cart.isEmpty) ? null : _submit,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check, size: 18),
                        label: Text(
                          _paymentMode == 'credit_request'
                              ? 'Send for Approval'
                              : 'Complete  ${money(_grandTotal)}',
                          style: const TextStyle(fontSize: 13),
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

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _CartItem extends StatelessWidget {
  const _CartItem({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditQty,
    required this.fmt,
  });
  final CartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEditQty;
  final String Function(double) fmt;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  line.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                money(line.total),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ]),
            Row(children: [
              InkWell(
                onTap: onDecrement,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.remove_circle_outline, size: 20),
                ),
              ),
              GestureDetector(
                onTap: onEditQty,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${fmt(line.quantity)} ${line.product.unit}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              InkWell(
                onTap: onIncrement,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.add_circle_outline, size: 20),
                ),
              ),
              const Spacer(),
              Text(
                '× ${money(line.product.sellingPrice)}',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 13 : 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? Colors.black54)),
          Text(value,
              style: TextStyle(
                  fontSize: bold ? 13 : 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? Colors.black54)),
        ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? c : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? c : Colors.black54,
          ),
        ),
      ),
    );
  }
}
