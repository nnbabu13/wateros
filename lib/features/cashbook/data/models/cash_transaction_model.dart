class CashTransactionModel {
  final String id;
  final String businessId;
  final String transactionType;
  final double amount;
  final String? referenceType;
  final String? referenceId;
  final String? description;
  final DateTime transactionDate;
  final String? createdBy;
  final DateTime createdAt;

  const CashTransactionModel({
    required this.id,
    required this.businessId,
    required this.transactionType,
    required this.amount,
    this.referenceType,
    this.referenceId,
    this.description,
    required this.transactionDate,
    this.createdBy,
    required this.createdAt,
  });

  factory CashTransactionModel.fromJson(Map<String, dynamic> json) {
    return CashTransactionModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      transactionType: json['transaction_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      description: json['description'] as String?,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'transaction_type': transactionType,
      'amount': amount,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'description': description,
      'transaction_date': transactionDate.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CashTransactionModel copyWith({
    String? id,
    String? businessId,
    String? transactionType,
    double? amount,
    String? referenceType,
    String? referenceId,
    String? description,
    DateTime? transactionDate,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return CashTransactionModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CashTransactionModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.transactionType == transactionType &&
        other.amount == amount &&
        other.referenceType == referenceType &&
        other.referenceId == referenceId &&
        other.description == description &&
        other.transactionDate == transactionDate &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      businessId,
      transactionType,
      amount,
      referenceType,
      referenceId,
      description,
      transactionDate,
      createdBy,
      createdAt,
    );
  }
}
