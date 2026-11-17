import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/auth/supabase_auth_service.dart';

void main() {
  group('SupabaseAuthService Tests', () {
    test('reports isSupported as true when credentials are configured', () {
      final service = SupabaseAuthService();
      expect(service.isSupported, isTrue);
    });

    test('gracefully handles missing client or uninitialized auth', () async {
      final service = SupabaseAuthService();
      // If client is not initialized in pure test harness, it returns graceful failure
      final result = await service.signInWithPassword(
        email: 'test@example.com',
        password: 'password123',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('signOut cleans up PowerSync without unhandled error', () async {
      final service = SupabaseAuthService();
      await expectLater(service.signOut(), completes);
    });
  });
}
