import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/purchase_model.dart';
import '../../data/repositories/purchase_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return PurchaseRepository(supabaseService);
});

final purchasesProvider =
    StateNotifierProvider<PurchaseNotifier, AsyncValue<List<PurchaseModel>>>(
        (ref) {
  return PurchaseNotifier(ref);
});

class PurchaseNotifier
    extends StateNotifier<AsyncValue<List<PurchaseModel>>> {
  final Ref _ref;

  PurchaseNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadPurchases() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final repository = _ref.read(purchaseRepositoryProvider);
      final purchases = await repository.getAllPurchases(businessId);
      state = AsyncData(purchases);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addPurchase(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(purchaseRepositoryProvider);
      await repository.createPurchase(data);
      await loadPurchases();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updatePurchase(String id, Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(purchaseRepositoryProvider);
      await repository.updatePurchase(id, data);
      await loadPurchases();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deletePurchase(String id) async {
    try {
      final repository = _ref.read(purchaseRepositoryProvider);
      await repository.deletePurchase(id);
      await loadPurchases();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
