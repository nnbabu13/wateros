import 'package:supabase_flutter/supabase_flutter.dart';

/// Single source of truth for Cost of Goods Sold.
///
/// Cost resolution order per product:
///   1. products.average_cost (weighted average from purchases)
///   2. products.purchase_price
///   3. recipe cost (sum of material costs / recipe yield) for finished goods
///   4. 0
class ProductCostHelper {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<double> calculateCogs({
    required String businessId,
    required List<String> saleIds,
  }) async {
    if (saleIds.isEmpty) return 0;

    final saleItems = await _client
        .from('sale_items')
        .select('quantity, product_id')
        .inFilter('sale_id', saleIds);
    if (saleItems.isEmpty) return 0;

    final productIds = <String>{};
    for (final item in saleItems) {
      final pid = item['product_id'] as String?;
      if (pid != null && pid.isNotEmpty) productIds.add(pid);
    }
    if (productIds.isEmpty) return 0;

    final costs = await fetchUnitCosts(
      businessId: businessId,
      productIds: productIds,
    );

    double cogs = 0;
    for (final item in saleItems) {
      final pid = item['product_id'] as String?;
      if (pid == null || pid.isEmpty) continue;
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
      cogs += qty * (costs[pid] ?? 0);
    }
    return cogs;
  }

  static Future<Map<String, double>> fetchUnitCosts({
    required String businessId,
    required Set<String> productIds,
  }) async {
    final costs = <String, double>{};
    if (productIds.isEmpty) return costs;

    final products = await _client
        .from('products')
        .select('id, average_cost, purchase_price')
        .inFilter('id', productIds.toList());
    for (final p in products) {
      final avg = (p['average_cost'] as num?)?.toDouble() ?? 0;
      final purchase = (p['purchase_price'] as num?)?.toDouble() ?? 0;
      costs[p['id'] as String] = avg > 0 ? avg : purchase;
    }

    final missing = productIds.where((id) => (costs[id] ?? 0) <= 0).toList();
    if (missing.isNotEmpty) {
      final recipeCosts = await _recipeUnitCosts(
        businessId: businessId,
        productIds: missing,
      );
      recipeCosts.forEach((id, cost) {
        if (cost > 0) costs[id] = cost;
      });
    }
    return costs;
  }

  static Future<Map<String, double>> _recipeUnitCosts({
    required String businessId,
    required List<String> productIds,
  }) async {
    final result = <String, double>{};
    try {
      final recipes = await _client
          .from('product_recipes')
          .select('id, product_id, yield_quantity')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .inFilter('product_id', productIds);
      if (recipes.isEmpty) return result;

      final recipeIds = recipes.map((r) => r['id'] as String).toList();
      final items = await _client
          .from('recipe_items')
          .select('recipe_id, material_id, quantity_per_unit')
          .inFilter('recipe_id', recipeIds);
      if (items.isEmpty) return result;

      final materialIds = items
          .map((i) => i['material_id'] as String?)
          .whereType<String>()
          .toSet();
      if (materialIds.isEmpty) return result;

      final materials = await _client
          .from('products')
          .select('id, average_cost, purchase_price')
          .inFilter('id', materialIds.toList());
      final materialCosts = <String, double>{};
      for (final m in materials) {
        final avg = (m['average_cost'] as num?)?.toDouble() ?? 0;
        final purchase = (m['purchase_price'] as num?)?.toDouble() ?? 0;
        materialCosts[m['id'] as String] = avg > 0 ? avg : purchase;
      }

      final perRecipe = <String, double>{};
      for (final item in items) {
        final rid = item['recipe_id'] as String;
        final mid = item['material_id'] as String?;
        if (mid == null) continue;
        final qty = (item['quantity_per_unit'] as num?)?.toDouble() ?? 0;
        perRecipe[rid] = (perRecipe[rid] ?? 0) + qty * (materialCosts[mid] ?? 0);
      }

      for (final r in recipes) {
        final rid = r['id'] as String;
        final pid = r['product_id'] as String;
        final yieldQty = (r['yield_quantity'] as num?)?.toDouble() ?? 1;
        final total = perRecipe[rid] ?? 0;
        if (total <= 0) continue;
        final unit = yieldQty > 0 ? total / yieldQty : total;
        final existing = result[pid];
        if (existing == null || unit < existing) result[pid] = unit;
      }
    } catch (_) {}
    return result;
  }
}
