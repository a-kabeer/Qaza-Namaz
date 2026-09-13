import 'package:flutter/material.dart';

import 'data/auth/firebase_auth_repository.dart';
import 'data/repositories/firestore_qaza_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/qaza_repository.dart';
import 'features/auth/auth_gate.dart';

class QazaNamazApp extends StatelessWidget {
  QazaNamazApp({
    AuthRepository? authRepository,
    QazaRepository? qazaRepository,
    super.key,
  })  : authRepository = authRepository ?? FirebaseAuthRepository(),
        qazaRepository = qazaRepository ?? FirestoreQazaRepository();

  final AuthRepository authRepository;
  final QazaRepository qazaRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qaza Namaz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: AuthGate(
        authRepository: authRepository,
        qazaRepository: qazaRepository,
      ),
    );
  }
}
