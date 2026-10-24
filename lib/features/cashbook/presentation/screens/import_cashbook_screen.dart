import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wateros/core/utils/business_helper.dart';
import 'package:wateros/features/sales/data/sale_save_helper.dart';
import '../../data/daybook_parser.dart';

enum _Step { paste, review }

class ImportCashbookScreen extends ConsumerStatefulWidget {
  const ImportCashbookScreen({super.key});

  @override
  ConsumerState<ImportCashbookScreen> createState() =>
      _ImportCashbookScreenState();
}

class _ImportCashbookScreenState extends ConsumerState<ImportCashbookScreen> {
  final _pasteController = TextEditingController();

  _Step _step = _Step.paste;
  String? _error;
  List<DaybookEntry> _entries = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  bool _isLoadingData = true;
  String? _businessId;
  bool _isImporting = false;
  int _importCurrent = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingData = false);
        return;
      }
      final businessId = await BusinessHelper.getOrCreateBusinessId();

      final categoriesFuture = Supabase.instance.client
          .from('expense_categories')
          .select('id, name')
          .eq('business_id', businessId)
          .order('name');

      final productsFuture = Supabase.instance.client
          .from('products')
          .select('id, name, selling_price, product_type')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');

      final results = await Future.wait([categoriesFuture, productsFuture]);

      if (mounted) {
        setState(() {
          _businessId = businessId;
          _categories = List<Map<String, dynamic>>.from(results[0]);
          _products = (List<Map<String, dynamic>>.from(results[1]))
              .where((p) => p['product_type'] == 'finished_product')
              .toList();
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  void _parse() {
    final text = _pasteController.text;
    if (text.trim().isEmpty) {
      setState(() => _error = 'Paste the income/expenditure table first.');
      return;
    }
    final result = DaybookParser.parse(text);
    if (result.entries.isEmpty) {
      setState(() =>
          _error = 'No rows with dates found. Expected columns: Date, '
              'Particulars, Income (₹), Expenditure (₹).');
      return;
    }
    setState(() {
      _entries = result.entries;
      _error = null;
      _step = _Step.review;
    });
    _applyDefaults();
  }

  void _applyDefaults() {
    for (final e in _entries) {
      if (e.invalid || e.isIncome) continue;
      final match = _matchCategory(e.particulars);
      if (match != null) {
        e.categoryId = match['id'] as String;
        e.categoryName = match['name'] as String;
      }
    }
  }

  Map<String, dynamic>? _matchCategory(String text) {
    final t = text.toLowerCase();
    bool has(List<String> keys) => keys.any(t.contains);

    String? want;
    if (has(['wage', 'wages', 'salary', 'hasil', 'staff', 'labor', 'labour'])) {
      want = 'salary';
    } else if (has(['transport', 'film', 'auto', 'tyre', 'trip', 'freight'])) {
      want = 'transport';
    } else if (has(['bill', 'recharge', 'mobile', 'electric', 'current'])) {
      want = 'electricity';
    } else if (has(['machine', 'pouch', 'repair', 'maintenance', 'service'])) {
      want = 'maintenance';
    } else if (has(['rent'])) {
      want = 'rent';
    } else if (has(['fuel', 'petrol', 'diesel'])) {
      want = 'fuel';
    } else if (has(['raw', 'material', 'caps', 'bags', 'can', 'preform'])) {
      want = 'raw material';
    }

    if (want != null) {
      for (final c in _categories) {
        final n = (c['name'] as String? ?? '').toLowerCase();
        if (n.contains(want)) return c;
      }
    }
    for (final c in _categories) {
      final n = (c['name'] as String? ?? '').toLowerCase();
      if (n == 'misc' || n == 'miscellaneous') return c;
    }
    return null;
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();

  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> list, String query, String nameKey) {
    final n = _normalize(query);
    if (n.isEmpty) return list.take(20).toList();
    return list
        .where((c) {
          final cn = _normalize(c[nameKey] as String? ?? '');
          if (cn.isEmpty) return false;
          return cn.contains(n) || n.contains(cn);
        })
        .take(20)
        .toList();
  }

  double get _incomeTotal => _entries
      .where((e) => !e.invalid && e.isIncome)
      .fold(0, (s, e) => s + e.amount);
  double get _expenseTotal => _entries
      .where((e) => !e.invalid && !e.isIncome)
      .fold(0, (s, e) => s + e.amount);
  int get _incomeCount => _entries.where((e) => !e.invalid && e.isIncome).length;
  int get _expenseCount =>
      _entries.where((e) => !e.invalid && !e.isIncome).length;
  bool get _allValid =>
      _entries.isNotEmpty && _entries.every((e) => e.isValid);

  Future<String> _resolveWalkIn(String businessId) async {
    var walkIn = await Supabase.instance.client
        .from('customers')
        .select('id')
        .eq('business_id', businessId)
        .eq('name', 'Walk-in')
        .eq('is_active', true)
        .maybeSingle();
    if (walkIn == null) {
      walkIn = await Supabase.instance.client
          .from('customers')
          .insert({
            'business_id': businessId,
            'name': 'Walk-in',
            'phone': '0000000000',
            'is_active': true,
          })
          .select('id')
          .single();
    }
    return walkIn['id'] as String;
  }

  Future<String> _ensureCategory(String businessId, String name) async {
    final existing = await Supabase.instance.client
        .from('expense_categories')
        .select('id, name')
        .eq('business_id', businessId)
        .ilike('name', name)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final created = await Supabase.instance.client
        .from('expense_categories')
        .insert({'business_id': businessId, 'name': name})
        .select('id, name')
        .single();
    final id = created['id'] as String;
    setState(() => _categories.add(created));
    return id;
  }

  Future<void> _import() async {
    if (!_allValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fix incomplete entries before importing')),
      );
      return;
    }
    final biz = _businessId;
    if (biz == null) return;

    setState(() {
      _isImporting = true;
      _importCurrent = 0;
    });

    var success = 0;
    final failures = <String>[];

    try {
      final walkInId = await _resolveWalkIn(biz);

      for (var i = 0; i < _entries.length; i++) {
        final e = _entries[i];
        if (mounted) setState(() => _importCurrent = i + 1);
        try {
          if (e.isIncome) {
            await SaleSaveHelper.createSale(
              businessId: biz,
              customerId: walkInId,
              invoiceDate: e.date!,
              items: [
                SaleLineInput(
                  productId: e.productId!,
                  productName: e.productName ?? e.particulars,
                  quantity: 1,
                  unitPrice: e.amount,
                ),
              ],
              payments: [SalePaymentInput(mode: 'cash', amount: e.amount)],
              notes: e.particulars,
            );
          } else {
            var categoryId = e.categoryId;
            if (categoryId == null || categoryId.isEmpty) {
              categoryId = await _ensureCategory(biz, 'Misc');
            }
            final expense = await Supabase.instance.client
                .from('expenses')
                .insert({
                  'business_id': biz,
                  'category_id': categoryId,
                  'amount': e.amount,
                  'description': e.particulars,
                  'expense_date': DateFormat('yyyy-MM-dd').format(e.date!),
                  'payment_mode': 'cash',
                })
                .select('id')
                .single();
            final expenseId = expense['id'] as String;
            await Supabase.instance.client.from('cash_transactions').insert({
              'business_id': biz,
              'transaction_type': 'out',
              'amount': e.amount,
              'reference_type': 'expense',
              'reference_id': expenseId,
              'description': e.particulars,
              'transaction_date': DateFormat('yyyy-MM-dd').format(e.date!),
            });
          }
          success++;
        } catch (err) {
          failures.add(
              '${e.particulars}: ${err.toString().replaceFirst('Exception: ', '')}');
        }
      }
    } catch (e) {
      failures.add(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }

    if (!mounted) return;

    if (success > 0 && failures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $success entries successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else if (success > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Imported $success of ${_entries.length}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: failures
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $f',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.red)),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      setState(() => _entries.removeWhere(
          (e) => !failures.any((f) => f.startsWith('${e.particulars}:'))));
      if (_entries.isEmpty && mounted) Navigator.of(context).pop(true);
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import failed'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: failures
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $f',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.red)),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_step) {
          _Step.paste => 'Import Cashbook',
          _Step.review => 'Review Entries',
        }),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : switch (_step) {
              _Step.paste => _buildPasteBody(cs),
              _Step.review => _buildReviewBody(cs),
            },
      bottomNavigationBar: _step == _Step.review && _entries.isNotEmpty
          ? _buildImportBar(cs)
          : null,
    );
  }

  Widget _buildPasteBody(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cs.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: cs.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: TextStyle(color: cs.error, fontSize: 13)),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 48, color: cs.primary),
                const SizedBox(height: 12),
                const Text(
                  'Paste your income/expenditure table (from Excel, Sheets, or ChatGPT).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Columns: Date, Particulars, Income (₹), Expenditure (₹)\n'
                  'Dates like 21-Sep-2026 · — means blank',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pasteController,
          maxLines: 12,
          minLines: 8,
          decoration: const InputDecoration(
            hintText:
                'Paste here...\n\nDate\tParticulars\tIncome\tExpenditure\n'
                '21-Sep-2026\tFilling\t80\t—\n'
                '21-Sep-2026\tReddy wages\t—\t800',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _parse,
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Parse entries'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewBody(ColorScheme cs) {
    final invalid = _entries.where((e) => e.invalid).length;
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Income  ₹${_incomeTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700)),
                      Text('$_incomeCount entries',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expense  ₹${_expenseTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700)),
                      Text('$_expenseCount entries',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (invalid > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$invalid invalid',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.error)),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _entries.length,
            itemBuilder: (context, index) =>
                _buildEntryCard(_entries[index], index, cs),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(DaybookEntry e, int index, ColorScheme cs) {
    final ready = e.isValid;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editEntry(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (e.date != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yy').format(e.date!),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.particulars.isEmpty ? '(no particulars)' : e.particulars,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${e.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (e.isIncome ? Colors.green : Colors.orange)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      e.isIncome ? 'Income' : 'Expense',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: e.isIncome
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (e.invalid) ...[
                    Expanded(
                      child: Text(
                        e.error ?? 'Invalid',
                        style: TextStyle(fontSize: 11, color: cs.error),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else if (!e.isIncome) ...[
                    Expanded(
                      child: e.categoryName == null
                          ? Text('Select category',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.error,
                                  fontWeight: FontWeight.w600))
                          : Text('Category: ${e.categoryName}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade700)),
                    ),
                  ] else ...[
                    Expanded(
                      child: e.productName == null
                          ? Text('Select product',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.error,
                                  fontWeight: FontWeight.w600))
                          : Text('Product: ${e.productName}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade700)),
                    ),
                  ],
                  if (ready)
                    Icon(Icons.check_circle,
                        size: 16, color: Colors.green.shade600),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: Colors.grey.shade500),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => setState(() => _entries.removeAt(index)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportBar(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline.withOpacity(0.2))),
      ),
      child: _isImporting
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                    value: _importCurrent / _entries.length),
                const SizedBox(height: 8),
                Text('Importing $_importCurrent of ${_entries.length}...'),
              ],
            )
          : SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _allValid ? _import : null,
                icon: const Icon(Icons.download_done),
                label: Text(_allValid
                    ? 'Import ${_entries.length} entries'
                    : 'Complete all entries to import'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _editEntry(int index) async {
    final e = _entries[index];
    if (e.invalid) return;

    var date = e.date ?? DateTime.now();
    var particulars = e.particulars;
    var amountText = e.amount > 0 ? e.amount.toStringAsFixed(0) : '';
    var isIncome = e.isIncome;
    String? categoryId = e.categoryId;
    String categoryName = e.categoryName ?? '';
    String? productId = e.productId;
    String productName = e.productName ?? '';
    var categoryQuery = '';
    var productQuery = '';

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final cs = Theme.of(ctx).colorScheme;
            final cats = _filter(_categories, categoryQuery, 'name');
            final prods = _filter(_products, productQuery, 'name');

            return SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Edit Entry',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: particulars,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Particulars *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                      onChanged: (v) => particulars = v,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: amountText,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Amount *',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final d = double.tryParse(v ?? '');
                              if (d == null || d <= 0) return 'Invalid';
                              return null;
                            },
                            onChanged: (v) => amountText = v,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: date,
                                firstDate: DateTime(2020),
                                lastDate:
                                    DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setSheetState(() => date = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                suffixIcon:
                                    Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(DateFormat('dd/MM/yyyy')
                                  .format(date)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isIncome,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Income (cash sale)'),
                      subtitle: const Text(
                          'Off = Expense · Income imports as a Walk-in cash sale'),
                      onChanged: (v) => setSheetState(() => isIncome = v),
                    ),
                    if (!isIncome) ...[
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: categoryQuery,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'Type to filter…',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                          isDense: true,
                        ),
                        onChanged: (v) => setSheetState(() {
                          categoryQuery = v;
                          categoryId = null;
                          categoryName = '';
                        }),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                             final name = await showDialog<String>(
                               context: context,
                               builder: (dialogCtx) {
                                 final ctrl = TextEditingController(
                                   text: categoryQuery.isNotEmpty
                                     ? categoryQuery
                                     : '',
                                 );
                                 return AlertDialog(
                                   title: const Text('New category'),
                                   content: TextField(
                                     controller: ctrl,
                                     decoration: InputDecoration(
                                       labelText: 'Category name',
                                       border: OutlineInputBorder(),
                                     ),
                                   ),
                                   actions: [
                                     TextButton(
                                       onPressed: () => Navigator.pop(dialogCtx, null),
                                       child: const Text('Cancel'),
                                     ),
                                     TextButton(
                                       onPressed: () => Navigator.pop(dialogCtx, ctrl.text),
                                       child: const Text('Create'),
                                     ),
                                   ],
                                 );
                               },
                             );
                            if (name != null && name.trim().isNotEmpty) {
                              final id =
                                  await _ensureCategory(_businessId!,
                                  name.trim());
                              setSheetState(() {
                                categoryId = id;
                                categoryName = name.trim();
                                categoryQuery = categoryName;
                              });
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create new category'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Builder(
                          builder: (context) {
                            if (cats.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  'No categories — "Misc" will be created on import',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              );
                            }
                            return ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: cats.length,
                              itemBuilder: (context, i) {
                                final c = cats[i];
                                final selected = c['id'] == categoryId;
                                return ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.category_outlined,
                                      size: 18,
                                      color: selected
                                          ? Colors.green
                                          : Colors.grey.shade500),
                                  title: Text(c['name'] as String,
                                      style: const TextStyle(fontSize: 14)),
                                  onTap: () => setSheetState(() {
                                    categoryId = c['id'] as String;
                                    categoryName = c['name'] as String;
                                    categoryQuery = categoryName;
                                  }),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: productQuery,
                        decoration: const InputDecoration(
                          labelText: 'Product *',
                          hintText: 'Type to filter…',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                          isDense: true,
                        ),
                        onChanged: (v) => setSheetState(() {
                          productQuery = v;
                          productId = null;
                          productName = '';
                        }),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Builder(
                          builder: (context) {
                            if (prods.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  'No products match — add a product first',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              );
                            }
                            return ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: prods.length,
                              itemBuilder: (context, i) {
                                final p = prods[i];
                                final selected = p['id'] == productId;
                                return ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  leading: Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.inventory_2_outlined,
                                      size: 18,
                                      color: selected
                                          ? Colors.green
                                          : Colors.grey.shade500),
                                  title: Text(p['name'] as String,
                                      style: const TextStyle(fontSize: 14)),
                                  onTap: () => setSheetState(() {
                                    productId = p['id'] as String;
                                    productName = p['name'] as String;
                                    productQuery = productName;
                                  }),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          if (!isIncome &&
                              (categoryId == null || categoryId!.isEmpty)) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('Select a category')),
                            );
                            return;
                          }
                          if (isIncome &&
                              (productId == null || productId!.isEmpty)) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Select a product')),
                            );
                            return;
                          }
                          setState(() {
                            e.particulars = particulars.trim();
                            e.amount = double.tryParse(amountText) ?? e.amount;
                            e.date = date;
                            e.isIncome = isIncome;
                            if (isIncome) {
                              e.productId = productId;
                              e.productName = productName;
                              e.categoryId = null;
                              e.categoryName = null;
                            } else {
                              e.categoryId = categoryId;
                              e.categoryName = categoryName;
                              e.productId = null;
                              e.productName = null;
                            }
                            e.invalid = false;
                            e.error = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save Entry'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
