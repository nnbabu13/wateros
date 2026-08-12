import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  final SupabaseService _supabaseService;

  PaymentRepository(this._supabaseService);

  Future<List<PaymentModel>> getAllPayments(
    String businessId, {
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    try {
      final filters = <String, dynamic>{
        'business_id': businessId,
      };

      if (customerId != null) {
        filters['customer_id'] = customerId;
      }

      final data = await _supabaseService.fetchAll(
        table: 'payments',
        filters: filters,
        orderBy: 'payment_date',
        ascending: false,
        limit: limit,
        offset: offset,
      );

      var results = data.map((json) => PaymentModel.fromJson(json)).toList();

      if (startDate != null) {
        results = results
            .where((p) => p.paymentDate.isAfter(startDate) ||
                p.paymentDate.isAtSameMomentAs(startDate))
            .toList();
      }
      if (endDate != null) {
        results = results
            .where((p) => p.paymentDate.isBefore(endDate) ||
                p.paymentDate.isAtSameMomentAs(endDate))
            .toList();
      }

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch payments',
        originalError: e,
      );
    }
  }

  Future<PaymentModel> recordPayment(Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.insert(
        table: 'payments',
        data: data,
      );

      if (data['sale_id'] != null) {
        final saleData = await _supabaseService.fetchById(
          table: 'sales',
          id: data['sale_id'],
        );

        final currentPaid =
            (saleData['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final newPaid = currentPaid + (data['amount'] as num).toDouble();
        final totalAmount =
            (saleData['total_amount'] as num?)?.toDouble() ?? 0.0;

        await _supabaseService.update(
          table: 'sales',
          id: data['sale_id'],
          data: {
            'paid_amount': newPaid,
            'balance_amount': totalAmount - newPaid,
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

      if (data['customer_id'] != null) {
        final customerData = await _supabaseService.fetchById(
          table: 'customers',
          id: data['customer_id'],
        );

        final currentBalance =
            (customerData['current_balance'] as num?)?.toDouble() ?? 0.0;
        final newBalance =
            currentBalance - (data['amount'] as num).toDouble();

        await _supabaseService.update(
          table: 'customers',
          id: data['customer_id'],
          data: {
            'current_balance': newBalance,
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

      return PaymentModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to record payment',
        originalError: e,
      );
    }
  }

  Future<List<PaymentModel>> getPaymentsBySale(String saleId) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'payments',
        filters: {'sale_id': saleId},
        orderBy: 'payment_date',
        ascending: false,
      );

      return data.map((json) => PaymentModel.fromJson(json)).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch payments by sale',
        originalError: e,
      );
    }
  }

  Future<List<PaymentModel>> getPaymentsByCustomer(String customerId) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'payments',
        filters: {'customer_id': customerId},
        orderBy: 'payment_date',
        ascending: false,
      );

      return data.map((json) => PaymentModel.fromJson(json)).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch payments by customer',
        originalError: e,
      );
    }
  }
}
