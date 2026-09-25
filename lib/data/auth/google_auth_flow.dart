import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class GoogleIdentityTokens {
  const GoogleIdentityTokens({required this.idToken});

  final String? idToken;
}

class GoogleAuthFlowCancelledException implements Exception {
  const GoogleAuthFlowCancelledException();

  @override
  String toString() => 'Google Sign-In was cancelled by the user.';
}

typedef BeginGoogleSignIn = Future<GoogleIdentityTokens?> Function();
typedef FirebaseGoogleSignIn = Future<GoogleSignInResult> Function(
    GoogleIdentityTokens tokens);

/// Platform-independent Google -> Firebase authentication handshake.
///
/// Existing Google users and first-time Google users both use Firebase's
/// credential sign-in API; Firebase decides whether to restore or create
/// the account.
class GoogleAuthFlow {
  const GoogleAuthFlow({
    required this.beginGoogleSignIn,
    required this.signInToFirebase,
  });

  final BeginGoogleSignIn beginGoogleSignIn;
  final FirebaseGoogleSignIn signInToFirebase;

  Future<AppUser> signIn() async => (await signInWithDetails()).user;

  Future<GoogleSignInResult> signInWithDetails() async {
    final tokens = await beginGoogleSignIn();
    if (tokens == null) {
      throw const GoogleAuthFlowCancelledException();
    }
    return signInToFirebase(tokens);
  }
}
