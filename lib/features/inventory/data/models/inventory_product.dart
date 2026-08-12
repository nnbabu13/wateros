class InventoryProduct {
  final String id;
  final String businessId;
  final String name;
  final String? categoryId;
  final String unit;
  final double currentStock;
  final double minStock;
  final double costPrice;
  final double sellPrice;
  final String? hsnCode;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryProduct({
    required this.id,
    required this.businessId,
    required this.name,
    this.categoryId,
    this.unit = 'piece',
    this.currentStock = 0,
    this.minStock = 0,
    this.costPrice = 0,
    this.sellPrice = 0,
    this.hsnCode,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => currentStock <= minStock;

  factory InventoryProduct.fromMap(Map<String, dynamic> map) {
    return InventoryProduct(
      id: map['id'] as String,
      businessId: map['business_id'] as String,
      name: map['name'] as String,
      categoryId: map['category_id'] as String?,
      unit: map['unit'] as String? ?? 'piece',
      currentStock: (map['current_stock'] as num?)?.toDouble() ?? 0,
      minStock: (map['minimum_stock'] as num?)?.toDouble() ?? 0,
      costPrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
      sellPrice: (map['selling_price'] as num?)?.toDouble() ?? 0,
      hsnCode: map['sku'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'category_id': categoryId,
      'unit': unit,
      'current_stock': currentStock,
      'minimum_stock': minStock,
      'purchase_price': costPrice,
      'selling_price': sellPrice,
      'sku': hsnCode,
      'is_active': isActive,
    };
  }
}
