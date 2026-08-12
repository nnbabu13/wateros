import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AttendanceRepository(supabaseService);
});

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AsyncValue<List<AttendanceModel>>>(
        (ref) {
  return AttendanceNotifier(ref);
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

class AttendanceNotifier
    extends StateNotifier<AsyncValue<List<AttendanceModel>>> {
  final Ref _ref;

  AttendanceNotifier(this._ref) : super(const AsyncLoading());

  Future<void> loadAttendance() async {
    state = const AsyncLoading();
    try {
      final businessId = _ref.read(businessIdProvider);
      final date = _ref.read(selectedDateProvider);
      final repository = _ref.read(attendanceRepositoryProvider);
      final attendance = await repository.getAttendanceByDate(businessId, date);
      state = AsyncData(attendance);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> markAttendance(Map<String, dynamic> data) async {
    try {
      final repository = _ref.read(attendanceRepositoryProvider);
      await repository.markAttendance(data);
      await loadAttendance();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> markBulkAttendance(
      List<Map<String, dynamic>> attendanceData) async {
    try {
      final repository = _ref.read(attendanceRepositoryProvider);
      await repository.markBulkAttendance(attendanceData);
      await loadAttendance();
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
