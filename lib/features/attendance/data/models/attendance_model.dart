class AttendanceModel {
  final String id;
  final String businessId;
  final String employeeId;
  final String employeeName;
  final DateTime attendanceDate;
  final String status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double overtimeHours;
  final String? notes;
  final String? markedBy;
  final DateTime createdAt;

  const AttendanceModel({
    required this.id,
    required this.businessId,
    required this.employeeId,
    required this.employeeName,
    required this.attendanceDate,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.overtimeHours = 0.0,
    this.notes,
    this.markedBy,
    required this.createdAt,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      attendanceDate: DateTime.parse(json['attendance_date'] as String),
      status: json['status'] as String,
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'] as String)
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'] as String)
          : null,
      overtimeHours: (json['overtime_hours'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      markedBy: json['marked_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'attendance_date': attendanceDate.toIso8601String(),
      'status': status,
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'overtime_hours': overtimeHours,
      'notes': notes,
      'marked_by': markedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AttendanceModel copyWith({
    String? id,
    String? businessId,
    String? employeeId,
    String? employeeName,
    DateTime? attendanceDate,
    String? status,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    double? overtimeHours,
    String? notes,
    String? markedBy,
    DateTime? createdAt,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      notes: notes ?? this.notes,
      markedBy: markedBy ?? this.markedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.employeeId == employeeId &&
        other.employeeName == employeeName &&
        other.attendanceDate == attendanceDate &&
        other.status == status &&
        other.checkInTime == checkInTime &&
        other.checkOutTime == checkOutTime &&
        other.overtimeHours == overtimeHours &&
        other.notes == notes &&
        other.markedBy == markedBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      businessId,
      employeeId,
      employeeName,
      attendanceDate,
      status,
      checkInTime,
      checkOutTime,
      overtimeHours,
      notes,
      markedBy,
      createdAt,
    );
  }
}
