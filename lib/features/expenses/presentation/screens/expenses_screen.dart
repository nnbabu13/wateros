import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final expensesFuture = Supabase.instance.client
          .from('expenses')
          .select('*, expense_categories(name)')
          .eq('business_id', bizId)
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
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    if (_selectedCategoryId == null) return _expenses;
    return _expenses.where((e) => e['category_id'] == _selectedCategoryId).toList();
  }

  double get _totalAmount => _filteredExpenses.fold<double>(0, (sum, e) => sum + (e['amount'] as num? ?? 0).toDouble());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Category',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.filter_list),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Categories')),
                          ..._categories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String))),
                        ],
                        onChanged: (v) => setState(() => _selectedCategoryId = v),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: cs.primaryContainer.withOpacity(0.3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_filteredExpenses.length} expenses', style: TextStyle(color: cs.onPrimaryContainer)),
                          Text('Total: ₹${_totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filteredExpenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 64, color: cs.outline),
                                  const SizedBox(height: 16),
                                  Text('No expenses found', style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredExpenses.length,
                                itemBuilder: (context, index) => _buildExpenseCard(_filteredExpenses[index]),
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/expenses/add');
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    final category = expense['expense_categories']?['name'] as String? ?? 'Other';
    final amount = (expense['amount'] as num? ?? 0).toDouble();
    final date = expense['expense_date'] as String? ?? '';
    final paymentMode = expense['payment_mode'] as String? ?? 'cash';
    final description = expense['description'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.1),
          child: const Icon(Icons.receipt, color: Colors.red),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('- ₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty) Text(description, maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(
              children: [
                Text(date, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(paymentMode.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
          onSelected: (v) {
            if (v == 'edit') _editExpense(expense);
            if (v == 'delete') _deleteExpense(expense);
          },
        ),
      ),
    );
  }

  void _editExpense(Map<String, dynamic> expense) async {
    await context.push('/expenses/add', extra: expense['id'] as String);
    _loadData();
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Delete this expense? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final expenseId = expense['id'] as String;
      final client = Supabase.instance.client;

      // Delete associated cash_transactions record
      await client.from('cash_transactions')
          .delete()
          .eq('reference_type', 'expense')
          .eq('reference_id', expenseId);

      await client.from('expenses').delete().eq('id', expenseId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted'), backgroundColor: Colors.green));
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }
}
