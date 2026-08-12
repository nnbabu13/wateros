import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ProductRepository(supabaseService);
});

final productsProvider =
    StateNotifierProvider<ProductNotifier, AsyncValue<List<ProductModel>>>(
        (ref) {
  return ProductNotifier(ref);
});

final lowStockProductsProvider = Provider<Future<List<ProductModel>>>(
  (ref) async {
    final businessId = ref.read(businessIdProvider);
    final repository = ref.read(productRepositoryProvider);
    return repository.getLowStockProducts(businessId);
  },
);

class ProductNotifier extends StateNotifier<AsyncValue<List<ProductModel>>> {
  final Ref _ref;

  ProductNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadProducts() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final repository = _ref.read(productRepositoryProvider);
      final products = await repository.getAllProducts(businessId);
      state = AsyncData(products);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(productRepositoryProvider);
      await repository.createProduct(data);
      await loadProducts();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(productRepositoryProvider);
      await repository.updateProduct(id, data);
      await loadProducts();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final repository = _ref.read(productRepositoryProvider);
      await repository.deleteProduct(id);
      await loadProducts();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
