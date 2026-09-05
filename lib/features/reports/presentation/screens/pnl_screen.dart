import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class PnlScreen extends StatefulWidget {
  const PnlScreen({super.key});

  @override
  State<PnlScreen> createState() => _PnlScreenState();
}

class _PnlScreenState extends State<PnlScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = true;
  double _openingStock = 0;
  double _purchases = 0;
  double _closingStock = 0;
  double _salesRevenue = 0;
  List<Map<String, dynamic>> _finishedProducts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _monthStr => DateFormat('yyyy-MM-01').format(_selectedMonth);

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final monthStart = DateFormat('yyyy-MM-dd').format(DateTime(_selectedMonth.year, _selectedMonth.month, 1));
      final monthEnd = DateFormat('yyyy-MM-dd').format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0));

      final openingFuture = Supabase.instance.client
          .from('stock_entries')
          .select('total_value')
          .eq('business_id', bizId)
          .eq('month', _monthStr)
          .eq('entry_type', 'opening');

      final closingFuture = Supabase.instance.client
          .from('stock_entries')
          .select('total_value')
          .eq('business_id', bizId)
          .eq('month', _monthStr)
          .eq('entry_type', 'closing');

      final purchasesFuture = Supabase.instance.client
          .from('purchases')
          .select('total_amount')
          .eq('business_id', bizId)
          .neq('status', 'cancelled')
          .gte('purchase_date', monthStart)
          .lte('purchase_date', monthEnd);

      final salesFuture = Supabase.instance.client
          .from('sales')
          .select('total_amount')
          .eq('business_id', bizId)
          .neq('status', 'cancelled')
          .gte('invoice_date', monthStart)
          .lte('invoice_date', monthEnd);

      final saleIdsFuture = Supabase.instance.client
          .from('sales')
          .select('id')
          .eq('business_id', bizId)
          .neq('status', 'cancelled')
          .gte('invoice_date', monthStart)
          .lte('invoice_date', monthEnd);

      final results = await Future.wait([openingFuture, closingFuture, purchasesFuture, salesFuture, saleIdsFuture]);

      final openingData = List<Map<String, dynamic>>.from(results[0] as List);
      final closingData = List<Map<String, dynamic>>.from(results[1] as List);
      final purchasesData = List<Map<String, dynamic>>.from(results[2] as List);
      final salesData = List<Map<String, dynamic>>.from(results[3] as List);
      final saleIdsData = List<Map<String, dynamic>>.from(results[4] as List);

      List<Map<String, dynamic>> finishedProducts = [];
      final saleIds = saleIdsData.map((s) => s['id'] as String).toList();
      if (saleIds.isNotEmpty) {
        try {
          final saleItems = await Supabase.instance.client
              .from('sale_items')
              .select('product_id, product_name, quantity')
              .inFilter('sale_id', saleIds);

          final productIds = saleItems
              .map((item) => item['product_id'] as String)
              .toSet()
              .toList();

          if (productIds.isNotEmpty) {
            final products = await Supabase.instance.client
                .from('products')
                .select('id, name, product_type')
                .inFilter('id', productIds);

            final finishedProductIds = products
                .where((p) => p['product_type'] == 'finished_product')
                .map((p) => p['id'] as String)
                .toSet();

            final productMap = <String, Map<String, dynamic>>{};
            for (final item in saleItems) {
              final pid = item['product_id'] as String;
              if (!finishedProductIds.contains(pid)) continue;
              final name = item['product_name'] as String? ?? '';
              final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
              if (productMap.containsKey(name)) {
                productMap[name]!['total_qty'] =
                    (productMap[name]!['total_qty'] as double) + qty;
              } else {
                productMap[name] = {'name': name, 'total_qty': qty};
              }
            }

            final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
            finishedProducts = productMap.values.map((e) {
              final totalQty = e['total_qty'] as double;
              return {
                'name': e['name'],
                'total_qty': totalQty,
                'avg_daily': totalQty / daysInMonth,
              };
            }).toList()
              ..sort((a, b) =>
                  (b['total_qty'] as double).compareTo(a['total_qty'] as double));
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _openingStock = openingData.fold(0, (s, e) => s + ((e['total_value'] as num?)?.toDouble() ?? 0));
          _closingStock = closingData.fold(0, (s, e) => s + ((e['total_value'] as num?)?.toDouble() ?? 0));
          _purchases = purchasesData.fold(0, (s, e) => s + ((e['total_amount'] as num?)?.toDouble() ?? 0));
          _salesRevenue = salesData.fold(0, (s, e) => s + ((e['total_amount'] as num?)?.toDouble() ?? 0));
          _finishedProducts = finishedProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _cogs => _openingStock + _purchases - _closingStock;
  double get _grossProfit => _salesRevenue - _cogs;

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() {
        _selectedMonth = next;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final isCurrentMonth = _selectedMonth.year == DateTime.now().year && _selectedMonth.month == DateTime.now().month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: cs.surface,
            child: Row(
              children: [
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                const Spacer(),
                Column(
                  children: [
                    Text(monthLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    if (isCurrentMonth)
                      Text('Current Month', style: TextStyle(fontSize: 11, color: cs.primary)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: isCurrentMonth ? null : _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _pnlCard('Sales Revenue', _salesRevenue, cs.primary, cs),
                  const SizedBox(height: 12),
                  _pnlCard('Opening Stock', _openingStock, Colors.orange, cs),
                  const SizedBox(height: 8),
                  _pnlCard('Purchases', _purchases, Colors.blue, cs),
                  const SizedBox(height: 8),
                  _pnlCard('Closing Stock', _closingStock, Colors.teal, cs),
                  const Divider(height: 32),
                  _pnlCard('Cost of Goods Sold (COGS)', _cogs, Colors.red, cs, isFormula: true),
                  const SizedBox(height: 16),
                  _pnlCard('Gross Profit', _grossProfit, _grossProfit >= 0 ? Colors.green : Colors.red, cs, isHighlight: true),
                  if (_finishedProducts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Finished Products Sold',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Monthly totals & daily averages',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('Product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: cs.onSurfaceVariant)),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: cs.onSurfaceVariant)),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text('Avg/Day', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: cs.onSurfaceVariant)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          for (int i = 0; i < _finishedProducts.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _finishedProducts[i]['name'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      '${(_finishedProducts[i]['total_qty'] as double).toStringAsFixed(0)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cs.primary),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      '${(_finishedProducts[i]['avg_daily'] as double).toStringAsFixed(1)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: cs.tertiary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pnlCard(String label, double value, Color color, ColorScheme cs, {bool isFormula = false, bool isHighlight = false}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (isFormula)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('f(x)', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ),
            if (isFormula) const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                  fontSize: isHighlight ? 16 : 14,
                ),
              ),
            ),
            Text(
              '₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: isHighlight ? 18 : 15,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
