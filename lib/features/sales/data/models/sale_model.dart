import 'sale_item_model.dart';

class SaleModel {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final double subtotal;
  final double discountAmount;
  final double discountPercent;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final String paymentMode;
  final String status;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SaleItemModel> items;

  const SaleModel({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.dueDate,
    required this.subtotal,
    this.discountAmount = 0.0,
    this.discountPercent = 0.0,
    this.taxAmount = 0.0,
    required this.totalAmount,
    this.paidAmount = 0.0,
    this.balanceAmount = 0.0,
    required this.paymentMode,
    required this.status,
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String,
      invoiceNumber: json['invoice_number'] as String,
      invoiceDate: DateTime.parse(json['invoice_date'] as String),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balance_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'customer_id': customerId,
      'customer_name': customerName,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'discount_percent': discountPercent,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'balance_amount': balanceAmount,
      'payment_mode': paymentMode,
      'status': status,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  SaleModel copyWith({
    String? id,
    String? businessId,
    String? customerId,
    String? customerName,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? dueDate,
    double? subtotal,
    double? discountAmount,
    double? discountPercent,
    double? taxAmount,
    double? totalAmount,
    double? paidAmount,
    double? balanceAmount,
    String? paymentMode,
    String? status,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SaleItemModel>? items,
  }) {
    return SaleModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SaleModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.customerId == customerId &&
        other.customerName == customerName &&
        other.invoiceNumber == invoiceNumber &&
        other.invoiceDate == invoiceDate &&
        other.dueDate == dueDate &&
        other.subtotal == subtotal &&
        other.discountAmount == discountAmount &&
        other.discountPercent == discountPercent &&
        other.taxAmount == taxAmount &&
        other.totalAmount == totalAmount &&
        other.paidAmount == paidAmount &&
        other.balanceAmount == balanceAmount &&
        other.paymentMode == paymentMode &&
        other.status == status &&
        other.notes == notes &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        _listEquals(other.items, items);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      businessId,
      customerId,
      customerName,
      invoiceNumber,
      invoiceDate,
      dueDate,
      subtotal,
      discountAmount,
      discountPercent,
      taxAmount,
      totalAmount,
      paidAmount,
      balanceAmount,
      paymentMode,
      status,
      notes,
      createdBy,
      createdAt,
      updatedAt,
    );
  }

  bool _listEquals(List<SaleItemModel> a, List<SaleItemModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
