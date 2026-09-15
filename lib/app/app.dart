import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_gate.dart';

/// Root widget for the application shell.
class QazaNamazApp extends ConsumerWidget {
  const QazaNamazApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: 'Qaza Namaz',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ref.watch(themeModeProvider).materialMode,
        home: const AuthGate(),
      );
}
