import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/domain/services/google_identity_contracts.dart';
import 'package:qaza_namaz_cloud/google_sign_in_identity_provider.dart';

void main() {
  test('Google provider exposes identity without a cloud backend', () {
    final provider = GoogleSignInIdentityProvider(
      serverClientId: 'test-web-client.apps.googleusercontent.com',
    );

    expect(provider.isSupported, isTrue);
  });

  test('identity snapshot requires a stable account ID', () {
    const snapshot = GoogleIdentitySnapshot.signedIn(
      accountId: 'stable-google-id',
      displayName: 'Test User',
      email: 'test@example.com',
    );

    expect(snapshot.isSignedIn, isTrue);
    expect(snapshot.accountId, 'stable-google-id');
    expect(snapshot.displayName, 'Test User');
  });
}
