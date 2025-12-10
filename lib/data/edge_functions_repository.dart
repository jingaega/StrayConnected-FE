import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple wrapper to call Supabase Edge Functions from the app.
class EdgeFunctionsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetches users via the deployed `get-users` edge function.
  ///
  /// Throws if there is no active session or the function responds with an error.
  Future<List<dynamic>> fetchUsers() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw Exception('Not logged in');
    }

    // Using Supabase Functions client automatically adds the `apikey` header and
    // forwards the current user's JWT, which prevents the 401 we hit when
    // calling the raw URL without the apikey header.
    try {
      final response = await _client.functions.invoke(
        'get-users',
        method: HttpMethod.get,
      );

      final data = response.data;
      if (data is List) {
        return data;
      }
      throw Exception('Failed to fetch users: unexpected response');
    } on FunctionException catch (e) {
      final details = e.details ?? e.reasonPhrase ?? e.status.toString();
      throw Exception('Failed to fetch users: $details');
    }
  }
}
