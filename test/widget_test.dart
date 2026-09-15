import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  AppUser? get currentUser => null;
  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(null);
  @override
  Future<AppUser> signInWithGoogle() async => const AppUser(id: 'test-user', email: 'test@example.com');
  @override
  Future<void> signOut() async {}
}

Future<void> _openAuth(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
      ],
      child: const QazaNamazApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Get Started'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Signed-out onboarding opens connected Google authentication entry', (WidgetTester tester) async {
    await _openAuth(tester);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Google is the currently connected authentication provider. Sign-in status is restored automatically from Firebase.'), findsOneWidget);
  });

  testWidgets('Authentication help explains the connected sign-in method', (WidgetTester tester) async {
    await _openAuth(tester);
    await tester.tap(find.byTooltip('Authentication help'));
    await tester.pumpAndSettle();
    expect(find.text('Authentication'), findsOneWidget);
    expect(find.textContaining('Google Sign-In is the connected authentication method'), findsOneWidget);
    expect(find.byType(CloseButton), findsOneWidget);
  });
}
