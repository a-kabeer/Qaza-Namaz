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
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('signed-out state shows authentication entry', (tester) async {
    final auth = StreamController<AppUser?>();
    addTearDown(auth.close);

    await _pumpGate(tester, auth);
    auth.add(null);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('setup completion is isolated per authenticated account', (tester) async {
    final auth = StreamController<AppUser?>();
    addTearDown(auth.close);

    await _pumpGate(tester, auth);

    const firstUser = AppUser(id: 'user-a', email: 'a@example.com');
    const secondUser = AppUser(id: 'user-b', email: 'b@example.com');

    auth.add(firstUser);
    await tester.pumpAndSettle();
    expect(find.text('First-Time Setup'), findsOneWidget);

    await tester.tap(find.text('Start Tracking'));
    await tester.pumpAndSettle();
    expect(find.text('Qaza Namaz'), findsWidgets);

    auth.add(null);
    await tester.pumpAndSettle();
    auth.add(secondUser);
    await tester.pumpAndSettle();

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
