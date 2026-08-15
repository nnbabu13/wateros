import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  State<InventoryDashboardScreen> createState() => _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  bool _isLoading = true;
  double _rawMaterialValue = 0;
  double _finishedGoodsValue = 0;
  double _rawMaterialOpening = 0;
  double _rawMaterialPurchases = 0;
  double _finishedSales = 0;
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _finishedProducts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final now = DateTime.now();
      final monthStr = DateFormat('yyyy-MM-01').format(now);
      final monthStart = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
      final monthEnd = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));

      final allProducts = await Supabase.instance.client
          .from('products')
          .select('id, name, product_type, unit, packaging_unit, conversion_quantity, current_stock, minimum_stock, purchase_price, average_cost, selling_price, is_active')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .order('name');

      final rawList = List<Map<String, dynamic>>.from(allProducts as List)
          .where((p) => ['raw_material', 'packaging'].contains(p['product_type']))
          .toList();
      final finishedList = List<Map<String, dynamic>>.from(allProducts as List)
          .where((p) => p['product_type'] == 'finished_product')
          .toList();

      double rawOpeningValue = 0;
      double rawPurchasesValue = 0;
      double salesValue = 0;

      try {
        final openingData = await Supabase.instance.client
            .from('stock_entries')
            .select('total_value')
            .eq('business_id', bizId)
            .eq('month', monthStr)
            .eq('entry_type', 'opening');
        rawOpeningValue = (openingData as List).fold<double>(0, (s, e) => s + ((e['total_value'] as num?)?.toDouble() ?? 0));
      } catch (_) {}

      try {
        final purchases = await Supabase.instance.client
            .from('purchases')
            .select('purchase_items(total_amount, product_id)')
            .eq('business_id', bizId)
            .neq('status', 'cancelled')
            .gte('purchase_date', monthStart)
            .lte('purchase_date', monthEnd);
        for (final p in (purchases as List)) {
          final items = (p['purchase_items'] as List?) ?? [];
          for (final item in items) {
            final pid = item['product_id'] as String?;
            final product = rawList.firstWhere((r) => r['id'] == pid, orElse: () => {});
            if (product.isNotEmpty) {
              rawPurchasesValue += ((item['total_amount'] as num?)?.toDouble() ?? 0);
            }
          }
        }
      } catch (_) {}

      try {
        final salesData = await Supabase.instance.client
            .from('sales')
            .select('total_amount')
            .eq('business_id', bizId)
            .neq('status', 'cancelled')
            .gte('invoice_date', monthStart)
            .lte('invoice_date', monthEnd);
        salesValue = (salesData as List).fold<double>(0, (s, e) => s + ((e['total_amount'] as num?)?.toDouble() ?? 0));
      } catch (_) {}

      if (mounted) {
        setState(() {
          _rawMaterials = rawList;
          _finishedProducts = finishedList;
          _rawMaterialOpening = rawOpeningValue;
          _rawMaterialPurchases = rawPurchasesValue;
          _rawMaterialValue = rawOpeningValue + rawPurchasesValue;
          _finishedSales = salesValue;
          _finishedGoodsValue = salesValue;
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
    final netValue = _rawMaterialValue - _finishedGoodsValue;

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
                      Expanded(child: _valueCard('Raw Materials', _rawMaterialValue, Colors.orange)),
                      const SizedBox(width: 8),
                      Expanded(child: _valueCard('Finished Goods', _finishedGoodsValue, Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _valueCard('Net Value', netValue, Colors.blue),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _actionTile(Icons.add_box, 'Add Product', '/products/add'),
                      const SizedBox(width: 8),
                      _actionTile(Icons.calendar_month, 'Monthly Stock', '/inventory/monthly-stock'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _actionTile(Icons.shopping_cart, 'Purchase Material', '/purchases/create'),
                      const SizedBox(width: 8),
                      _actionTile(Icons.receipt_long, 'Stock Ledger', '/inventory/stock-ledger'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(height: 4),
            Text(
              '₹${value.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: color),
            ),
          ],
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
    final avgCost = (p['average_cost'] as num?)?.toDouble() ?? 0;
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
        trailing: Text('₹${(stock * avgCost).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: () => context.push('/inventory/${p['id']}/edit'),
      ),
    );
  }

  Widget _finishedProductTile(Map<String, dynamic> p) {
    final stock = (p['current_stock'] as num?)?.toDouble() ?? 0;
    final sellPrice = (p['selling_price'] as num?)?.toDouble() ?? 0;
    final unit = p['unit'] as String? ?? '';
    final pkgUnit = p['packaging_unit'] as String?;
    final conv = (p['conversion_quantity'] as num?)?.toDouble() ?? 1;

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
        onTap: () => context.push('/inventory/${p['id']}/edit'),
      ),
    );
  }
}
