class ProductionBatch {
  final String id;
  final String businessId;
  final String productId;
  final String? productName;
  final String? recipeId;
  final double plannedQuantity;
  final double actualQuantity;
  final DateTime productionDate;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  List<ProductionConsumption>? consumptions;
  List<ProductionOutput>? outputs;

  ProductionBatch({
    required this.id,
    required this.businessId,
    required this.productId,
    this.productName,
    this.recipeId,
    this.plannedQuantity = 0,
    this.actualQuantity = 0,
    required this.productionDate,
    this.status = 'planned',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.consumptions,
    this.outputs,
  });

  factory ProductionBatch.fromMap(Map<String, dynamic> map) {
    return ProductionBatch(
      id: map['id'] as String,
      businessId: map['business_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String?,
      recipeId: map['recipe_id'] as String?,
      plannedQuantity: (map['planned_quantity'] as num?)?.toDouble() ?? 0,
      actualQuantity: (map['actual_quantity'] as num?)?.toDouble() ?? 0,
      productionDate: DateTime.parse(map['production_date'] as String),
      status: map['status'] as String? ?? 'planned',
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'business_id': businessId,
      'product_id': productId,
      'recipe_id': recipeId,
      'planned_quantity': plannedQuantity,
      'actual_quantity': actualQuantity,
      'production_date': productionDate.toIso8601String().substring(0, 10),
      'status': status,
      'notes': notes,
    };
  }
}

class ProductionConsumption {
  final String id;
  final String batchId;
  final String materialId;
  final String? materialName;
  final double plannedQuantity;
  final double actualQuantity;

  ProductionConsumption({
    required this.id,
    required this.batchId,
    required this.materialId,
    this.materialName,
    this.plannedQuantity = 0,
    this.actualQuantity = 0,
  });

  factory ProductionConsumption.fromMap(Map<String, dynamic> map) {
    return ProductionConsumption(
      id: map['id'] as String,
      batchId: map['batch_id'] as String,
      materialId: map['material_id'] as String,
      materialName: map['material_name'] as String?,
      plannedQuantity: (map['planned_quantity'] as num?)?.toDouble() ?? 0,
      actualQuantity: (map['actual_quantity'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batch_id': batchId,
      'material_id': materialId,
      'planned_quantity': plannedQuantity,
      'actual_quantity': actualQuantity,
    };
  }
}

class ProductionOutput {
  final String id;
  final String batchId;
  final String productId;
  final String? productName;
  final double quantity;

  ProductionOutput({
    required this.id,
    required this.batchId,
    required this.productId,
    this.productName,
    this.quantity = 0,
  });

  factory ProductionOutput.fromMap(Map<String, dynamic> map) {
    return ProductionOutput(
      id: map['id'] as String,
      batchId: map['batch_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'batch_id': batchId,
      'product_id': productId,
      'quantity': quantity,
    };
  }
}
