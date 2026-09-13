import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/auth/firebase_auth_repository.dart';
import '../../data/repositories/firestore_qaza_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../ui/final_ui.dart';
import '../ui/onboarding_ui.dart';

class AuthGate extends StatefulWidget {
  AuthGate({required this.themeMode, required this.onThemeModeChanged, AuthRepository? authRepository, QazaRepository? qazaRepository, super.key})
      : authRepository = authRepository ?? FirebaseAuthRepository(),
        qazaRepository = qazaRepository ?? FirestoreQazaRepository();
  final AuthRepository authRepository;
  final QazaRepository qazaRepository;
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  @override State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool showWelcome = true;
  bool showSetup = false;
  Timer? splashTimer;
  bool splash = true;
  @override void initState(){super.initState();splashTimer=Timer(const Duration(milliseconds:700),(){if(mounted)setState(()=>splash=false);});}
  @override void dispose(){splashTimer?.cancel();super.dispose();}
  @override Widget build(BuildContext context){
    if(splash)return const SplashScreen();
    return StreamBuilder<AppUser?>(stream:widget.authRepository.authStateChanges(),initialData:widget.authRepository.currentUser,builder:(context,snapshot){
      if(snapshot.connectionState==ConnectionState.waiting&&!snapshot.hasData)return const SplashScreen();
      final user=snapshot.data;
      if(user==null){if(showSetup)setState(()=>showSetup=false);return showWelcome?WelcomeScreen(onGetStarted:()=>setState(()=>showWelcome=false)):FinalAuthPage(onGoogleSignIn:widget.authRepository.signInWithGoogle);}
      if(showSetup)return FirstTimeSetupScreen(onDone:()=>setState(()=>showSetup=false));
      return FinalAppShell(userId:user.id,repository:widget.qazaRepository,onSignOut:widget.authRepository.signOut,themeMode:widget.themeMode,onThemeModeChanged:widget.onThemeModeChanged);
    });
  }
}
