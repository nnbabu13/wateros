import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/purchase_model.dart';

class PurchaseRepository {
  final SupabaseService _supabaseService;

  PurchaseRepository(this._supabaseService);

  Future<List<PurchaseModel>> getAllPurchases(
    String businessId, {
    String? status,
    String? supplierId,
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
      if (supplierId != null) {
        filters['supplier_id'] = supplierId;
      }

      final data = await _supabaseService.fetchAll(
        table: 'purchases',
        filters: filters,
        orderBy: 'purchase_date',
        ascending: false,
        limit: limit,
        offset: offset,
      );

      var results = data.map((json) => PurchaseModel.fromJson(json)).toList();

      if (startDate != null) {
        results = results
            .where((p) => p.purchaseDate.isAfter(startDate) ||
                p.purchaseDate.isAtSameMomentAs(startDate))
            .toList();
      }
      if (endDate != null) {
        results = results
            .where((p) => p.purchaseDate.isBefore(endDate) ||
                p.purchaseDate.isAtSameMomentAs(endDate))
            .toList();
      }

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch purchases',
        originalError: e,
      );
    }
  }

  Future<PurchaseModel> getPurchaseById(String id) async {
    try {
      final data = await _supabaseService.fetchById(
        table: 'purchases',
        id: id,
        select: '*, items:purchase_items(*)',
      );
      return PurchaseModel.fromJson(data);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch purchase',
        originalError: e,
      );
    }
  }

  Future<PurchaseModel> createPurchase(Map<String, dynamic> data) async {
    try {
      final items = data['items'] as List<Map<String, dynamic>>?;
      final purchaseData = Map<String, dynamic>.from(data)..remove('items');

      final result = await _supabaseService.insert(
        table: 'purchases',
        data: purchaseData,
      );

      if (items != null && items.isNotEmpty) {
        for (final item in items) {
          item['purchase_id'] = result['id'];
          await _supabaseService.insert(
            table: 'purchase_items',
            data: item,
          );
        }
      }

      return getPurchaseById(result['id']);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create purchase',
        originalError: e,
      );
    }
  }

  Future<PurchaseModel> updatePurchase(
      String id, Map<String, dynamic> data) async {
    try {
      final items = data['items'] as List<Map<String, dynamic>>?;
      final purchaseData = Map<String, dynamic>.from(data)..remove('items');

      final result = await _supabaseService.update(
        table: 'purchases',
        id: id,
        data: purchaseData,
      );

      if (items != null) {
        for (final item in items) {
          if (item['id'] != null) {
            await _supabaseService.update(
              table: 'purchase_items',
              id: item['id'],
              data: item,
            );
          } else {
            item['purchase_id'] = id;
            await _supabaseService.insert(
              table: 'purchase_items',
              data: item,
            );
          }
        }
      }

      return getPurchaseById(result['id']);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update purchase',
        originalError: e,
      );
    }
  }

  Future<void> deletePurchase(String id) async {
    try {
      final items = await _supabaseService.fetchAll(
        table: 'purchase_items',
        filters: {'purchase_id': id},
      );

      for (final item in items) {
        await _supabaseService.delete(
          table: 'purchase_items',
          id: item['id'],
        );
      }

      await _supabaseService.delete(
        table: 'purchases',
        id: id,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to delete purchase',
        originalError: e,
      );
    }
  }
}
