import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/auth/firebase_auth_repository.dart';
import 'data/repositories/firestore_qaza_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/qaza_repository.dart';
import 'features/auth/auth_gate.dart';

class QazaNamazApp extends StatefulWidget {
  QazaNamazApp({AuthRepository? authRepository, QazaRepository? qazaRepository, super.key})
      : authRepository = authRepository ?? FirebaseAuthRepository(),
        qazaRepository = qazaRepository ?? FirestoreQazaRepository();

  final AuthRepository authRepository;
  final QazaRepository qazaRepository;

  @override
  State<QazaNamazApp> createState() => _QazaNamazAppState();
}

class _QazaNamazAppState extends State<QazaNamazApp> {
  AppThemeMode _themeMode = AppThemeMode.system;

  ThemeMode get _materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qaza Namaz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _materialThemeMode,
      home: AuthGate(
        authRepository: widget.authRepository,
        qazaRepository: widget.qazaRepository,
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}
