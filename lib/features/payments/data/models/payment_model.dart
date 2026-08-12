class PaymentModel {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String? saleId;
  final String? invoiceNumber;
  final double amount;
  final String paymentMode;
  final DateTime paymentDate;
  final String? referenceNumber;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    this.saleId,
    this.invoiceNumber,
    required this.amount,
    required this.paymentMode,
    required this.paymentDate,
    this.referenceNumber,
    this.notes,
    this.createdBy,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      saleId: json['sale_id'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      amount: (json['amount'] as num).toDouble(),
      paymentMode: json['payment_mode'] as String,
      paymentDate: DateTime.parse(json['payment_date'] as String),
      referenceNumber: json['reference_number'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'customer_id': customerId,
      'customer_name': customerName,
      'sale_id': saleId,
      'invoice_number': invoiceNumber,
      'amount': amount,
      'payment_mode': paymentMode,
      'payment_date': paymentDate.toIso8601String(),
      'reference_number': referenceNumber,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PaymentModel copyWith({
    String? id,
    String? businessId,
    String? customerId,
    String? customerName,
    String? saleId,
    String? invoiceNumber,
    double? amount,
    String? paymentMode,
    DateTime? paymentDate,
    String? referenceNumber,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      saleId: saleId ?? this.saleId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentDate: paymentDate ?? this.paymentDate,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.customerId == customerId &&
        other.customerName == customerName &&
        other.saleId == saleId &&
        other.invoiceNumber == invoiceNumber &&
        other.amount == amount &&
        other.paymentMode == paymentMode &&
        other.paymentDate == paymentDate &&
        other.referenceNumber == referenceNumber &&
        other.notes == notes &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      businessId,
      customerId,
      customerName,
      saleId,
      invoiceNumber,
      amount,
      paymentMode,
      paymentDate,
      referenceNumber,
      notes,
      createdBy,
      createdAt,
    );
  }
}
