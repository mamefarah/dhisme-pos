// The pdf package exposes TextStyle/FontWeight combinations that the Flutter
// const-constructor lint can suggest even though Dart cannot const-evaluate
// those FontWeight operands. Keep these PDF styles runtime-constructed.
// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/money.dart';
import '../data/customer_repository.dart';
import '../models/customer.dart';

class CustomerStatementScreen extends StatefulWidget {
  const CustomerStatementScreen({super.key, required this.customer});
  final Customer customer;

  @override
  State<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  final _repo = CustomerRepository();
  late Future<Map<String, dynamic>> _future;
  bool _sharing = false;

  @override
  void initState() { super.initState(); _reload(); }
  void _reload() => setState(() => _future = _repo.customerStatement(customerId: widget.customer.id));

  List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) => List<Map<String, dynamic>>.from((data[key] as List?) ?? const []);

  double _sum(List<Map<String, dynamic>> rows, String key) => rows.fold(0, (s, e) => s + (((e[key] as num?) ?? 0).toDouble()));

  Future<void> _sharePdf(Map<String, dynamic> data) async {
    setState(() => _sharing = true);
    try {
      final bytes = await _buildPdf(data);
      await Printing.sharePdf(bytes: bytes, filename: 'customer-statement-${widget.customer.name}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Statement PDF lama samayn karin.', 'Could not generate statement PDF.'))), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<Uint8List> _buildPdf(Map<String, dynamic> data) async {
    final doc = pw.Document();
    final sales = _list(data, 'sales');
    final payments = _list(data, 'payments');
    final returns = _list(data, 'returns');
    final credit = _sum(sales, 'total_amount');
    final paid = _sum(payments, 'amount');
    final refunded = _sum(returns, 'refund_amount');
    final balance = widget.customer.totalBalance;
    final title = AppLanguage.instance.isSomali ? 'STATEMENT MACMIIL' : 'CUSTOMER STATEMENT';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => [
        pw.Text('Dukaan Dhisme POS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('${AppLanguage.instance.isSomali ? 'Macmiil' : 'Customer'}: ${widget.customer.name}'),
        if (widget.customer.phone != null) pw.Text('${AppLanguage.instance.isSomali ? 'Telefoon' : 'Phone'}: ${widget.customer.phone}'),
        pw.Text('${AppLanguage.instance.isSomali ? 'Taariikh' : 'Date'}: ${DateTime.now().toLocal()}'),
        pw.SizedBox(height: 16),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400), children: [
          _summaryRow(AppLanguage.instance.isSomali ? 'Iib deyn ah' : 'Credit sales', money(credit)),
          _summaryRow(AppLanguage.instance.isSomali ? 'Lacag la bixiyay' : 'Payments', money(paid)),
          _summaryRow(AppLanguage.instance.isSomali ? 'Celino' : 'Returns', money(refunded)),
          _summaryRow(AppLanguage.instance.isSomali ? 'Deyn taagan' : 'Current balance', money(balance), bold: true),
        ]),
        pw.SizedBox(height: 16),
        pw.Text(AppLanguage.instance.isSomali ? 'Iibka Deynta ah' : 'Credit Sales', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _simpleTable(sales, ['invoice_no', 'created_at', 'total_amount', 'balance_amount']),
        pw.SizedBox(height: 16),
        pw.Text(AppLanguage.instance.isSomali ? 'Lacag Bixinno' : 'Payments', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _simpleTable(payments, ['created_at', 'amount', 'payment_method', 'reference_no']),
        if (returns.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(AppLanguage.instance.isSomali ? 'Celino' : 'Returns', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _simpleTable(returns, ['return_no', 'created_at', 'refund_amount', 'reason']),
        ],
      ],
    ));
    return doc.save();
  }

  pw.TableRow _summaryRow(String label, String value, {bool bold = false}) => pw.TableRow(children: [
    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(value, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
  ]);

  pw.Widget _simpleTable(List<Map<String, dynamic>> rows, List<String> cols) {
    if (rows.isEmpty) return pw.Text(AppLanguage.instance.isSomali ? 'Xog ma jirto.' : 'No data.');
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(children: cols.map((c) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(c, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList()),
        ...rows.map((r) => pw.TableRow(children: cols.map((c) {
          final v = r[c];
          final text = v is num && c.contains('amount') ? money(v.toDouble()) : (v?.toString() ?? '');
          return pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(text, style: pw.TextStyle(fontSize: 8)));
        }).toList())),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Statement Macmiil', 'Customer Statement'))),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), Text(friendlyError(snapshot.error!, fallback: context.tr('Statement-ka lama soo gelin karin.', 'Could not load statement.')), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: Text(context.tr('Mar kale isku day', 'Try Again')))])));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final data = snapshot.data!;
            final sales = _list(data, 'sales');
            final payments = _list(data, 'payments');
            final returns = _list(data, 'returns');
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: ListTile(leading: const Icon(Icons.person_outline), title: Text(widget.customer.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(widget.customer.phone ?? context.tr('Telefoon ma jiro', 'No phone')), trailing: Text(money(widget.customer.totalBalance), style: TextStyle(fontWeight: FontWeight.bold, color: widget.customer.hasDebt ? Colors.red.shade700 : Colors.green.shade700)))),
              const SizedBox(height: 12),
              _SummaryCard(title: context.tr('Iibka Deynta ah', 'Credit Sales'), count: sales.length, amount: _sum(sales, 'total_amount')),
              _SummaryCard(title: context.tr('Lacag Bixinno', 'Payments'), count: payments.length, amount: _sum(payments, 'amount')),
              _SummaryCard(title: context.tr('Celino', 'Returns'), count: returns.length, amount: _sum(returns, 'refund_amount')),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _sharing ? null : () => _sharePdf(data), icon: _sharing ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf_outlined), label: Text(context.tr('Wadaag Statement PDF', 'Share Statement PDF'))),
              const SizedBox(height: 16),
              Text(context.tr('Dhaqdhaqaaqyadii ugu dambeeyay', 'Recent activity'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...sales.take(10).map((s) => ListTile(contentPadding: EdgeInsets.zero, title: Text(s['invoice_no'] as String? ?? '-'), subtitle: Text(s['created_at']?.toString() ?? ''), trailing: Text(money(((s['total_amount'] as num?) ?? 0).toDouble())))),
            ]);
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.count, required this.amount});
  final String title;
  final int count;
  final double amount;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(title: Text(title), subtitle: Text(context.tr('$count diiwaan', '$count record(s)')), trailing: Text(money(amount), style: const TextStyle(fontWeight: FontWeight.bold))));
}
