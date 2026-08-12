import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessHelper {
  static Future<String> getOrCreateBusinessId() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final profile = await client
        .from('user_profiles')
        .select('business_id')
        .eq('id', user.id)
        .maybeSingle();

    if (profile != null && profile['business_id'] != null) {
      return profile['business_id'] as String;
    }

    final businessName = user.userMetadata?['full_name'] as String? ??
        user.email?.split('@').first ??
        'My Business';

    final business = await client.from('businesses').insert({
      'name': businessName,
      'owner_name': user.userMetadata?['full_name'] as String? ?? businessName,
      'phone': user.phone ?? '',
      'email': user.email ?? '',
    }).select().single();

    final businessId = business['id'] as String;

    await client.from('user_profiles').insert({
      'id': user.id,
      'business_id': businessId,
      'full_name': user.userMetadata?['full_name'] as String? ?? businessName,
      'phone': user.phone ?? '',
      'role': 'owner',
    });

    return businessId;
  }
}
