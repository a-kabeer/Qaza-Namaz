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
  final GlobalKey<NavigatorState> _authNavigatorKey =
      GlobalKey<NavigatorState>();
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

  void _openAuthentication() {
    _authNavigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AuthenticationScreen(),
      ),
    );
  }

  Route<void> _authenticationRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const AuthenticationScreen(),
    );
  }

  Route<void> _welcomeRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => WelcomeScreen(
        onGetStarted: _openAuthentication,
        onContinueAsGuest: () =>
            ref.read(guestSessionProvider.notifier).start(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (splash) return const SplashScreen();

    final auth = ref.watch(authStateProvider);
    final upgrade = ref.watch(guestUpgradeControllerProvider);
    final isGuest = ref.watch(guestSessionProvider);

    if (auth.isLoading && !auth.hasValue) return const SplashScreen();
    if (upgrade.restoring) return const SplashScreen();

    final user = auth.valueOrNull;

    // Firebase can become authenticated before the guest data decision is
    // complete. Keep the user on the auth/decision surface until that state is
    // resolved rather than entering the account workspace early.
    if (upgrade.running ||
        upgrade.awaitingDecision ||
        (upgrade.error != null && isGuest)) {
      // The navigator remains the single source of truth for pre-auth
      // navigation. These states are normally reached from Authentication,
      // but persisted guest-upgrade decisions can also start here.
      wasSignedIn = user != null || wasSignedIn;
      final navigator = Navigator(
        key: _authNavigatorKey,
        initialRoute: '/authentication',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/authentication':
              return _authenticationRoute(settings);
            case '/welcome':
              return _welcomeRoute(settings);
            default:
              return _authenticationRoute(
                const RouteSettings(name: '/authentication'),
              );
          }
        },
      );

      return NavigatorPopHandler<void>(
        enabled: !upgrade.running,
        onPopWithResult: (result) {
          unawaited(
            _authNavigatorKey.currentState?.maybePop(result) ??
                Future<bool>.value(false),
          );
        },
        child: navigator,
      );
    }

    // A guest reaches the workspace on the same footing as an account: the
    // ledger is local, but every screen works.
    if (user == null && isGuest) {
      wasSignedIn = false;
      return const WorkspaceShell();
    }

    if (user == null) {
      // Signing out returns to the welcome entry. Because the authenticated
      // workspace is rendered outside this pre-auth Navigator, signing out
      // creates a fresh navigator whose initial route is Welcome.
      wasSignedIn = false;
      return NavigatorPopHandler<void>(
        onPopWithResult: (result) {
          unawaited(
            _authNavigatorKey.currentState?.maybePop(result) ??
                Future<bool>.value(false),
          );
        },
        child: Navigator(
          key: _authNavigatorKey,
          initialRoute: '/welcome',
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/welcome':
                return _welcomeRoute(settings);
              case '/authentication':
                return _authenticationRoute(settings);
              default:
                return _welcomeRoute(
                  const RouteSettings(name: '/welcome'),
                );
            }
          },
        ),
      );
    }

    wasSignedIn = true;
    return const WorkspaceShell();
  }
}
