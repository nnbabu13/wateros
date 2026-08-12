import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final SupabaseService _supabaseService;

  SupplierRepository(this._supabaseService);

  Future<List<SupplierModel>> getAllSuppliers(
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
        table: 'suppliers',
        filters: filters,
        orderBy: 'name',
        ascending: true,
        limit: limit,
        offset: offset,
      );

      var results = data.map((json) => SupplierModel.fromJson(json)).toList();

      if (search != null && search.isNotEmpty) {
        final query = search.toLowerCase();
        results = results
            .where((s) =>
                s.name.toLowerCase().contains(query) ||
                s.phone.contains(query))
            .toList();
      }

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch suppliers',
        originalError: e,
      );
    }
  }

  Future<SupplierModel> getSupplierById(String id) async {
    try {
      final data = await _supabaseService.fetchById(
        table: 'suppliers',
        id: id,
      );
      return SupplierModel.fromJson(data);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch supplier',
        originalError: e,
      );
    }
  }

  Future<SupplierModel> createSupplier(Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.insert(
        table: 'suppliers',
        data: data,
      );
      return SupplierModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create supplier',
        originalError: e,
      );
    }
  }

  Future<SupplierModel> updateSupplier(
      String id, Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.update(
        table: 'suppliers',
        id: id,
        data: data,
      );
      return SupplierModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update supplier',
        originalError: e,
      );
    }
  }

  Future<void> deleteSupplier(String id) async {
    try {
      await _supabaseService.delete(
        table: 'suppliers',
        id: id,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to delete supplier',
        originalError: e,
      );
    }
  }

  Future<double> getSupplierOutstanding(String businessId) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'suppliers',
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
        message: 'Failed to fetch supplier outstanding',
        originalError: e,
      );
    }
  }
}
