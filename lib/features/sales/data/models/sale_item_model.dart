class SaleItemModel {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double gstRate;
  final double gstAmount;
  final double totalAmount;
  final DateTime createdAt;

  const SaleItemModel({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0.0,
    this.gstRate = 0.0,
    this.gstAmount = 0.0,
    required this.totalAmount,
    required this.createdAt,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    return SaleItemModel(
      id: json['id'] as String,
      saleId: json['sale_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (json['gst_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_amount': discountAmount,
      'gst_rate': gstRate,
      'gst_amount': gstAmount,
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SaleItemModel copyWith({
    String? id,
    String? saleId,
    String? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    double? discountAmount,
    double? gstRate,
    double? gstAmount,
    double? totalAmount,
    DateTime? createdAt,
  }) {
    return SaleItemModel(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      gstRate: gstRate ?? this.gstRate,
      gstAmount: gstAmount ?? this.gstAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SaleItemModel &&
        other.id == id &&
        other.saleId == saleId &&
        other.productId == productId &&
        other.productName == productName &&
        other.quantity == quantity &&
        other.unitPrice == unitPrice &&
        other.discountAmount == discountAmount &&
        other.gstRate == gstRate &&
        other.gstAmount == gstAmount &&
        other.totalAmount == totalAmount &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      saleId,
      productId,
      productName,
      quantity,
      unitPrice,
      discountAmount,
      gstRate,
      gstAmount,
      totalAmount,
      createdAt,
    );
  }
}
