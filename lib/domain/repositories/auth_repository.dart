import '../entities/app_user.dart';

class GoogleSignInResult {
  const GoogleSignInResult({
    required this.user,
    required this.isNewUser,
  });

  final AppUser user;
  final bool isNewUser;
}

abstract interface class DetailedAuthRepository {
  Future<GoogleSignInResult> signInWithGoogleDetails();
}

abstract interface class AuthRepository {
  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();

  Future<AppUser> signInWithGoogle();

  Future<void> signOut();
}
