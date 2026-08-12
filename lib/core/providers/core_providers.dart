import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

final businessIdProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw Exception('No authenticated user');
  return user.userMetadata?['business_id'] as String? ?? '';
});

final businessIdFutureProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw Exception('No authenticated user');

  final meta = user.userMetadata;
  final cachedBizId = meta?['business_id'] as String?;
  if (cachedBizId != null && cachedBizId.isNotEmpty) return cachedBizId;

  final response = await Supabase.instance.client
      .from('user_profiles')
      .select('business_id')
      .eq('id', user.id)
      .maybeSingle();

  if (response == null) throw Exception('User profile not found');
  return response['business_id'] as String;
});
