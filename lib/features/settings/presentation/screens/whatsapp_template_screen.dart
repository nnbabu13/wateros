import 'package:flutter/material.dart';

class WhatsAppTemplateScreen extends StatefulWidget {
  const WhatsAppTemplateScreen({super.key});

  @override
  State<WhatsAppTemplateScreen> createState() => _WhatsAppTemplateScreenState();
}

class _WhatsAppTemplateScreenState extends State<WhatsAppTemplateScreen> {
  final _invoiceTemplate = TextEditingController(
    text: 'Dear {customer_name},\n\nYour invoice of ₹{amount} is ready.\n\nThank you for your business!\n\n{business_name}',
  );
  final _paymentReminder = TextEditingController(
    text: 'Dear {customer_name},\n\nReminder: Payment of ₹{balance} is pending.\n\nPlease make the payment at your earliest convenience.\n\n{business_name}',
  );
  final _paymentReceived = TextEditingController(
    text: 'Dear {customer_name},\n\nWe have received your payment of ₹{amount}.\n\nThank you!\n\n{business_name}',
  );
  bool _isSaving = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    // In a real app, save to Supabase
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Templates saved!'), backgroundColor: Colors.green));
    }
  }

  @override
  void dispose() { _invoiceTemplate.dispose(); _paymentReminder.dispose(); _paymentReceived.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp Templates')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _templateCard('Invoice Sharing', _invoiceTemplate, Icons.receipt),
          const SizedBox(height: 12),
          _templateCard('Payment Reminder', _paymentReminder, Icons.alarm),
          const SizedBox(height: 12),
          _templateCard('Payment Received', _paymentReceived, Icons.check_circle),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Variables', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _var('{customer_name}', 'Customer name'),
                  _var('{amount}', 'Invoice amount'),
                  _var('{balance}', 'Pending balance'),
                  _var('{business_name}', 'Your business name'),
                  _var('{date}', 'Current date'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Templates'),
              style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _templateCard(String title, TextEditingController ctrl, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: ctrl, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter template...')),
          ],
        ),
      ),
    );
  }

  Widget _var(String varName, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(varName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          Text(desc, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
