import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class ExpenseReportScreen extends StatefulWidget {
  const ExpenseReportScreen({super.key});

  @override
  State<ExpenseReportScreen> createState() => _ExpenseReportScreenState();
}

class _ExpenseReportScreenState extends State<ExpenseReportScreen> {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate);
      final expensesFuture = Supabase.instance.client
          .from('expenses')
          .select('*, expense_categories(name)')
          .eq('business_id', bizId)
          .gte('expense_date', fromStr)
          .lte('expense_date', toStr)
          .order('expense_date', ascending: false);
      final categoriesFuture = Supabase.instance.client
          .from('expense_categories')
          .select('id, name')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .order('name');
      final results = await Future.wait([expensesFuture, categoriesFuture]);
      if (mounted) {
        setState(() {
          _expenses = List<Map<String, dynamic>>.from(results[0]);
          _categories = List<Map<String, dynamic>>.from(results[1]);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered =>
      _selectedCategory == null ? _expenses : _expenses.where((e) => e['category_id'] == _selectedCategory).toList();

  double get _total => _filtered.fold<double>(0, (s, e) => s + (e['amount'] as num? ?? 0).toDouble());

  Map<String, double> get _byCategory {
    final map = <String, double>{};
    for (final e in _filtered) {
      final cat = e['expense_categories']?['name'] as String? ?? 'Other';
      map[cat] = (map[cat] ?? 0) + (e['amount'] as num? ?? 0).toDouble();
    }
    return map;
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_fromDate.isAfter(_toDate)) _toDate = _fromDate;
        } else {
          _toDate = picked;
          if (_toDate.isBefore(_fromDate)) _fromDate = _toDate;
        }
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Report')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date Range', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDate(true),
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(DateFormat('dd MMM yyyy').format(_fromDate)),
                              ),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward)),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDate(false),
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(DateFormat('dd MMM yyyy').format(_toDate)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Categories')),
                            ..._categories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))),
                          ],
                          onChanged: (v) => setState(() => _selectedCategory = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: cs.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Expenses', style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w600)),
                        Text('₹${_total.toStringAsFixed(2)}', style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w700, fontSize: 20)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_byCategory.isNotEmpty) ...[
                  Text('By Category', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._byCategory.entries.map((e) {
                    final pct = _total > 0 ? (e.value / _total * 100) : 0.0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${e.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: cs.outline)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                Text('Details (${_filtered.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ..._filtered.map((e) {
                  final cat = e['expense_categories']?['name'] as String? ?? 'Other';
                  final date = e['expense_date'] as String? ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(radius: 14, backgroundColor: cs.error.withOpacity(0.1), child: Icon(Icons.receipt, size: 16, color: cs.error)),
                      title: Text(cat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: Text(date, style: const TextStyle(fontSize: 12)),
                      trailing: Text('-₹${(e['amount'] as num? ?? 0).toDouble().toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
