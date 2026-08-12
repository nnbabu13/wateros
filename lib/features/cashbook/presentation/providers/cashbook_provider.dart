import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/cash_transaction_model.dart';
import '../../data/repositories/cashbook_repository.dart';

final cashbookRepositoryProvider = Provider<CashbookRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return CashbookRepository(supabaseService);
});

final cashTransactionsProvider =
    StateNotifierProvider<CashbookNotifier, AsyncValue<List<CashTransactionModel>>>(
        (ref) {
  return CashbookNotifier(ref);
});

final cashBalanceProvider = Provider<Future<double>>((ref) async {
  final businessId = ref.read(businessIdProvider);
  final repository = ref.read(cashbookRepositoryProvider);
  return repository.getCashBalance(businessId);
});

class CashbookNotifier
    extends StateNotifier<AsyncValue<List<CashTransactionModel>>> {
  final Ref _ref;

  CashbookNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadTransactions() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final repository = _ref.read(cashbookRepositoryProvider);
      final transactions = await repository.getCashTransactions(businessId);
      state = AsyncData(transactions);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> recordCashIn(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(cashbookRepositoryProvider);
      await repository.recordCashIn(data);
      await loadTransactions();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> recordCashOut(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(cashbookRepositoryProvider);
      await repository.recordCashOut(data);
      await loadTransactions();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
