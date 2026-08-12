import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  SupabaseClient get client => _client;
  GoTrueClient get auth => _client.auth;
  User? get currentUser => auth.currentUser;

  Future<List<Map<String, dynamic>>> fetchAll({
    required String table,
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = false,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic query = _client.from(table).select(select ?? '*');

      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) {
            query = query.eq(key, value);
          }
        });
      }

      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      if (limit != null && offset != null) {
        query = query.range(offset, offset + limit - 1);
      } else if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch data: $e');
    }
  }

  Future<Map<String, dynamic>> fetchById({
    required String table,
    required String id,
    String? select,
  }) async {
    try {
      final response = await _client
          .from(table)
          .select(select ?? '*')
          .eq('id', id)
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to fetch record: $e');
    }
  }

  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _client.from(table).insert(data).select().single();
      return response;
    } catch (e) {
      throw Exception('Failed to insert record: $e');
    }
  }

  Future<Map<String, dynamic>> update({
    required String table,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _client
          .from(table)
          .update(data)
          .eq('id', id)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update record: $e');
    }
  }

  Future<void> delete({
    required String table,
    required String id,
  }) async {
    try {
      await _client.from(table).delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete record: $e');
    }
  }

  Future<List<Map<String, dynamic>>> rpc({
    required String function,
    Map<String, dynamic>? params,
  }) async {
    try {
      final response = await _client.rpc(function, params: params);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to call function: $e');
    }
  }
}
