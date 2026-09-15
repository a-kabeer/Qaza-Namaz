import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';
import 'package:qaza_namaz/features/auth/auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/in_memory_qaza_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._controller);

  final StreamController<AppUser?> _controller;

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  Future<AppUser> signInWithGoogle() async => const AppUser(
        id: 'signed-in-user',
        email: 'user@example.com',
      );

  @override
  Future<void> signOut() async {}
}

Future<void> _pumpGate(
  WidgetTester tester,
  StreamController<AppUser?> auth,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(auth)),
        qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
      ],
      child: const MaterialApp(home: AuthGate()),
    ),
  );
  // Seed the same initial state Firebase Auth provides: signed out.
  auth.add(null);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump();
}

Future<void> _pumpAuthEvent(
  WidgetTester tester,
  AppUser? user,
  StreamController<AppUser?> auth,
) async {
  auth.add(user);
  // An authenticated transition causes AuthGate to schedule setup-state
  // loading in a post-frame callback and then rebuild asynchronously after
  // SharedPreferences completes. Settle all resulting frames before asserting.
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('signed-out state shows authentication entry', (tester) async {
    final auth = StreamController<AppUser?>();
    addTearDown(auth.close);

    await _pumpGate(tester, auth);
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('setup completion is isolated per authenticated account', (tester) async {
    final auth = StreamController<AppUser?>();
    addTearDown(auth.close);

    await _pumpGate(tester, auth);
    await tester.tap(find.text('Get Started'));
    await tester.pump();

    const firstUser = AppUser(id: 'user-a', email: 'a@example.com');
    const secondUser = AppUser(id: 'user-b', email: 'b@example.com');

    await _pumpAuthEvent(tester, firstUser, auth);
    expect(find.text('First-Time Setup'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Start Tracking'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start Tracking'));
    await tester.pump();
    expect(find.text('Qaza Namaz'), findsWidgets);

    await _pumpAuthEvent(tester, null, auth);
    await _pumpAuthEvent(tester, secondUser, auth);

    expect(find.text('First-Time Setup'), findsOneWidget);
  });

  test('Firestore rules enforce authenticated UID ownership for users data', () async {
    final rules = await File('firestore.rules').readAsString();
    expect(rules, contains("request.auth != null"));
    expect(rules, contains("request.auth.uid == userId"));
    expect(
      RegExp(r'allow read, write: if request\.auth != null\s*&&\s*request\.auth\.uid == userId;')
          .hasMatch(rules),
      isTrue,
    );
  });
}
