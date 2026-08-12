import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/salary_record_model.dart';

class SalaryRepository {
  final SupabaseService _supabaseService;

  SalaryRepository(this._supabaseService);

  Future<List<SalaryRecordModel>> getSalaryByMonth(
      String businessId, int month, int year) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'salary_records',
        filters: {
          'business_id': businessId,
          'month': month,
          'year': year,
        },
        orderBy: 'employee_name',
        ascending: true,
      );

      return data.map((json) => SalaryRecordModel.fromJson(json)).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch salary by month',
        originalError: e,
      );
    }
  }

  Future<SalaryRecordModel> calculateSalary(
    String employeeId,
    int month,
    int year,
  ) async {
    try {
      final employeeData = await _supabaseService.fetchById(
        table: 'employees',
        id: employeeId,
      );

      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      final attendanceData = await _supabaseService.fetchAll(
        table: 'attendance',
        filters: {'employee_id': employeeId},
        orderBy: 'attendance_date',
        ascending: true,
      );

      final attendance = attendanceData.where((a) {
        final date = DateTime.parse(a['attendance_date']);
        return date.isAfter(startDate) && date.isBefore(endDate);
      }).toList();

      int workingDays = 0;
      int presentDays = 0;
      int absentDays = 0;
      int halfDays = 0;
      int leaveDays = 0;

      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        if (date.weekday != DateTime.saturday &&
            date.weekday != DateTime.sunday) {
          workingDays++;
        }
      }

      for (final record in attendance) {
        final status = record['status'] as String;
        switch (status) {
          case 'present':
            presentDays++;
            break;
          case 'absent':
            absentDays++;
            break;
          case 'half_day':
            halfDays++;
            break;
          case 'leave':
            leaveDays++;
            break;
        }
      }

      final basicSalary = (employeeData['basic_salary'] as num?)?.toDouble() ?? 0.0;
      final perDaySalary = workingDays > 0 ? basicSalary / workingDays : 0.0;
      final netSalary = perDaySalary * presentDays + (perDaySalary * halfDays * 0.5);

      final existingData = await _supabaseService.fetchAll(
        table: 'salary_records',
        filters: {
          'employee_id': employeeId,
          'month': month,
          'year': year,
        },
      );

      final salaryData = {
        'business_id': employeeData['business_id'],
        'employee_id': employeeId,
        'employee_name': employeeData['name'],
        'month': month,
        'year': year,
        'working_days': workingDays,
        'present_days': presentDays,
        'absent_days': absentDays,
        'half_days': halfDays,
        'leave_days': leaveDays,
        'basic_salary': basicSalary,
        'net_salary': netSalary,
        'status': 'draft',
        'paid_amount': 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingData.isNotEmpty) {
        final result = await _supabaseService.update(
          table: 'salary_records',
          id: existingData.first['id'],
          data: salaryData,
        );
        return SalaryRecordModel.fromJson(result);
      } else {
        salaryData['created_at'] = DateTime.now().toIso8601String();
        final result = await _supabaseService.insert(
          table: 'salary_records',
          data: salaryData,
        );
        return SalaryRecordModel.fromJson(result);
      }
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to calculate salary',
        originalError: e,
      );
    }
  }

  Future<SalaryRecordModel> updateSalaryRecord(
      String id, Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.update(
        table: 'salary_records',
        id: id,
        data: data,
      );
      return SalaryRecordModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to update salary record',
        originalError: e,
      );
    }
  }

  Future<SalaryRecordModel> generatePayslip(String salaryId) async {
    try {
      final data = await _supabaseService.fetchById(
        table: 'salary_records',
        id: salaryId,
      );

      final salaryRecord = SalaryRecordModel.fromJson(data);

      if (salaryRecord.status == 'draft') {
        await _supabaseService.update(
          table: 'salary_records',
          id: salaryId,
          data: {
            'status': 'approved',
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

      return salaryRecord;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to generate payslip',
        originalError: e,
      );
    }
  }
}
