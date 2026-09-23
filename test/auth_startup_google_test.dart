import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';
import 'package:qaza_namaz/features/auth/auth_gate.dart';
import 'package:qaza_namaz/features/auth/authentication_screen.dart';
import 'package:qaza_namaz/features/onboarding/welcome_screen.dart';
import 'package:qaza_namaz/features/prayer_times/presentation/prayer_times_setup_prompt.dart';
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

  testWidgets('shows prayer-time setup after account entry', (tester) async {
    final auth = StartupAuthRepository(
      const AppUser(id: 'setup-user', email: 'setup@example.com'),
    );
    addTearDown(auth.dispose);

    await pumpStartup(tester, auth.account, auth);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceShell), findsOneWidget);
    expect(
      find.byKey(const Key('prayer_times_setup_prompt')),
      findsOneWidget,
    );
    expect(find.text('Set up prayer times'), findsOneWidget);
    expect(find.text('Use My Location'), findsOneWidget);
    expect(find.text('Choose City'), findsOneWidget);
    expect(find.text('Not Now'), findsOneWidget);
  });

  testWidgets('startup Google failure shows the real diagnostic',
      (tester) async {
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

  group('authentication back navigation', () {
    Future<StartupAuthRepository> pumpUnauthenticated(
      WidgetTester tester,
    ) async {
      final auth = StartupAuthRepository(
        const AppUser(id: 'back-test-user', email: 'back@example.com'),
      );
      addTearDown(auth.dispose);

      await pumpStartup(tester, auth.account, auth);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      return auth;
    }

    testWidgets(
      'Get Started opens Authentication as a real route and AppBar Back returns to Welcome',
      (tester) async {
        await pumpUnauthenticated(tester);

        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();

        expect(find.byType(AuthenticationScreen), findsOneWidget);
        expect(find.byType(WelcomeScreen), findsNothing);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(find.byType(AuthenticationScreen), findsNothing);
      },
    );

    testWidgets(
      'Android system Back pops Authentication and returns to Welcome',
      (tester) async {
        await pumpUnauthenticated(tester);

        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();
        expect(find.byType(AuthenticationScreen), findsOneWidget);

        final handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(handled, isTrue);
        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(find.byType(AuthenticationScreen), findsNothing);
      },
    );

    testWidgets(
      'Already have an account opens the same Authentication route and Back works',
      (tester) async {
        await pumpUnauthenticated(tester);

        await tester.tap(find.text('Already have an account? Sign In'));
        await tester.pumpAndSettle();

        expect(find.byType(AuthenticationScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        expect(find.byType(WelcomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Authentication can be opened again after returning to Welcome',
      (tester) async {
        await pumpUnauthenticated(tester);

        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();
        expect(find.byType(AuthenticationScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(WelcomeScreen), findsOneWidget);

        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();
        expect(find.byType(AuthenticationScreen), findsOneWidget);
      },
    );
  });

}
