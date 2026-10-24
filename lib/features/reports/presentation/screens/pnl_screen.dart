import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';
import '../../../../core/utils/product_cost_helper.dart';

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
  double _cogs = 0;
  double _operatingExpenses = 0;
  Map<String, double> _expenseBreakdown = {};
  String? _openingCarriedFrom;
  bool _openingMissing = false;
  bool _closingMissing = false;
  List<Map<String, dynamic>> _finishedProducts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _monthStr => DateFormat('yyyy-MM-01').format(_selectedMonth);

  double get _grossProfit => _salesRevenue - _cogs;
  double get _netProfit => _grossProfit - _operatingExpenses;
  double get _grossMargin =>
      _salesRevenue > 0 ? (_grossProfit / _salesRevenue) * 100 : 0;
  double get _netMargin =>
      _salesRevenue > 0 ? (_netProfit / _salesRevenue) * 100 : 0;

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final monthStart = DateFormat('yyyy-MM-dd')
          .format(DateTime(_selectedMonth.year, _selectedMonth.month, 1));
      final monthEnd = DateFormat('yyyy-MM-dd')
          .format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0));

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

      final expensesFuture = Supabase.instance.client
          .from('expenses')
          .select('amount, expense_categories(name)')
          .eq('business_id', bizId)
          .gte('expense_date', monthStart)
          .lte('expense_date', monthEnd);

      final results = await Future.wait(
          [openingFuture, closingFuture, purchasesFuture, salesFuture, saleIdsFuture, expensesFuture]);

      final openingData = List<Map<String, dynamic>>.from(results[0] as List);
      final closingData = List<Map<String, dynamic>>.from(results[1] as List);
      final purchasesData = List<Map<String, dynamic>>.from(results[2] as List);
      final salesData = List<Map<String, dynamic>>.from(results[3] as List);
      final saleIdsData = List<Map<String, dynamic>>.from(results[4] as List);
      final expensesData = List<Map<String, dynamic>>.from(results[5] as List);

      // Opening stock: use this month's entry, otherwise carry forward the
      // latest prior month's closing stock.
      var openingStock = _sumValue(openingData);
      String? carriedFrom;
      var openingMissing = false;
      if (openingData.isEmpty) {
        final carried = await _fetchCarriedOpening(bizId);
        if (carried != null) {
          openingStock = carried.value;
          carriedFrom = carried.month;
        } else {
          openingMissing = true;
        }
      }

      final saleIds = saleIdsData.map((s) => s['id'] as String).toList();

      // Unified COGS: same helper as the dashboard.
      double cogs = 0;
      try {
        cogs = await ProductCostHelper.calculateCogs(
          businessId: bizId,
          saleIds: saleIds,
        );
      } catch (_) {}

      // Operating expenses grouped by category.
      var operatingExpenses = 0.0;
      final breakdown = <String, double>{};
      for (final ex in expensesData) {
        final amount = (ex['amount'] as num?)?.toDouble() ?? 0;
        operatingExpenses += amount;
        final cat = (ex['expense_categories'] as Map?)?['name'] as String? ??
            'Uncategorized';
        breakdown[cat] = (breakdown[cat] ?? 0) + amount;
      }

      final finishedProducts = await _loadFinishedProducts(bizId, saleIds);

      if (mounted) {
        setState(() {
          _openingStock = openingStock;
          _openingCarriedFrom = carriedFrom;
          _openingMissing = openingMissing;
          _closingStock = _sumValue(closingData);
          _closingMissing = closingData.isEmpty;
          _purchases = purchasesData.fold(
              0, (s, e) => s + ((e['total_amount'] as num?)?.toDouble() ?? 0));
          _salesRevenue = salesData.fold(
              0, (s, e) => s + ((e['total_amount'] as num?)?.toDouble() ?? 0));
          _cogs = cogs;
          _operatingExpenses = operatingExpenses;
          _expenseBreakdown = breakdown;
          _finishedProducts = finishedProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _sumValue(List<Map<String, dynamic>> rows) =>
      rows.fold(0, (s, e) => s + ((e['total_value'] as num?)?.toDouble() ?? 0));

  Future<({String month, double value})?> _fetchCarriedOpening(
      String bizId) async {
    try {
      final prior = await Supabase.instance.client
          .from('stock_entries')
          .select('month')
          .eq('business_id', bizId)
          .eq('entry_type', 'closing')
          .lt('month', _monthStr)
          .order('month', ascending: false)
          .limit(1)
          .maybeSingle();
      if (prior == null) return null;

      final raw = prior['month'];
      final monthStr =
          raw is String ? raw : DateFormat('yyyy-MM-dd').format(raw as DateTime);

      final rows = await Supabase.instance.client
          .from('stock_entries')
          .select('total_value')
          .eq('business_id', bizId)
          .eq('month', monthStr)
          .eq('entry_type', 'closing');

      final value = (rows as List).fold<double>(
          0,
          (s, e) =>
              s + (((e as Map)['total_value'] as num?)?.toDouble() ?? 0));
      return (month: monthStr, value: value);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadFinishedProducts(
      String bizId, List<String> saleIds) async {
    if (saleIds.isEmpty) return [];
    try {
      final saleItems = await Supabase.instance.client
          .from('sale_items')
          .select('product_id, product_name, quantity')
          .inFilter('sale_id', saleIds);

      final productIds = saleItems
          .map((item) => item['product_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      if (productIds.isEmpty) return [];

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
        final pid = item['product_id'] as String?;
        if (pid == null || !finishedProductIds.contains(pid)) continue;
        final name = item['product_name'] as String? ?? '';
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        if (productMap.containsKey(name)) {
          productMap[name]!['total_qty'] =
              (productMap[name]!['total_qty'] as double) + qty;
        } else {
          productMap[name] = {'name': name, 'total_qty': qty};
        }
      }

      final daysInMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
      return productMap.values.map((e) {
        final totalQty = e['total_qty'] as double;
        return {
          'name': e['name'],
          'total_qty': totalQty,
          'avg_daily': totalQty / daysInMonth,
        };
      }).toList()
        ..sort((a, b) =>
            (b['total_qty'] as double).compareTo(a['total_qty'] as double));
    } catch (_) {
      return [];
    }
  }

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

  String _formatMonth(String monthStr) {
    final d = DateTime.tryParse(monthStr);
    if (d == null) return monthStr;
    return DateFormat('MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final isCurrentMonth = _selectedMonth.year == DateTime.now().year &&
        _selectedMonth.month == DateTime.now().month;
    final showBanners =
        _openingCarriedFrom != null || _openingMissing || _closingMissing;

    final expenseEntries = _expenseBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                IconButton(
                    onPressed: _prevMonth,
                    icon: const Icon(Icons.chevron_left)),
                const Spacer(),
                Column(
                  children: [
                    Text(monthLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    if (isCurrentMonth)
                      Text('Current Month',
                          style: TextStyle(fontSize: 11, color: cs.primary)),
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
                  if (_openingCarriedFrom != null)
                    _banner(
                      icon: Icons.info_outline,
                      color: Colors.blue,
                      text:
                          'Opening stock not entered for this month. Carried forward from ${_formatMonth(_openingCarriedFrom!)} closing stock.',
                      cs: cs,
                    ),
                  if (_openingMissing)
                    _banner(
                      icon: Icons.warning_amber_outlined,
                      color: Colors.orange,
                      text:
                          'No opening stock found for this month or any earlier month. Profit is unaffected (COGS uses product costs), but set opening stock to track inventory accurately.',
                      cs: cs,
                    ),
                  if (_closingMissing)
                    _banner(
                      icon: Icons.warning_amber_outlined,
                      color: Colors.orange,
                      text: 'Closing stock not entered for this month.',
                      cs: cs,
                    ),
                  if (showBanners) const SizedBox(height: 4),
                  _pnlCard('Sales Revenue', _salesRevenue, cs.primary, cs),
                  const SizedBox(height: 8),
                  _pnlCard(
                    'Cost of Goods Sold (COGS)',
                    _cogs,
                    Colors.red,
                    cs,
                    isFormula: true,
                    subtitle: 'Sold quantity × product cost',
                  ),
                  const Divider(height: 24),
                  _pnlCard(
                    'Gross Profit',
                    _grossProfit,
                    _grossProfit >= 0 ? Colors.green : Colors.red,
                    cs,
                    isHighlight: true,
                    subtitle: 'Gross margin ${_grossMargin.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 20),
                  _pnlCard(
                    'Operating Expenses',
                    _operatingExpenses,
                    Colors.orange,
                    cs,
                  ),
                  if (expenseEntries.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < expenseEntries.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      expenseEntries[i].key,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text(
                                    '₹${expenseEntries[i].value.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant,
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
                  const Divider(height: 28),
                  _pnlCard(
                    'Net Profit',
                    _netProfit,
                    _netProfit >= 0 ? Colors.green : Colors.red,
                    cs,
                    isHighlight: true,
                    subtitle: 'Net margin ${_netMargin.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Inventory Movement (for reference)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Not used in profit — shown for stock tracking',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  _pnlCard('Opening Stock', _openingStock, Colors.orange, cs),
                  const SizedBox(height: 8),
                  _pnlCard('Purchases', _purchases, Colors.blue, cs),
                  const SizedBox(height: 8),
                  _pnlCard('Closing Stock', _closingStock, Colors.teal, cs),
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
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('Product',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text('Total',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text('Avg/Day',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          for (int i = 0; i < _finishedProducts.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _finishedProducts[i]['name'] as String,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      '${(_finishedProducts[i]['total_qty'] as double).toStringAsFixed(0)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: cs.primary),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      '${(_finishedProducts[i]['avg_daily'] as double).toStringAsFixed(1)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                          color: cs.tertiary),
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

  Widget _banner({
    required IconData icon,
    required Color color,
    required String text,
    required ColorScheme cs,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pnlCard(
    String label,
    double value,
    Color color,
    ColorScheme cs, {
    bool isFormula = false,
    bool isHighlight = false,
    String? subtitle,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (isFormula)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('f(x)',
                    style:
                        TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ),
            if (isFormula) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                      fontSize: isHighlight ? 16 : 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
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
