class CustomerModel {
  final String id;
  final String businessId;
  final String name;
  final String phone;
  final String? whatsappPhone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? gstNumber;
  final double openingBalance;
  final double currentBalance;
  final double creditLimit;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.phone,
    this.whatsappPhone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.gstNumber,
    this.openingBalance = 0.0,
    this.currentBalance = 0.0,
    this.creditLimit = 0.0,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      whatsappPhone: json['whatsapp_phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      gstNumber: json['gst_number'] as String?,
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'phone': phone,
      'whatsapp_phone': whatsappPhone,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'gst_number': gstNumber,
      'opening_balance': openingBalance,
      'current_balance': currentBalance,
      'credit_limit': creditLimit,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CustomerModel copyWith({
    String? id,
    String? businessId,
    String? name,
    String? phone,
    String? whatsappPhone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstNumber,
    double? openingBalance,
    double? currentBalance,
    double? creditLimit,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsappPhone: whatsappPhone ?? this.whatsappPhone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      gstNumber: gstNumber ?? this.gstNumber,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.name == name &&
        other.phone == phone &&
        other.whatsappPhone == whatsappPhone &&
        other.email == email &&
        other.address == address &&
        other.city == city &&
        other.state == state &&
        other.pincode == pincode &&
        other.gstNumber == gstNumber &&
        other.openingBalance == openingBalance &&
        other.currentBalance == currentBalance &&
        other.creditLimit == creditLimit &&
        other.notes == notes &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      businessId,
      name,
      phone,
      whatsappPhone,
      email,
      address,
      city,
      state,
      pincode,
      gstNumber,
      openingBalance,
      currentBalance,
      creditLimit,
      notes,
      isActive,
      createdAt,
      updatedAt,
    );
  }
}
