import 'package:flutter/material.dart';

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.saleId});
  final String saleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Receipt generation placeholder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Sale ID: $saleId'),
            const SizedBox(height: 12),
            const Text('Next step: fetch sale, sale_items, payment, and generate PDF using pdf + printing packages.'),
          ],
        ),
      ),
    );
  }
}
