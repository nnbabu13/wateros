class ProductModel {
  final String id;
  final String businessId;
  final String? categoryId;
  final String? categoryName;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final double gstRate;
  final double currentStock;
  final double minimumStock;
  final double? maximumStock;
  final String? imageUrl;
  final bool isActive;
  final String productType;
  final String? packagingUnit;
  final double conversionQuantity;
  final double averageCost;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.businessId,
    this.categoryId,
    this.categoryName,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    this.unit = 'pcs',
    this.purchasePrice = 0.0,
    required this.sellingPrice,
    this.gstRate = 0.0,
    this.currentStock = 0.0,
    this.minimumStock = 0.0,
    this.maximumStock,
    this.imageUrl,
    this.isActive = true,
    this.productType = 'finished_product',
    this.packagingUnit,
    this.conversionQuantity = 1,
    this.averageCost = 0.0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isRawMaterial => productType == 'raw_material';
  bool get isPackaging => productType == 'packaging';
  bool get isFinishedProduct => productType == 'finished_product';
  bool get isReusableAsset => productType == 'reusable_asset';
  bool get isLowStock => currentStock <= minimumStock;

  String get stockDisplay {
    if (packagingUnit != null && conversionQuantity > 1) {
      final cases = currentStock ~/ conversionQuantity;
      final remaining = currentStock % conversionQuantity;
      if (cases > 0 && remaining > 0) {
        return '$cases ${packagingUnit} + ${remaining.toInt()} $unit';
      } else if (cases > 0) {
        return '$cases ${packagingUnit}';
      }
    }
    return '${currentStock.toInt()} $unit';
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      description: json['description'] as String?,
      unit: json['unit'] as String? ?? 'pcs',
      purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['selling_price'] as num).toDouble(),
      gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 0.0,
      currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0.0,
      minimumStock: (json['minimum_stock'] as num?)?.toDouble() ?? 0.0,
      maximumStock: (json['maximum_stock'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      productType: json['product_type'] as String? ?? 'finished_product',
      packagingUnit: json['packaging_unit'] as String?,
      conversionQuantity: (json['conversion_quantity'] as num?)?.toDouble() ?? 1,
      averageCost: (json['average_cost'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
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
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'description': description,
      'unit': unit,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'gst_rate': gstRate,
      'current_stock': currentStock,
      'minimum_stock': minimumStock,
      'maximum_stock': maximumStock,
      'image_url': imageUrl,
      'is_active': isActive,
      'product_type': productType,
      'packaging_unit': packagingUnit,
      'conversion_quantity': conversionQuantity,
      'average_cost': averageCost,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? businessId,
    String? categoryId,
    String? categoryName,
    String? name,
    String? sku,
    String? barcode,
    String? description,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    double? gstRate,
    double? currentStock,
    double? minimumStock,
    double? maximumStock,
    String? imageUrl,
    bool? isActive,
    String? productType,
    String? packagingUnit,
    double? conversionQuantity,
    double? averageCost,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      gstRate: gstRate ?? this.gstRate,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      maximumStock: maximumStock ?? this.maximumStock,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      productType: productType ?? this.productType,
      packagingUnit: packagingUnit ?? this.packagingUnit,
      conversionQuantity: conversionQuantity ?? this.conversionQuantity,
      averageCost: averageCost ?? this.averageCost,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
