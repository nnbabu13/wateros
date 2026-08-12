import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/salary_record_model.dart';
import '../../data/repositories/salary_repository.dart';

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SalaryRepository(supabaseService);
});

final salaryRecordsProvider =
    StateNotifierProvider<SalaryNotifier, AsyncValue<List<SalaryRecordModel>>>(
        (ref) {
  return SalaryNotifier(ref);
});

final selectedMonthProvider = StateProvider<int>((ref) {
  return DateTime.now().month;
});

final selectedYearProvider = StateProvider<int>((ref) {
  return DateTime.now().year;
});

class SalaryNotifier
    extends StateNotifier<AsyncValue<List<SalaryRecordModel>>> {
  final Ref _ref;

  SalaryNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadSalaryRecords() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final month = _ref.read(selectedMonthProvider);
      final year = _ref.read(selectedYearProvider);
      final repository = _ref.read(salaryRepositoryProvider);
      final records = await repository.getSalaryByMonth(businessId, month, year);
      state = AsyncData(records);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> calculateSalary(
      String employeeId, int month, int year) async {
    try {
      final repository = _ref.read(salaryRepositoryProvider);
      await repository.calculateSalary(employeeId, month, year);
      await loadSalaryRecords();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateSalary(String id, Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(salaryRepositoryProvider);
      await repository.updateSalaryRecord(id, data);
      await loadSalaryRecords();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
