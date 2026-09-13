import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/auth/firebase_auth_repository.dart';
import '../../data/repositories/firestore_qaza_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../ui/onboarding_ui.dart';
import '../ui/workspace_v2.dart';
import 'authentication_screen.dart';

class AuthGate extends StatefulWidget {
  AuthGate({required this.themeMode, required this.onThemeModeChanged, AuthRepository? authRepository, QazaRepository? qazaRepository, super.key})
      : authRepository = authRepository ?? FirebaseAuthRepository(),
        qazaRepository = qazaRepository ?? FirestoreQazaRepository();

  final AuthRepository authRepository;
  final QazaRepository qazaRepository;
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool showWelcome = true;
  bool showSetup = false;
  bool setupRequested = false;
  bool splash = true;
  Timer? splashTimer;

  @override
  void initState() {
    super.initState();
    splashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => splash = false);
    });
  }

  @override
  void dispose() {
    splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (splash) return const SplashScreen();
    return StreamBuilder<AppUser?>(
      stream: widget.authRepository.authStateChanges(),
      initialData: widget.authRepository.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SplashScreen();
        }
        final user = snapshot.data;
        if (user == null) {
          if (showWelcome) {
            return WelcomeScreen(onGetStarted: () => setState(() => showWelcome = false));
          }
          return AuthenticationScreen(onGoogleSignIn: widget.authRepository.signInWithGoogle);
        }
        if (!setupRequested) {
          setupRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => showSetup = true);
          });
        }
        if (showSetup) {
          return FirstTimeSetupScreen(
            onDone: () => setState(() => showSetup = false),
            onThemeModeChanged: (mode) {
              switch (mode) {
                case ThemeMode.system:
                  widget.onThemeModeChanged(AppThemeMode.system);
                  break;
                case ThemeMode.light:
                  widget.onThemeModeChanged(AppThemeMode.light);
                  break;
                case ThemeMode.dark:
                  widget.onThemeModeChanged(AppThemeMode.dark);
                  break;
              }
            },
          );
        }
        return WorkspaceShellV2(
          userId: user.id,
          repository: widget.qazaRepository,
          onSignOut: widget.authRepository.signOut,
        );
      },
    );
  }
}
