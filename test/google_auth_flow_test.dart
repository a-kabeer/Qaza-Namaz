import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/auth/google_auth_flow.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';

void main() {
  test('existing Google account signs in through Firebase handshake', () async {
    const expected =
        AppUser(id: 'existing-user', email: 'existing@example.com');
    String? receivedToken;

    final flow = GoogleAuthFlow(
      beginGoogleSignIn: () async =>
          const GoogleIdentityTokens(idToken: 'existing-token'),
      signInToFirebase: (tokens) async {
        receivedToken = tokens.idToken;
        return const GoogleSignInResult(user: expected, isNewUser: false);
      },
    );

    expect(await flow.signIn(), expected);
    expect(receivedToken, 'existing-token');
  });

  test('new Google account follows the same credential path', () async {
    const created = AppUser(id: 'new-user', email: 'new@example.com');

    final flow = GoogleAuthFlow(
      beginGoogleSignIn: () async =>
          const GoogleIdentityTokens(idToken: 'new-token'),
      signInToFirebase: (_) async =>
          const GoogleSignInResult(user: created, isNewUser: true),
    );

    expect(await flow.signIn(), created);
  });

  test('Google cancellation is surfaced as a distinct cancellation error',
      () async {
    final flow = GoogleAuthFlow(
      beginGoogleSignIn: () async => null,
      signInToFirebase: (_) async => const GoogleSignInResult(
          user: AppUser(id: 'unused', email: 'unused@example.com'),
          isNewUser: false,
        ),
    );

    expect(
      flow.signIn,
      throwsA(isA<GoogleAuthFlowCancelledException>()),
    );
  });

  test('Firebase/platform failures are allowed to propagate through the flow',
      () async {
    final failure = StateError('operation-not-allowed');

    final flow = GoogleAuthFlow(
      beginGoogleSignIn: () async =>
          const GoogleIdentityTokens(idToken: 'token'),
      signInToFirebase: (_) async => throw failure,
    );

    expect(flow.signIn, throwsA(same(failure)));
  });
}
