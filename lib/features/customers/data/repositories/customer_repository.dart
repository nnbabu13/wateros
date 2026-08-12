import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final SupabaseService _supabaseService;

  CustomerRepository(this._supabaseService);

  Future<List<CustomerModel>> getAllCustomers(
    String businessId, {
    String? search,
    int? limit,
    int? offset,
  }) async {
    try {
      final filters = <String, dynamic>{
        'business_id': businessId,
      };

      final data = await _supabaseService.fetchAll(
        table: 'customers',
        filters: filters,
        orderBy: 'name',
        ascending: true,
        limit: limit,
        offset: offset,
      );

      var results = data.map((json) => CustomerModel.fromJson(json)).toList();

      if (search != null && search.isNotEmpty) {
        final query = search.toLowerCase();
        results = results
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                c.phone.contains(query))
            .toList();
      }

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch customers',
        originalError: e,
      );
    }
  }

  Future<CustomerModel> getCustomerById(String id) async {
    try {
      final data = await _supabaseService.fetchById(
        table: 'customers',
        id: id,
      );
      return CustomerModel.fromJson(data);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch customer',
        originalError: e,
      );
    }
  }

  Future<CustomerModel> createCustomer(Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.insert(
        table: 'customers',
        data: data,
      );
      return CustomerModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create customer',
        originalError: e,
      );
    }
  }

  Future<CustomerModel> updateCustomer(
      String id, Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.update(
        table: 'customers',
        id: id,
        data: data,
      );
      return CustomerModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update customer',
        originalError: e,
      );
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _supabaseService.delete(
        table: 'customers',
        id: id,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to delete customer',
        originalError: e,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerLedger(String customerId) async {
    try {
      final sales = await _supabaseService.fetchAll(
        table: 'sales',
        filters: {'customer_id': customerId},
        orderBy: 'invoice_date',
        ascending: false,
      );

      final payments = await _supabaseService.fetchAll(
        table: 'payments',
        filters: {'customer_id': customerId},
        orderBy: 'payment_date',
        ascending: false,
      );

      final ledger = <Map<String, dynamic>>[];

      for (final sale in sales) {
        ledger.add({
          'date': sale['invoice_date'],
          'type': 'sale',
          'reference': sale['invoice_number'],
          'debit': sale['total_amount'],
          'credit': 0.0,
          'balance': sale['balance_amount'],
        });
      }

      for (final payment in payments) {
        ledger.add({
          'date': payment['payment_date'],
          'type': 'payment',
          'reference': payment['reference_number'],
          'debit': 0.0,
          'credit': payment['amount'],
          'balance': 0.0,
        });
      }

      ledger.sort((a, b) =>
          DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

      return ledger;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch customer ledger',
        originalError: e,
      );
    }
  }

  Future<double> getCustomerOutstanding(String businessId) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'customers',
        filters: {'business_id': businessId},
        select: 'current_balance',
      );

      double total = 0.0;
      for (final row in data) {
        total += (row['current_balance'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch customer outstanding',
        originalError: e,
      );
    }
  }
}
