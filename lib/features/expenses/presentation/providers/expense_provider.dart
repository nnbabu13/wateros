import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ExpenseRepository(supabaseService);
});

final expensesProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<List<ExpenseModel>>>(
        (ref) {
  return ExpenseNotifier(ref);
});

final expenseCategoryFilterProvider = StateProvider<String?>((ref) => null);

class ExpenseNotifier extends StateNotifier<AsyncValue<List<ExpenseModel>>> {
  final Ref _ref;

  ExpenseNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadExpenses() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final categoryId = _ref.read(expenseCategoryFilterProvider);
      final repository = _ref.read(expenseRepositoryProvider);
      final expenses = await repository.getAllExpenses(
        businessId,
        categoryId: categoryId,
      );
      state = AsyncData(expenses);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addExpense(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(expenseRepositoryProvider);
      await repository.createExpense(data);
      await loadExpenses();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateExpense(String id, Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(expenseRepositoryProvider);
      await repository.updateExpense(id, data);
      await loadExpenses();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      final repository = _ref.read(expenseRepositoryProvider);
      await repository.deleteExpense(id);
      await loadExpenses();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
