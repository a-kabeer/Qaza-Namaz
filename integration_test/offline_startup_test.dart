import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:qaza_namaz/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'cold-starts successfully while Android is offline',
    (tester) async {
      await app.main();

      // Do not use pumpAndSettle here. The application may intentionally show
      // an indeterminate startup indicator while local initialization completes,
      // and pumpAndSettle would wait forever for that ticker.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 5));

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.textContaining('Qaza'), findsWidgets);
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
