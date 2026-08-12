import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final SupabaseService _supabaseService;

  AttendanceRepository(this._supabaseService);

  Future<List<AttendanceModel>> getAttendanceByDate(
      String businessId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final data = await _supabaseService.fetchAll(
        table: 'attendance',
        filters: {'business_id': businessId},
        orderBy: 'attendance_date',
        ascending: false,
      );

      final results = data
          .map((json) => AttendanceModel.fromJson(json))
          .where((a) =>
              a.attendanceDate.isAfter(startOfDay) &&
              a.attendanceDate.isBefore(endOfDay))
          .toList();

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch attendance by date',
        originalError: e,
      );
    }
  }

  Future<AttendanceModel> markAttendance(Map<String, dynamic> data) async {
    try {
      final existing = await _supabaseService.fetchAll(
        table: 'attendance',
        filters: {
          'employee_id': data['employee_id'],
          'business_id': data['business_id'],
        },
      );

      final attendanceDate = data['attendance_date'] as String;
      final matching = existing.where((a) =>
          a['attendance_date'].toString().split('T').first ==
          attendanceDate.split('T').first);

      if (matching.isNotEmpty) {
        final result = await _supabaseService.update(
          table: 'attendance',
          id: matching.first['id'],
          data: data,
        );
        return AttendanceModel.fromJson(result);
      } else {
        final result = await _supabaseService.insert(
          table: 'attendance',
          data: data,
        );
        return AttendanceModel.fromJson(result);
      }
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to mark attendance',
        originalError: e,
      );
    }
  }

  Future<List<AttendanceModel>> markBulkAttendance(
      List<Map<String, dynamic>> attendanceData) async {
    try {
      final results = <AttendanceModel>[];

      for (final data in attendanceData) {
        final result = await markAttendance(data);
        results.add(result);
      }

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to mark bulk attendance',
        originalError: e,
      );
    }
  }

  Future<List<AttendanceModel>> getAttendanceByEmployee(
    String employeeId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'attendance',
        filters: {'employee_id': employeeId},
        orderBy: 'attendance_date',
        ascending: false,
      );

      final results = data
          .map((json) => AttendanceModel.fromJson(json))
          .where((a) =>
              a.attendanceDate.isAfter(startDate) &&
              a.attendanceDate.isBefore(endDate))
          .toList();

      return results;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch attendance by employee',
        originalError: e,
      );
    }
  }
}
