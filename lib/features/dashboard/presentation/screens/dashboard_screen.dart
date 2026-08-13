import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/business_helper.dart';
import '../../../../core/widgets/app_card.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _loading = true;
  String? _error;

  double _todaySales = 0;
  double _todayCollection = 0;
  double _pendingPayments = 0;
  double _todayExpenses = 0;
  double _cashBalance = 0;
  double _bankBalance = 0;
  double _todayProfit = 0;
  double _receivables = 0;
  double _payables = 0;
  List<Map<String, dynamic>> _lowStockProducts = [];
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final businessId = await BusinessHelper.getOrCreateBusinessId();
      if (businessId.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No business found.';
        });
        return;
      }

      final now = DateTime.now();
      final todayStr = DateTime(now.year, now.month, now.day)
          .toIso8601String()
          .substring(0, 10);

      final results = await Future.wait([
        _safeQuery(() => _client
            .from('sales')
            .select('total_amount, id')
            .eq('business_id', businessId)
            .eq('invoice_date', todayStr)),
        _safeQuery(() => _client
            .from('payments')
            .select('amount')
            .eq('business_id', businessId)
            .eq('payment_date', todayStr)),
        _safeQuery(() => _client
            .from('sales')
            .select('balance_amount')
            .eq('business_id', businessId)
            .neq('status', 'paid')
            .neq('status', 'cancelled')),
        _safeQuery(() => _client
            .from('expenses')
            .select('amount')
            .eq('business_id', businessId)
            .eq('expense_date', todayStr)),
        _safeQuery(() => _client
            .from('customers')
            .select('current_balance')
            .eq('business_id', businessId)
            .gt('current_balance', 0)),
        _safeQuery(() => _client
            .from('suppliers')
            .select('current_balance')
            .eq('business_id', businessId)
            .gt('current_balance', 0)),
        _safeQuery(() => _client
            .from('cash_transactions')
            .select('transaction_type, amount')
            .eq('business_id', businessId)),
        _safeQuery(() => _client
            .from('bank_accounts')
            .select('id, balance')
            .eq('business_id', businessId)
            .eq('is_active', true)),
        _safeQuery(() => _client
            .from('products')
            .select('id, name, current_stock, minimum_stock')
            .eq('business_id', businessId)
            .eq('is_active', true)),
        _safeQuery(() => _client
            .from('sales')
            .select('id, invoice_number, total_amount, invoice_date, status, customer_id')
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(5)),
        _safeQuery(() => _client
            .from('payments')
            .select('id, amount, payment_date, payment_mode, customer_id')
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(5)),
        _safeQuery(() => _client
            .from('expenses')
            .select('id, amount, description, expense_date, payment_mode')
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(5)),
      ]);

      double todaySales = 0;
      double todayCollection = 0;
      double pendingPayments = 0;
      double todayExpenses = 0;
      double receivables = 0;
      double payables = 0;
      double cashBalance = 0;
      double bankBalance = 0;

      final todaySalesList = results[0];
      for (final sale in todaySalesList) {
        todaySales += (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
      }
      for (final p in results[1]) {
        todayCollection += (p['amount'] as num?)?.toDouble() ?? 0.0;
      }
      for (final sale in results[2]) {
        pendingPayments += (sale['balance_amount'] as num?)?.toDouble() ?? 0.0;
      }
      for (final e in results[3]) {
        todayExpenses += (e['amount'] as num?)?.toDouble() ?? 0.0;
      }
      for (final c in results[4]) {
        receivables += (c['current_balance'] as num?)?.toDouble() ?? 0.0;
      }
      for (final s in results[5]) {
        payables += (s['current_balance'] as num?)?.toDouble() ?? 0.0;
      }
      for (final tx in results[6]) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final type = tx['transaction_type'] as String;
        if (type == 'in') {
          cashBalance += amount;
        } else {
          cashBalance -= amount;
        }
      }
      for (final acc in results[7]) {
        bankBalance += (acc['balance'] as num?)?.toDouble() ?? 0.0;
      }

      final lowStockProducts = <Map<String, dynamic>>[];
      for (final p in results[8]) {
        final currentStock = (p['current_stock'] as num?)?.toDouble() ?? 0.0;
        final minimumStock = (p['minimum_stock'] as num?)?.toDouble() ?? 0.0;
        if (currentStock <= minimumStock && minimumStock > 0) {
          lowStockProducts.add({
            'id': p['id'],
            'name': p['name'],
            'current_stock': currentStock,
            'minimum_stock': minimumStock,
          });
        }
      }

      double todayCogs = 0;
      final todaySaleIds = todaySalesList.map((s) => s['id'] as String).toList();
      if (todaySaleIds.isNotEmpty) {
        try {
          final saleItems = await _client
              .from('sale_items')
              .select('quantity, product_id')
              .inFilter('sale_id', todaySaleIds);
          final productIds = saleItems
              .map((item) => item['product_id'] as String)
              .toSet()
              .toList();
          if (productIds.isNotEmpty) {
            final products = await _client
                .from('products')
                .select('id, purchase_price, average_cost')
                .inFilter('id', productIds);
            final costMap = <String, double>{};
            for (final p in products) {
              final avgCost = (p['average_cost'] as num?)?.toDouble() ?? 0;
              final purchasePrice =
                  (p['purchase_price'] as num?)?.toDouble() ?? 0;
              costMap[p['id'] as String] = avgCost > 0 ? avgCost : purchasePrice;
            }
            for (final item in saleItems) {
              final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
              final cost = costMap[item['product_id'] as String] ?? 0;
              todayCogs += qty * cost;
            }
          }
        } catch (_) {}
      }

      final recentSales = results[9];
      final recentPayments = results[10];
      final recentExpenses = results[11];

      final customerIds = <String>{};
      for (final s in recentSales) {
        final cid = s['customer_id'] as String?;
        if (cid != null) customerIds.add(cid);
      }
      for (final p in recentPayments) {
        final cid = p['customer_id'] as String?;
        if (cid != null) customerIds.add(cid);
      }

      Map<String, String> customerNames = {};
      if (customerIds.isNotEmpty) {
        try {
          final custResult = await _client
              .from('customers')
              .select('id, name')
              .inFilter('id', customerIds.toList());
          for (final c in custResult) {
            customerNames[c['id'] as String] = c['name'] as String;
          }
        } catch (_) {}
      }

      final recentActivity = <Map<String, dynamic>>[];
      for (final sale in recentSales) {
        final cid = sale['customer_id'] as String?;
        final custName =
            (cid != null) ? (customerNames[cid] ?? 'Customer') : 'Customer';
        recentActivity.add({
          'type': 'sale',
          'id': sale['id'] as String,
          'title': 'Sale - ${sale['invoice_number'] ?? ''}',
          'subtitle': '$custName - ${String.fromCharCode(8377)}${sale['total_amount'] ?? 0}',
          'date': sale['invoice_date'] ?? '',
          'status': sale['status'] ?? '',
        });
      }
      for (final p in recentPayments) {
        final cid = p['customer_id'] as String?;
        final custName =
            (cid != null) ? (customerNames[cid] ?? 'Customer') : 'Customer';
        recentActivity.add({
          'type': 'payment',
          'id': p['id'] as String,
          'title': 'Payment Received',
          'subtitle': '$custName - ${String.fromCharCode(8377)}${p['amount'] ?? 0}',
          'date': p['payment_date'] ?? '',
          'status': p['payment_mode'] ?? '',
        });
      }
      for (final e in recentExpenses) {
        recentActivity.add({
          'type': 'expense',
          'id': e['id'] as String,
          'title': 'Expense',
          'subtitle': '${e['description'] ?? ''} - ${String.fromCharCode(8377)}${e['amount'] ?? 0}',
          'date': e['expense_date'] ?? '',
          'status': e['payment_mode'] ?? '',
        });
      }
      recentActivity.sort((a, b) {
        final aDate = a['date'] as String? ?? '';
        final bDate = b['date'] as String? ?? '';
        return bDate.compareTo(aDate);
      });

      setState(() {
        _todaySales = todaySales;
        _todayCollection = todayCollection;
        _pendingPayments = pendingPayments;
        _todayExpenses = todayExpenses;
        _cashBalance = cashBalance;
        _bankBalance = bankBalance;
        _todayProfit = todaySales - todayCogs - todayExpenses;
        _receivables = receivables;
        _payables = payables;
        _lowStockProducts = lowStockProducts;
        _recentActivity = recentActivity;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _safeQuery(
      Future<List<Map<String, dynamic>>> Function() queryFn) async {
    try {
      return await queryFn();
    } catch (_) {
      return [];
    }
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return '${String.fromCharCode(8377)}0';
    if (amount < 0) return '-${String.fromCharCode(8377)}${amount.abs().toStringAsFixed(0)}';
    return '${String.fromCharCode(8377)}${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dashboardRefreshProvider, (previous, next) {
      _loadData();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text('Failed to load dashboard',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildWelcomeHeader(context),
                      const SizedBox(height: 20),
                      _buildMetricsGrid(context),
                      const SizedBox(height: 20),
                      _buildFinancialOverview(context),
                      const SizedBox(height: 20),
                      _buildQuickActions(context),
                      const SizedBox(height: 20),
                      _buildLowStockAlerts(context),
                      const SizedBox(height: 20),
                      _buildRecentActivity(context),
                      const SizedBox(height: 20),
                    ],
                  ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning!';
    } else if (hour < 17) {
      greeting = 'Good Afternoon!';
    } else {
      greeting = 'Good Evening!';
    }

    final today = DateFormat('EEEE, d MMMM y').format(DateTime.now());

    return AppCard(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            today,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer
                      .withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          title: 'Today\'s Sales',
          value: _formatCurrency(_todaySales),
          icon: Icons.trending_up,
          color: Colors.blue,
          onTap: () => context.push('/daily-sales'),
        ),
        StatCard(
          title: 'Today\'s Collection',
          value: _formatCurrency(_todayCollection),
          icon: Icons.payments,
          color: Colors.green,
          onTap: () => context.push('/payments'),
        ),
        StatCard(
          title: 'Pending Payments',
          value: _formatCurrency(_pendingPayments),
          icon: Icons.pending_actions,
          color: Colors.orange,
          onTap: () => context.push('/payments'),
        ),
        StatCard(
          title: 'Today\'s Expenses',
          value: _formatCurrency(_todayExpenses),
          icon: Icons.receipt_long,
          color: Colors.red,
          onTap: () => context.push('/expenses'),
        ),
        StatCard(
          title: 'Cash Balance',
          value: _formatCurrency(_cashBalance),
          icon: Icons.account_balance_wallet,
          color: Colors.teal,
          onTap: () => context.push('/cashbook'),
        ),
        StatCard(
          title: 'Bank Balance',
          value: _formatCurrency(_bankBalance),
          icon: Icons.account_balance,
          color: Colors.indigo,
          onTap: () => context.push('/bankbook'),
        ),
      ],
    );
  }

  Widget _buildFinancialOverview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Overview',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppCard(
                margin: EdgeInsets.zero,
                onTap: () => context.push('/reports'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: _todayProfit >= 0 ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(_todayProfit),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _todayProfit >= 0 ? Colors.green : Colors.red,
                          ),
                    ),
                    Text(
                      'Today\'s Profit',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppCard(
                margin: EdgeInsets.zero,
                onTap: () => context.push('/customers'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.people, color: Colors.blue, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(_receivables),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.blue,
                          ),
                    ),
                    Text(
                      'Receivables',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          margin: EdgeInsets.zero,
          onTap: () => context.push('/suppliers'),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCurrency(_payables),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                    ),
                    Text(
                      'Outstanding Payables',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction('Create Sale', Icons.add_shopping_cart, Colors.blue, '/sales/create'),
      _QuickAction('Add Expense', Icons.receipt, Colors.red, '/expenses/add'),
      _QuickAction('Record Payment', Icons.payments, Colors.green, '/payments/record'),
      _QuickAction('Inventory', Icons.inventory_2, Colors.teal, '/inventory'),
      _QuickAction('Employees', Icons.people, Colors.purple, '/employees'),
    ];

    final reportActions = [
      _QuickAction('Daily Sales', Icons.receipt_long, Colors.teal, '/daily-sales'),
      _QuickAction('Cash Book', Icons.account_balance_wallet, Colors.indigo, '/cashbook'),
      _QuickAction('Reports', Icons.analytics, Colors.orange, '/reports'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        AppCard(
          margin: EdgeInsets.zero,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return GestureDetector(
                onTap: () => context.push(action.route),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: action.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(action.icon, color: action.color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action.label,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Book Keeping',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        AppCard(
          margin: EdgeInsets.zero,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: reportActions.length,
            itemBuilder: (context, index) {
              final action = reportActions[index];
              return GestureDetector(
                onTap: () => context.push(action.route),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: action.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(action.icon, color: action.color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action.label,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockAlerts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Low Stock Alerts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextButton(
              onPressed: () => context.push('/inventory'),
              child: const Text('View All'),
            ),
          ],
        ),
        if (_lowStockProducts.isEmpty)
          AppCard(
            margin: EdgeInsets.zero,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Text(
                  'All stock levels healthy',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                      ),
                ),
              ],
            ),
          )
        else
          AppCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < _lowStockProducts.length; i++) ...[
                  if (i > 0) const Divider(),
                  _buildStockAlertItem(
                    context,
                    _lowStockProducts[i]['id'] as String,
                    _lowStockProducts[i]['name'] as String,
                    (_lowStockProducts[i]['current_stock'] as num).toDouble(),
                    (_lowStockProducts[i]['minimum_stock'] as num).toDouble(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStockAlertItem(
      BuildContext context, String productId, String name, double current, double minimum) {
    final needed = minimum - current;
    return GestureDetector(
      onTap: () => context.push('/inventory/$productId'),
      child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                'Stock: ${current.toStringAsFixed(0)} (Min: ${minimum.toStringAsFixed(0)})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text(
          '${needed.toStringAsFixed(0)} needed',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        if (_recentActivity.isEmpty)
          AppCard(
            margin: EdgeInsets.zero,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                Text(
                  'No recent activity',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          )
        else
          AppCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < _recentActivity.length; i++) ...[
                  if (i > 0) const Divider(),
                  _buildActivityItem(context, _recentActivity[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActivityItem(BuildContext context, Map<String, dynamic> activity) {
    final type = activity['type'] as String;
    final id = activity['id'] as String? ?? '';
    final title = activity['title'] as String;
    final subtitle = activity['subtitle'] as String;
    final date = activity['date'] as String;

    IconData icon;
    Color color;
    switch (type) {
      case 'sale':
        icon = Icons.receipt;
        color = Colors.blue;
        break;
      case 'payment':
        icon = Icons.payments;
        color = Colors.green;
        break;
      case 'expense':
        icon = Icons.receipt_long;
        color = Colors.red;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    String displayDate = date;
    try {
      final parsed = DateTime.parse(date);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final itemDate = DateTime(parsed.year, parsed.month, parsed.day);
      final diff = today.difference(itemDate).inDays;
      if (diff == 0) {
        displayDate = 'Today';
      } else if (diff == 1) {
        displayDate = 'Yesterday';
      } else {
        displayDate = DateFormat('d MMM').format(parsed);
      }
    } catch (_) {}

    VoidCallback? onTap;
    if (type == 'sale' && id.isNotEmpty) {
      onTap = () => context.push('/sales/$id');
    } else if (type == 'payment') {
      onTap = () => context.push('/payments');
    } else if (type == 'expense') {
      onTap = () => context.push('/expenses');
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text(
          displayDate,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withOpacity(0.5),
              ),
        ),
      ],
    ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  _QuickAction(this.label, this.icon, this.color, this.route);
}
