import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';
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
      child: const TestApp(home: AuthGate()),
    ),
  );
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
  await tester.pump();
  await tester.pump();
  await tester.pump();
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

  testWidgets('signing in goes straight to Home with no setup step',
      (tester) async {
    final auth = StreamController<AppUser?>();
    addTearDown(auth.close);

    await _pumpGate(tester, auth);
    await tester.tap(find.text('Get Started'));
    await tester.pump();

    const firstUser = AppUser(id: 'user-a', email: 'a@example.com');
    await _pumpAuthEvent(tester, firstUser, auth);

    expect(find.text('Home').first, findsOneWidget);
    expect(find.text('First-Time Setup'), findsNothing);
  });

  testWidgets('a brand new account also reaches Home directly', (tester) async {
    final auth = StreamController<AppUser?>();
    addTearDown(auth.close);

    await _pumpGate(tester, auth);
    await tester.tap(find.text('Get Started'));
    await tester.pump();

    const firstUser = AppUser(id: 'user-a', email: 'a@example.com');
    const secondUser = AppUser(id: 'user-b', email: 'b@example.com');

    await _pumpAuthEvent(tester, firstUser, auth);
    expect(find.text('Home').first, findsOneWidget);

    // Switching to an account that has never signed in before must not
    // reintroduce a configuration step.
    await _pumpAuthEvent(tester, null, auth);
    await _pumpAuthEvent(tester, secondUser, auth);

    expect(find.text('Home').first, findsOneWidget);
    expect(find.text('First-Time Setup'), findsNothing);
  });

  testWidgets('signing out returns to the welcome entry', (tester) async {
    final auth = StreamController<AppUser?>();
    addTearDown(auth.close);

    await _pumpGate(tester, auth);
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    expect(find.text('Continue with Google'), findsOneWidget);

    await _pumpAuthEvent(
      tester,
      const AppUser(id: 'user-a', email: 'a@example.com'),
      auth,
    );
    expect(find.text('Home').first, findsOneWidget);

    await _pumpAuthEvent(tester, null, auth);
    expect(find.text('Get Started'), findsOneWidget);
  });

  test('Firestore rules enforce authenticated UID ownership for users data',
      () async {
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
