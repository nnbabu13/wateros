import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/business_helper.dart';
import '../../data/repositories/dashboard_repository.dart';

/// Increment this to force dashboard reload from anywhere
final dashboardRefreshProvider = StateProvider<int>((ref) => 0);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

final dashboardSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final businessId = await BusinessHelper.getOrCreateBusinessId();
  if (businessId.isEmpty) {
    return _emptySummary();
  }
  final repository = ref.read(dashboardRepositoryProvider);
  return repository.getDashboardSummary(businessId);
});

Map<String, dynamic> _emptySummary() => {
      'today_sales': 0.0,
      'today_collection': 0.0,
      'pending_payments': 0.0,
      'today_expenses': 0.0,
      'cash_balance': 0.0,
      'bank_balance': 0.0,
      'today_profit': 0.0,
      'receivables': 0.0,
      'payables': 0.0,
      'low_stock_count': 0,
      'low_stock_products': <Map<String, dynamic>>[],
      'employee_attendance': {'present': 0, 'absent': 0},
      'recent_activity': <Map<String, dynamic>>[],
    };

final todaySalesProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['today_sales'] as num?)?.toDouble() ?? 0.0;
});

final todayCollectionProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['today_collection'] as num?)?.toDouble() ?? 0.0;
});

final pendingPaymentsProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['pending_payments'] as num?)?.toDouble() ?? 0.0;
});

final todayExpensesProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['today_expenses'] as num?)?.toDouble() ?? 0.0;
});

final dashboardCashBalanceProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['cash_balance'] as num?)?.toDouble() ?? 0.0;
});

final bankBalanceProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['bank_balance'] as num?)?.toDouble() ?? 0.0;
});

final todayProfitProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['today_profit'] as num?)?.toDouble() ?? 0.0;
});

final receivablesProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['receivables'] as num?)?.toDouble() ?? 0.0;
});

final payablesProvider = FutureProvider<double>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['payables'] as num?)?.toDouble() ?? 0.0;
});

final lowStockCountProvider = FutureProvider<int>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['low_stock_count'] as int?) ?? 0;
});

final lowStockProductsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['low_stock_products'] as List<Map<String, dynamic>>?) ?? [];
});

final employeeAttendanceProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['employee_attendance'] as Map<String, dynamic>?) ?? {};
});

final recentActivityProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  return (summary['recent_activity'] as List<Map<String, dynamic>>?) ?? [];
});
