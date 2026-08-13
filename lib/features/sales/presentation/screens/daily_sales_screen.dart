import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/business_helper.dart';

class DailySalesScreen extends StatefulWidget {
  const DailySalesScreen({super.key});

  @override
  State<DailySalesScreen> createState() => _DailySalesScreenState();
}

class _DailySalesScreenState extends State<DailySalesScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final salesFuture = Supabase.instance.client
          .from('sales')
          .select('*, customers(id, name, phone, whatsapp_phone, current_balance)')
          .eq('business_id', bizId)
          .eq('invoice_date', dateStr)
          .neq('status', 'cancelled')
          .order('created_at', ascending: false);
      final paymentsFuture = Supabase.instance.client
          .from('payments')
          .select('*, customers(name)')
          .eq('business_id', bizId)
          .eq('payment_date', dateStr)
          .order('created_at', ascending: false);
      final results = await Future.wait([salesFuture, paymentsFuture]);

      final salesList = List<Map<String, dynamic>>.from(results[0]);

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
          _sales = salesList;
          _payments = List<Map<String, dynamic>>.from(results[1]);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Sales'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError(_error!)
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
              _loadData();
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(_selectedDate),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (_isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _isToday ? null : () {
              setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
              _loadData();
            },
            icon: Icon(Icons.chevron_right, color: _isToday ? Colors.grey : null),
          ),
        ],
      ),
    );
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isToday) return 'Today, ${DateFormat('dd MMM yyyy').format(date)}';
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) return 'Yesterday, ${DateFormat('dd MMM yyyy').format(date)}';
    return DateFormat('EEEE, dd MMM yyyy').format(date);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  Widget _buildContent() {
    final cs = Theme.of(context).colorScheme;
    if (_sales.isEmpty && _payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('No sales today', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cs.onSurface.withOpacity(0.7))),
            const SizedBox(height: 8),
            Text('No sales or receipts for ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/sales/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Sale'),
            ),
          ],
        ),
      );
    }

    final totalSales = _sales.fold<double>(0, (sum, s) => sum + (s['total_amount'] as num? ?? 0).toDouble());
    final totalCollected = _payments.fold<double>(0, (sum, p) => sum + (p['amount'] as num? ?? 0).toDouble());
    final totalPending = _sales.fold<double>(0, (sum, s) => sum + (s['balance_amount'] as num? ?? 0).toDouble());

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(DateFormat('dd MMMM yyyy').format(_selectedDate),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cs.onPrimaryContainer)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _summaryItem('Total Sales', totalSales, Colors.blue),
                      _summaryItem('Collected', totalCollected, Colors.green),
                      _summaryItem('Pending', totalPending, Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_sales.isNotEmpty) ...[
            Text('Sales (${_sales.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._sales.map(_buildSaleCard),
          ],
          if (_payments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Receipts (${_payments.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._payments.map(_buildReceiptCard),
          ],
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final customer = sale['customers'] as Map<String, dynamic>?;
    final customerName = customer?['name'] as String? ?? 'Walk-in';
    final phone = customer?['phone'] as String? ?? '';
    final whatsappPhone = customer?['whatsapp_phone'] as String?;
    final customerId = customer?['id'] as String?;
    final status = sale['status'] as String? ?? 'pending';
    final statusColor = _getStatusColor(status);
    final total = (sale['total_amount'] as num? ?? 0).toDouble();
    final paid = (sale['paid_amount'] as num? ?? 0).toDouble();
    final balance = (sale['balance_amount'] as num? ?? 0).toDouble();
    final customerBalance = (customer?['current_balance'] as num? ?? 0).toDouble();
    final items = sale['items'] as List<dynamic>? ?? [];
    final saleId = sale['id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                _statusBadge(status, statusColor),
                PopupMenuButton(
                  padding: EdgeInsets.zero,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Sale')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Sale', style: TextStyle(color: Colors.red))),
                  ],
                  onSelected: (v) async {
                    if (v == 'edit') {
                      final result = await context.push<bool>('/sales/$saleId/edit');
                      if (result == true) _loadData();
                    } else if (v == 'delete') {
                      _deleteSale(sale);
                    }
                  },
                ),
              ],
            ),
            Text(sale['invoice_number'] ?? '', style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...items.map((item) {
                final name = item['product_name'] as String? ?? '';
                final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
                final rate = (item['unit_price'] as num?)?.toDouble() ?? 0;
                final amt = (item['total_amount'] as num?)?.toDouble() ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 4, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                      Text('${qty.toInt()} × ₹${rate.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                      const SizedBox(width: 8),
                      Text('₹${amt.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (paid > 0) ...[
                  const SizedBox(width: 8),
                  Text('Paid: ₹${paid.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
                if (balance > 0) ...[
                  const SizedBox(width: 8),
                  Text('Due: ₹${balance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
                const Spacer(),
                if (customerName != 'Walk-in' && phone.isNotEmpty)
                  IconButton(
                    onPressed: () => _sendWhatsAppReminder(sale, customerName, phone, whatsappPhone, items, total, paid, balance, customerBalance),
                    icon: const Icon(Icons.chat, color: Colors.green, size: 22),
                    tooltip: 'Send WhatsApp Reminder',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppReminder(
    Map<String, dynamic> sale,
    String customerName,
    String phone,
    String? whatsappPhone,
    List<dynamic> items,
    double total,
    double paid,
    double balance,
    double customerBalance,
  ) async {
    final dateStr = DateFormat('dd MMM yyyy').format(_selectedDate);
    final customerId = sale['customers']?['id'] as String?;

    // Fetch previous unpaid sales for this customer (before today)
    List<Map<String, dynamic>> previousSales = [];
    if (customerId != null) {
      try {
        final prevData = await Supabase.instance.client
            .from('sales')
            .select('id, invoice_number, invoice_date, total_amount, paid_amount, balance_amount')
            .eq('customer_id', customerId)
            .neq('status', 'cancelled')
            .neq('id', sale['id'] as String)
            .lt('invoice_date', DateFormat('yyyy-MM-dd').format(_selectedDate))
            .gt('balance_amount', 0)
            .order('invoice_date', ascending: true);
        
        for (var prev in prevData) {
          try {
            final prevItems = await Supabase.instance.client
                .from('sale_items')
                .select('product_name, quantity, unit_price, total_amount')
                .eq('sale_id', prev['id'] as String);
            prev['items'] = prevItems;
          } catch (e) {
            prev['items'] = [];
          }
          previousSales.add(prev);
        }
      } catch (e) {
        // Ignore errors fetching previous sales
      }
    }

    final buffer = StringBuffer();
    final rupee = String.fromCharCode(8377);

    // Header
    buffer.writeln('Date: $dateStr');
    buffer.writeln('Customer: $customerName');
    buffer.writeln('');

    // Items table header
    buffer.writeln('Item            Qty   Rate    Amount');
    buffer.writeln('- * - * - * - * - * - * - * - * - * -');

    // Items
    for (final item in items) {
      final name = item['product_name'] as String? ?? '';
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final rate = (item['unit_price'] as num?)?.toDouble() ?? 0;
      final amt = (item['total_amount'] as num?)?.toDouble() ?? 0;
      // Pad name to 14 chars, qty to 5 chars, rate to 6 chars
      final namePad = name.length > 14 ? name.substring(0, 14) : name.padRight(14);
      final qtyPad = qty.toString().padLeft(5);
      final ratePad = '$rupee${rate.toStringAsFixed(0)}'.padLeft(6);
      final amtStr = '$rupee${amt.toStringAsFixed(0)}';
      buffer.writeln('$namePad $qtyPad   $ratePad    $amtStr');
    }

    buffer.writeln('- * - * - * - * - * - * - * - * - * -');

    // Totals
    final totalStr = '$rupee${total.toStringAsFixed(0)}';
    buffer.writeln('Total${''.padRight(19)}$totalStr');

    if (paid > 0) {
      final paidStr = '$rupee${paid.toStringAsFixed(0)}';
      buffer.writeln('Received${''.padRight(16)}$paidStr');
    }

    if (balance > 0) {
      final balanceStr = '$rupee${balance.toStringAsFixed(0)}';
      buffer.writeln('*Balance Due${''.padRight(12)}$balanceStr*');
    }

    // Previous unpaid sales
    if (previousSales.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~');

      double totalPrevBalance = 0;

      for (final prev in previousSales) {
        final prevDateStr = prev['invoice_date'] as String? ?? '';
        final prevDate = DateTime.tryParse(prevDateStr);
        final prevFormattedDate = prevDate != null ? DateFormat('dd MMM').format(prevDate) : prevDateStr;
        final prevPaid = (prev['paid_amount'] as num?)?.toDouble() ?? 0;
        final prevBalance = (prev['balance_amount'] as num?)?.toDouble() ?? 0;
        final prevItems = prev['items'] as List<dynamic>? ?? [];
        totalPrevBalance += prevBalance;

        buffer.writeln('');
        buffer.writeln('*$prevFormattedDate*');

        // Items header
        buffer.writeln('Item            Qty   Rate    Amount');
        buffer.writeln('- * - * - * - * - * - * - * - * - * -');

        for (final item in prevItems) {
          final name = item['product_name'] as String? ?? '';
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          final rate = (item['unit_price'] as num?)?.toDouble() ?? 0;
          final amt = (item['total_amount'] as num?)?.toDouble() ?? 0;
          final namePad = name.length > 14 ? name.substring(0, 14) : name.padRight(14);
          final qtyPad = qty.toString().padLeft(5);
          final ratePad = '$rupee${rate.toStringAsFixed(0)}'.padLeft(6);
          final amtStr = '$rupee${amt.toStringAsFixed(0)}';
          buffer.writeln('$namePad $qtyPad   $ratePad    $amtStr');
        }

        buffer.writeln('- * - * - * - * - * - * - * - * - * -');
        if (prevPaid > 0) {
          buffer.writeln('Received${''.padRight(16)}$rupee${prevPaid.toStringAsFixed(0)}');
        }
        buffer.writeln('*Due${''.padRight(20)}$rupee${prevBalance.toStringAsFixed(0)}*');
      }

      buffer.writeln('');
      buffer.writeln('~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~ * ~');
      buffer.writeln('Previous Balance${''.padRight(8)}$rupee${totalPrevBalance.toStringAsFixed(0)}');
    }

    // Total balance (previous + today)
    final totalBalance = customerBalance;
    if (totalBalance > 0) {
      buffer.writeln('');
      buffer.writeln('*TOTAL DUE${''.padRight(15)}$rupee${totalBalance.toStringAsFixed(0)}*');
    }

    final message = buffer.toString();
    final phoneNumber = (whatsappPhone != null && whatsappPhone.isNotEmpty)
        ? whatsappPhone.replaceAll(RegExp(r'[^0-9]'), '')
        : phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phoneNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number found for this customer'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final url = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteSale(Map<String, dynamic> sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale'),
        content: Text('Delete invoice ${sale['invoice_number'] ?? ''}? This will reverse all related transactions and restore inventory.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final client = Supabase.instance.client;
    final saleId = sale['id'] as String;
    final customerId = sale['customers']?['id'] as String?;
    final paidAmount = (sale['paid_amount'] as num?)?.toDouble() ?? 0;
    final paymentMode = sale['payment_mode'] as String? ?? '';

    try {
      // 1. Restore inventory for each sale item
      final saleItems = await client.from('sale_items').select('product_id, quantity').eq('sale_id', saleId);
      for (final item in saleItems) {
        final productId = item['product_id'] as String?;
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
        if (productId != null && quantity > 0) {
          try {
            final product = await client.from('products').select('product_type, current_stock').eq('id', productId).single();
            final productType = product['product_type'] as String? ?? '';
            if (productType == 'finished_product') {
              final currentStock = (product['current_stock'] as num?)?.toDouble() ?? 0;
              await client.from('products').update({'current_stock': currentStock + quantity}).eq('id', productId);
            }
          } catch (_) {}
        }
      }

      // 2. Delete inventory movements
      await client.from('inventory_movements').delete().eq('reference_type', 'sale').eq('reference_id', saleId);

      // 3. Delete payments
      await client.from('payments').delete().eq('sale_id', saleId);

      // 4. Delete cash transactions
      await client.from('cash_transactions').delete().eq('reference_type', 'sale').eq('reference_id', saleId);

      // 5. Reverse bank account balance and delete bank transactions
      final bankTxns = await client.from('bank_transactions').select('bank_account_id, amount').eq('reference_type', 'sale').eq('reference_id', saleId);
      for (final txn in bankTxns) {
        final accId = txn['bank_account_id'] as String?;
        final amt = (txn['amount'] as num?)?.toDouble() ?? 0;
        if (accId != null && amt > 0) {
          try {
            final acc = await client.from('bank_accounts').select('balance').eq('id', accId).single();
            final currentBal = (acc['balance'] as num?)?.toDouble() ?? 0;
            await client.from('bank_accounts').update({'balance': currentBal - amt}).eq('id', accId);
          } catch (_) {}
        }
      }
      await client.from('bank_transactions').delete().eq('reference_type', 'sale').eq('reference_id', saleId);

      // 6. Delete sale items
      await client.from('sale_items').delete().eq('sale_id', saleId);

      // 7. Delete the sale
      await client.from('sales').delete().eq('id', saleId);

      // 8. Recalculate customer balance
      if (customerId != null) {
        try {
          final remainingSales = await client.from('sales').select('balance_amount').eq('customer_id', customerId);
          double totalDue = 0;
          for (final s in remainingSales) {
            totalDue += (s['balance_amount'] as num?)?.toDouble() ?? 0;
          }
          await client.from('customers').update({'current_balance': totalDue}).eq('id', customerId);
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale deleted and transactions reversed'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildReceiptCard(Map<String, dynamic> payment) {
    final customerName = payment['customers']?['name'] as String? ?? 'Customer';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.payments, color: Colors.white)),
        title: Text(customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(payment['payment_mode']?.toUpperCase() ?? 'CASH'),
        trailing: Text('+ ₹${(payment['amount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return Colors.green;
      case 'partially_paid': return Colors.orange;
      case 'pending': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $message'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }
}
