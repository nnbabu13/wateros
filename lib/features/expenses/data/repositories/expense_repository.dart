import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final SupabaseService _supabaseService;

  ExpenseRepository(this._supabaseService);

  Future<List<ExpenseModel>> getAllExpenses(
    String businessId, {
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    try {
      final filters = <String, dynamic>{
        'business_id': businessId,
      };

      if (categoryId != null) {
        filters['category_id'] = categoryId;
      }

      final data = await _supabaseService.fetchAll(
        table: 'expenses',
        filters: filters,
        orderBy: 'expense_date',
        ascending: false,
        limit: limit,
        offset: offset,
      );

      var results = data.map((json) => ExpenseModel.fromJson(json)).toList();

      if (startDate != null) {
        results = results
            .where((e) => e.expenseDate.isAfter(startDate) ||
                e.expenseDate.isAtSameMomentAs(startDate))
            .toList();
      }
      if (endDate != null) {
        results = results
            .where((e) => e.expenseDate.isBefore(endDate) ||
                e.expenseDate.isAtSameMomentAs(endDate))
            .toList();
      }

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch expenses',
        originalError: e,
      );
    }
  }

  Future<ExpenseModel> getExpenseById(String id) async {
    try {
      final data = await _supabaseService.fetchById(
        table: 'expenses',
        id: id,
      );
      return ExpenseModel.fromJson(data);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch expense',
        originalError: e,
      );
    }
  }

  Future<ExpenseModel> createExpense(Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.insert(
        table: 'expenses',
        data: data,
      );
      return ExpenseModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create expense',
        originalError: e,
      );
    }
  }

  Future<ExpenseModel> updateExpense(
      String id, Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.update(
        table: 'expenses',
        id: id,
        data: data,
      );
      return ExpenseModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update expense',
        originalError: e,
      );
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _supabaseService.delete(
        table: 'expenses',
        id: id,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to delete expense',
        originalError: e,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getExpensesByCategory(
      String businessId) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'expenses',
        filters: {'business_id': businessId},
        select: 'category_id, category_name, amount',
      );

      final categoryMap = <String, Map<String, dynamic>>{};

      for (final row in data) {
        final categoryId = row['category_id'] as String? ?? 'uncategorized';
        final categoryName = row['category_name'] as String? ?? 'Uncategorized';
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;

        if (categoryMap.containsKey(categoryId)) {
          categoryMap[categoryId]!['total'] += amount;
          categoryMap[categoryId]!['count'] += 1;
        } else {
          categoryMap[categoryId] = {
            'category_id': categoryId,
            'category_name': categoryName,
            'total': amount,
            'count': 1,
          };
        }
      }

      return categoryMap.values.toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch expenses by category',
        originalError: e,
      );
    }
  }

  Future<List<ExpenseModel>> getMonthlyExpenses(
      String businessId, int month, int year) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final data = await _supabaseService.fetchAll(
        table: 'expenses',
        filters: {'business_id': businessId},
        orderBy: 'expense_date',
        ascending: false,
      );

      final results = data
          .map((json) => ExpenseModel.fromJson(json))
          .where((e) =>
              e.expenseDate.isAfter(startOfMonth) &&
              e.expenseDate.isBefore(endOfMonth))
          .toList();

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch monthly expenses',
        originalError: e,
      );
    }
  }
}
