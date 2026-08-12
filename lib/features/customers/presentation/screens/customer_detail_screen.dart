import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final custFuture = Supabase.instance.client
          .from('customers')
          .select()
          .eq('id', widget.customerId)
          .single();
      final salesFuture = Supabase.instance.client
          .from('sales')
          .select('id, invoice_number, invoice_date, total_amount, paid_amount, balance_amount, status')
          .eq('customer_id', widget.customerId)
          .order('invoice_date', ascending: false)
          .limit(50);
      final paymentsFuture = Supabase.instance.client
          .from('payments')
          .select('id, amount, payment_mode, payment_date, reference_number, notes')
          .eq('customer_id', widget.customerId)
          .order('payment_date', ascending: false)
          .limit(50);
      final results = await Future.wait([custFuture, salesFuture, paymentsFuture]);
      
      final salesList = List<Map<String, dynamic>>.from(results[1] as List);
      
      // Fetch sale items for each sale
      for (var sale in salesList) {
        try {
          final items = await Supabase.instance.client
              .from('sale_items')
              .select('product_name, quantity, unit_price, total_amount')
              .eq('sale_id', sale['id'] as String);
          sale['items'] = items;
        } catch (e) {
          sale['items'] = [];
        }
      }

      if (mounted) {
        setState(() {
          _customer = results[0] as Map<String, dynamic>;
          _sales = salesList;
          _payments = List<Map<String, dynamic>>.from(results[3] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final c = _customer;
    if (c == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Customer not found')));
    }

    final cs = Theme.of(context).colorScheme;
    final balance = (c['current_balance'] as num?)?.toDouble() ?? 0;
    final creditLimit = (c['credit_limit'] as num?)?.toDouble() ?? 0;
    final totalSales = _sales.fold<double>(0, (s, sale) => s + ((sale['total_amount'] as num?)?.toDouble() ?? 0));
    final totalPaid = _payments.fold<double>(0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(c['name'] as String),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              const PopupMenuItem(value: 'edit', child: Text('Edit Customer')),
              const PopupMenuItem(value: 'call', child: Text('Call')),
              const PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
              const PopupMenuItem(value: 'create_sale', child: Text('Create Sale')),
              const PopupMenuItem(value: 'record_payment', child: Text('Record Payment')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('Delete Customer', style: TextStyle(color: Colors.red))),
            ],
            onSelected: (v) => _handleMenuAction(v),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProfileHeader(c, cs),
          _buildBalanceSummary(balance, creditLimit, totalSales, totalPaid, cs),
          _buildTabBar(cs),
          Expanded(child: _buildTabContent(cs)),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> c, ColorScheme cs) {
    final phone = c['phone'] as String? ?? '';
    final email = c['email'] as String?;
    final address = c['address'] as String?;
    final city = c['city'] as String?;
    final state = c['state'] as String?;
    final gst = c['gst_number'] as String?;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    (c['name'] as String).substring(0, 1).toUpperCase(),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(phone, style: TextStyle(color: cs.outline, fontSize: 14)),
                      if (email != null && email.isNotEmpty)
                        Text(email, style: TextStyle(color: cs.outline, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: cs.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [address, city, state].where((e) => e != null && e.isNotEmpty).join(', '),
                      style: TextStyle(color: cs.outline, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            if (gst != null && gst.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.receipt_long, size: 16, color: cs.outline),
                  const SizedBox(width: 6),
                  Text('GST: $gst', style: TextStyle(color: cs.outline, fontSize: 13)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSummary(double balance, double creditLimit, double totalSales, double totalPaid, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _statCard('Balance Due', '₹${balance.toStringAsFixed(0)}', balance > 0 ? Colors.red : Colors.green, cs),
                const SizedBox(width: 8),
                _statCard('Credit Limit', '₹${creditLimit.toStringAsFixed(0)}', Colors.orange, cs),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _statCard('Total Sales', '₹${totalSales.toStringAsFixed(0)}', Colors.blue, cs),
                const SizedBox(width: 8),
                _statCard('Total Paid', '₹${totalPaid.toStringAsFixed(0)}', Colors.teal, cs),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, ColorScheme cs) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: cs.outline)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _tabButton('Sales (${_sales.length})', 0, cs),
          _tabButton('Payments (${_payments.length})', 1, cs),
          _tabButton('Info', 2, cs),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index, ColorScheme cs) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? cs.onPrimary : cs.outline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ColorScheme cs) {
    switch (_selectedTab) {
      case 0:
        return _buildSalesTab(cs);
      case 1:
        return _buildPaymentsTab(cs);
      case 2:
        return _buildInfoTab(cs);
      default:
        return const SizedBox();
    }
  }

  Widget _buildSalesTab(ColorScheme cs) {
    if (_sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('No sales yet', style: TextStyle(color: cs.outline)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sales.length,
      itemBuilder: (context, index) {
        final sale = _sales[index];
        final total = (sale['total_amount'] as num?)?.toDouble() ?? 0;
        final balance = (sale['balance_amount'] as num?)?.toDouble() ?? 0;
        final status = sale['status'] as String;
        final dateStr = sale['invoice_date'] as String;
        final date = DateTime.tryParse(dateStr);
        final invNo = sale['invoice_number'] as String? ?? '';
        final items = sale['items'] as List<dynamic>? ?? [];

        final statusColor = status == 'paid' ? Colors.green : status == 'partially_paid' ? Colors.orange : Colors.red;
        final statusText = status == 'paid' ? 'Paid' : status == 'partially_paid' ? 'Partial' : 'Due';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/sales/${sale['id']}'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          invNo,
                          style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        date != null ? DateFormat('dd MMM yyyy').format(date) : dateStr,
                        style: TextStyle(fontSize: 11, color: cs.outline),
                      ),
                    ],
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...items.take(5).map((item) {
                      final name = item['product_name'] as String? ?? '';
                      final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
                      final price = (item['total_amount'] as num?)?.toDouble() ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 5, color: cs.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${qty.toInt()} × ₹${price.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 12, color: cs.outline),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (items.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('+ ${items.length - 5} more items', style: TextStyle(fontSize: 11, color: cs.outline)),
                      ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                      ),
                      const Spacer(),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      if (balance > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Due ₹${balance.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab(ColorScheme cs) {
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('No payments yet', style: TextStyle(color: cs.outline)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
        final mode = payment['payment_mode'] as String? ?? 'cash';
        final dateStr = payment['payment_date'] as String;
        final date = DateTime.tryParse(dateStr);
        final ref = payment['reference_number'] as String?;

        final modeIcon = mode == 'cash' ? Icons.money : mode == 'upi' ? Icons.phone_android : Icons.account_balance;
        final modeLabel = mode.toUpperCase();

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: Icon(modeIcon, color: Colors.green, size: 20),
            ),
            title: Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green)),
            subtitle: Text(
              '$modeLabel${ref != null ? ' • $ref' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              date != null ? DateFormat('dd MMM yy').format(date) : dateStr,
              style: TextStyle(fontSize: 12, color: cs.outline),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(ColorScheme cs) {
    final c = _customer!;
    final createdAt = c['created_at'] as String?;
    final createdDate = createdAt != null ? DateTime.tryParse(createdAt) : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoRow('Phone', c['phone'] as String? ?? '-', Icons.phone),
        if (c['whatsapp_phone'] != null && (c['whatsapp_phone'] as String).isNotEmpty)
          _infoRow('WhatsApp', c['whatsapp_phone'] as String, Icons.chat),
        if (c['email'] != null && (c['email'] as String).isNotEmpty)
          _infoRow('Email', c['email'] as String, Icons.email),
        if (c['address'] != null && (c['address'] as String).isNotEmpty)
          _infoRow('Address', c['address'] as String, Icons.location_on),
        if (c['city'] != null && (c['city'] as String).isNotEmpty)
          _infoRow('City', c['city'] as String, Icons.location_city),
        if (c['state'] != null && (c['state'] as String).isNotEmpty)
          _infoRow('State', c['state'] as String, Icons.map),
        if (c['pincode'] != null && (c['pincode'] as String).isNotEmpty)
          _infoRow('Pincode', c['pincode'] as String, Icons.pin_drop),
        if (c['gst_number'] != null && (c['gst_number'] as String).isNotEmpty)
          _infoRow('GST Number', c['gst_number'] as String, Icons.receipt_long),
        _infoRow('Opening Balance', '₹${(c['opening_balance'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}', Icons.account_balance_wallet),
        _infoRow('Credit Limit', '₹${(c['credit_limit'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}', Icons.credit_card),
        if (c['notes'] != null && (c['notes'] as String).isNotEmpty)
          _infoRow('Notes', c['notes'] as String, Icons.notes),
        if (createdDate != null)
          _infoRow('Added On', DateFormat('dd MMM yyyy').format(createdDate), Icons.calendar_today),
      ],
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        context.push('/customers/${widget.customerId}/edit').then((_) => _loadData());
        break;
      case 'call':
        final phone = _customer?['phone'] as String? ?? '';
        if (phone.isNotEmpty) launchUrl(Uri.parse('tel:$phone'));
        break;
      case 'whatsapp':
        final phone = _customer?['whatsapp_phone'] as String? ?? _customer?['phone'] as String? ?? '';
        if (phone.isNotEmpty) launchUrl(Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'[^0-9]'), '')}'));
        break;
      case 'create_sale':
        context.push('/sales/create');
        break;
      case 'record_payment':
        _showRecordPaymentDialog();
        break;
      case 'delete':
        _deleteCustomer();
        break;
    }
  }

  Future<void> _deleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Delete "${_customer?['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await Supabase.instance.client.from('customers').delete().eq('id', widget.customerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer deleted'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('foreign key') || e.toString().contains('violates')
            ? 'Cannot delete — this customer has linked sales. Delete all their sales first.'
            : 'Failed: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showRecordPaymentDialog() async {
    final amountController = TextEditingController();
    String mode = 'cash';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer: ${_customer?['name']}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text('Balance Due: ₹${(_customer?['current_balance'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ ', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Cash')),
                  ButtonSegment(value: 'upi', label: Text('UPI')),
                  ButtonSegment(value: 'bank_transfer', label: Text('Bank')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setDialogState(() => mode = s.first),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final amt = double.tryParse(amountController.text);
              if (amt != null && amt > 0) {
                Navigator.pop(ctx, {'amount': amt, 'mode': mode});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      try {
        final bizId = await Supabase.instance.client
            .from('customers')
            .select('business_id')
            .eq('id', widget.customerId)
            .single();

        await Supabase.instance.client.from('payments').insert({
          'business_id': bizId['business_id'],
          'customer_id': widget.customerId,
          'amount': result['amount'],
          'payment_mode': result['mode'],
        });

        // Update customer balance
        final currentBalance = (_customer?['current_balance'] as num?)?.toDouble() ?? 0;
        final newBalance = currentBalance - (result['amount'] as double);
        await Supabase.instance.client
            .from('customers')
            .update({'current_balance': newBalance})
            .eq('id', widget.customerId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment recorded'), backgroundColor: Colors.green),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
