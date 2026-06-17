import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../auth/models/app_profile.dart';
import '../data/sales_repository.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.saleId, required this.profile, this.initialData});

  final String saleId;
  final AppProfile profile;
  final Map<String, dynamic>? initialData;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _repo = SalesRepository();

  Map<String, dynamic>? _sale;
  String _storeName = 'Dukaan Dhisme POS';
  String? _storePhone;
  String? _storeAddress;
  bool _loading = true;
  String? _error;
  bool _generatingPdf = false;

  String _t(String so, String en) => AppLanguage.instance.isSomali ? so : en;

  @override
  void initState() {
    super.initState();
    _sale = widget.initialData;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([_repo.fetchSaleDetails(widget.saleId), _repo.fetchStore(widget.profile.storeId)]);
      final saleData = results[0];
      final storeData = results[1];
      if (!mounted) return;
      setState(() {
        _sale = saleData ?? _sale;
        _storeName = storeData?['name'] as String? ?? 'Dukaan Dhisme POS';
        _storePhone = storeData?['phone'] as String?;
        _storeAddress = storeData?['address'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = _t('Faahfaahinta rasiidka lama soo gelin karin.', 'Could not load full receipt details.'); });
    }
  }

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

  String get _sellerName => (_sale?['profiles'] as Map?)?['full_name'] as String? ?? '—';
  String get _customerName => (_sale?['customers'] as Map?)?['name'] as String? ?? _t('Macmiil socod ah', 'Walk-in customer');
  double get _total => (_sale?['total_amount'] as num?)?.toDouble() ?? 0;
  double get _subtotal => (_sale?['subtotal'] as num?)?.toDouble() ?? _total;
  double get _discount => (_sale?['discount'] as num?)?.toDouble() ?? 0;
  String? get _notes => _sale?['notes'] as String?;
  String? get _referenceNo => _sale?['reference_no'] as String?;
  bool get _isCreditUnpaid => _sale?['sale_type'] == 'credit' && _sale?['payment_status'] != 'paid';

  String get _paymentLabel {
    final saleType = _sale?['sale_type'] as String?;
    if (saleType == 'credit') return _sale?['payment_status'] == 'paid' ? _t('Deyn (la bixiyay)', 'Credit (paid)') : _t('Deyn', 'Credit');
    switch (_sale?['payment_method'] as String?) {
      case 'cash': return _t('Caddaan', 'Cash');
      case 'bank': return _t('Bangiga', 'Bank Transfer');
      case 'mobile_money': return 'Mobile Money';
      case 'mixed': return _t('Isku dhafan', 'Mixed');
      default: return saleType == 'partial' ? _t('Qayb bixin', 'Partial payment') : (saleType ?? '—');
    }
  }

  String get _statusLabel {
    final s = (_sale?['status'] as String?)?.toLowerCase();
    switch (s) {
      case 'pending': return _t('Sugaya', 'Pending');
      case 'cancelled': return _t('La joojiyay', 'Cancelled');
      case 'completed':
      case null:
      case '': return _t('Dhammaystiran', 'Completed');
      default: return s[0].toUpperCase() + s.substring(1);
    }
  }

  List<Map<String, dynamic>> get _items {
    final raw = _sale?['sale_items'];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(raw as List);
  }

  String _itemName(Map item) => item['product_name'] as String? ?? (item['products'] as Map?)?['name'] as String? ?? _t('Alaab aan la aqoon', 'Unknown item');
  String _itemUnit(Map item) => item['unit'] as String? ?? (item['products'] as Map?)?['unit'] as String? ?? '';
  double _itemQty(Map item) => ((item['quantity'] ?? item['qty'] ?? 0) as num).toDouble();
  double _itemUnitPrice(Map item) => ((item['unit_price'] ?? item['selling_price'] ?? item['price'] ?? 0) as num).toDouble();
  double _itemTotal(Map item) => ((item['total_price'] ?? item['line_total'] ?? item['subtotal']) as num?)?.toDouble() ?? _itemUnitPrice(item) * _itemQty(item);
  String _fmtQty(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  Future<void> _printPdf() async {
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (_) {
      _showPdfError(_t('Rasiidka lama daabici karin. Fadlan mar kale isku day.', 'Could not print receipt. Please try again.'));
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildPdf();
      await Printing.sharePdf(bytes: bytes, filename: 'receipt-$_invoiceNo.pdf');
    } catch (_) {
      _showPdfError(_t('PDF-ka lama samayn karin. Fadlan mar kale isku day.', 'Could not generate PDF. Please try again.'));
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  void _showPdfError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final estimatedHeightMm = 150 + (_items.length * 18) + (_notes != null && _notes!.isNotEmpty ? 18 : 0) + (_isCreditUnpaid ? 24 : 0);
    final receiptFormat = PdfPageFormat(80 * PdfPageFormat.mm, estimatedHeightMm * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm);
    const black = PdfColors.black;
    const grey = PdfColors.grey700;
    pw.TextStyle text([double size = 8]) => const pw.TextStyle(color: black).copyWith(fontSize: size);
    pw.TextStyle bold([double size = 8]) => pw.TextStyle(color: black, fontSize: size, fontWeight: pw.FontWeight.bold);

    doc.addPage(pw.Page(
      pageFormat: receiptFormat,
      build: (pw.Context ctx) => pw.Container(
        color: PdfColors.white,
        child: pw.DefaultTextStyle(
          style: text(),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Center(child: pw.Column(children: [
              pw.Text(_storeName, style: bold(13), textAlign: pw.TextAlign.center),
              if (_storePhone != null) pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(_storePhone!, style: text(9), textAlign: pw.TextAlign.center)),
              if (_storeAddress != null) pw.Text(_storeAddress!, style: text(9), textAlign: pw.TextAlign.center),
            ])),
            pw.Divider(color: black),
            pw.Center(child: pw.Text(_t('RASIID', 'RECEIPT'), style: bold(10))),
            pw.SizedBox(height: 4),
            _pdfMetaRow(_t('Invoice', 'Invoice'), _invoiceNo),
            _pdfMetaRow(_t('Taariikh', 'Date'), _dateLabel),
            _pdfMetaRow(_t('Iibiye', 'Seller'), _sellerName),
            _pdfMetaRow(_t('Macmiil', 'Customer'), _customerName),
            if (_referenceNo != null && _referenceNo!.isNotEmpty) _pdfMetaRow(_t('Ref No', 'Ref No'), _referenceNo!),
            pw.Divider(thickness: 0.5, color: black),
            if (_items.isNotEmpty) ...[
              pw.Table(columnWidths: const {0: pw.FlexColumnWidth(4.5), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(2.5)}, children: [
                pw.TableRow(children: [pw.Text(_t('Alaab', 'Item'), style: bold()), pw.Text(_t('Tiro', 'Qty'), style: bold()), pw.Text(_t('Wadar', 'Total'), textAlign: pw.TextAlign.right, style: bold())]),
                for (final item in _items)
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(_itemName(item), style: text()), pw.Text('@ ${money(_itemUnitPrice(item))}', style: text(7).copyWith(color: grey))])),
                    pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Text('${_fmtQty(_itemQty(item))} ${_itemUnit(item)}', style: text())),
                    pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Text(money(_itemTotal(item)), textAlign: pw.TextAlign.right, style: text())),
                  ]),
              ]),
              pw.Divider(thickness: 0.5, color: black),
            ],
            if (_discount > 0) ...[_pdfTotalRow(_t('Subtotal', 'Subtotal'), money(_subtotal)), _pdfTotalRow(_t('Dhimis', 'Discount'), '- ${money(_discount)}')],
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(_t('WADAR', 'TOTAL'), style: bold(11)), pw.Text(money(_total), style: bold(11))]),
            pw.SizedBox(height: 4),
            _pdfMetaRow(_t('Bixin', 'Payment'), _paymentLabel),
            if (_isCreditUnpaid) ...[
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(width: 1.5, color: black)),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(_t('DEYN TAAGAN', 'AMOUNT DUE'), style: bold(10)), pw.Text(money(_total), style: bold(10))]),
              ),
            ],
            if (_notes != null && _notes!.isNotEmpty) ...[pw.SizedBox(height: 4), pw.Text('${_t('Qoraal', 'Notes')}: $_notes', style: text(8).copyWith(color: grey))],
            pw.Divider(color: black),
            pw.Center(child: pw.Text(_t('Waad ku mahadsan tahay ganacsigaaga!', 'Thank you for your business!'), style: text(9))),
            pw.SizedBox(height: 6),
          ]),
        ),
      ),
    ));
    return doc.save();
  }

  pw.Widget _pdfMetaRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(width: 48, child: pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
      pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 8, color: PdfColors.black))),
    ]),
  );

  pw.Widget _pdfTotalRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)), pw.Text(value, style: const pw.TextStyle(fontSize: 9, color: PdfColors.black))]),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(_sale != null ? _invoiceNo : context.tr('Rasiid', 'Receipt')),
          actions: [
            if (_sale != null)
              _generatingPdf
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(onPressed: _printPdf, icon: const Icon(Icons.print_outlined), tooltip: context.tr('Daabac rasiidka', 'Print receipt')),
                      IconButton(onPressed: _sharePdf, icon: const Icon(Icons.share_outlined), tooltip: context.tr('Wadaag PDF', 'Share PDF')),
                    ]),
          ],
        ),
        body: _loading && _sale == null
            ? const Center(child: CircularProgressIndicator())
            : _sale == null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.black26),
                    const SizedBox(height: 16),
                    Text(context.tr('Rasiid lama heli karo.', 'Receipt not available.'), style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _loadDetails, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Retry'))),
                  ])))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(_storeName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        if (_storePhone != null) ...[const SizedBox(height: 2), Text(_storePhone!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 13))],
                        if (_storeAddress != null) ...[const SizedBox(height: 2), Text(_storeAddress!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 13))],
                      ]))),
                      const SizedBox(height: 12),
                      if (_isCreditUnpaid)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade300)),
                          child: Row(children: [Icon(Icons.schedule, size: 18, color: Colors.amber.shade800), const SizedBox(width: 8), Expanded(child: Text('${context.tr('Bixintu way sugaysaa — deyn taagan', 'Payment pending — amount due')}: ${money(_total)}', style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.w600)))]),
                        ),
                      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                        _MetaRow(label: context.tr('Invoice', 'Invoice'), value: _invoiceNo, bold: true),
                        _MetaRow(label: context.tr('Taariikh', 'Date'), value: _dateLabel),
                        _MetaRow(label: context.tr('Iibiye', 'Seller'), value: _sellerName),
                        _MetaRow(label: context.tr('Macmiil', 'Customer'), value: _customerName),
                        _MetaRow(label: context.tr('Bixin', 'Payment'), value: _paymentLabel),
                        _MetaRow(label: context.tr('Xaalad', 'Status'), value: _statusLabel, valueColor: _statusLabel == context.tr('Dhammaystiran', 'Completed') ? Colors.green : null),
                        if (_referenceNo != null && _referenceNo!.isNotEmpty) _MetaRow(label: 'Ref No', value: _referenceNo!),
                        if (_notes != null && _notes!.isNotEmpty) _MetaRow(label: context.tr('Qoraal', 'Notes'), value: _notes!),
                      ]))),
                      const SizedBox(height: 12),
                      if (_loading)
                        Card(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Column(children: [const CircularProgressIndicator(), const SizedBox(height: 8), Text(context.tr('Alaabta ayaa la soo gelinayaa…', 'Loading items…'), style: const TextStyle(color: Colors.black45))]))))
                      else
                        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(context.tr('Alaabta', 'Items'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_error != null && _items.isEmpty) Text(_error!, style: const TextStyle(color: Colors.black45, fontSize: 13))
                          else if (_items.isEmpty) Text(context.tr('Faahfaahinta alaabta iibkan lama heli karo.', 'Item details not available for this sale.'), style: const TextStyle(color: Colors.black45, fontSize: 13))
                          else ...[
                            const Divider(height: 1),
                            for (final item in _items) ...[
                              const SizedBox(height: 10),
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_itemName(item), style: const TextStyle(fontWeight: FontWeight.w600)), Text('${_fmtQty(_itemQty(item))} ${_itemUnit(item)}  ×  ${money(_itemUnitPrice(item))}', style: const TextStyle(fontSize: 12, color: Colors.black54))])),
                                Text(money(_itemTotal(item)), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ]),
                            ],
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                          ],
                        ]))),
                      const SizedBox(height: 12),
                      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                        if (_discount > 0) ...[_MetaRow(label: context.tr('Subtotal', 'Subtotal'), value: money(_subtotal)), _MetaRow(label: context.tr('Dhimis', 'Discount'), value: '− ${money(_discount)}', valueColor: Colors.red)],
                        _MetaRow(label: context.tr('Wadar', 'Total'), value: money(_total), bold: true, valueColor: cs.primary),
                      ]))),
                      const SizedBox(height: 24),
                      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _generatingPdf ? null : _printPdf, icon: _generatingPdf ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.print_outlined), label: Text(context.tr('Daabac Rasiid', 'Print Receipt')))),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _generatingPdf ? null : _sharePdf, icon: const Icon(Icons.share_outlined), label: Text(context.tr('Wadaag PDF', 'Share PDF')))),
                      const SizedBox(height: 12),
                    ]),
                  ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value, this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13))),
        Expanded(child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 14 : 13, color: valueColor))),
      ]),
    );
  }
}
