import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';
import '../../../../core/utils/cash_transaction_helper.dart';

class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({super.key});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _refController = TextEditingController();

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _pendingSales = [];
  String? _selectedCustomerId;
  String? _selectedSaleId;
  String _paymentMode = 'cash';
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final data = await Supabase.instance.client
          .from('customers')
          .select('id, name, phone, current_balance')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(data);
          _isLoadingCustomers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCustomers = false);
    }
  }

  Future<void> _loadPendingSales(String customerId) async {
    try {
      final data = await Supabase.instance.client
          .from('sales')
          .select('id, invoice_number, total_amount, balance_amount')
          .eq('customer_id', customerId)
          .inFilter('status', ['pending', 'partially_paid'])
          .order('invoice_date', ascending: false);
      if (mounted) setState(() => _pendingSales = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final amount = double.parse(_amountController.text);

      // Create payment record and capture its ID
      final paymentResponse = await Supabase.instance.client
          .from('payments')
          .insert({
            'business_id': bizId,
            'customer_id': _selectedCustomerId,
            'sale_id': _selectedSaleId,
            'amount': amount,
            'payment_mode': _paymentMode,
            'payment_date': DateFormat('yyyy-MM-dd').format(_paymentDate),
            'reference_number': _refController.text.isEmpty ? null : _refController.text.trim(),
            'notes': _notesController.text.isEmpty ? null : _notesController.text.trim(),
          })
          .select()
          .single();
      final paymentId = paymentResponse['id'] as String;

      // Create cash transaction if payment mode is cash
      if (_paymentMode == 'cash') {
        await CashTransactionHelper.recordCashIn(
          businessId: bizId,
          amount: amount,
          referenceType: 'customer_payment',
          referenceId: paymentId,
          description: 'Payment from customer',
          transactionDate: _paymentDate,
        );
      }

      // Update sale paid_amount and balance_amount
      if (_selectedSaleId != null) {
        try {
          final saleData = await Supabase.instance.client
              .from('sales')
              .select('total_amount, paid_amount')
              .eq('id', _selectedSaleId!)
              .single();
          final totalAmt = (saleData['total_amount'] as num?)?.toDouble() ?? 0;
          final currentPaid = (saleData['paid_amount'] as num?)?.toDouble() ?? 0;
          final newPaid = currentPaid + amount;
          final newBalance = totalAmt - newPaid;
          final newStatus = newPaid >= totalAmt ? 'paid' : (newPaid > 0 ? 'partially_paid' : 'pending');
          await Supabase.instance.client.from('sales').update({
            'paid_amount': newPaid,
            'balance_amount': newBalance < 0 ? 0 : newBalance,
            'status': newStatus,
          }).eq('id', _selectedSaleId!);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _refController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _isLoadingCustomers
                ? const InputDecorator(
                    decoration: InputDecoration(labelText: 'Customer *', border: OutlineInputBorder()),
                    child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedCustomerId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Customer *', border: OutlineInputBorder()),
                    items: _customers
                        .map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text('${c['name']} (Bal: ₹${(c['current_balance'] as num).toStringAsFixed(0)})'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedCustomerId = v;
                        _selectedSaleId = null;
                        _pendingSales = [];
                      });
                      if (v != null) _loadPendingSales(v);
                    },
                    validator: (v) => v == null ? 'Required' : null,
                  ),
            if (_pendingSales.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSaleId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Link to Invoice (optional)',
                  border: OutlineInputBorder(),
                ),
                items: _pendingSales
                    .map((s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text('${s['invoice_number']} - Bal ₹${(s['balance_amount'] as num).toStringAsFixed(0)}'),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedSaleId = v);
                  if (v != null) {
                    final sale = _pendingSales.firstWhere((s) => s['id'] == v);
                    _amountController.text = (sale['balance_amount'] as num).toString();
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ ', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Cash')),
                ButtonSegment(value: 'upi', label: Text('UPI')),
                ButtonSegment(value: 'bank_transfer', label: Text('Bank')),
              ],
              selected: {_paymentMode},
              onSelectionChanged: (s) => setState(() => _paymentMode = s.first),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_paymentDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _paymentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _paymentDate = picked);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _refController,
              decoration: const InputDecoration(labelText: 'Reference Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Record Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
