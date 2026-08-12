import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/cash_transaction_model.dart';

class CashbookRepository {
  final SupabaseService _supabaseService;

  CashbookRepository(this._supabaseService);

  Future<List<CashTransactionModel>> getCashTransactions(
    String businessId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final filters = <String, dynamic>{
        'business_id': businessId,
      };

      final data = await _supabaseService.fetchAll(
        table: 'cash_transactions',
        filters: filters,
        orderBy: 'transaction_date',
        ascending: false,
      );

      var results =
          data.map((json) => CashTransactionModel.fromJson(json)).toList();

      if (startDate != null) {
        results = results
            .where((t) => t.transactionDate.isAfter(startDate) ||
                t.transactionDate.isAtSameMomentAs(startDate))
            .toList();
      }
      if (endDate != null) {
        results = results
            .where((t) => t.transactionDate.isBefore(endDate) ||
                t.transactionDate.isAtSameMomentAs(endDate))
            .toList();
      }

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch cash transactions',
        originalError: e,
      );
    }
  }

  Future<CashTransactionModel> recordCashIn(Map<String, dynamic> data) async {
    try {
      data['transaction_type'] = 'in';
      final result = await _supabaseService.insert(
        table: 'cash_transactions',
        data: data,
      );
      return CashTransactionModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to record cash in',
        originalError: e,
      );
    }
  }

  Future<CashTransactionModel> recordCashOut(Map<String, dynamic> data) async {
    try {
      data['transaction_type'] = 'out';
      final result = await _supabaseService.insert(
        table: 'cash_transactions',
        data: data,
      );
      return CashTransactionModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to record cash out',
        originalError: e,
      );
    }
  }

  Future<double> getCashBalance(String businessId) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'cash_transactions',
        filters: {'business_id': businessId},
        select: 'transaction_type, amount',
      );

      double balance = 0.0;

      for (final transaction in data) {
        final type = transaction['transaction_type'] as String;
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;

        if (type == 'in') {
          balance += amount;
        } else if (type == 'out') {
          balance -= amount;
        }
      }

      return balance;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch cash balance',
        originalError: e,
      );
    }
  }
}
