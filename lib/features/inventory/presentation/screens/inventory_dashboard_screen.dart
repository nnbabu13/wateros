import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';
import '../../data/models/inventory_product.dart';

class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  State<InventoryDashboardScreen> createState() => _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _finishedProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final allProducts = await Supabase.instance.client
          .from('products')
          .select('id, name, product_type, unit, packaging_unit, conversion_quantity, current_stock, minimum_stock, purchase_price, average_cost, selling_price, is_active')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        final allList = List<Map<String, dynamic>>.from(allProducts as List);
        setState(() {
          _rawMaterials = allList
              .where((p) => ['raw_material', 'packaging'].contains(p['product_type']))
              .toList();
          _finishedProducts = allList
              .where((p) => p['product_type'] == 'finished_product')
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rawValue = _rawMaterials.fold<double>(0, (s, p) {
      final stock = (p['current_stock'] as num?)?.toDouble() ?? 0;
      final cost = (p['average_cost'] as num?)?.toDouble() ?? 0;
      return s + stock * cost;
    });
    final finishedValue = _finishedProducts.fold<double>(0, (s, p) {
      final stock = (p['current_stock'] as num?)?.toDouble() ?? 0;
      final price = (p['selling_price'] as num?)?.toDouble() ?? 0;
      return s + stock * price;
    });
    final lowStockCount = [..._rawMaterials, ..._finishedProducts]
        .where((p) {
          final stock = (p['current_stock'] as num?)?.toDouble() ?? 0;
          final min = (p['minimum_stock'] as num?)?.toDouble() ?? 0;
          return min > 0 && stock <= min;
        })
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(onPressed: () => context.push('/inventory/stock-ledger'), icon: const Icon(Icons.receipt_long), tooltip: 'Stock Ledger'),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _valueCard('Raw Materials', rawValue, Colors.orange),
                      const SizedBox(width: 8),
                      _valueCard('Finished Goods', finishedValue, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _valueCard('Total Value', rawValue + finishedValue, Colors.blue),
                      const SizedBox(width: 8),
                      _valueCard('Low Stock', lowStockCount.toDouble(), lowStockCount > 0 ? Colors.red : Colors.green),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionHeader('Quick Actions', null),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _actionTile(Icons.add_box, 'Add Product', '/products/add'),
                      const SizedBox(width: 8),
                      _actionTile(Icons.restaurant, 'Recipes', '/inventory/recipes'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _actionTile(Icons.precision_manufacturing, 'Production', '/inventory/production'),
                      const SizedBox(width: 8),
                      _actionTile(Icons.shopping_cart, 'Purchase Material', '/purchases/create'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionHeader('Raw Materials & Packaging', null),
                  const SizedBox(height: 8),
                  if (_rawMaterials.isEmpty)
                    _emptyCard('No raw materials yet')
                  else
                    ..._rawMaterials.map((p) => _materialTile(p)),
                  const SizedBox(height: 20),
                  _sectionHeader('Finished Products', null),
                  const SizedBox(height: 8),
                  if (_finishedProducts.isEmpty)
                    _emptyCard('No finished products yet')
                  else
                    ..._finishedProducts.map((p) => _finishedProductTile(p)),
                ],
              ),
            ),
    );
  }

  Widget _valueCard(String label, double value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 4),
              Text(
                label.contains('Stock') ? '${value.toInt()}' : '₹${value.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback? onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('See All')),
      ],
    );
  }

  Widget _actionTile(IconData icon, String label, String route) {
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.outline))),
      ),
    );
  }

  Widget _materialTile(Map<String, dynamic> p) {
    final stock = (p['current_stock'] as num?)?.toDouble() ?? 0;
    final minStock = (p['minimum_stock'] as num?)?.toDouble() ?? 0;
    final avgCost = (p['average_cost'] as num?)?.toDouble() ?? 0;
    final isLow = stock <= minStock && minStock > 0;
    final unit = p['unit'] as String? ?? '';
    final type = p['product_type'] as String? ?? '';
    final typeColor = type == 'raw_material' ? Colors.orange : Colors.teal;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withOpacity(0.1),
          child: Icon(type == 'raw_material' ? Icons.water_drop : Icons.inventory, color: typeColor, size: 18),
        ),
        title: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('${stock.toInt()} $unit • ₹${avgCost.toStringAsFixed(0)}/$unit',
            style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLow)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('LOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.red)),
              )
            else
              Text('₹${(stock * avgCost).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
        onTap: () => context.push('/inventory/${p['id']}/edit'),
      ),
    );
  }

  Widget _finishedProductTile(Map<String, dynamic> p) {
    final stock = (p['current_stock'] as num?)?.toDouble() ?? 0;
    final sellPrice = (p['selling_price'] as num?)?.toDouble() ?? 0;
    final minStock = (p['minimum_stock'] as num?)?.toDouble() ?? 0;
    final unit = p['unit'] as String? ?? '';
    final pkgUnit = p['packaging_unit'] as String?;
    final conv = (p['conversion_quantity'] as num?)?.toDouble() ?? 1;
    final isLow = stock <= minStock && minStock > 0;

    String stockText = '${stock.toInt()} $unit';
    if (pkgUnit != null && conv > 1) {
      final cases = stock ~/ conv;
      final rem = stock % conv;
      if (cases > 0 && rem > 0) {
        stockText = '$cases $pkgUnit + ${rem.toInt()} $unit';
      } else if (cases > 0) {
        stockText = '$cases $pkgUnit';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: const Icon(Icons.inventory_2, color: Colors.green, size: 18),
        ),
        title: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('$stockText • ₹$sellPrice', style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLow)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('LOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.red)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
        onTap: () => context.push('/inventory/${p['id']}/edit'),
      ),
    );
  }
}
