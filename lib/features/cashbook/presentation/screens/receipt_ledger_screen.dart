import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:wateros/core/widgets/app_card.dart';
import 'package:wateros/core/widgets/empty_state.dart';
import 'package:wateros/core/widgets/loading_widget.dart';
import 'package:wateros/features/payments/presentation/providers/payment_provider.dart';
import 'package:wateros/features/cashbook/presentation/providers/cashbook_provider.dart';

class ReceiptLedgerScreen extends ConsumerStatefulWidget {
  const ReceiptLedgerScreen({super.key});

  @override
  ConsumerState<ReceiptLedgerScreen> createState() => _ReceiptLedgerScreenState();
}

class _ReceiptLedgerScreenState extends ConsumerState<ReceiptLedgerScreen> {
  DateTime _selectedDate = DateTime.now();
  String _filterMode = 'all'; // all, cash, upi, bank

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    ref.read(paymentsProvider.notifier).loadPayments();
    ref.read(cashTransactionsProvider.notifier).loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentsProvider);
    final cashAsync = ref.watch(cashTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Ledger'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _filterMode = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Payments')),
              const PopupMenuItem(value: 'cash', child: Text('Cash Only')),
              const PopupMenuItem(value: 'upi', child: Text('UPI Only')),
              const PopupMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          _buildFilterChips(),
          Expanded(
            child: paymentsAsync.when(
              loading: () => const LoadingWidget(message: 'Loading receipts...'),
              error: (e, _) => _buildError(e.toString()),
              data: (payments) {
                final dayPayments = payments.where((p) {
                  final sameDay = p.paymentDate.year == _selectedDate.year &&
                      p.paymentDate.month == _selectedDate.month &&
                      p.paymentDate.day == _selectedDate.day;
                  if (_filterMode == 'all') return sameDay;
                  return sameDay && p.paymentMode == _filterMode;
                }).toList();

                final dayCashIn = cashAsync.valueOrNull?.where((t) =>
                    t.transactionType == 'in' &&
                    t.transactionDate.year == _selectedDate.year &&
                    t.transactionDate.month == _selectedDate.month &&
                    t.transactionDate.day == _selectedDate.day).toList() ?? [];

                final dayCashOut = cashAsync.valueOrNull?.where((t) =>
                    t.transactionType == 'out' &&
                    t.transactionDate.year == _selectedDate.year &&
                    t.transactionDate.month == _selectedDate.month &&
                    t.transactionDate.day == _selectedDate.day).toList() ?? [];

                if (dayPayments.isEmpty && dayCashIn.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No receipts today',
                    message: 'No receipts found for ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                    buttonText: 'Record Payment',
                    onButtonPressed: () => context.push('/payments/record'),
                  );
                }

                final totalReceipts = dayPayments.fold<double>(0, (sum, p) => sum + p.amount);
                final totalCashIn = dayCashIn.fold<double>(0, (sum, t) => sum + t.amount);

                return RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDaySummary(totalReceipts + totalCashIn, dayPayments.length + dayCashIn.length),
                      const SizedBox(height: 16),
                      if (dayPayments.isNotEmpty) ...[
                        _buildSectionHeader('Customer Payments (${dayPayments.length})'),
                        const SizedBox(height: 8),
                        ...dayPayments.map((payment) => _buildPaymentCard(payment)),
                      ],
                      if (dayCashIn.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSectionHeader('Cash In (${dayCashIn.length})'),
                        const SizedBox(height: 8),
                        ...dayCashIn.map((cash) => _buildCashCard(cash, 'in')),
                      ],
                      if (dayCashOut.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSectionHeader('Cash Out (${dayCashOut.length})'),
                        const SizedBox(height: 8),
                        ...dayCashOut.map((cash) => _buildCashCard(cash, 'out')),
                      ],
                      const SizedBox(height: 16),
                      _buildRunningBalance(dayPayments, dayCashIn, dayCashOut),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
            }),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(_selectedDate),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _isToday ? null : () => setState(() {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
            }),
            icon: Icon(
              Icons.chevron_right,
              color: _isToday ? Colors.grey : null,
            ),
          ),
        ],
      ),
    );
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today, ${DateFormat('dd MMM yyyy').format(date)}';
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday, ${DateFormat('dd MMM yyyy').format(date)}';
    }
    return DateFormat('EEEE, dd MMM yyyy').format(date);
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
    }
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip('All', 'all'),
          const SizedBox(width: 8),
          _buildChip('Cash', 'cash'),
          const SizedBox(width: 8),
          _buildChip('UPI', 'upi'),
          const SizedBox(width: 8),
          _buildChip('Bank', 'bank_transfer'),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = _filterMode == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterMode = value),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildDaySummary(double totalAmount, int count) {
    return AppCard(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '₹${totalAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                'Total Received',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.2),
          ),
          Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                'Transactions',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPaymentCard(payment) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getPaymentIcon(payment.paymentMode),
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      payment.customerName ?? 'Customer',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPaymentModeColor(payment.paymentMode).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        payment.paymentMode.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _getPaymentModeColor(payment.paymentMode),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (payment.invoiceNumber != null)
                  Text(
                    'Invoice: ${payment.invoiceNumber}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (payment.notes != null && payment.notes!.isNotEmpty)
                  Text(
                    payment.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '+ ₹${payment.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(payment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashCard(cash, String type) {
    final isIn = type == 'in';
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isIn ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIn ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIn ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cash.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  cash.referenceType ?? 'Cash ${isIn ? 'In' : 'Out'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${isIn ? '+' : '-'} ₹${cash.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isIn ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(cash.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningBalance(List payments, List cashIn, List cashOut) {
    final totalIn = payments.fold<double>(0, (sum, p) => sum + p.amount) +
        cashIn.fold<double>(0, (sum, t) => sum + t.amount);
    final totalOut = cashOut.fold<double>(0, (sum, t) => sum + t.amount);
    final netBalance = totalIn - totalOut;

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Text(
            'Day Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildBalanceRow('Total In', totalIn, Colors.green, Icons.arrow_downward),
          const Divider(),
          _buildBalanceRow('Total Out', totalOut, Colors.red, Icons.arrow_upward),
          const Divider(),
          _buildBalanceRow(
            'Net Balance',
            netBalance,
            netBalance >= 0 ? Colors.green : Colors.red,
            netBalance >= 0 ? Icons.trending_up : Icons.trending_down,
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String label, double amount, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  IconData _getPaymentIcon(String mode) {
    switch (mode) {
      case 'cash': return Icons.money;
      case 'upi': return Icons.phone_android;
      case 'bank_transfer': return Icons.account_balance;
      default: return Icons.payment;
    }
  }

  Color _getPaymentModeColor(String mode) {
    switch (mode) {
      case 'cash': return Colors.green;
      case 'upi': return Colors.blue;
      case 'bank_transfer': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $message'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
