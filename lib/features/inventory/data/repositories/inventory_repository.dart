import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_product.dart';
import '../models/stock_movement.dart';

class InventoryRepository {
  final _client = Supabase.instance.client;

  Future<List<InventoryProduct>> getProducts(String businessId) async {
    final data = await _client
        .from('products')
        .select()
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('name');
    return (data as List).map((e) => InventoryProduct.fromMap(e)).toList();
  }

  Future<InventoryProduct> addProduct(Map<String, dynamic> product) async {
    final data = await _client.from('products').insert(product).select().single();
    return InventoryProduct.fromMap(data);
  }

  Future<void> updateProduct(String id, Map<String, dynamic> updates) async {
    await _client.from('products').update(updates).eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('products').update({'is_active': false}).eq('id', id);
  }

  Future<List<StockMovement>> getMovements(String businessId, {String? productId}) async {
    final List<dynamic> data;
    if (productId != null) {
      data = await _client
          .from('inventory_movements')
          .select('*, products(name, unit)')
          .eq('business_id', businessId)
          .eq('product_id', productId)
          .order('created_at', ascending: false);
    } else {
      data = await _client
          .from('inventory_movements')
          .select('*, products(name, unit)')
          .eq('business_id', businessId)
          .order('created_at', ascending: false);
    }
    return data.map((e) => StockMovement.fromMap(e)).toList();
  }

  Future<StockMovement> addMovement(Map<String, dynamic> movement) async {
    final data = await _client.from('inventory_movements').insert(movement).select().single();
    return StockMovement.fromMap(data);
  }

  Future<void> updateStock(String productId, double newStock) async {
    await _client.from('products').update({'current_stock': newStock}).eq('id', productId);
  }
}
