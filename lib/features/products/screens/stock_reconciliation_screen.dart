import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../auth/models/app_profile.dart';
import '../data/product_repository.dart';
import '../models/product.dart';

class StockReconciliationScreen extends StatefulWidget {
  const StockReconciliationScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<StockReconciliationScreen> createState() => _StockReconciliationScreenState();
}

class _StockReconciliationScreenState extends State<StockReconciliationScreen> {
  final _repo = ProductRepository();
  final _search = TextEditingController();
  late Future<List<Product>> _future;
  final Map<String, TextEditingController> _controllers = {};
  bool _submitting = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); for (final c in _controllers.values) { c.dispose(); } super.dispose(); }

  void _load() {
    setState(() {
      _future = _repo.listProducts().then((products) {
        for (final p in products) { _controllers.putIfAbsent(p.id, () => TextEditingController()); }
        return products;
      });
    });
  }

  List<StockChange> _changes(List<Product> products) {
    final result = <StockChange>[];
    for (final p in products) {
      final text = _controllers[p.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final counted = double.tryParse(text);
      if (counted == null) continue;
      final delta = counted - p.currentStock;
      if (delta != 0) result.add(StockChange(p, counted, delta));
    }
    return result;
  }

  Future<void> _submit(List<Product> products) async {
    final changes = _changes(products);
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(context.tr('Isbeddel la gudbiyo ma jiro.', 'No changes to submit.')), behavior: SnackBarBehavior.floating));
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(context.tr('Xaqiiji Tirinta Kaydka', 'Confirm Stock Count')),
      content: Text(context.tr('${changes.length} alaab ayaa la sixi doonaa.', '${changes.length} item(s) will be adjusted.')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Jooji', 'Cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Xaqiiji', 'Confirm')))],
    ));
    if (ok != true || !mounted) return;
    setState(() => _submitting = true);
    var succeeded = 0;
    final failedNames = <String>[];
    // Each item is its own RPC call, so a mid-list failure must not be
    // reported as if nothing happened: items that already succeeded keep
    // their adjustment and have their field cleared, so re-submitting only
    // retries the ones that actually failed.
    for (final c in changes) {
      try {
        await _repo.adjustStock(productId: c.product.id, quantityChange: c.delta, reason: 'Stock count correction');
        succeeded++;
        _controllers[c.product.id]?.clear();
      } catch (e) {
        failedNames.add(c.product.name);
      }
    }
    if (!mounted) return;
    _load();
    if (failedNames.isEmpty) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(context.tr('$succeeded alaab ayaa la saxay.', '$succeeded item(s) adjusted.')), behavior: SnackBarBehavior.floating));
    } else {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(
        content: Text(context.tr(
          '$succeeded ayaa la saxay, ${failedNames.length} way fashilantay: ${failedNames.join(', ')}. Fadlan mar kale isku day kuwaas.',
          '$succeeded adjusted, ${failedNames.length} failed: ${failedNames.join(', ')}. Fix and submit again for those.',
        )),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    }
    setState(() => _submitting = false);
  }

  String _fmt(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  List<Product> _filter(List<Product> products) { final q = _search.text.trim().toLowerCase(); return q.isEmpty ? products : products.where((p) => p.name.toLowerCase().contains(q)).toList(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];
          final changed = _changes(all).length;
          final list = _filter(all);
          return Scaffold(
            appBar: AppBar(title: Text(context.tr('Tirinta Kaydka', 'Stock Count')), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: context.tr('Cusboonaysii', 'Refresh'))]),
            body: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: TextField(controller: _search, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: context.tr('Raadi alaabta', 'Search products'), isDense: true), onChanged: (_) => setState(() {}))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text(context.tr('Geli tirada dhabta ah. Ka tag madhan haddii aanad tirin.', 'Enter the physical count. Leave blank to skip.'), style: const TextStyle(fontSize: 12, color: Colors.black54))),
              Expanded(child: snapshot.hasError ? _ErrorView(error: snapshot.error!, onRetry: _load) : !snapshot.hasData ? const Center(child: CircularProgressIndicator()) : list.isEmpty ? Center(child: Text(context.tr('Alaab lama helin.', 'No products found.'), style: const TextStyle(color: Colors.black45))) : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 96), itemCount: list.length, itemBuilder: (context, i) { final p = list[i]; return _ProductCountRow(product: p, controller: _controllers[p.id]!, fmt: _fmt, onChanged: () => setState(() {})); })),
            ]),
            floatingActionButton: snapshot.hasData ? FloatingActionButton.extended(onPressed: _submitting ? null : () => _submit(all), icon: _submitting ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_outlined), label: Text(changed > 0 ? '${context.tr('Gudbi', 'Submit')} ($changed)' : context.tr('Gudbi', 'Submit'))) : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          );
        },
      ),
    );
  }
}

class StockChange {
  StockChange(this.product, this.counted, this.delta);
  final Product product;
  final double counted;
  final double delta;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), Text(friendlyError(error, fallback: context.tr('Alaabta lama soo gelin karin.', 'Could not load products.')), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again')))])));
}

class _ProductCountRow extends StatelessWidget {
  const _ProductCountRow({required this.product, required this.controller, required this.fmt, required this.onChanged});
  final Product product;
  final TextEditingController controller;
  final String Function(double) fmt;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final counted = double.tryParse(controller.text.trim());
    final countedText = counted == null ? '' : ' → ${fmt(counted)}';
    final hasChange = counted != null && counted != product.currentStock;
    final delta = counted == null ? 0.0 : counted - product.currentStock;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text('${context.tr('Nidaam', 'System')}: ${fmt(product.currentStock)} ${product.unit}${hasChange ? countedText : ''}', style: const TextStyle(fontSize: 12, color: Colors.black45))])),
        if (hasChange) Padding(padding: const EdgeInsets.only(right: 8), child: Text('${delta > 0 ? '+' : ''}${fmt(delta)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: delta >= 0 ? Colors.green.shade700 : Colors.orange.shade800))),
        SizedBox(width: 82, child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, decoration: InputDecoration(hintText: fmt(product.currentStock), isDense: true, border: const OutlineInputBorder()), onChanged: (_) => onChanged())),
      ])),
    );
  }
}
