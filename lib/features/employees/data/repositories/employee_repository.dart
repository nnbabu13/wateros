import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/employee_model.dart';

class EmployeeRepository {
  final SupabaseService _supabaseService;

  EmployeeRepository(this._supabaseService);

  Future<List<EmployeeModel>> getAllEmployees(
    String businessId, {
    String? search,
    bool? activeOnly,
    int? limit,
    int? offset,
  }) async {
    try {
      final filters = <String, dynamic>{
        'business_id': businessId,
      };

      if (activeOnly == true) {
        filters['is_active'] = true;
      }

      final data = await _supabaseService.fetchAll(
        table: 'employees',
        filters: filters,
        orderBy: 'name',
        ascending: true,
        limit: limit,
        offset: offset,
      );

      var results = data.map((json) => EmployeeModel.fromJson(json)).toList();

      if (search != null && search.isNotEmpty) {
        final query = search.toLowerCase();
        results = results
            .where((e) =>
                e.name.toLowerCase().contains(query) ||
                e.employeeCode.toLowerCase().contains(query) ||
                e.phone.contains(query))
            .toList();
      }

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch employees',
        originalError: e,
      );
    }
  }

  Future<EmployeeModel> getEmployeeById(String id) async {
    try {
      final data = await _supabaseService.fetchById(
        table: 'employees',
        id: id,
      );
      return EmployeeModel.fromJson(data);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch employee',
        originalError: e,
      );
    }
  }

  Future<EmployeeModel> createEmployee(Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.insert(
        table: 'employees',
        data: data,
      );
      return EmployeeModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create employee',
        originalError: e,
      );
    }
  }

  Future<EmployeeModel> updateEmployee(
      String id, Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.update(
        table: 'employees',
        id: id,
        data: data,
      );
      return EmployeeModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update employee',
        originalError: e,
      );
    }
  }

  Future<void> deleteEmployee(String id) async {
    try {
      await _supabaseService.delete(
        table: 'employees',
        id: id,
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to delete employee',
        originalError: e,
      );
    }
  }
}
