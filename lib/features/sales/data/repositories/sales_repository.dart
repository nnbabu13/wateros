import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/sale_model.dart';

class SalesRepository {
  final SupabaseService _supabaseService;

  SalesRepository(this._supabaseService);

  Future<List<SaleModel>> getAllSales(
    String businessId, {
    String? status,
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

      if (status != null) {
        filters['status'] = status;
      }
      if (customerId != null) {
        filters['customer_id'] = customerId;
      }

      final data = await _supabaseService.fetchAll(
        table: 'sales',
        filters: filters,
        orderBy: 'invoice_date',
        ascending: false,
        limit: limit,
        offset: offset,
      );

      var results = data.map((json) => SaleModel.fromJson(json)).toList();

      if (startDate != null) {
        results = results
            .where((s) => s.invoiceDate.isAfter(startDate) ||
                s.invoiceDate.isAtSameMomentAs(startDate))
            .toList();
      }
      if (endDate != null) {
        results = results
            .where((s) => s.invoiceDate.isBefore(endDate) ||
                s.invoiceDate.isAtSameMomentAs(endDate))
            .toList();
      }

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch sales',
        originalError: e,
      );
    }
  }

  Future<SaleModel> getSaleById(String id) async {
    try {
      final data = await _supabaseService.fetchById(
        table: 'sales',
        id: id,
        select: '*, items:sale_items(*)',
      );
      return SaleModel.fromJson(data);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch sale',
        originalError: e,
      );
    }
  }

  Future<SaleModel> createSale(Map<String, dynamic> data) async {
    try {
      final items = data['items'] as List<Map<String, dynamic>>?;
      final saleData = Map<String, dynamic>.from(data)..remove('items');

      final result = await _supabaseService.insert(
        table: 'sales',
        data: saleData,
      );

      if (items != null && items.isNotEmpty) {
        for (final item in items) {
          item['sale_id'] = result['id'];
          await _supabaseService.insert(
            table: 'sale_items',
            data: item,
          );
        }
      }

      return getSaleById(result['id']);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create sale',
        originalError: e,
      );
    }
  }

  Future<SaleModel> updateSale(String id, Map<String, dynamic> data) async {
    try {
      final items = data['items'] as List<Map<String, dynamic>>?;
      final saleData = Map<String, dynamic>.from(data)..remove('items');

      final result = await _supabaseService.update(
        table: 'sales',
        id: id,
        data: saleData,
      );

      if (items != null) {
        for (final item in items) {
          if (item['id'] != null) {
            await _supabaseService.update(
              table: 'sale_items',
              id: item['id'],
              data: item,
            );
          } else {
            item['sale_id'] = id;
            await _supabaseService.insert(
              table: 'sale_items',
              data: item,
            );
          }
        }
      }

      return getSaleById(result['id']);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update sale',
        originalError: e,
      );
    }
  }

  Future<void> deleteSale(String id) async {
    try {
      final items = await _supabaseService.fetchAll(
        table: 'sale_items',
        filters: {'sale_id': id},
      );

      for (final item in items) {
        await _supabaseService.delete(
          table: 'sale_items',
          id: item['id'],
        );
      }

      await _supabaseService.delete(
        table: 'sales',
        id: id,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to delete sale',
        originalError: e,
      );
    }
  }

  Future<List<SaleModel>> getSalesByCustomer(String customerId) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'sales',
        filters: {'customer_id': customerId},
        orderBy: 'invoice_date',
        ascending: false,
      );

      return data.map((json) => SaleModel.fromJson(json)).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch sales by customer',
        originalError: e,
      );
    }
  }

  Future<List<SaleModel>> getDailySales(
      String businessId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final data = await _supabaseService.fetchAll(
        table: 'sales',
        filters: {'business_id': businessId},
        orderBy: 'invoice_date',
        ascending: false,
      );

      final results = data
          .map((json) => SaleModel.fromJson(json))
          .where((s) =>
              s.invoiceDate.isAfter(startOfDay) &&
              s.invoiceDate.isBefore(endOfDay))
          .toList();

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch daily sales',
        originalError: e,
      );
    }
  }

  Future<List<SaleModel>> getMonthlySales(
      String businessId, int month, int year) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final data = await _supabaseService.fetchAll(
        table: 'sales',
        filters: {'business_id': businessId},
        orderBy: 'invoice_date',
        ascending: false,
      );

      final results = data
          .map((json) => SaleModel.fromJson(json))
          .where((s) =>
              s.invoiceDate.isAfter(startOfMonth) &&
              s.invoiceDate.isBefore(endOfMonth))
          .toList();

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch monthly sales',
        originalError: e,
      );
    }
  }
}
