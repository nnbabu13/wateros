import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/supplier_model.dart';
import '../../data/repositories/supplier_repository.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SupplierRepository(supabaseService);
});

final suppliersProvider =
    StateNotifierProvider<SupplierNotifier, AsyncValue<List<SupplierModel>>>(
        (ref) {
  return SupplierNotifier(ref);
});

class SupplierNotifier extends StateNotifier<AsyncValue<List<SupplierModel>>> {
  final Ref _ref;

  SupplierNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadSuppliers() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final repository = _ref.read(supplierRepositoryProvider);
      final suppliers = await repository.getAllSuppliers(businessId);
      state = AsyncData(suppliers);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addSupplier(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(supplierRepositoryProvider);
      await repository.createSupplier(data);
      await loadSuppliers();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateSupplier(String id, Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(supplierRepositoryProvider);
      await repository.updateSupplier(id, data);
      await loadSuppliers();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteSupplier(String id) async {
    try {
      final repository = _ref.read(supplierRepositoryProvider);
      await repository.deleteSupplier(id);
      await loadSuppliers();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
