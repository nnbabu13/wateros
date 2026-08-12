import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/sale_model.dart';
import '../../data/repositories/sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SalesRepository(supabaseService);
});

final salesProvider =
    StateNotifierProvider<SalesNotifier, AsyncValue<List<SaleModel>>>((ref) {
  return SalesNotifier(ref);
});

final saleStatusFilterProvider = StateProvider<String?>((ref) => null);

final salesSummaryProvider = Provider<Future<SalesSummary>>((ref) async {
  final businessId = ref.read(businessIdProvider);
  final repository = ref.read(salesRepositoryProvider);
  final sales = await repository.getAllSales(businessId);

  double totalSales = 0;
  double totalPaid = 0;
  double totalPending = 0;

  for (final sale in sales) {
    totalSales += sale.totalAmount;
    totalPaid += sale.paidAmount;
    totalPending += sale.balanceAmount;
  }

  return SalesSummary(
    totalSales: totalSales,
    totalPaid: totalPaid,
    totalPending: totalPending,
    totalInvoices: sales.length,
  );
});

class SalesSummary {
  final double totalSales;
  final double totalPaid;
  final double totalPending;
  final int totalInvoices;

  const SalesSummary({
    required this.totalSales,
    required this.totalPaid,
    required this.totalPending,
    required this.totalInvoices,
  });
}

class SalesNotifier extends StateNotifier<AsyncValue<List<SaleModel>>> {
  final Ref _ref;

  SalesNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadSales() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final status = _ref.read(saleStatusFilterProvider);
      final repository = _ref.read(salesRepositoryProvider);
      final sales = await repository.getAllSales(
        businessId,
        status: status,
      );
      state = AsyncData(sales);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addSale(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(salesRepositoryProvider);
      await repository.createSale(data);
      await loadSales();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateSale(String id, Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(salesRepositoryProvider);
      await repository.updateSale(id, data);
      await loadSales();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteSale(String id) async {
    try {
      final repository = _ref.read(salesRepositoryProvider);
      await repository.deleteSale(id);
      await loadSales();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
