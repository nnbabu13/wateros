import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class AddExpenseScreen extends StatefulWidget {
  final String? expenseId;
  const AddExpenseScreen({super.key, this.expenseId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategoryId;
  String _paymentMode = 'cash';
  DateTime _expenseDate = DateTime.now();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  bool _isLoadingCategories = true;

  bool get isEditing => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    _loadCategories().then((_) {
      if (isEditing) _loadExpense();
    });
  }

  Future<void> _loadExpense() async {
    try {
      final data = await Supabase.instance.client
          .from('expenses')
          .select()
          .eq('id', widget.expenseId!)
          .single();
      if (mounted) {
        setState(() {
          _selectedCategoryId = data['category_id'] as String?;
          _amountController.text = (data['amount'] as num?)?.toString() ?? '';
          _descriptionController.text = data['description'] as String? ?? '';
          _paymentMode = data['payment_mode'] as String? ?? 'cash';
          final dateStr = data['expense_date'] as String?;
          if (dateStr != null) _expenseDate = DateTime.parse(dateStr);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load expense: $e')),
        );
      }
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final data = await Supabase.instance.client
          .from('expense_categories')
          .select('id, name')
          .eq('business_id', bizId)
          .order('name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);
          _isLoadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _createCategory() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, nameController.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        final bizId = await BusinessHelper.getOrCreateBusinessId();
        final data = await Supabase.instance.client
            .from('expense_categories')
            .insert({'business_id': bizId, 'name': result})
            .select('id, name')
            .single();
        if (mounted) {
          setState(() {
            _categories.add(data);
            _selectedCategoryId = data['id'] as String;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final data = {
        'business_id': bizId,
        'category_id': _selectedCategoryId,
        'amount': double.parse(_amountController.text),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'expense_date': DateFormat('yyyy-MM-dd').format(_expenseDate),
        'payment_mode': _paymentMode,
      };

      if (isEditing) {
        await Supabase.instance.client
            .from('expenses')
            .update(data)
            .eq('id', widget.expenseId!);
      } else {
        await Supabase.instance.client.from('expenses').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Expense updated!' : 'Expense saved!'),
            backgroundColor: Colors.green,
          ),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Expense' : 'Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _isLoadingCategories
                      ? const InputDecorator(
                          decoration: InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                          child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                          items: _categories
                              .map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCategoryId = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _createCategory,
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Create Category',
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ ', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_expenseDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expenseDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _expenseDate = picked);
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Cash')),
                ButtonSegment(value: 'upi', label: Text('UPI')),
                ButtonSegment(value: 'bank_transfer', label: Text('Bank')),
              ],
              selected: {_paymentMode},
              onSelectionChanged: (s) => setState(() => _paymentMode = s.first),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEditing ? 'Update Expense' : 'Save Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
