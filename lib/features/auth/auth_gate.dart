import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../onboarding/onboarding_screens.dart';
import '../shell/workspace_shell.dart';
import 'authentication_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  static const _setupCompleteKey = 'qaza_first_time_setup_complete';

  bool showWelcome = true;
  bool showSetup = false;
  bool setupRequested = false;
  bool setupComplete = false;
  bool splash = true;
  Timer? splashTimer;

  @override
  void initState() {
    super.initState();
    splashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => splash = false);
    });
    _loadSetupState();
  }

  Future<void> _loadSetupState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => setupComplete = prefs.getBool(_setupCompleteKey) ?? false);
  }

  Future<void> _finishSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, true);
    if (mounted) setState(() {
      setupComplete = true;
      showSetup = false;
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
      return const AuthenticationScreen();
    }

    if (!setupComplete && !setupRequested) {
      setupRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !setupComplete) setState(() => showSetup = true);
      });
    }
    if (showSetup) {
      return FirstTimeSetupScreen(onDone: _finishSetup);
    }

    return const WorkspaceShell();
  }
}
