import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/business_helper.dart';

class _TxnItem {
  final String id;
  final String type; // 'sale', 'payment_in', 'expense', 'cash_in', 'cash_out'
  final String description;
  final String? subtitle;
  final double amount;
  final DateTime date;
  final String? mode;
  final bool isIncoming;

  _TxnItem({
    required this.id,
    required this.type,
    required this.description,
    this.subtitle,
    required this.amount,
    required this.date,
    this.mode,
    required this.isIncoming,
  });
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<_TxnItem> _allTxns = [];
  bool _isLoading = true;
  String _filterType = 'all';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final businessId = await BusinessHelper.getOrCreateBusinessId();
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final salesFuture = Supabase.instance.client
          .from('sales')
          .select('id, invoice_number, total_amount, paid_amount, balance_amount, status, payment_mode, invoice_date, created_at, customer:customers(name)')
          .eq('business_id', businessId)
          .gte('invoice_date', DateFormat('yyyy-MM-dd').format(startOfDay))
          .lt('invoice_date', DateFormat('yyyy-MM-dd').format(endOfDay))
          .order('created_at', ascending: false);

      final paymentsFuture = Supabase.instance.client
          .from('payments')
          .select('id, amount, payment_mode, payment_date, notes, created_at, customer:customers(name), sale:sales(invoice_number)')
          .eq('business_id', businessId)
          .gte('payment_date', DateFormat('yyyy-MM-dd').format(startOfDay))
          .lt('payment_date', DateFormat('yyyy-MM-dd').format(endOfDay))
          .order('created_at', ascending: false);

      final expensesFuture = Supabase.instance.client
          .from('expenses')
          .select('id, amount, description, expense_date, payment_mode, created_at, category:expense_categories(name)')
          .eq('business_id', businessId)
          .gte('expense_date', DateFormat('yyyy-MM-dd').format(startOfDay))
          .lt('expense_date', DateFormat('yyyy-MM-dd').format(endOfDay))
          .order('created_at', ascending: false);

      final cashFuture = Supabase.instance.client
          .from('cash_transactions')
          .select('id, transaction_type, amount, description, transaction_date, created_at')
          .eq('business_id', businessId)
          .gte('transaction_date', DateFormat('yyyy-MM-dd').format(startOfDay))
          .lt('transaction_date', DateFormat('yyyy-MM-dd').format(endOfDay))
          .order('created_at', ascending: false);

      final results = await Future.wait([salesFuture, paymentsFuture, expensesFuture, cashFuture]);

      final txns = <_TxnItem>[];

      for (final s in results[0]) {
        final customer = s['customer'] as Map<String, dynamic>?;
        final total = (s['total_amount'] as num?)?.toDouble() ?? 0;
        final paid = (s['paid_amount'] as num?)?.toDouble() ?? 0;
        final status = s['status'] as String? ?? 'pending';
        final createdAt = s['created_at'] as String? ?? '';

        txns.add(_TxnItem(
          id: s['id'] as String,
          type: 'sale',
          description: 'Sale - ${customer?['name'] ?? 'Customer'}',
          subtitle: '${s['invoice_number'] ?? ''} | ${status.toUpperCase()}',
          amount: total,
          date: createdAt.isNotEmpty ? DateTime.parse(createdAt) : DateTime.now(),
          mode: s['payment_mode'] as String?,
          isIncoming: true,
        ));
      }

      for (final p in results[1]) {
        final customer = p['customer'] as Map<String, dynamic>?;
        final sale = p['sale'] as Map<String, dynamic>?;
        final createdAt = p['created_at'] as String? ?? '';

        txns.add(_TxnItem(
          id: p['id'] as String,
          type: 'payment_in',
          description: 'Payment from ${customer?['name'] ?? 'Customer'}',
          subtitle: sale != null ? 'Invoice: ${sale['invoice_number'] ?? ''}' : null,
          amount: (p['amount'] as num?)?.toDouble() ?? 0,
          date: createdAt.isNotEmpty ? DateTime.parse(createdAt) : DateTime.now(),
          mode: p['payment_mode'] as String?,
          isIncoming: true,
        ));
      }

      for (final e in results[2]) {
        final category = e['category'] as Map<String, dynamic>?;
        final createdAt = e['created_at'] as String? ?? '';

        txns.add(_TxnItem(
          id: e['id'] as String,
          type: 'expense',
          description: e['description'] as String? ?? 'Expense',
          subtitle: category?['name'] as String?,
          amount: (e['amount'] as num?)?.toDouble() ?? 0,
          date: createdAt.isNotEmpty ? DateTime.parse(createdAt) : DateTime.now(),
          mode: e['payment_mode'] as String?,
          isIncoming: false,
        ));
      }

      for (final c in results[3]) {
        final isIn = c['transaction_type'] == 'in';
        final createdAt = c['created_at'] as String? ?? '';

        txns.add(_TxnItem(
          id: c['id'] as String,
          type: isIn ? 'cash_in' : 'cash_out',
          description: c['description'] as String? ?? (isIn ? 'Cash In' : 'Cash Out'),
          amount: (c['amount'] as num?)?.toDouble() ?? 0,
          date: createdAt.isNotEmpty ? DateTime.parse(createdAt) : DateTime.now(),
          isIncoming: isIn,
        ));
      }

      txns.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _allTxns = txns;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_TxnItem> get _filteredTxns {
    if (_filterType == 'all') return _allTxns;
    if (_filterType == 'income') return _allTxns.where((t) => t.isIncoming).toList();
    if (_filterType == 'expense') return _allTxns.where((t) => !t.isIncoming).toList();
    return _allTxns.where((t) => t.type == _filterType).toList();
  }

  double get _totalIn => _allTxns.where((t) => t.isIncoming).fold(0, (s, t) => s + t.amount);
  double get _totalOut => _allTxns.where((t) => !t.isIncoming).fold(0, (s, t) => s + t.amount);
  double get _netBalance => _totalIn - _totalOut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(cs),
          _buildSummaryBar(cs),
          _buildFilterChips(cs),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTxns.isEmpty
                    ? _buildEmptyState(cs)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredTxns.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) => _buildTxnCard(_filteredTxns[index], cs),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
              _isLoading = true;
              _loadData();
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: cs.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(_selectedDate),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _isToday
                ? null
                : () {
                    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                    _isLoading = true;
                    _loadData();
                  },
            icon: Icon(Icons.chevron_right, color: _isToday ? Colors.grey : null),
          ),
        ],
      ),
    );
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today, ${DateFormat('dd MMM').format(date)}';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday, ${DateFormat('dd MMM').format(date)}';
    }
    return DateFormat('EEE, dd MMM').format(date);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _isLoading = true;
      _loadData();
    }
  }

  Widget _buildSummaryBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: cs.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Expanded(child: _summaryItem('In', _totalIn, Colors.green)),
          Container(width: 1, height: 32, color: cs.outline.withOpacity(0.3)),
          Expanded(child: _summaryItem('Out', _totalOut, Colors.red)),
          Container(width: 1, height: 32, color: cs.outline.withOpacity(0.3)),
          Expanded(child: _summaryItem('Net', _netBalance, _netBalance >= 0 ? Colors.green : Colors.red)),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          '₹ ${amount.toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 16),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildFilterChips(ColorScheme cs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _chip('All', 'all'),
          const SizedBox(width: 6),
          _chip('Income', 'income'),
          const SizedBox(width: 6),
          _chip('Expenses', 'expense'),
          const SizedBox(width: 6),
          _chip('Sales', 'sale'),
          const SizedBox(width: 6),
          _chip('Payments', 'payment_in'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filterType == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
      selected: selected,
      onSelected: (_) => setState(() => _filterType = value),
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No transactions', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd MMM yyyy').format(_selectedDate),
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildTxnCard(_TxnItem txn, ColorScheme cs) {
    IconData icon;
    Color color;

    switch (txn.type) {
      case 'sale':
        icon = Icons.receipt_long;
        color = Colors.blue;
        break;
      case 'payment_in':
        icon = Icons.payments;
        color = Colors.green;
        break;
      case 'expense':
        icon = Icons.money_off;
        color = Colors.red;
        break;
      case 'cash_in':
        icon = Icons.arrow_downward;
        color = Colors.green;
        break;
      case 'cash_out':
        icon = Icons.arrow_upward;
        color = Colors.red;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: txn.type == 'sale' ? () => context.push('/sales/${txn.id}') : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.description,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (txn.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        txn.subtitle!,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${txn.isIncoming ? '+' : '-'} ₹${txn.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: txn.isIncoming ? Colors.green : Colors.red,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (txn.mode != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            txn.mode!.toUpperCase().replaceAll('_', ' '),
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        DateFormat('hh:mm a').format(txn.date),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
