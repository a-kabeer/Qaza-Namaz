import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../onboarding/splash_screen.dart';
import '../settings/app_lock_gate.dart';
import '../onboarding/welcome_screen.dart';
import '../prayer_times/presentation/prayer_times_setup_prompt.dart';
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

  /// The deliberate brand moment at launch.
  static const Duration splashDuration = Duration(milliseconds: 700);

  /// The point after which the splash is no longer allowed to be the answer.
  ///
  /// Startup waits on state that can, on a misconfigured release build, never
  /// arrive. Past this deadline the app renders whatever it knows — an
  /// unresolved account is treated as signed out — rather than showing a
  /// splash screen indefinitely, which reads as a frozen app.
  static const Duration startupDeadline = Duration(seconds: 8);

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final GlobalKey<NavigatorState> _authNavigatorKey =
      GlobalKey<NavigatorState>();
  bool splash = true;
  bool startupOverdue = false;
  Timer? splashTimer;
  Timer? startupTimer;

  @override
  void initState() {
    super.initState();
    splashTimer = Timer(AuthGate.splashDuration, () {
      if (mounted) setState(() => splash = false);
    });
    startupTimer = Timer(AuthGate.startupDeadline, () {
      if (mounted) setState(() => startupOverdue = true);
    });
  }

  @override
  void dispose() {
    splashTimer?.cancel();
    startupTimer?.cancel();
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

  Widget _buildAuthFlowNavigator({
    required String initialRoute,
    required bool backEnabled,
  }) {
    final navigator = Navigator(
      key: _authNavigatorKey,
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/authentication':
            return _authenticationRoute(settings);
          case '/welcome':
            return _welcomeRoute(settings);
          default:
            return initialRoute == '/authentication'
                ? _authenticationRoute(
                    const RouteSettings(name: '/authentication'),
                  )
                : _welcomeRoute(
                    const RouteSettings(name: '/welcome'),
                  );
        }
      },
    );

    if (!backEnabled) {
      return PopScope<void>(
        canPop: false,
        child: navigator,
      );
    }

    return NavigatorPopHandler<void>(
      onPopWithResult: (_) {
        _authNavigatorKey.currentState?.pop();
      },
      child: navigator,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (splash) return const SplashScreen();

    final auth = ref.watch(authStateProvider);
    final upgrade = ref.watch(guestUpgradeControllerProvider);
    final isGuest = ref.watch(guestSessionProvider);

    if (!startupOverdue) {
      if (auth.isLoading && !auth.hasValue) return const SplashScreen();
      if (upgrade.restoring) return const SplashScreen();
    }

    final user = auth.valueOrNull;

    // Firebase can become authenticated before the guest data decision is
    // complete. Keep the user on the auth/decision surface until that state is
    // resolved rather than entering the account workspace early.
    if (upgrade.running ||
        upgrade.awaitingDecision ||
        (upgrade.error != null && isGuest)) {
      // Keep this as the same pre-auth Navigator used by the Welcome route.
      // If the transition started from Welcome, the Authentication route was
      // already pushed and remains intact across this auth-state rebuild.
      // Persisted guest-upgrade decisions start directly on Authentication.
      return _buildAuthFlowNavigator(
        initialRoute: '/authentication',
        backEnabled: !upgrade.running,
      );
    }

    // A guest reaches the workspace on the same footing as an account: the
    // ledger is local, but every screen works.
    if (user == null && isGuest) {
      return const AppLockGate(
        child: PrayerTimesSetupPromptGate(child: WorkspaceShell()),
      );
    }

    if (user == null) {
      // The pre-auth Navigator owns Welcome -> Authentication navigation.
      // Authentication is pushed as a real route, so AppBar Back, Android
      // system Back, Android predictive Back, and supported iOS back-swipe
      // behavior all operate on the same route history.
      return _buildAuthFlowNavigator(
        initialRoute: '/welcome',
        backEnabled: true,
      );
    }

    return const AppLockGate(child: WorkspaceShell());
  }
}
