import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';
import 'package:qaza_namaz/features/auth/auth_gate.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

class StartupAuthRepository implements AuthRepository {
  StartupAuthRepository(this.account, {this.signInFailure});

  final AppUser account;
  final controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;
  final Object? signInFailure;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* controller.stream;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    if (signInFailure != null) throw signInFailure!;
    _current = account;
    controller.add(account);
    return account;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    controller.add(null);
  }

  Future<void> dispose() => controller.close();
}

Future<void> pumpStartup(
  WidgetTester tester,
  AppUser account,
  StartupAuthRepository auth,
) async {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
      ],
      child: const TestApp(home: AuthGate()),
    ),
  );

  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('startup Google sign-in restores an existing account',
      (tester) async {
    final auth = StartupAuthRepository(
      const AppUser(id: 'existing-user', email: 'existing@example.com'),
    );
    addTearDown(auth.dispose);

    await pumpStartup(tester, auth.account, auth);
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceShell), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('startup Google failure shows the real diagnostic', (tester) async {
    final auth = StartupAuthRepository(
      const AppUser(id: 'failed-user', email: 'failed@example.com'),
      signInFailure: StateError('firebase-auth/operation-not-allowed'),
    );
    addTearDown(auth.dispose);

    await pumpStartup(tester, auth.account, auth);
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('firebase-auth/operation-not-allowed'),
        findsOneWidget);
  });

  testWidgets('startup Google sign-in creates a new account through Firebase',
      (tester) async {
    final auth = StartupAuthRepository(
      const AppUser(id: 'new-user', email: 'new@example.com'),
    );
    addTearDown(auth.dispose);

    await pumpStartup(tester, auth.account, auth);
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceShell), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });
}

// CI verification marker.
