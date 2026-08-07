import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/idempotency.dart';
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
  List<Map<String, dynamic>> _categories = [];
  final _searchCtrl = TextEditingController();
  final _reason = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _cashSplitCtrl = TextEditingController();
  final _bankSplitCtrl = TextEditingController();
  final _mobileSplitCtrl = TextEditingController();
  String? _selectedCategoryId;
  String _paymentMode = 'cash';
  String? _customerId;
  String? _operationKey;
  bool _loading = false;
  bool _dataLoading = true;

  List<Product> get _visible {
    var list = _products;
    if (_selectedCategoryId != null) {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    return list;
  }

  double get _subtotal => _cart.fold(0.0, (s, e) => s + e.total);
  double get _discount => double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
  double get _grandTotal => (_subtotal - _discount).clamp(0.0, double.infinity);
  double get _cashSplit => double.tryParse(_cashSplitCtrl.text.trim()) ?? 0;
  double get _bankSplit => double.tryParse(_bankSplitCtrl.text.trim()) ?? 0;
  double get _mobileSplit => double.tryParse(_mobileSplitCtrl.text.trim()) ?? 0;
  double get _splitTotal => _cashSplit + _bankSplit + _mobileSplit;

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
    _cashSplitCtrl.dispose();
    _bankSplitCtrl.dispose();
    _mobileSplitCtrl.dispose();
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
      if (!mounted) return;
      setState(() {
        _products = (results[0] as List).cast<Product>();
        _customers = (results[1] as List).cast<Customer>();
        _categories = (results[2] as List).cast<Map<String, dynamic>>();
        _dataLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _dataLoading = false);
      _showError(context.tr(
        'Alaabta lama soo gelin karin. Hubi internet-ka oo mar kale isku day.',
        'Could not load products. Check your connection and try again.',
      ));
    }
  }

  void _addToCart(Product p) {
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
        _showError(context.tr(
          'Kayd ku filan ma jiro: ${p.name}. Waxaa yaalla keliya ${_fmt(p.currentStock)} ${p.unit}.',
          'Not enough stock for ${p.name}. Only ${_fmt(p.currentStock)} ${p.unit} available.',
        ));
      }
    });
  }

  void _increment(int i) {
    final c = _cart[i];
    if (c.quantity + 1 > c.product.currentStock) {
      _showError(context.tr(
        'Kaydka ugu badan: ${_fmt(c.product.currentStock)} ${c.product.unit}.',
        'Max stock: ${_fmt(c.product.currentStock)} ${c.product.unit}.',
      ));
      return;
    }
    setState(() => c.quantity += 1);
  }

  void _decrement(int i) {
    final c = _cart[i];
    c.quantity <= 1 ? setState(() => _cart.removeAt(i)) : setState(() => c.quantity -= 1);
  }

  void _editQty(int i) {
    final c = _cart[i];
    final ctrl = TextEditingController(text: _fmt(c.quantity));
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(c.product.name, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.tr('Tirada', 'Quantity'),
            helperText: '${context.tr('Ugu badan', 'Max')}: ${_fmt(c.product.currentStock)} ${c.product.unit}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Jooji', 'Cancel'))),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(ctrl.text.trim());
              if (qty == null || qty <= 0) return;
              if (qty > c.product.currentStock) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${context.tr('Ugu badan ee la heli karo', 'Max available')}: ${_fmt(c.product.currentStock)} ${c.product.unit}.'),
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              setState(() => c.quantity = qty);
              Navigator.pop(context);
            },
            child: Text(context.tr('Deji', 'Set')),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  void _resetPaymentFields() {
    _referenceCtrl.clear();
    _reason.clear();
    _cashSplitCtrl.clear();
    _bankSplitCtrl.clear();
    _mobileSplitCtrl.clear();
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _customerId = null;
      _paymentMode = 'cash';
      _reason.clear();
      _referenceCtrl.clear();
      _discountCtrl.clear();
      _cashSplitCtrl.clear();
      _bankSplitCtrl.clear();
      _mobileSplitCtrl.clear();
      _operationKey = null;
    });
  }

  List<Map<String, dynamic>>? _buildPayments() {
    if (_paymentMode != 'mixed') {
      return [
        {
          'payment_method': _paymentMode,
          'amount': _grandTotal,
          'reference_no': _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
        }
      ];
    }

    if (_cashSplit < 0 || _bankSplit < 0 || _mobileSplit < 0) {
      _showError(context.tr('Qaybaha bixintu ma noqon karaan tiro taban.', 'Payment splits cannot be negative.'));
      return null;
    }
    if ((_splitTotal - _grandTotal).abs() > 0.01) {
      _showError(context.tr(
        'Wadarta qaybaha bixinta (${money(_splitTotal)}) waa inay la mid noqotaa wadarta iibka (${money(_grandTotal)}).',
        'Payment splits (${money(_splitTotal)}) must equal the sale total (${money(_grandTotal)}).',
      ));
      return null;
    }

    return [
      if (_cashSplit > 0) {'payment_method': 'cash', 'amount': _cashSplit},
      if (_bankSplit > 0) {'payment_method': 'bank', 'amount': _bankSplit},
      if (_mobileSplit > 0) {'payment_method': 'mobile_money', 'amount': _mobileSplit},
    ];
  }

  Future<void> _submit() async {
    if (_cart.isEmpty) {
      _showError(context.tr(
        'Cart-ku wuu madhan yahay. Ku dar alaab ka hor intaadan iibka dhamaystirin.',
        'Your cart is empty. Add items before completing a sale.',
      ));
      return;
    }

    final isCredit = _paymentMode == 'credit_request';
    if (isCredit && _customerId == null) {
      _showError(context.tr('Iibka deynta ah wuxuu u baahan yahay macmiil. Fadlan dooro macmiil.', 'Credit sales require a customer. Please select one.'));
      return;
    }
    if (isCredit && _reason.text.trim().length < 3) {
      _showError(context.tr('Geli sababta deynta (ugu yaraan 3 xaraf).', 'Enter a reason for the credit request (at least 3 characters).'));
      return;
    }
    if (_discount < 0) {
      _showError(context.tr('Dhimistu ma noqon karto tiro taban.', 'Discount cannot be negative.'));
      return;
    }
    if (_discount >= _subtotal && _subtotal > 0) {
      _showError(context.tr('Dhimistu waa inay ka yaraataa wadarta cart-ka.', 'Discount must be lower than the cart total.'));
      return;
    }

    final payments = isCredit ? null : _buildPayments();
    if (!isCredit && payments == null) return;

    _operationKey ??= newOperationKey(isCredit ? 'credit-request' : 'sale');
    setState(() => _loading = true);
    try {
      final items = _cart.map((c) => {'product_id': c.product.id, 'quantity': c.quantity}).toList();
      if (isCredit) {
        await _salesRepo.requestCreditSale(
          items: items,
          customerId: _customerId!,
          reason: _reason.text.trim(),
          discount: _discount,
          idempotencyKey: _operationKey,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(context.tr('Codsiga deynta waxaa loo diray milkiilaha si loo ansixiyo.', 'Credit request sent to owner for approval.')),
            behavior: SnackBarBehavior.floating,
          ));
        _clearCart();
        await _load();
      } else {
        final saleId = await _salesRepo.createCashSale(
          items: items,
          payments: payments!,
          customerId: _customerId,
          discount: _discount,
          idempotencyKey: _operationKey,
        );
        if (!mounted) return;
        _clearCart();
        await _load();
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReceiptScreen(saleId: saleId, profile: widget.profile),
        ));
      }
    } catch (e) {
      if (mounted) {
        _showError(friendlyError(
          e,
          fallback: context.tr(
            'Iibka lama dhamaystiri karin. Fadlan mar kale isku day. Isla codsiga dib ayaa loo isticmaali doonaa si aan iibku laba jeer u dhicin.',
            'Sale could not be completed. Retry safely; the same operation key will be reused to prevent duplicates.',
          ),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

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

  @override
  Widget build(BuildContext context) {
    if (_dataLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('POS'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: context.tr('Cusboonaysii', 'Refresh'))],
        ),
        body: LayoutBuilder(builder: (ctx, constraints) {
          final wide = constraints.maxWidth >= 700;
          if (wide) {
            return Row(children: [
              Expanded(flex: 3, child: _buildProductsPanel()),
              Container(width: 1, color: Colors.black12),
              Expanded(flex: 2, child: _buildCartPanel(compact: false)),
            ]);
          }
          return DefaultTabController(
            length: 2,
            child: Column(children: [
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  labelColor: Theme.of(context).colorScheme.primary,
                  tabs: [
                    Tab(icon: const Icon(Icons.inventory_2_outlined), text: context.tr('Alaab', 'Products')),
                    Tab(icon: const Icon(Icons.shopping_cart_outlined), text: '${context.tr('Cart', 'Cart')} (${_cart.length})'),
                  ],
                ),
              ),
              Expanded(child: TabBarView(children: [_buildProductsPanel(), _buildCartPanel(compact: true)])),
            ]),
          );
        }),
      ),
    );
  }

  Widget _buildProductsPanel() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('Raadi alaabta…', 'Search products…'), isDense: true),
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
              _CatChip(label: context.tr('Dhammaan', 'All'), selected: _selectedCategoryId == null, onTap: () => setState(() => _selectedCategoryId = null)),
              for (final cat in _categories) ...[
                const SizedBox(width: 6),
                _CatChip(
                  label: cat['name'] as String,
                  selected: _selectedCategoryId == cat['id'],
                  onTap: () => setState(() => _selectedCategoryId = cat['id'] as String),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 4),
      Expanded(
        child: _visible.isEmpty
            ? Center(child: Text(context.tr('Alaab lama helin.', 'No products found.'), style: const TextStyle(color: Colors.black38)))
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
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      subtitle: Text('${money(p.sellingPrice)}  •  ${_fmt(p.currentStock)} ${p.unit}', style: TextStyle(fontSize: 11, color: outOfStock ? Colors.red.shade700 : p.isLowStock ? Colors.orange.shade700 : null)),
                      trailing: FilledButton.tonal(
                        onPressed: outOfStock ? null : () => _addToCart(p),
                        style: FilledButton.styleFrom(minimumSize: const Size(48, 40), padding: const EdgeInsets.symmetric(horizontal: 12), textStyle: const TextStyle(fontSize: 20)),
                        child: Text(outOfStock ? context.tr('Maqan', 'Out') : '+'),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _buildCartPanel({required bool compact}) {
    final checkout = _buildCheckoutArea(compact: compact);
    return SafeArea(
      top: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Row(children: [
            Expanded(child: Text(_cart.isEmpty ? context.tr('Cart', 'Cart') : '${context.tr('Cart', 'Cart')} (${_cart.length})', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
            if (_cart.isNotEmpty) TextButton(onPressed: _clearCart, style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact), child: Text(context.tr('Nadiifi', 'Clear'), style: const TextStyle(fontSize: 12))),
          ]),
        ),
        Expanded(
          child: _cart.isEmpty
              ? Center(child: Text(context.tr('Alaab ka dooro tab-ka Alaabta', 'Add items from the Products tab'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black38, fontSize: 13)))
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
        Material(elevation: compact ? 8 : 0, color: Theme.of(context).scaffoldBackgroundColor, child: checkout),
      ]),
    );
  }

  Widget _buildCheckoutArea({required bool compact}) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_cart.isNotEmpty) ...[
          const Divider(height: 12),
          _TotalRow(label: context.tr('Subtotal', 'Subtotal'), value: money(_subtotal)),
          if (_discount > 0) _TotalRow(label: context.tr('Dhimis', 'Discount'), value: '− ${money(_discount)}', color: Colors.red.shade700),
          _TotalRow(label: context.tr('Wadar', 'Total'), value: money(_grandTotal), bold: true, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<String?>(
          initialValue: _customerId,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('Macmiil', 'Customer'), isDense: true),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(context.tr('Macmiil socod ah', 'Walk-in customer'), overflow: TextOverflow.ellipsis)),
            ..._customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => setState(() => _customerId = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _paymentMode,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('Qaabka bixinta', 'Payment mode'), isDense: true),
          items: [
            DropdownMenuItem(value: 'cash', child: Text(context.tr('Caddaan', 'Cash'))),
            DropdownMenuItem(value: 'bank', child: Text(context.tr('Bangiga', 'Bank transfer'))),
            DropdownMenuItem(value: 'mobile_money', child: Text(context.tr('Lacagta dhijitaalka', 'Mobile money'))),
            DropdownMenuItem(value: 'mixed', child: Text(context.tr('Isku dhafan', 'Mixed payment'))),
            DropdownMenuItem(value: 'credit_request', child: Text(context.tr('Codsi deyn', 'Credit request'))),
          ],
          onChanged: (v) => setState(() {
            _paymentMode = v ?? 'cash';
            _resetPaymentFields();
          }),
        ),
        if (_paymentMode == 'bank' || _paymentMode == 'mobile_money') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _referenceCtrl,
            decoration: InputDecoration(labelText: context.tr('Reference / lambarka transaction-ka', 'Reference / transaction no.'), isDense: true, prefixIcon: const Icon(Icons.tag_outlined, size: 18)),
          ),
        ],
        if (_paymentMode == 'mixed') ...[
          const SizedBox(height: 8),
          Text(context.tr('Qaybi wadarta hababka bixinta', 'Split the total across payment methods'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(controller: _cashSplitCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.tr('Caddaan', 'Cash'), isDense: true), onChanged: (_) => setState(() {}))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _bankSplitCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.tr('Bangiga', 'Bank'), isDense: true), onChanged: (_) => setState(() {}))),
            const SizedBox(width: 6),
            Expanded(child: TextField(controller: _mobileSplitCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.tr('Dhijitaal', 'Mobile'), isDense: true), onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 4),
          Text('${context.tr('Qaybaha', 'Splits')}: ${money(_splitTotal)} / ${money(_grandTotal)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: (_splitTotal - _grandTotal).abs() <= 0.01 ? Colors.green.shade700 : Colors.orange.shade700)),
        ],
        if (_paymentMode == 'credit_request') ...[
          const SizedBox(height: 8),
          TextField(controller: _reason, decoration: InputDecoration(labelText: context.tr('Sababta deynta *', 'Reason for credit *'), isDense: true)),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _discountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: context.tr('Dhimis ETB (ikhtiyaari)', 'Discount ETB (optional)'), isDense: true, prefixIcon: const Icon(Icons.discount_outlined, size: 18)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: (_loading || _cart.isEmpty) ? null : _submit,
          icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 18),
          label: Text(
            _paymentMode == 'credit_request' ? context.tr('U dir Ansixin', 'Send for Approval') : '${context.tr('Dhammee', 'Complete')}  ${money(_grandTotal)}',
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
    if (!compact) return content;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 430),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: content,
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  const _CartItem({required this.line, required this.onIncrement, required this.onDecrement, required this.onEditQty, required this.fmt});
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
            Text(money(line.total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          Row(children: [
            InkWell(onTap: onDecrement, borderRadius: BorderRadius.circular(12), child: const Padding(padding: EdgeInsets.all(14), child: Icon(Icons.remove_circle_outline, size: 20))),
            GestureDetector(onTap: onEditQty, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(6)), child: Text('${fmt(line.quantity)} ${line.product.unit}', style: const TextStyle(fontSize: 12)))),
            InkWell(onTap: onIncrement, borderRadius: BorderRadius.circular(12), child: const Padding(padding: EdgeInsets.all(14), child: Icon(Icons.add_circle_outline, size: 20))),
            const Spacer(),
            Text('× ${money(line.product.sellingPrice)}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ]),
        ]),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: bold ? 13 : 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black54)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: bold ? 13 : 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black54), overflow: TextOverflow.ellipsis)),
        ]),
      );
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
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? c : Colors.black54)),
      ),
    );
  }
}
