import 'package:flutter/material.dart';
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
  // product.id → controller for the counted quantity field
  final Map<String, TextEditingController> _controllers = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = _repo.listProducts().then((products) {
        // Create/keep controllers; don't reset ones already edited.
        for (final p in products) {
          _controllers.putIfAbsent(p.id, () => TextEditingController());
        }
        return products;
      });
    });
  }

  // Returns all products where the typed count differs from system stock.
  List<({Product product, double counted, double delta})> _changes(List<Product> products) {
    final result = <({Product product, double counted, double delta})>[];
    for (final p in products) {
      final text = _controllers[p.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final counted = double.tryParse(text);
      if (counted == null) continue;
      final delta = counted - p.currentStock;
      if (delta != 0) result.add((product: p, counted: counted, delta: delta));
    }
    return result;
  }

  Future<void> _submit(List<Product> allProducts) async {
    final changes = _changes(allProducts);
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('No changes to submit. All counted quantities match system stock.'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }

    final confirmed = await _showConfirmDialog(changes);
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    int successCount = 0;
    final errors = <String>[];

    for (final c in changes) {
      try {
        await _repo.adjustStock(
          productId: c.product.id,
          quantityChange: c.delta,
          reason: 'Stock reconciliation',
        );
        successCount++;
      } catch (e) {
        errors.add('${c.product.name}: ${friendlyError(e, fallback: 'Failed')}');
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (errors.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('$successCount item${successCount == 1 ? '' : 's'} adjusted successfully.'),
          behavior: SnackBarBehavior.floating,
        ));
      // Clear entered counts and reload
      for (final c in _controllers.values) c.clear();
      _load();
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Some adjustments failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (successCount > 0)
                Text('$successCount item${successCount == 1 ? '' : 's'} adjusted.'),
              const SizedBox(height: 8),
              ...errors.map((e) => Text('• $e', style: const TextStyle(fontSize: 13))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _load();
    }
  }

  Future<bool> _showConfirmDialog(
    List<({Product product, double counted, double delta})> changes,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Stock Adjustments'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${changes.length} product${changes.length == 1 ? '' : 's'} will be adjusted:',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: changes.length,
                      itemBuilder: (_, i) {
                        final c = changes[i];
                        final isGain = c.delta > 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.product.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(
                                    '${_fmtQty(c.product.currentStock)} → ${_fmtQty(c.counted)} ${c.product.unit}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isGain ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${isGain ? '+' : ''}${_fmtQty(c.delta)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isGain ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _fmtQty(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  List<Product> _filter(List<Product> products) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snapshot) {
        final allProducts = snapshot.data ?? [];
        final changeCount = _changes(allProducts).length;
        final filtered = _filter(allProducts);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Stock Count'),
            actions: [
              if (changeCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$changeCount change${changeCount == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload stock',
              ),
            ],
          ),
          body: Column(
            children: [
              // Instruction banner
              Container(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Enter the physical count for each product. Leave blank to skip.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search products',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              // List
              Expanded(
                child: snapshot.hasError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(
                              friendlyError(snapshot.error!, fallback: 'Could not load products.'),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                            ),
                          ]),
                        ),
                      )
                    : !snapshot.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? const Center(child: Text('No products found.', style: TextStyle(color: Colors.black45)))
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) => _ProductCountRow(
                                  product: filtered[i],
                                  controller: _controllers[filtered[i].id]!,
                                  fmtQty: _fmtQty,
                                  onChanged: () => setState(() {}),
                                ),
                              ),
              ),
            ],
          ),
          floatingActionButton: snapshot.hasData
              ? FloatingActionButton.extended(
                  onPressed: _submitting ? null : () => _submit(allProducts),
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_outlined),
                  label: Text(changeCount > 0 ? 'Submit ($changeCount)' : 'Submit'),
                  backgroundColor: changeCount > 0 ? cs.primary : Colors.grey.shade400,
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

// ── Product row ───────────────────────────────────────────────────────────────

class _ProductCountRow extends StatelessWidget {
  const _ProductCountRow({
    required this.product,
    required this.controller,
    required this.fmtQty,
    required this.onChanged,
  });

  final Product product;
  final TextEditingController controller;
  final String Function(double) fmtQty;
  final VoidCallback onChanged;

  double? get _counted => double.tryParse(controller.text.trim());
  double? get _delta => _counted != null ? _counted! - product.currentStock : null;
  bool get _hasChange => _delta != null && _delta != 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isGain = (_delta ?? 0) > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: _hasChange
          ? (isGain ? Colors.green.shade50 : Colors.orange.shade50)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(
                      'System: ${fmtQty(product.currentStock)} ${product.unit}',
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                    if (_hasChange) ...[
                      const SizedBox(width: 8),
                      Text(
                        '→ ${fmtQty(_counted!)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isGain ? Colors.green.shade700 : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Delta badge
            if (_hasChange)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isGain ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isGain ? '+' : ''}${fmtQty(_delta!)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isGain ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
              ),
            // Count input
            SizedBox(
              width: 80,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: fmtQty(product.currentStock),
                  hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _hasChange
                          ? (isGain ? Colors.green.shade400 : Colors.orange.shade400)
                          : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.primary),
                  ),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
