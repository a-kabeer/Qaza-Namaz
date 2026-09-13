import 'package:flutter/material.dart';

import '../../data/auth/firebase_auth_repository.dart';
import '../../data/repositories/firestore_qaza_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../home/home_page.dart';

class AuthGate extends StatelessWidget {
  AuthGate({
    AuthRepository? authRepository,
    QazaRepository? qazaRepository,
    super.key,
  })  : authRepository = authRepository ?? FirebaseAuthRepository(),
        qazaRepository = qazaRepository ?? FirestoreQazaRepository();

  final AuthRepository authRepository;
  final QazaRepository qazaRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: authRepository.authStateChanges(),
      initialData: authRepository.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return _SignInPage(authRepository: authRepository);
        }

        return HomePage(
          userId: user.id,
          repository: qazaRepository,
          onSignOut: authRepository.signOut,
        );
      },
    );
  }
}

class _SignInPage extends StatefulWidget {
  const _SignInPage({required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  bool _signingIn = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.signInWithGoogle();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Google Sign-In failed. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Qaza Namaz',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sign in with Google to securely sync your Qaza records.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _signingIn ? null : _signIn,
                    icon: _signingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      _signingIn ? 'Signing in...' : 'Continue with Google',
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
