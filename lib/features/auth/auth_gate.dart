import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../onboarding/first_time_setup_screen.dart';
import '../onboarding/splash_screen.dart';
import '../onboarding/welcome_screen.dart';
import '../shell/workspace_shell.dart';
import 'authentication_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  static const _setupCompleteKeyPrefix = 'qaza_first_time_setup_complete_';

  bool showWelcome = true;
  bool showSetup = false;
  bool setupRequested = false;
  bool setupComplete = false;
  bool setupLoading = true;
  String? setupUserId;
  bool splash = true;
  Timer? splashTimer;

  @override
  void initState() {
    super.initState();
    splashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => splash = false);
    });
  }

  Future<void> _loadSetupState(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool('$_setupCompleteKeyPrefix$userId') ?? false;
    if (!mounted) return;
    setState(() {
      setupUserId = userId;
      setupComplete = complete;
      setupLoading = false;
      setupRequested = false;
      showSetup = false;
    });
  }

  Future<void> _finishSetup(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_setupCompleteKeyPrefix$userId', true);
    if (!mounted || setupUserId != userId) return;
    setState(() {
      setupComplete = true;
      showSetup = false;
    });
  }

  void _resetSetupState() {
    if (!mounted) return;
    setState(() {
      setupUserId = null;
      setupComplete = false;
      setupLoading = true;
      setupRequested = false;
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

    final user = auth.valueOrNull;
    if (user == null) {
      if (setupUserId != null || !setupLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _resetSetupState());
      }
      if (showWelcome) {
        return WelcomeScreen(
          onGetStarted: () => setState(() => showWelcome = false),
        );
      }
      return const AuthenticationScreen();
    }

    if (setupUserId != user.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && setupUserId != user.id) {
          _loadSetupState(user.id);
        }
      });
      return const SplashScreen();
    }

    if (setupLoading) return const SplashScreen();

    if (!setupComplete && !setupRequested) {
      setupRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && setupUserId == user.id && !setupComplete) {
          setState(() => showSetup = true);
        }
      });
    }
    if (showSetup) {
      return FirstTimeSetupScreen(
        onDone: () => _finishSetup(user.id),
      );
    }

    return const WorkspaceShell();
  }
}
