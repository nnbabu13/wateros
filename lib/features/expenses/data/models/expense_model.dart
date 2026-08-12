class ExpenseModel {
  final String id;
  final String businessId;
  final String? categoryId;
  final String? categoryName;
  final double amount;
  final String description;
  final DateTime expenseDate;
  final String paymentMode;
  final String? receiptUrl;
  final bool isRecurring;
  final String? recurringFrequency;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseModel({
    required this.id,
    required this.businessId,
    this.categoryId,
    this.categoryName,
    required this.amount,
    required this.description,
    required this.expenseDate,
    required this.paymentMode,
    this.receiptUrl,
    this.isRecurring = false,
    this.recurringFrequency,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      paymentMode: json['payment_mode'] as String,
      receiptUrl: json['receipt_url'] as String?,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurringFrequency: json['recurring_frequency'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'category_id': categoryId,
      'category_name': categoryName,
      'amount': amount,
      'description': description,
      'expense_date': expenseDate.toIso8601String(),
      'payment_mode': paymentMode,
      'receipt_url': receiptUrl,
      'is_recurring': isRecurring,
      'recurring_frequency': recurringFrequency,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? businessId,
    String? categoryId,
    String? categoryName,
    double? amount,
    String? description,
    DateTime? expenseDate,
    String? paymentMode,
    String? receiptUrl,
    bool? isRecurring,
    String? recurringFrequency,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      expenseDate: expenseDate ?? this.expenseDate,
      paymentMode: paymentMode ?? this.paymentMode,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpenseModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.categoryId == categoryId &&
        other.categoryName == categoryName &&
        other.amount == amount &&
        other.description == description &&
        other.expenseDate == expenseDate &&
        other.paymentMode == paymentMode &&
        other.receiptUrl == receiptUrl &&
        other.isRecurring == isRecurring &&
        other.recurringFrequency == recurringFrequency &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      businessId,
      categoryId,
      categoryName,
      amount,
      description,
      expenseDate,
      paymentMode,
      receiptUrl,
      isRecurring,
      recurringFrequency,
      createdBy,
      createdAt,
      updatedAt,
    );
  }
}
