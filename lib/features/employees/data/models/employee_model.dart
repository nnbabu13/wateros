class EmployeeModel {
  final String id;
  final String businessId;
  final String? userProfileId;
  final String employeeCode;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? city;
  final DateTime? dateOfBirth;
  final DateTime? dateOfJoining;
  final String? designation;
  final String? department;
  final double basicSalary;
  final String? bankName;
  final String? bankAccountNumber;
  final String? ifscCode;
  final String? panNumber;
  final String? aadharNumber;
  final String? emergencyContact;
  final String? emergencyContactName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeModel({
    required this.id,
    required this.businessId,
    this.userProfileId,
    required this.employeeCode,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.dateOfBirth,
    this.dateOfJoining,
    this.designation,
    this.department,
    this.basicSalary = 0.0,
    this.bankName,
    this.bankAccountNumber,
    this.ifscCode,
    this.panNumber,
    this.aadharNumber,
    this.emergencyContact,
    this.emergencyContactName,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      userProfileId: json['user_profile_id'] as String?,
      employeeCode: json['employee_code'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      dateOfJoining: json['date_of_joining'] != null
          ? DateTime.parse(json['date_of_joining'] as String)
          : null,
      designation: json['designation'] as String?,
      department: json['department'] as String?,
      basicSalary: (json['basic_salary'] as num?)?.toDouble() ?? 0.0,
      bankName: json['bank_name'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      panNumber: json['pan_number'] as String?,
      aadharNumber: json['aadhar_number'] as String?,
      emergencyContact: json['emergency_contact'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'user_profile_id': userProfileId,
      'employee_code': employeeCode,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'date_of_joining': dateOfJoining?.toIso8601String(),
      'designation': designation,
      'department': department,
      'basic_salary': basicSalary,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'ifsc_code': ifscCode,
      'pan_number': panNumber,
      'aadhar_number': aadharNumber,
      'emergency_contact': emergencyContact,
      'emergency_contact_name': emergencyContactName,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EmployeeModel copyWith({
    String? id,
    String? businessId,
    String? userProfileId,
    String? employeeCode,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    DateTime? dateOfBirth,
    DateTime? dateOfJoining,
    String? designation,
    String? department,
    double? basicSalary,
    String? bankName,
    String? bankAccountNumber,
    String? ifscCode,
    String? panNumber,
    String? aadharNumber,
    String? emergencyContact,
    String? emergencyContactName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      userProfileId: userProfileId ?? this.userProfileId,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      dateOfJoining: dateOfJoining ?? this.dateOfJoining,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      basicSalary: basicSalary ?? this.basicSalary,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      panNumber: panNumber ?? this.panNumber,
      aadharNumber: aadharNumber ?? this.aadharNumber,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyContactName:
          emergencyContactName ?? this.emergencyContactName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmployeeModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.userProfileId == userProfileId &&
        other.employeeCode == employeeCode &&
        other.name == name &&
        other.phone == phone &&
        other.email == email &&
        other.address == address &&
        other.city == city &&
        other.dateOfBirth == dateOfBirth &&
        other.dateOfJoining == dateOfJoining &&
        other.designation == designation &&
        other.department == department &&
        other.basicSalary == basicSalary &&
        other.bankName == bankName &&
        other.bankAccountNumber == bankAccountNumber &&
        other.ifscCode == ifscCode &&
        other.panNumber == panNumber &&
        other.aadharNumber == aadharNumber &&
        other.emergencyContact == emergencyContact &&
        other.emergencyContactName == emergencyContactName &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      businessId,
      userProfileId,
      employeeCode,
      name,
      phone,
      email,
      address,
      city,
      dateOfBirth,
      dateOfJoining,
      designation,
      department,
      basicSalary,
      bankName,
      bankAccountNumber,
      ifscCode,
      panNumber,
      aadharNumber,
      emergencyContact,
    );
  }
}
