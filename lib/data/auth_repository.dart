import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'adopter', // adopter | rescuer | shelter
  }) async {
    final res = await _client.auth.signUp(email: email, password: password);
    final user = res.user;

    if (user == null) {
      throw Exception('Sign up failed');
    }

    await _client.from('user').insert({
      'id': user.id,
      'email': email,
      'name': name,
      'role': role,
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

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
    if (role != null) payload['role'] = role;

    if (payload.isEmpty) return;
    await _client.from('user').update(payload).eq('id', uid);
  }

  Future<dynamic> callGetUsersFunction() async {
  final response = await _client.functions.invoke('get-users');
  return response.data;
  }

}

