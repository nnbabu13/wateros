import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/product_model.dart';

class ProductRepository {
  final SupabaseService _supabaseService;

  ProductRepository(this._supabaseService);

  Future<List<ProductModel>> getAllProducts(
    String businessId, {
    String? search,
    String? categoryId,
    bool? lowStockOnly,
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
        table: 'products',
        filters: filters,
        orderBy: 'name',
        ascending: true,
        limit: limit,
        offset: offset,
      );

      var results = data.map((json) => ProductModel.fromJson(json)).toList();

      if (search != null && search.isNotEmpty) {
        final query = search.toLowerCase();
        results = results
            .where((p) =>
                p.name.toLowerCase().contains(query) ||
                (p.sku?.toLowerCase().contains(query) ?? false))
            .toList();
      }

      if (lowStockOnly == true) {
        results = results
            .where((p) => p.currentStock <= p.minimumStock)
            .toList();
      }

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch products',
        originalError: e,
      );
    }
  }

  Future<ProductModel> getProductById(String id) async {
    try {
      final data = await _supabaseService.fetchById(
        table: 'products',
        id: id,
      );
      return ProductModel.fromJson(data);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch product',
        originalError: e,
      );
    }
  }

  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.insert(
        table: 'products',
        data: data,
      );
      return ProductModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create product',
        originalError: e,
      );
    }
  }

  Future<ProductModel> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.update(
        table: 'products',
        id: id,
        data: data,
      );
      return ProductModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update product',
        originalError: e,
      );
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _supabaseService.delete(
        table: 'products',
        id: id,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to delete product',
        originalError: e,
      );
    }
  }

  Future<List<ProductModel>> getLowStockProducts(String businessId) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'products',
        filters: {'business_id': businessId},
        orderBy: 'name',
        ascending: true,
      );

      final results = data
          .map((json) => ProductModel.fromJson(json))
          .where((p) => p.currentStock <= p.minimumStock)
          .toList();

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch low stock products',
        originalError: e,
      );
    }
  }

  Future<ProductModel> updateStock(
    String productId,
    double quantity,
    String movementType,
  ) async {
    try {
      final product = await getProductById(productId);

      double newStock;
      if (movementType == 'in') {
        newStock = product.currentStock + quantity;
      } else if (movementType == 'out') {
        newStock = product.currentStock - quantity;
      } else {
        newStock = quantity;
      }

      final result = await _supabaseService.update(
        table: 'products',
        id: productId,
        data: {
          'current_stock': newStock,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      return ProductModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update stock',
        originalError: e,
      );
    }
  }
}
