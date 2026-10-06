import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/remote/firebase_services.dart';

class _ControlledFirebaseServices extends FirebaseServices {
  _ControlledFirebaseServices(this.initializer);

  final Completer<bool> initializer;

  @override
  Future<bool> initialize() => initializer.future;
}

void main() {
  test(
    'lightweight authentication owns the shared auth gate and blocks interactive auth',
    () async {
      final initializer = Completer<bool>();
      final firebase = _ControlledFirebaseServices(initializer);
      final service = GoogleFirebaseAuthService(firebase);

      final lightweight = service.attemptLightweightAuthentication(
        timeout: const Duration(seconds: 1),
      );

      await Future<void>.delayed(Duration.zero);

      expect(
        () => service.signIn(),
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
    },
  );

  test(
    'interactive authentication owns the shared auth gate until the operation completes',
    () async {
      final initializer = Completer<bool>();
      final firebase = _ControlledFirebaseServices(initializer);
      final service = GoogleFirebaseAuthService(firebase);

      final interactive = service.signIn();

      await Future<void>.delayed(Duration.zero);

      expect(
        () => service.attemptLightweightAuthentication(),
        returnsNormally,
      );

      initializer.complete(false);

      await expectLater(interactive, throwsA(isA<StateError>()));
    },
  );
}
