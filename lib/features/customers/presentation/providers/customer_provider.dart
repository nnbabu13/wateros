import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/customer_model.dart';
import '../../data/repositories/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return CustomerRepository(supabaseService);
});

final customersProvider =
    StateNotifierProvider<CustomerNotifier, AsyncValue<List<CustomerModel>>>(
        (ref) {
  return CustomerNotifier(ref);
});

final customerSearchProvider = StateProvider<String>((ref) => '');

final selectedCustomerProvider = StateProvider<String?>((ref) => null);

class CustomerNotifier extends StateNotifier<AsyncValue<List<CustomerModel>>> {
  final Ref _ref;

  CustomerNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadCustomers() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final search = _ref.read(customerSearchProvider);
      final repository = _ref.read(customerRepositoryProvider);
      final customers = await repository.getAllCustomers(
        businessId,
        search: search.isNotEmpty ? search : null,
      );
      state = AsyncData(customers);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addCustomer(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(customerRepositoryProvider);
      await repository.createCustomer(data);
      await loadCustomers();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(customerRepositoryProvider);
      await repository.updateCustomer(id, data);
      await loadCustomers();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      final repository = _ref.read(customerRepositoryProvider);
      await repository.deleteCustomer(id);
      await loadCustomers();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
