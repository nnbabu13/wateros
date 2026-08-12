import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employee_repository.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return EmployeeRepository(supabaseService);
});

final employeesProvider =
    StateNotifierProvider<EmployeeNotifier, AsyncValue<List<EmployeeModel>>>(
        (ref) {
  return EmployeeNotifier(ref);
});

class EmployeeNotifier extends StateNotifier<AsyncValue<List<EmployeeModel>>> {
  final Ref _ref;

  EmployeeNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadEmployees() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final repository = _ref.read(employeeRepositoryProvider);
      final employees = await repository.getAllEmployees(businessId);
      state = AsyncData(employees);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addEmployee(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(employeeRepositoryProvider);
      await repository.createEmployee(data);
      await loadEmployees();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(employeeRepositoryProvider);
      await repository.updateEmployee(id, data);
      await loadEmployees();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deleteEmployee(String id) async {
    try {
      final repository = _ref.read(employeeRepositoryProvider);
      await repository.deleteEmployee(id);
      await loadEmployees();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
