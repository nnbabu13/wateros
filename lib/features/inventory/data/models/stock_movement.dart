class StockMovement {
  final String id;
  final String businessId;
  final String productId;
  final String type; // 'in', 'out', 'adjustment'
  final double quantity;
  final String? referenceType;
  final String? referenceId;
  final String? notes;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.type,
    required this.quantity,
    this.referenceType,
    this.referenceId,
    this.notes,
    required this.createdAt,
  });

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as String,
      businessId: map['business_id'] as String,
      productId: map['product_id'] as String,
      type: map['movement_type'] as String,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      referenceType: map['reference_type'] as String?,
      referenceId: map['reference_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  DateTime get date => createdAt;
  String? get reason => notes;

  Map<String, dynamic> toMap() {
    return {
      'business_id': businessId,
      'product_id': productId,
      'movement_type': type,
      'quantity': quantity,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'notes': notes,
    };
  }
}
