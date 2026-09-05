import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>> getDashboardSummary(String businessId) async {
    final now = DateTime.now();
    final todayStr =
        DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10);
    final monthStartStr =
        DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);

    double todaySales = 0;
    double todayCollection = 0;
    double pendingPayments = 0;
    double todayExpenses = 0;
    double receivables = 0;
    double payables = 0;
    double cashBalance = 0;
    double bankBalance = 0;
    int lowStockCount = 0;
    List<Map<String, dynamic>> lowStockProducts = [];
    int presentToday = 0;
    int absentToday = 0;
    List<Map<String, dynamic>> recentActivity = [];

    final results = await Future.wait([
      // 0. Today's sales
      _safeQuery(() => _client
          .from('sales')
          .select('total_amount, id')
          .eq('business_id', businessId)
          .eq('invoice_date', todayStr)),
      // 1. Today's payments
      _safeQuery(() => _client
          .from('payments')
          .select('amount')
          .eq('business_id', businessId)
          .eq('payment_date', todayStr)),
      // 2. Pending payments
      _safeQuery(() => _client
          .from('sales')
          .select('balance_amount')
          .eq('business_id', businessId)
          .neq('status', 'paid')),
      // 3. Today's expenses
      _safeQuery(() => _client
          .from('expenses')
          .select('amount')
          .eq('business_id', businessId)
          .eq('expense_date', todayStr)),
      // 4. Customer receivables
      _safeQuery(() => _client
          .from('customers')
          .select('current_balance')
          .eq('business_id', businessId)
          .gt('current_balance', 0)),
      // 5. Supplier payables
      _safeQuery(() => _client
          .from('suppliers')
          .select('current_balance')
          .eq('business_id', businessId)
          .gt('current_balance', 0)),
      // 6. Cash transactions (current month)
      _safeQuery(() => _client
          .from('cash_transactions')
          .select('transaction_type, amount')
          .eq('business_id', businessId)
          .gte('transaction_date', monthStartStr)
          .lte('transaction_date', todayStr)),
      // 7. Bank transactions (current month)
      _safeQuery(() => _client
          .from('bank_transactions')
          .select('transaction_type, amount')
          .eq('business_id', businessId)
          .gte('transaction_date', monthStartStr)
          .lte('transaction_date', todayStr)),
      // 8. Products for low stock
      _safeQuery(() => _client
          .from('products')
          .select('id, name, current_stock, minimum_stock')
          .eq('business_id', businessId)
          .eq('is_active', true)),
      // 9. Attendance
      _safeQuery(() => _client
          .from('attendance')
          .select('status')
          .eq('business_id', businessId)
          .eq('attendance_date', todayStr)),
      // 10. Recent sales
      _safeQuery(() => _client
          .from('sales')
          .select('id, invoice_number, total_amount, invoice_date, status, customer_id')
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(5)),
      // 11. Recent payments
      _safeQuery(() => _client
          .from('payments')
          .select('id, amount, payment_date, payment_mode, customer_id')
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(5)),
      // 12. Recent expenses
      _safeQuery(() => _client
          .from('expenses')
          .select('id, amount, description, expense_date, payment_mode')
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(5)),
    ]);

    // 0. Today's sales
    final todaySalesList = results[0];
    for (final sale in todaySalesList) {
      todaySales += (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 1. Today's collection
    for (final p in results[1]) {
      todayCollection += (p['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Pending payments
    for (final sale in results[2]) {
      pendingPayments += (sale['balance_amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 3. Today's expenses
    for (final e in results[3]) {
      todayExpenses += (e['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 4. Receivables
    for (final c in results[4]) {
      receivables += (c['current_balance'] as num?)?.toDouble() ?? 0.0;
    }

    // 5. Payables
    for (final s in results[5]) {
      payables += (s['current_balance'] as num?)?.toDouble() ?? 0.0;
    }

    // 6. Cash balance (current month)
    for (final tx in results[6]) {
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final type = tx['transaction_type'] as String;
      if (type == 'in') {
        cashBalance += amount;
      } else {
        cashBalance -= amount;
      }
    }

    // 7. Bank balance (current month)
    for (final tx in results[7]) {
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final type = tx['transaction_type'] as String;
      if (type == 'in') {
        bankBalance += amount;
      } else if (type == 'out') {
        bankBalance -= amount;
      }
    }

    // 8. Low stock
    for (final p in results[8]) {
      final currentStock = (p['current_stock'] as num?)?.toDouble() ?? 0.0;
      final minimumStock = (p['minimum_stock'] as num?)?.toDouble() ?? 0.0;
      if (currentStock <= minimumStock && minimumStock > 0) {
        lowStockCount++;
        lowStockProducts.add({
          'id': p['id'],
          'name': p['name'],
          'current_stock': currentStock,
          'minimum_stock': minimumStock,
        });
      }
    }

    // 9. Attendance
    for (final a in results[9]) {
      final status = a['status'] as String;
      if (status == 'present') presentToday++;
      if (status == 'absent') absentToday++;
    }

    // COGS: calculate cost of goods sold for today's sales
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

    // 10. Build recent activity
    final recentSales = results[10];
    final recentPayments = results[11];
    final recentExpenses = results[12];

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

    for (final sale in recentSales) {
      final cid = sale['customer_id'] as String?;
      final custName = (cid != null) ? (customerNames[cid] ?? 'Customer') : 'Customer';
      recentActivity.add({
        'type': 'sale',
        'title': 'Sale - ${sale['invoice_number'] ?? ''}',
        'subtitle': '$custName - ₹${sale['total_amount'] ?? 0}',
        'date': sale['invoice_date'] ?? '',
        'status': sale['status'] ?? '',
      });
    }

    for (final p in recentPayments) {
      final cid = p['customer_id'] as String?;
      final custName = (cid != null) ? (customerNames[cid] ?? 'Customer') : 'Customer';
      recentActivity.add({
        'type': 'payment',
        'title': 'Payment Received',
        'subtitle': '$custName - ₹${p['amount'] ?? 0}',
        'date': p['payment_date'] ?? '',
        'status': p['payment_mode'] ?? '',
      });
    }

    for (final e in recentExpenses) {
      recentActivity.add({
        'type': 'expense',
        'title': 'Expense',
        'subtitle': '${e['description'] ?? ''} - ₹${e['amount'] ?? 0}',
        'date': e['expense_date'] ?? '',
        'status': e['payment_mode'] ?? '',
      });
    }

    recentActivity.sort((a, b) {
      final aDate = a['date'] as String? ?? '';
      final bDate = b['date'] as String? ?? '';
      return bDate.compareTo(aDate);
    });

    return {
      'today_sales': todaySales,
      'today_collection': todayCollection,
      'pending_payments': pendingPayments,
      'today_expenses': todayExpenses,
      'cash_balance': cashBalance,
      'bank_balance': bankBalance,
      'today_profit': todaySales - todayCogs - todayExpenses,
      'receivables': receivables,
      'payables': payables,
      'low_stock_count': lowStockCount,
      'low_stock_products': lowStockProducts,
      'employee_attendance': {
        'present': presentToday,
        'absent': absentToday,
      },
      'recent_activity': recentActivity,
    };
  }

  Future<List<Map<String, dynamic>>> _safeQuery(
      Future<List<Map<String, dynamic>>> Function() queryFn) async {
    try {
      return await queryFn();
    } catch (_) {
      return [];
    }
  }
}
