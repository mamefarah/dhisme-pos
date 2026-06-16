import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../auth/models/app_profile.dart';
import '../data/sales_repository.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({
    super.key,
    required this.saleId,
    required this.profile,
    this.initialData,
  });

  final String saleId;
  final AppProfile profile;

  /// Basic sale row pre-loaded from the list screen.
  /// Shown immediately while full details load in background.
  final Map<String, dynamic>? initialData;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _repo = SalesRepository();

  Map<String, dynamic>? _sale;
  String _storeName = 'Dhisme POS';
  String? _storePhone;
  String? _storeAddress;
  bool _loading = true;
  String? _error;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    _sale = widget.initialData;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _repo.fetchSaleDetails(widget.saleId),
        _repo.fetchStore(widget.profile.storeId),
      ]);
      final saleData = results[0] as Map<String, dynamic>?;
      final storeData = results[1] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _sale = saleData ?? _sale;
          _storeName = storeData?['name'] as String? ?? 'Dhisme POS';
          _storePhone = storeData?['phone'] as String?;
          _storeAddress = storeData?['address'] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load full receipt details.';
        });
      }
    }
  }

  // ── Data helpers ───────────────────────────────────────────────

  String get _invoiceNo {
    final inv = _sale?['invoice_no'] as String?;
    if (inv != null && inv.isNotEmpty) return inv;
    final id = widget.saleId;
    return id.length >= 8 ? id.substring(0, 8).toUpperCase() : id;
  }

  String get _dateLabel {
    final raw = _sale?['created_at'] as String?;
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    return dt != null ? formatDateTime(dt) : raw;
  }

  String get _sellerName =>
      (_sale?['profiles'] as Map?)?['full_name'] as String? ?? '—';

  String get _customerName =>
      (_sale?['customers'] as Map?)?['name'] as String? ?? 'Walk-in customer';

  double get _total => (_sale?['total_amount'] as num?)?.toDouble() ?? 0;
  double get _discount => (_sale?['discount'] as num?)?.toDouble() ?? 0;

  String get _paymentLabel {
    final saleType = _sale?['sale_type'] as String?;
    if (saleType == 'credit') {
      return _sale?['payment_status'] == 'paid' ? 'Credit (paid)' : 'Credit';
    }
    switch (_sale?['payment_method'] as String?) {
      case 'cash':         return 'Cash';
      case 'bank':         return 'Bank Transfer';
      case 'mobile_money': return 'Mobile Money';
      case 'mixed':        return 'Mixed';
      default:             return saleType == 'partial' ? 'Partial payment' : (saleType ?? '—');
    }
  }

  String get _statusLabel {
    final s = _sale?['status'] as String?;
    if (s == null || s.isEmpty) return 'Completed';
    return s[0].toUpperCase() + s.substring(1);
  }

  List<Map<String, dynamic>> get _items {
    final raw = _sale?['sale_items'];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  String _itemName(Map item) =>
      item['product_name'] as String? ??
      (item['products'] as Map?)?['name'] as String? ??
      'Unknown item';

  String _itemUnit(Map item) =>
      item['unit'] as String? ??
      (item['products'] as Map?)?['unit'] as String? ??
      '';

  double _itemQty(Map item) =>
      ((item['quantity'] ?? item['qty'] ?? 0) as num).toDouble();

  double _itemUnitPrice(Map item) =>
      ((item['unit_price'] ?? item['selling_price'] ?? item['price'] ?? 0) as num).toDouble();

  double _itemTotal(Map item) {
    final explicit =
        (item['total_price'] ?? item['line_total'] ?? item['subtotal']) as num?;
    return explicit?.toDouble() ?? _itemUnitPrice(item) * _itemQty(item);
  }

  String _fmtQty(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  // ── PDF generation ─────────────────────────────────────────────

  Future<void> _sharePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildPdf();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'receipt-$_invoiceNo.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate PDF. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      _storeName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (_storePhone != null)
                      pw.Text(
                        _storePhone!,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    if (_storeAddress != null)
                      pw.Text(
                        _storeAddress!,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Text(
                'RECEIPT',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice: $_invoiceNo',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_dateLabel, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Text('Seller: $_sellerName',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Customer: $_customerName',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),
              if (_items.isNotEmpty) ...[
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(3.5),
                    1: pw.FlexColumnWidth(1.2),
                    2: pw.FlexColumnWidth(1.8),
                    3: pw.FlexColumnWidth(1.8),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Text('Item',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Text('Qty',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 2),
                          child: pw.Text('Price',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Text('Total',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    for (final item in _items)
                      pw.TableRow(
                        children: [
                          pw.Text(
                            '${_itemName(item)} (${_itemUnit(item)})',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            _fmtQty(_itemQty(item)),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(right: 2),
                            child: pw.Text(
                              money(_itemUnitPrice(item)),
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          pw.Text(
                            money(_itemTotal(item)),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                  ],
                ),
                pw.Divider(thickness: 0.5),
              ],
              if (_discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('- ${money(_discount)}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(money(_total),
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('Payment: $_paymentLabel',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Status: $_statusLabel',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Thank you for your business!',
                    style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  // ── UI build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_sale != null ? _invoiceNo : 'Receipt'),
        actions: [
          if (_sale != null)
            _generatingPdf
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    onPressed: _sharePdf,
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share / Print PDF',
                  ),
        ],
      ),
      body: _loading && _sale == null
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 64, color: Colors.black26),
                        const SizedBox(height: 16),
                        const Text('Receipt not available.',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loadDetails,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _storeName,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (_storePhone != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _storePhone!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 13),
                                ),
                              ],
                              if (_storeAddress != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _storeAddress!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Meta info card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _MetaRow(
                                label: 'Invoice',
                                value: _invoiceNo,
                                bold: true,
                              ),
                              _MetaRow(label: 'Date', value: _dateLabel),
                              _MetaRow(label: 'Seller', value: _sellerName),
                              _MetaRow(
                                  label: 'Customer', value: _customerName),
                              _MetaRow(
                                  label: 'Payment', value: _paymentLabel),
                              _MetaRow(
                                label: 'Status',
                                value: _statusLabel,
                                valueColor: _statusLabel == 'Completed'
                                    ? Colors.green
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Items card
                      if (_loading)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Loading items…',
                                      style:
                                          TextStyle(color: Colors.black45)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Items',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                if (_error != null && _items.isEmpty) ...[
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                        color: Colors.black45,
                                        fontSize: 13),
                                  ),
                                ] else if (_items.isEmpty) ...[
                                  const Text(
                                    'Item details not available for this sale.',
                                    style: TextStyle(
                                        color: Colors.black45,
                                        fontSize: 13),
                                  ),
                                ] else ...[
                                  const Divider(height: 1),
                                  for (final item in _items) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _itemName(item),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                              Text(
                                                '${_fmtQty(_itemQty(item))} ${_itemUnit(item)}'
                                                '  ×  ${money(_itemUnitPrice(item))}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black54),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          money(_itemTotal(item)),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                ],
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Totals card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (_discount > 0)
                                _MetaRow(
                                  label: 'Discount',
                                  value: '− ${money(_discount)}',
                                  valueColor: Colors.red,
                                ),
                              _MetaRow(
                                label: 'Total',
                                value: money(_total),
                                bold: true,
                                valueColor: cs.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Share/Print button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _generatingPdf ? null : _sharePdf,
                          icon: _generatingPdf
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.share_outlined),
                          label: const Text('Share / Print PDF'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: bold ? 14 : 13,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
