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
  test(
    'startup lightweight authentication blocks interactive authentication until it actually finishes',
    () async {
      final initializer = Completer<bool>();
      final firebase = _ControlledFirebaseServices(initializer);
      final lightweightService = GoogleFirebaseAuthService(firebase);
      final interactiveService = GoogleFirebaseAuthService(firebase);

      final lightweight =
          lightweightService.attemptLightweightAuthentication();
      await Future<void>.delayed(Duration.zero);

      var interactiveCompleted = false;
      final interactive = interactiveService.signIn().whenComplete(() {
        interactiveCompleted = true;
      });

      await Future<void>.delayed(Duration.zero);
      expect(interactiveCompleted, isFalse);

      initializer.complete(false);
      expect(await lightweight, isNull);

      await expectLater(interactive, throwsA(isA<StateError>()));
      expect(interactiveCompleted, isTrue);
    },
  );

  test(
    'interactive authentication remains the single owner until it completes',
    () async {
      final initializer = Completer<bool>();
      final firebase = _ControlledFirebaseServices(initializer);
      final interactiveService = GoogleFirebaseAuthService(firebase);
      final lightweightService = GoogleFirebaseAuthService(firebase);

      final interactive = interactiveService.signIn();
      await Future<void>.delayed(Duration.zero);

      var lightweightCompleted = false;
      final lightweight = lightweightService
          .attemptLightweightAuthentication()
          .whenComplete(() {
        lightweightCompleted = true;
      });

      await Future<void>.delayed(Duration.zero);
      expect(lightweightCompleted, isFalse);

      initializer.complete(false);

      await expectLater(interactive, throwsA(isA<StateError>()));
      expect(await lightweight, isNull);
      expect(lightweightCompleted, isTrue);
    },
  );

  test(
    'a caller timeout does not release the authentication coordinator',
    () async {
      final coordinator = GoogleAuthenticationCoordinator();
      final nativeOperation = Completer<void>();
      var interactiveStarted = false;

      final lightweight = coordinator.run<void>(() async {
        await nativeOperation.future;
      });

      await expectLater(
        lightweight.timeout(const Duration(milliseconds: 20)),
        throwsA(isA<TimeoutException>()),
      );

      expect(coordinator.isBusy, isTrue);

      final interactive = coordinator.run<void>(() async {
        interactiveStarted = true;
      });

      await Future<void>.delayed(Duration.zero);
      expect(interactiveStarted, isFalse);

      nativeOperation.complete();
      await lightweight;
      await interactive;

      expect(interactiveStarted, isTrue);
      expect(coordinator.isBusy, isFalse);
    },
  );
}
