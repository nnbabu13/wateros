import 'purchase_item_model.dart';

class PurchaseModel {
  final String id;
  final String businessId;
  final String supplierId;
  final String supplierName;
  final String purchaseNumber;
  final DateTime purchaseDate;
  final DateTime? dueDate;
  final double subtotal;
  final double discountAmount;
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
  final List<PurchaseItemModel> items;

  const PurchaseModel({
    required this.id,
    required this.businessId,
    required this.supplierId,
    required this.supplierName,
    required this.purchaseNumber,
    required this.purchaseDate,
    this.dueDate,
    required this.subtotal,
    this.discountAmount = 0.0,
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

  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    return PurchaseModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      supplierId: json['supplier_id'] as String,
      supplierName: json['supplier_name'] as String,
      purchaseNumber: json['purchase_number'] as String,
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
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
              ?.map((e) =>
                  PurchaseItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'purchase_number': purchaseNumber,
      'purchase_date': purchaseDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'subtotal': subtotal,
      'discount_amount': discountAmount,
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

  PurchaseModel copyWith({
    String? id,
    String? businessId,
    String? supplierId,
    String? supplierName,
    String? purchaseNumber,
    DateTime? purchaseDate,
    DateTime? dueDate,
    double? subtotal,
    double? discountAmount,
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
    List<PurchaseItemModel>? items,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      purchaseNumber: purchaseNumber ?? this.purchaseNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      dueDate: dueDate ?? this.dueDate,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
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
    return other is PurchaseModel &&
        other.id == id &&
        other.businessId == businessId &&
        other.supplierId == supplierId &&
        other.supplierName == supplierName &&
        other.purchaseNumber == purchaseNumber &&
        other.purchaseDate == purchaseDate &&
        other.dueDate == dueDate &&
        other.subtotal == subtotal &&
        other.discountAmount == discountAmount &&
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
      supplierId,
      supplierName,
      purchaseNumber,
      purchaseDate,
      dueDate,
      subtotal,
      discountAmount,
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

  bool _listEquals(List<PurchaseItemModel> a, List<PurchaseItemModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
