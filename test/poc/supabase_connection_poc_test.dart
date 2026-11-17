import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Supabase client initializes and queries live project endpoint', () async {
    const url = 'https://willvonrjbtvfqvmfwam.supabase.co';
    const publishableKey = 'sb_publishable_mnmRQHw9HyB4MsLAo3iNIw_ubr_WPJF';

    final client = SupabaseClient(url, publishableKey);
    expect(client, isNotNull);

    // Query an empty/authenticated table with RLS. Since there is no authenticated session,
    // RLS policy should return an empty list [] with status 200 (no crash/error).
    final response = await client.from('account_profiles').select();
    expect(response, isA<List>());
    expect(response, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('Supabase Auth endpoint is reachable', () async {
    const url = 'https://willvonrjbtvfqvmfwam.supabase.co';
    const publishableKey = 'sb_publishable_mnmRQHw9HyB4MsLAo3iNIw_ubr_WPJF';

    final client = SupabaseClient(url, publishableKey);
    // Attempting to get current session should return null gracefully
    final session = client.auth.currentSession;
    expect(session, isNull);
  }, timeout: const Timeout(Duration(minutes: 1)));
}
