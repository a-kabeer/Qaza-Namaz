import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/database/app_database.dart';
import '../data/migration/qaza_database_bootstrap.dart';
import '../firebase_options.dart';

class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  late Future<void> _startupFuture;
  Timer? _slowTimer;
  bool _isTakingLonger = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  void _start() {
    _slowTimer?.cancel();
    _isTakingLonger = false;
    _startupFuture = _initialize();
    _slowTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _isTakingLonger = true);
    });
  }

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // App Check must not hold the entire UI behind the Android launch
      // screen. A Play Integrity/network/device problem is logged and startup
      // continues; Firebase services will surface an actionable error if the
      // backend enforces App Check.
      try {
        await FirebaseAppCheck.instance
            .activate(
              androidProvider: kDebugMode
                  ? AndroidProvider.debug
                  : AndroidProvider.playIntegrity,
            )
            .timeout(const Duration(seconds: 10));
      } on Object catch (error, stack) {
        if (kDebugMode) {
          debugPrint(
            '[startup] Firebase App Check activation failed: '
            '${error.runtimeType}: $error',
          );
          debugPrintStack(stackTrace: stack);
        }
      }

      final database = AppDatabase();
      try {
        final preferences = await SharedPreferences.getInstance();
        await bootstrapQazaDatabase(
          database: database,
          preferences: preferences,
        );
      } finally {
        await database.close();
      }
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint(
          '[startup] initialization failed: '
          '${error.runtimeType}: $error',
        );
        debugPrintStack(stackTrace: stack);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return _StartupError(error: snapshot.error!, onRetry: _start);
          }
          return widget.child;
        }

        return _StartupLoading(isTakingLonger: _isTakingLonger);
      },
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading({required this.isTakingLonger});

  final bool isTakingLonger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Preparing Qaza Namaz…',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTakingLonger
                        ? 'This is taking longer than expected. Your data is safe; please wait a little longer.'
                        : 'Loading your local data and secure services.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Qaza Namaz could not finish starting',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your existing data was not deleted. Please try again. '
                    'If the problem continues, the technical error below '
                    'can help identify the cause.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    '${error.runtimeType}: $error',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
