class ProductRecipe {
  final String id;
  final String businessId;
  final String productId;
  final String name;
  final String? description;
  final double yieldQuantity;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  List<RecipeItem>? items;

  ProductRecipe({
    required this.id,
    required this.businessId,
    required this.productId,
    this.name = 'Default Recipe',
    this.description,
    this.yieldQuantity = 1,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.items,
  });

  factory ProductRecipe.fromMap(Map<String, dynamic> map) {
    return ProductRecipe(
      id: map['id'] as String,
      businessId: map['business_id'] as String,
      productId: map['product_id'] as String,
      name: map['name'] as String? ?? 'Default Recipe',
      description: map['description'] as String?,
      yieldQuantity: (map['yield_quantity'] as num?)?.toDouble() ?? 1,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'business_id': businessId,
      'product_id': productId,
      'name': name,
      'description': description,
      'yield_quantity': yieldQuantity,
      'is_active': isActive,
    };
  }
}

class RecipeItem {
  final String id;
  final String recipeId;
  final String materialId;
  final String? materialName;
  final String? materialUnit;
  final double quantityPerUnit;
  final String unit;
  final int sortOrder;

  RecipeItem({
    required this.id,
    required this.recipeId,
    required this.materialId,
    this.materialName,
    this.materialUnit,
    required this.quantityPerUnit,
    this.unit = 'piece',
    this.sortOrder = 0,
  });

  factory RecipeItem.fromMap(Map<String, dynamic> map) {
    return RecipeItem(
      id: map['id'] as String,
      recipeId: map['recipe_id'] as String,
      materialId: map['material_id'] as String,
      materialName: map['material_name'] as String?,
      materialUnit: map['material_unit'] as String?,
      quantityPerUnit: (map['quantity_per_unit'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'piece',
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipe_id': recipeId,
      'material_id': materialId,
      'quantity_per_unit': quantityPerUnit,
      'unit': unit,
      'sort_order': sortOrder,
    };
  }
}
