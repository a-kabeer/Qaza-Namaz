import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';

/// Root widget.
///
/// Owns nothing but the [MaterialApp] shell: the active theme mode comes from
/// [themeModeProvider] and the session is resolved inside [AuthGate], so
/// repositories, theme callbacks and user ids are no longer threaded down
/// through widget constructors.
class QazaNamazApp extends ConsumerWidget {
  const QazaNamazApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Qaza Namaz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider).materialMode,
      home: const AuthGate(),
    );
  }
}
