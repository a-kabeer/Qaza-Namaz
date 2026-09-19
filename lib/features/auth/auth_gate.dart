import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../onboarding/splash_screen.dart';
import '../onboarding/welcome_screen.dart';
import '../shell/workspace_shell.dart';
import 'authentication_screen.dart';
import 'guest_session.dart';
import 'guest_upgrade_controller.dart';

/// Decides what the app shows at startup.
///
/// The journey is deliberately short:
///
/// ```text
/// Splash -> Google authentication -> guest decision (when needed) -> Home
/// ```
///
/// There is no configuration step in the way. Theme defaults to System and
/// language to English, both persisted and both changeable at any time from
/// Settings, so a new account reaches Home immediately after signing in.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool showWelcome = true;
  bool splash = true;
  bool wasSignedIn = false;
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
    final upgrade = ref.watch(guestUpgradeControllerProvider);
    if (auth.isLoading && !auth.hasValue) return const SplashScreen();
    if (upgrade.restoring) return const SplashScreen();

    final user = auth.valueOrNull;

    // Firebase can become authenticated before the guest data decision is
    // complete. Keep the user on the auth/decision surface until that state is
    // resolved rather than entering the account workspace early.
    if (upgrade.running ||
        upgrade.awaitingDecision ||
        (upgrade.error != null && ref.watch(guestSessionProvider))) {
      return const AuthenticationScreen();
    }
    // A guest reaches the workspace on the same footing as an account: the
    // ledger is local, but every screen works.
    if (user == null && ref.watch(guestSessionProvider)) {
      return const WorkspaceShell();
    }

    if (user == null) {
      // Signing out returns to the welcome entry. This only fires on the
      // signed-in -> signed-out transition, so tapping "Get Started" and then
      // sitting on the sign-in screen is never bounced backwards.
      if (wasSignedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(authStateProvider).valueOrNull == null) {
            setState(() {
              wasSignedIn = false;
              showWelcome = true;
            });
          }
        });
      }
      return showWelcome
          ? WelcomeScreen(
              onGetStarted: () => setState(() => showWelcome = false),
              onContinueAsGuest: () =>
                  ref.read(guestSessionProvider.notifier).start(),
            )
          : const AuthenticationScreen();
    }

    wasSignedIn = true;
    return const WorkspaceShell();
  }
}
