import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/business_helper.dart';
import '../../data/models/stock_movement.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class InventoryProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const InventoryProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<InventoryProductDetailScreen> createState() => _InventoryProductDetailScreenState();
}

class _InventoryProductDetailScreenState extends ConsumerState<InventoryProductDetailScreen> {
  Map<String, dynamic>? _product;
  List<StockMovement> _movements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.listen<int>(dashboardRefreshProvider, (_, __) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prodFuture = Supabase.instance.client
          .from('products')
          .select()
          .eq('id', widget.productId)
          .single();
      final movFuture = Supabase.instance.client
          .from('inventory_movements')
          .select()
          .eq('product_id', widget.productId)
          .order('created_at', ascending: false)
          .limit(50);
      final results = await Future.wait([prodFuture, movFuture]);
      if (mounted) {
        setState(() {
          _product = results[0] as Map<String, dynamic>;
          _movements = (results[1] as List).map((e) => StockMovement.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final p = _product;
    if (p == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Product not found')));

    final cs = Theme.of(context).colorScheme;
    final stock = (p['current_stock'] as num?)?.toDouble() ?? 0;
    final minStock = (p['minimum_stock'] as num?)?.toDouble() ?? 0;
    final isLow = minStock > 0 && stock <= minStock;

    return Scaffold(
      appBar: AppBar(
        title: Text(p['name'] as String),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Product')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Product')),
            ],
            onSelected: (v) async {
              if (v == 'edit') {
                context.push('/inventory/${widget.productId}/edit');
              } else if (v == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Product?'),
                    content: const Text('This will deactivate the product.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await Supabase.instance.client.from('products').update({'is_active': false}).eq('id', widget.productId);
                  if (mounted) context.pop();
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: isLow ? Colors.red.withOpacity(0.05) : cs.primaryContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _stockStat('Current Stock', stock.toInt().toString(), isLow ? Colors.red : Colors.green),
                      _stockStat('Min Stock', minStock.toInt().toString(), Colors.orange),
                      _stockStat('Unit', p['unit'] as String? ?? 'piece', Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stockStat('Cost', '₹${(p['purchase_price'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}', Colors.teal),
                      _stockStat('Sell', '₹${(p['selling_price'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}', Colors.indigo),
                      _stockStat('Type', p['product_type'] as String? ?? 'N/A', Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _actionButton('Stock In', Icons.add_circle, Colors.green, () => _showStockDialog('in'))),
              const SizedBox(width: 8),
              Expanded(child: _actionButton('Stock Out', Icons.remove_circle, Colors.red, () => _showStockDialog('out'))),
              const SizedBox(width: 8),
              Expanded(child: _actionButton('Adjust', Icons.tune, Colors.orange, () => _showStockDialog('adjustment'))),
            ],
          ),
          const SizedBox(height: 16),
          Text('Recent Movements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_movements.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('No stock movements yet', style: TextStyle(color: cs.outline))),
              ),
            )
          else
            ..._movements.map((m) => _movementTile(m)),
        ],
      ),
    );
  }

  Widget _stockStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: color.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _movementTile(StockMovement m) {
    final isIn = m.type == 'in';
    final color = isIn ? Colors.green : m.type == 'out' ? Colors.red : Colors.orange;
    final icon = isIn ? Icons.arrow_downward : m.type == 'out' ? Icons.arrow_upward : Icons.tune;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          '${isIn ? '+' : m.type == 'out' ? '-' : ''}${m.quantity.toInt()} ${_product?['unit'] ?? ''}',
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
        subtitle: Text(m.notes ?? m.type.toUpperCase()),
        trailing: Text(DateFormat('dd MMM').format(m.date), style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Future<void> _showStockDialog(String type) async {
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'in' ? 'Stock In' : type == 'out' ? 'Stock Out' : 'Stock Adjustment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: type == 'adjustment' ? 'Actual Count' : 'Quantity',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text);
              if (qty != null && qty > 0) {
                Navigator.pop(ctx, {'quantity': qty, 'reason': reasonController.text});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (picked != null) {
      try {
        double qty = picked['quantity'] as double;
        final reason = (picked['reason'] as String).isEmpty ? null : picked['reason'] as String;

        double newStock = (_product?['current_stock'] as num?)?.toDouble() ?? 0;
        if (type == 'in') {
          newStock += qty;
        } else if (type == 'out') {
          newStock -= qty;
          qty = -qty;
        } else {
          final currentSystem = newStock;
          newStock = qty;
          qty = newStock - currentSystem;
        }

        await Future.wait([
          Supabase.instance.client.from('inventory_movements').insert({
            'business_id': _product?['business_id'],
            'product_id': widget.productId,
            'movement_type': type,
            'quantity': qty,
            'notes': reason,
          }),
          Supabase.instance.client.from('products').update({
            'current_stock': newStock,
          }).eq('id', widget.productId),
        ]);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stock ${type == 'in' ? 'added' : type == 'out' ? 'deducted' : 'adjusted'}'), backgroundColor: Colors.green),
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
