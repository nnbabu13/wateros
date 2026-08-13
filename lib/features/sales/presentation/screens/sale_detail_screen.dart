import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class SaleDetailScreen extends ConsumerStatefulWidget {
  final String saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  Map<String, dynamic>? _sale;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSale();
  }

  Future<void> _loadSale() async {
    try {
      final saleFuture = Supabase.instance.client
          .from('sales')
          .select('*, customer:customers(name, phone, address, gst_number)')
          .eq('id', widget.saleId)
          .single();

      final itemsFuture = Supabase.instance.client
          .from('sale_items')
          .select()
          .eq('sale_id', widget.saleId);

      final paymentsFuture = Supabase.instance.client
          .from('payments')
          .select()
          .eq('sale_id', widget.saleId)
          .order('created_at');

      final results = await Future.wait<dynamic>([saleFuture, itemsFuture, paymentsFuture]);

      if (mounted) {
        setState(() {
          _sale = results[0] as Map<String, dynamic>;
          _items = List<Map<String, dynamic>>.from(results[1] as List);
          _payments = List<Map<String, dynamic>>.from(results[2] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sale: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_sale != null
            ? 'Invoice ${_sale!['invoice_number'] ?? ''}'
            : 'Sale Details'),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Sale')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Sale', style: TextStyle(color: Colors.red))),
            ],
            onSelected: (v) async {
              if (v == 'edit') {
                final result = await context.push<bool>('/sales/${widget.saleId}/edit');
                if (result == true && mounted) {
                  _loadSale();
                }
              } else if (v == 'delete') {
                _deleteSale();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
              ? const Center(child: Text('Sale not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader(cs),
                    const SizedBox(height: 16),
                    _buildCustomerInfo(cs),
                    const SizedBox(height: 16),
                    _buildItemsCard(cs),
                    const SizedBox(height: 16),
                    _buildSummaryCard(cs),
                    const SizedBox(height: 16),
                    _buildPaymentInfo(cs),
                  ],
                ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    final invoiceNum = _sale!['invoice_number'] as String? ?? '';
    final invoiceDate = _sale!['invoice_date'] as String? ?? '';
    final status = _sale!['status'] as String? ?? 'pending';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: cs.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    invoiceNum,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                _statusBadge(status, cs),
              ],
            ),
            if (invoiceDate.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(DateTime.parse(invoiceDate)),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status, ColorScheme cs) {
    Color color;
    String text;
    switch (status) {
      case 'paid':
        color = Colors.green;
        text = 'Paid';
        break;
      case 'partially_paid':
        color = Colors.orange;
        text = 'Partial';
        break;
      case 'cancelled':
        color = Colors.grey;
        text = 'Cancelled';
        break;
      default:
        color = Colors.red;
        text = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCustomerInfo(ColorScheme cs) {
    final customer = _sale!['customer'] as Map<String, dynamic>?;
    final name = customer?['name'] as String? ?? 'Unknown';
    final phone = customer?['phone'] as String? ?? '';
    final address = customer?['address'] as String? ?? '';
    final gst = customer?['gst_number'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Customer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
              ],
            ),
            const Divider(height: 20),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(phone, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
            if (address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(address, style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ],
              ),
            ],
            if (gst.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.business, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('GST: $gst', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Items (${_items.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
              ],
            ),
            const Divider(height: 20),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No items', style: TextStyle(color: Colors.grey)),
              )
            else
              ...List.generate(_items.length, (index) {
                final item = _items[index];
                final productName = item['product_name'] as String? ?? '';
                final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
                final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
                final discount = (item['discount_amount'] as num?)?.toDouble() ?? 0;
                final gstRate = (item['gst_rate'] as num?)?.toDouble() ?? 0;
                final gstAmount = (item['gst_amount'] as num?)?.toDouble() ?? 0;
                final total = (item['total_amount'] as num?)?.toDouble() ?? 0;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: index < _items.length - 1
                      ? const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              productName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            '₹ ${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)} × ₹ ${unitPrice.toStringAsFixed(2)}'
                        '${discount > 0 ? ' (-₹${discount.toStringAsFixed(2)})' : ''}'
                        '${gstRate > 0 ? ' (GST $gstRate%)' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme cs) {
    final subtotal = (_sale!['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (_sale!['discount_amount'] as num?)?.toDouble() ?? 0;
    final tax = (_sale!['tax_amount'] as num?)?.toDouble() ?? 0;
    final total = (_sale!['total_amount'] as num?)?.toDouble() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('Subtotal', subtotal),
            if (discount > 0) _summaryRow('Discount', -discount, isNegative: true),
            if (tax > 0) _summaryRow('GST', tax),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                Text(
                  '₹ ${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${isNegative ? '-' : ''}₹ ${amount.abs().toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo(ColorScheme cs) {
    final paid = (_sale!['paid_amount'] as num?)?.toDouble() ?? 0;
    final balance = (_sale!['balance_amount'] as num?)?.toDouble() ?? 0;
    final notes = _sale!['notes'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Payment',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
              ],
            ),
            const Divider(height: 20),
            if (_payments.isNotEmpty) ...[
              ...List.generate(_payments.length, (index) {
                final p = _payments[index];
                final amount = (p['amount'] as num?)?.toDouble() ?? 0;
                final mode = (p['payment_mode'] as String? ?? '').toUpperCase().replaceAll('_', ' ');
                final date = p['payment_date'] as String? ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: index < _payments.length - 1
                      ? const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
                        )
                      : null,
                  child: Row(
                    children: [
                      Icon(
                        _paymentModeIcon(p['payment_mode'] as String? ?? ''),
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mode, style: const TextStyle(fontWeight: FontWeight.w500)),
                            if (date.isNotEmpty)
                              Text(
                                DateFormat('dd MMM yyyy').format(DateTime.parse(date)),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '₹ ${amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Paid Amount'),
                  Text(
                    '₹ ${paid.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.green),
                  ),
                ],
              ),
            ],
            if (balance > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance'),
                  Text(
                    '₹ ${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.red),
                  ),
                ],
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Notes',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(notes, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }

  IconData _paymentModeIcon(String mode) {
    switch (mode) {
      case 'cash':
        return Icons.money;
      case 'upi':
        return Icons.qr_code;
      case 'bank_transfer':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  Future<void> _deleteSale() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale'),
        content: Text('Delete invoice ${_sale!['invoice_number'] ?? ''}? This will reverse all related transactions and restore inventory. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final client = Supabase.instance.client;
    final saleId = widget.saleId;
    final sale = _sale!;
    final customerId = sale['customer_id'] as String?;
    final paidAmount = (sale['paid_amount'] as num?)?.toDouble() ?? 0;
    final paymentMode = sale['payment_mode'] as String? ?? '';

    try {
      // 1. Restore inventory for each sale item
      for (final item in _items) {
        final productId = item['product_id'] as String?;
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
        if (productId != null && quantity > 0) {
          final product = await client
              .from('products')
              .select('product_type, current_stock')
              .eq('id', productId)
              .single();
          final productType = product['product_type'] as String? ?? '';
          if (productType == 'finished_product') {
            final currentStock = (product['current_stock'] as num?)?.toDouble() ?? 0;
            await client.from('products').update({
              'current_stock': currentStock + quantity,
            }).eq('id', productId);
          }
        }
      }

      // 2. Delete inventory movements for this sale
      await client.from('inventory_movements')
          .delete()
          .eq('reference_type', 'sale')
          .eq('reference_id', saleId);

      // 3. Delete payments for this sale
      await client.from('payments').delete().eq('sale_id', saleId);

      // 4. Delete cash transactions for this sale
      await client.from('cash_transactions')
          .delete()
          .eq('reference_type', 'sale')
          .eq('reference_id', saleId);

      // 5. Reverse bank account balance if paid via UPI/bank_transfer
      if (paidAmount > 0 && (paymentMode == 'upi' || paymentMode == 'bank_transfer')) {
        final bankTxns = await client
            .from('bank_transactions')
            .select('bank_account_id, amount')
            .eq('reference_type', 'sale')
            .eq('reference_id', saleId);
        for (final txn in bankTxns) {
          final accId = txn['bank_account_id'] as String?;
          final amt = (txn['amount'] as num?)?.toDouble() ?? 0;
          if (accId != null && amt > 0) {
            final acc = await client
                .from('bank_accounts')
                .select('balance')
                .eq('id', accId)
                .single();
            final currentBal = (acc['balance'] as num?)?.toDouble() ?? 0;
            await client.from('bank_accounts').update({
              'balance': currentBal - amt,
            }).eq('id', accId);
          }
        }
        await client.from('bank_transactions')
            .delete()
            .eq('reference_type', 'sale')
            .eq('reference_id', saleId);
      } else {
        await client.from('bank_transactions')
            .delete()
            .eq('reference_type', 'sale')
            .eq('reference_id', saleId);
      }

      // 6. Delete sale items
      await client.from('sale_items').delete().eq('sale_id', saleId);

      // 7. Delete the sale
      await client.from('sales').delete().eq('id', saleId);

      // 8. Recalculate customer balance from remaining sales
      if (customerId != null) {
        try {
          final remainingSales = await client
              .from('sales')
              .select('balance_amount')
              .eq('customer_id', customerId);
          double totalDue = 0;
          for (final s in remainingSales) {
            totalDue += (s['balance_amount'] as num?)?.toDouble() ?? 0;
          }
          await client.from('customers').update({
            'current_balance': totalDue,
          }).eq('id', customerId);
        } catch (_) {}
      }

      if (mounted) {
        ref.read(dashboardRefreshProvider.notifier).state++;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale deleted and transactions reversed'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
