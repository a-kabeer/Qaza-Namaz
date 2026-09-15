import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../ui/onboarding_ui.dart';
import '../ui/workspace_v2.dart';
import 'authentication_screen.dart';

/// Resolves the current session and renders the matching surface: splash,
/// onboarding, sign-in, first-time setup, or the workspace.
///
/// The session itself lives in [authStateProvider], and the offline cache
/// namespace is kept in step by [qazaRepositoryProvider], so this widget only
/// decides *what* to show.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
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

    final auth = ref.watch(authStateProvider);
    if (auth.isLoading && !auth.hasValue) return const SplashScreen();

    if (auth.valueOrNull == null) {
      if (showWelcome) {
        return WelcomeScreen(
          onGetStarted: () => setState(() => showWelcome = false),
        );
      }
      return AuthenticationScreen(
        onGoogleSignIn: ref.read(authRepositoryProvider).signInWithGoogle,
      );
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
        onThemeModeChanged: (mode) => ref
            .read(themeModeProvider.notifier)
            .set(switch (mode) {
          ThemeMode.light => AppThemeMode.light,
          ThemeMode.dark => AppThemeMode.dark,
          ThemeMode.system => AppThemeMode.system,
        }),
      );
    }

    return const WorkspaceShellV2();
  }
}
