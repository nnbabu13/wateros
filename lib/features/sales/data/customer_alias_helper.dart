import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists "register name variant -> real customer" links so OCR/import
/// can auto-match Sharath→Sarath, Chikkala→Surya bar, etc. next time.
class CustomerAliasHelper {
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();

  /// Upsert alias for [aliasText] pointing at [customerId].
  /// No-op when alias is empty or identical to the customer's own name.
  static Future<void> remember({
    required String businessId,
    required String customerId,
    required String customerName,
    required String? aliasText,
  }) async {
    final raw = aliasText?.trim() ?? '';
    if (raw.isEmpty) return;
    final aliasNorm = normalize(raw);
    final nameNorm = normalize(customerName);
    if (aliasNorm.isEmpty || aliasNorm == nameNorm) return;

    try {
      await Supabase.instance.client.from('customer_name_aliases').upsert(
        {
          'business_id': businessId,
          'customer_id': customerId,
          'alias': raw,
          'alias_normalized': aliasNorm,
          'last_used_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'business_id,alias_normalized',
      );
    } catch (_) {
      // Non-fatal — memory is best-effort.
    }
  }

  /// Bump last_used_at when an alias successfully matches (optional).
  static Future<void> touch({
    required String businessId,
    required String aliasNormalized,
  }) async {
    try {
      await Supabase.instance.client
          .from('customer_name_aliases')
          .update({
        'last_used_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('business_id', businessId).eq('alias_normalized', aliasNormalized);
    } catch (_) {}
  }

  static Future<Map<String, String>> loadMap(String businessId) async {
    try {
      final rows = await Supabase.instance.client
          .from('customer_name_aliases')
          .select('alias_normalized, customer_id')
          .eq('business_id', businessId);
      return {
        for (final r in List<Map<String, dynamic>>.from(rows))
          (r['alias_normalized'] as String): r['customer_id'] as String,
      };
    } catch (_) {
      return {};
    }
  }

  /// Remembers "Bags" → Water Bag etc. when user picks a product.
  static Future<void> rememberProduct({
    required String businessId,
    required String productId,
    required String productName,
    required String? aliasText,
  }) async {
    final raw = aliasText?.trim() ?? '';
    if (raw.isEmpty) return;
    final aliasNorm = normalize(raw);
    final nameNorm = normalize(productName);
    if (aliasNorm.isEmpty || aliasNorm == nameNorm) return;

    try {
      await Supabase.instance.client.from('product_name_aliases').upsert(
        {
          'business_id': businessId,
          'product_id': productId,
          'alias': raw,
          'alias_normalized': aliasNorm,
          'last_used_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'business_id,alias_normalized',
      );
    } catch (_) {}
  }

  static Future<Map<String, String>> loadProductMap(String businessId) async {
    try {
      final rows = await Supabase.instance.client
          .from('product_name_aliases')
          .select('alias_normalized, product_id')
          .eq('business_id', businessId);
      return {
        for (final r in List<Map<String, dynamic>>.from(rows))
          (r['alias_normalized'] as String): r['product_id'] as String,
      };
    } catch (_) {
      return {};
    }
  }
}
