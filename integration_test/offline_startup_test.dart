import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:qaza_namaz/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'cold-starts successfully while Android is offline',
    (tester) async {
      app.main();

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(const Duration(seconds: 8));

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.textContaining('Qaza'), findsWidgets);
    },
  );
}
