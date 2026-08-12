class SalaryRecordModel {
  final String id;
  final String businessId;
  final String employeeId;
  final String employeeName;
  final int month;
  final int year;
  final int workingDays;
  final int presentDays;
  final int absentDays;
  final int halfDays;
  final int leaveDays;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final double advanceDeduction;
  final double netSalary;
  final String status;
  final double paidAmount;
  final DateTime? paymentDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalaryRecordModel({
    required this.id,
    required this.businessId,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.year,
    required this.workingDays,
    required this.presentDays,
    this.absentDays = 0,
    this.halfDays = 0,
    this.leaveDays = 0,
    required this.basicSalary,
    this.allowances = 0.0,
    this.deductions = 0.0,
    this.advanceDeduction = 0.0,
    required this.netSalary,
    required this.status,
    this.paidAmount = 0.0,
    this.paymentDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalaryRecordModel.fromJson(Map<String, dynamic> json) {
    return SalaryRecordModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      month: json['month'] as int,
      year: json['year'] as int,
      workingDays: json['working_days'] as int,
      presentDays: json['present_days'] as int,
      absentDays: json['absent_days'] as int? ?? 0,
      halfDays: json['half_days'] as int? ?? 0,
      leaveDays: json['leave_days'] as int? ?? 0,
      basicSalary: (json['basic_salary'] as num).toDouble(),
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0.0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0.0,
      advanceDeduction:
          (json['advance_deduction'] as num?)?.toDouble() ?? 0.0,
      netSalary: (json['net_salary'] as num).toDouble(),
      status: json['status'] as String,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'month': month,
      'year': year,
      'working_days': workingDays,
      'present_days': presentDays,
      'absent_days': absentDays,
      'half_days': halfDays,
      'leave_days': leaveDays,
      'basic_salary': basicSalary,
      'allowances': allowances,
      'deductions': deductions,
      'advance_deduction': advanceDeduction,
      'net_salary': netSalary,
      'status': status,
      'paid_amount': paidAmount,
      'payment_date': paymentDate?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SalaryRecordModel copyWith({
    String? id,
    String? businessId,
    String? employeeId,
    String? employeeName,
    int? month,
    int? year,
    int? workingDays,
    int? presentDays,
    int? absentDays,
    int? halfDays,
    int? leaveDays,
    double? basicSalary,
    double? allowances,
    double? deductions,
    double? advanceDeduction,
    double? netSalary,
    String? status,
    double? paidAmount,
    DateTime? paymentDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SalaryRecordModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      month: month ?? this.month,
      year: year ?? this.year,
      workingDays: workingDays ?? this.workingDays,
      presentDays: presentDays ?? this.presentDays,
      absentDays: absentDays ?? this.absentDays,
      halfDays: halfDays ?? this.halfDays,
      leaveDays: leaveDays ?? this.leaveDays,
      basicSalary: basicSalary ?? this.basicSalary,
      allowances: allowances ?? this.allowances,
      deductions: deductions ?? this.deductions,
      advanceDeduction: advanceDeduction ?? this.advanceDeduction,
      netSalary: netSalary ?? this.netSalary,
      status: status ?? this.status,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SalaryRecordModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.employeeId == employeeId &&
        other.employeeName == employeeName &&
        other.month == month &&
        other.year == year &&
        other.workingDays == workingDays &&
        other.presentDays == presentDays &&
        other.absentDays == absentDays &&
        other.halfDays == halfDays &&
        other.leaveDays == leaveDays &&
        other.basicSalary == basicSalary &&
        other.allowances == allowances &&
        other.deductions == deductions &&
        other.advanceDeduction == advanceDeduction &&
        other.netSalary == netSalary &&
        other.status == status &&
        other.paidAmount == paidAmount &&
        other.paymentDate == paymentDate &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      businessId,
      employeeId,
      employeeName,
      month,
      year,
      workingDays,
      presentDays,
      absentDays,
      halfDays,
      leaveDays,
      basicSalary,
      allowances,
      deductions,
      advanceDeduction,
      netSalary,
      status,
      paidAmount,
      paymentDate,
      notes,
    );
  }
}
