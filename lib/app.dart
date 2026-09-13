import 'package:flutter/material.dart';

import 'features/home/home_page.dart';

class QazaNamazApp extends StatelessWidget {
  const QazaNamazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qaza Namaz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomePage(),
    );
  }
}
