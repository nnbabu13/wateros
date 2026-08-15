import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class MonthlyStockScreen extends StatefulWidget {
  const MonthlyStockScreen({super.key});

  @override
  State<MonthlyStockScreen> createState() => _MonthlyStockScreenState();
}

class _MonthlyStockScreenState extends State<MonthlyStockScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _products = [];
  Map<String, Map<String, dynamic>> _openingEntries = {};
  Map<String, Map<String, dynamic>> _closingEntries = {};
  bool _isLoading = true;
  bool _isSaving = false;

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
      final productsFuture = Supabase.instance.client
          .from('products')
          .select('id, name, unit, product_type')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .order('name');

      final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      final prevMonthStr = DateFormat('yyyy-MM-01').format(prevMonth);

      final openingFuture = Supabase.instance.client
          .from('stock_entries')
          .select('product_id, quantity, unit_cost')
          .eq('business_id', bizId)
          .eq('month', _monthStr)
          .eq('entry_type', 'opening');

      final closingFuture = Supabase.instance.client
          .from('stock_entries')
          .select('product_id, quantity, unit_cost')
          .eq('business_id', bizId)
          .eq('month', prevMonthStr)
          .eq('entry_type', 'closing');

      final results = await Future.wait([productsFuture, openingFuture, closingFuture]);

      final products = List<Map<String, dynamic>>.from(results[0] as List);
      final openingData = List<Map<String, dynamic>>.from(results[1] as List);
      final prevClosingData = List<Map<String, dynamic>>.from(results[2] as List);

      final openingMap = <String, Map<String, dynamic>>{};
      for (final e in openingData) {
        openingMap[e['product_id'] as String] = {
          'quantity': (e['quantity'] as num?)?.toDouble() ?? 0,
          'unit_cost': (e['unit_cost'] as num?)?.toDouble() ?? 0,
        };
      }

      final closingMap = <String, Map<String, dynamic>>{};
      for (final e in prevClosingData) {
        closingMap[e['product_id'] as String] = {
          'quantity': (e['quantity'] as num?)?.toDouble() ?? 0,
          'unit_cost': (e['unit_cost'] as num?)?.toDouble() ?? 0,
        };
      }

      if (mounted) {
        setState(() {
          _products = products;
          _openingEntries = openingMap;
          _closingEntries = {};
          for (final p in products) {
            final pid = p['id'] as String;
            if (_openingEntries.containsKey(pid)) {
              _closingEntries[pid] = {
                'quantity': _openingEntries[pid]!['quantity'],
                'unit_cost': _openingEntries[pid]!['unit_cost'],
              };
            } else if (closingMap.containsKey(pid)) {
              _openingEntries[pid] = Map.from(closingMap[pid]!);
              _closingEntries[pid] = {
                'quantity': closingMap[pid]!['quantity'],
                'unit_cost': closingMap[pid]!['unit_cost'],
              };
            } else {
              _openingEntries[pid] = {'quantity': 0.0, 'unit_cost': 0.0};
              _closingEntries[pid] = {'quantity': 0.0, 'unit_cost': 0.0};
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalOpeningValue => _openingEntries.values.fold(
      0, (s, e) => s + (e['quantity'] as double) * (e['unit_cost'] as double));

  double get _totalClosingValue => _closingEntries.values.fold(
      0, (s, e) => s + (e['quantity'] as double) * (e['unit_cost'] as double));

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();

      for (final p in _products) {
        final pid = p['id'] as String;
        final opening = _openingEntries[pid]!;
        final closing = _closingEntries[pid]!;
        final oQty = opening['quantity'] as double;
        final oCost = opening['unit_cost'] as double;
        final cQty = closing['quantity'] as double;
        final cCost = closing['unit_cost'] as double;

        if (oQty > 0 || oCost > 0) {
          await Supabase.instance.client.from('stock_entries').upsert({
            'business_id': bizId,
            'product_id': pid,
            'month': _monthStr,
            'entry_type': 'opening',
            'quantity': oQty,
            'unit_cost': oCost,
          }, onConflict: 'business_id,product_id,month,entry_type');
        } else {
          await Supabase.instance.client
              .from('stock_entries')
              .delete()
              .eq('business_id', bizId)
              .eq('product_id', pid)
              .eq('month', _monthStr)
              .eq('entry_type', 'opening');
        }

        if (cQty > 0 || cCost > 0) {
          await Supabase.instance.client.from('stock_entries').upsert({
            'business_id': bizId,
            'product_id': pid,
            'month': _monthStr,
            'entry_type': 'closing',
            'quantity': cQty,
            'unit_cost': cCost,
          }, onConflict: 'business_id,product_id,month,entry_type');
        } else {
          await Supabase.instance.client
              .from('stock_entries')
              .delete()
              .eq('business_id', bizId)
              .eq('product_id', pid)
              .eq('month', _monthStr)
              .eq('entry_type', 'closing');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock entries saved!'), backgroundColor: Colors.green),
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
      if (mounted) setState(() => _isSaving = false);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final isCurrentMonth = _selectedMonth.year == DateTime.now().year && _selectedMonth.month == DateTime.now().month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Stock'),
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
                  icon: const Icon(Icons.chevron_left),
                ),
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
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text('Opening Stock', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text('₹${_totalOpeningValue.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.primary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text('Closing Stock', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text('₹${_totalClosingValue.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.tertiary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _products.length,
                itemBuilder: (context, index) => _buildProductRow(_products[index], cs),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> product, ColorScheme cs) {
    final pid = product['id'] as String;
    final name = product['name'] as String;
    final unit = product['unit'] as String? ?? 'pcs';
    final opening = _openingEntries[pid]!;
    final closing = _closingEntries[pid]!;
    final oQty = opening['quantity'] as double;
    final oCost = opening['unit_cost'] as double;
    final cQty = closing['quantity'] as double;
    final cCost = closing['unit_cost'] as double;
    final oValue = oQty * oCost;
    final cValue = cQty * cCost;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                if (oValue > 0 || cValue > 0)
                  Text('₹${(cValue - oValue).toStringAsFixed(0)}', style: TextStyle(
                    fontSize: 12,
                    color: cValue >= oValue ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  )),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Opening', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _StockInput(
                              value: oQty > 0 ? oQty.toStringAsFixed(oQty == oQty.roundToDouble() ? 0 : 1) : '',
                              hint: 'Qty',
                              suffix: unit,
                              onChanged: (v) {
                                setState(() {
                                  opening['quantity'] = double.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _StockInput(
                              value: oCost > 0 ? oCost.toStringAsFixed(oCost == oCost.roundToDouble() ? 0 : 2) : '',
                              hint: 'Cost',
                              prefix: '₹',
                              onChanged: (v) {
                                setState(() {
                                  opening['unit_cost'] = double.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Closing', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: _StockInput(
                              value: cQty > 0 ? cQty.toStringAsFixed(cQty == cQty.roundToDouble() ? 0 : 1) : '',
                              hint: 'Qty',
                              suffix: unit,
                              onChanged: (v) {
                                setState(() {
                                  closing['quantity'] = double.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _StockInput(
                              value: cCost > 0 ? cCost.toStringAsFixed(cCost == cCost.roundToDouble() ? 0 : 2) : '',
                              hint: 'Cost',
                              prefix: '₹',
                              onChanged: (v) {
                                setState(() {
                                  closing['unit_cost'] = double.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StockInput extends StatelessWidget {
  final String value;
  final String hint;
  final String? prefix;
  final String? suffix;
  final ValueChanged<String> onChanged;

  const _StockInput({
    required this.value,
    required this.hint,
    this.prefix,
    this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextFormField(
        initialValue: value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          suffixText: suffix,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
