import 'package:flutter/material.dart';

import 'features/auth/auth_gate.dart';

class QazaNamazApp extends StatelessWidget {
  QazaNamazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qaza Namaz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: FirebaseAuthGate(),
    );
  }
}
