import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/remote/firebase_services.dart';

// Regression coverage for split Google/Firebase authentication initialization.
class _ControlledFirebaseServices extends FirebaseServices {
  _ControlledFirebaseServices(this.initializer);

  final Completer<bool> initializer;

  @override
  Future<bool> initializeAuthentication() => initializer.future;

  @override
  Future<bool> initializeFirebaseCore() => initializer.future;

  @override
  Future<bool> initializeGoogleSignIn() => initializer.future;
}

void main() {
  test('lightweight authentication owns the shared auth gate and blocks interactive auth', () async {
    final initializer = Completer<bool>();
    final firebase = _ControlledFirebaseServices(initializer);
    final lightweightService = GoogleFirebaseAuthService(firebase);
    final interactiveService = GoogleFirebaseAuthService(firebase);

    final lightweight = lightweightService.attemptLightweightAuthentication(
      timeout: const Duration(seconds: 1),
    );

    await Future<void>.delayed(Duration.zero);

    await expectLater(
      interactiveService.signIn(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('already in progress'),
        ),
      ),
    );

    initializer.complete(false);
    expect(await lightweight, isNull);
  });

  test('interactive authentication owns the shared auth gate until the operation completes', () async {
    final initializer = Completer<bool>();
    final firebase = _ControlledFirebaseServices(initializer);
    final interactiveService = GoogleFirebaseAuthService(firebase);
    final lightweightService = GoogleFirebaseAuthService(firebase);

    final interactive = interactiveService.signIn();

    await Future<void>.delayed(Duration.zero);

    expect(await lightweightService.attemptLightweightAuthentication(), isNull);

    initializer.complete(false);

    await expectLater(interactive, throwsA(isA<StateError>()));
  });
}
