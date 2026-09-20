import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides one consistent Flutter/platform test environment for every test
/// file, including pure unit tests that exercise platform-backed services.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Sync cursors use SharedPreferences. Reset the mock store before every
  // test so cursor state can never leak between test cases.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  await testMain();
}
