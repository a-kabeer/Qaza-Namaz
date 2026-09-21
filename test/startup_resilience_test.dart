import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';
import 'package:qaza_namaz/features/auth/auth_gate.dart';
import 'package:qaza_namaz/features/auth/guest_upgrade_controller.dart';
import 'package:qaza_namaz/features/onboarding/splash_screen.dart';
import 'package:qaza_namaz/features/onboarding/welcome_screen.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

/// An auth backend whose first emission can be withheld indefinitely.
///
/// This is the release-build condition the app hung on: Firebase Auth never
/// produced an initial event, so everything waiting on it waited forever.
class _SilentAuthRepository implements AuthRepository {
  _SilentAuthRepository({this.emit = false});

  /// When false, `authStateChanges()` never yields anything at all.
  final bool emit;
  final _controller = StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> authStateChanges() async* {
    if (emit) yield null;
    yield* _controller.stream;
  }

  @override
  Future<AppUser> signInWithGoogle() async =>
      throw UnimplementedError('not part of this test');

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _controller.close();
}

/// Startup must always end somewhere the user can act.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('an auth stream that never emits', () {
    ProviderContainer container(_SilentAuthRepository auth) {
      final result = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
        // The real wait is five seconds; the rule under test is that there
        // is one at all.
        startupAuthTimeoutProvider
            .overrideWithValue(const Duration(milliseconds: 50)),
      ]);
      addTearDown(result.dispose);
      addTearDown(auth.dispose);
      return result;
    }

    test('restoration finishes anyway, instead of pinning the splash',
        () async {
      final auth = _SilentAuthRepository();
      final scope = container(auth);
      scope.listen(guestUpgradeControllerProvider, (_, __) {});

      expect(
        scope.read(guestUpgradeControllerProvider).restoring,
        isTrue,
        reason: 'restoration starts before the first frame',
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // The defect: this stayed true forever, and AuthGate shows the splash
      // screen for exactly as long as it is true.
      expect(scope.read(guestUpgradeControllerProvider).restoring, isFalse);
    });

    test('a stream that does emit is not made to wait for the timeout',
        () async {
      final auth = _SilentAuthRepository(emit: true);
      final scope = container(auth);
      scope.listen(guestUpgradeControllerProvider, (_, __) {});

      // Well inside the 50ms stop: this has to finish on the emission.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(scope.read(guestUpgradeControllerProvider).restoring, isFalse);
    });
  });

  group('AuthGate', () {
    Future<_SilentAuthRepository> pumpGate(WidgetTester tester,
        {required bool emit}) async {
      final auth = _SilentAuthRepository(emit: emit);
      addTearDown(auth.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
          startupAuthTimeoutProvider
              .overrideWithValue(const Duration(milliseconds: 50)),
        ],
        child: const TestApp(home: AuthGate()),
      ));
      return auth;
    }

    testWidgets('does not sit on the splash screen forever', (tester) async {
      await pumpGate(tester, emit: false);

      // The brand moment is still shown.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Past the startup deadline the app renders what it knows: nobody is
      // signed in, so the way in is offered.
      await tester.pump(AuthGate.startupDeadline);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
          find.byKey(const Key('welcome_continue_as_guest')), findsOneWidget);
    });

    testWidgets('reaches the same place promptly when auth does emit',
        (tester) async {
      await pumpGate(tester, emit: true);

      await tester.pump(AuthGate.splashDuration);
      await tester.pump(const Duration(milliseconds: 100));

      // No deadline needed: the stream answered.
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });
}
