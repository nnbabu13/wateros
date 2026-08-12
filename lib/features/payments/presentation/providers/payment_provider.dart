import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return PaymentRepository(supabaseService);
});

final paymentsProvider =
    StateNotifierProvider<PaymentNotifier, AsyncValue<List<PaymentModel>>>(
        (ref) {
  return PaymentNotifier(ref);
});

class PaymentNotifier extends StateNotifier<AsyncValue<List<PaymentModel>>> {
  final Ref _ref;

  PaymentNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadPayments() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final repository = _ref.read(paymentRepositoryProvider);
      final payments = await repository.getAllPayments(businessId);
      state = AsyncData(payments);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> recordPayment(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(paymentRepositoryProvider);
      await repository.recordPayment(data);
      await loadPayments();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
