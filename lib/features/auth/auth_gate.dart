import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/auth/firebase_auth_repository.dart';
import '../../data/repositories/firestore_qaza_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../home/home_page.dart';

class AuthGate extends StatelessWidget {
  AuthGate({required this.themeMode, required this.onThemeModeChanged, AuthRepository? authRepository, QazaRepository? qazaRepository, super.key})
      : authRepository = authRepository ?? FirebaseAuthRepository(),
        qazaRepository = qazaRepository ?? FirestoreQazaRepository();

  final AuthRepository authRepository;
  final QazaRepository qazaRepository;
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: authRepository.authStateChanges(),
      initialData: authRepository.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) return _SignInPage(authRepository: authRepository);
        return HomePage(
          userId: user.id,
          repository: qazaRepository,
          onSignOut: authRepository.signOut,
          themeMode: themeMode,
          onThemeModeChanged: onThemeModeChanged,
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
    setState(() { _signingIn = true; _errorMessage = null; });
    try {
      await widget.authRepository.signInWithGoogle();
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Google Sign-In failed. Please try again.');
    }
    if (mounted) setState(() => _signingIn = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.mosque_rounded, size: 34, color: cs.primary)),
      const SizedBox(height: 20),
      Text('Qaza Namaz', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('A calm, private ledger for completing missed prayers.', textAlign: TextAlign.center),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _signingIn ? null : _signIn, icon: _signingIn ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: Text(_signingIn ? 'Signing in...' : 'Continue with Google'))),
      if (_errorMessage != null) ...[const SizedBox(height: 16), Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red))],
    ]))))));
  }
}
