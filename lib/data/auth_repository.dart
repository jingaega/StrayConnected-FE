import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/services/push_notifications.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;
  static const Set<String> _selfServiceRoles = {
    'adopter',
    'rescuer',
    'shelter',
  };

  Future<String> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'adopter', // adopter | rescuer | shelter
    double? latitude,
    double? longitude,
  }) async {
    final normalizedRole = role.trim().toLowerCase();
    if (!_selfServiceRoles.contains(normalizedRole)) {
      throw Exception('Role not allowed for self sign-up');
    }

    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'role': normalizedRole},
    );
    final user = res.user;

    if (user == null) {
      throw Exception('Sign up failed');
    }

    // Ensure profile row exists/updates with selected role and name
    await _client.from('user').upsert(
      {
        'id': user.id,
        'email': email,
        'name': name,
        'role': normalizedRole,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
      onConflict: 'id',
    );

    return user.id;
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
    await PushNotifications.saveDeviceToken();
    await PushNotifications.startRealtimeListener();
  }

  Future<void> signOut() async {
    await PushNotifications.stopRealtimeListener();
    await _client.auth.signOut();
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    return await _client.from('user').select().eq('id', uid).maybeSingle();
  }

  Future<void> updateMyProfile({String? name, String? role}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not logged in');

    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (role != null) {
      final normalizedRole = role.trim().toLowerCase();
      if (!_selfServiceRoles.contains(normalizedRole)) {
        throw Exception('Role change not permitted');
      }
      payload['role'] = normalizedRole;
    }

    if (payload.isEmpty) return;
    await _client.from('user').update(payload).eq('id', uid);
  }

  Future<dynamic> callGetUsersFunction() async {
  final response = await _client.functions.invoke('get-users');
  return response.data;
  }

}
