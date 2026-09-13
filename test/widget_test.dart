import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  final StreamController<AppUser?> _controller = StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(null);

  @override
  Future<AppUser> signInWithGoogle() async => const AppUser(id: 'test-user', email: 'test@example.com');

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _controller.close();
}

Future<void> _openAuth(WidgetTester tester) async {
  await tester.pumpWidget(QazaNamazApp(authRepository: _FakeAuthRepository(), qazaRepository: InMemoryQazaRepository()));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Get Started'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Signed-out onboarding opens complete authentication entry', (WidgetTester tester) async {
    final authRepository = _FakeAuthRepository();
    await tester.pumpWidget(QazaNamazApp(authRepository: authRepository, qazaRepository: InMemoryQazaRepository()));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('Qaza Namaz'), findsOneWidget);
    expect(find.text('Track your missed prayers with clarity and consistency.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Authentication'), findsOneWidget);
    expect(find.text('Sign In'), findsAtLeastNWidgets(1));
    expect(find.text('Create Account'), findsAtLeastNWidgets(1));
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Phone'), findsOneWidget);
    expect(find.text('Continue with WhatsApp'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);

    await authRepository.dispose();
  });

  testWidgets('Create Account exposes confirmation field and switches back to Sign In', (WidgetTester tester) async {
    await _openAuth(tester);
    await tester.tap(find.text('Create Account').first);
    await tester.pumpAndSettle();
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create Account'), findsAtLeastNWidgets(1));
    expect(find.text('Already have an account? '), findsOneWidget);
    expect(find.text('Sign In'), findsAtLeastNWidgets(1));
  });

  testWidgets('Phone verification flow opens and validates code entry', (WidgetTester tester) async {
    await _openAuth(tester);
    await tester.tap(find.text('Continue with Phone'));
    await tester.pumpAndSettle();
    expect(find.text('Phone verification'), findsOneWidget);
    expect(find.text('+92'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '03001234567');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter verification code'), findsOneWidget);
    expect(find.text('6-digit code'), findsOneWidget);

    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 6-digit verification code.'), findsOneWidget);
  });

  testWidgets('WhatsApp verification flow opens', (WidgetTester tester) async {
    await _openAuth(tester);
    await tester.tap(find.text('Continue with WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp verification'), findsOneWidget);
    expect(find.text('Continue with WhatsApp'), findsOneWidget);
  });

  testWidgets('Forgot Password screen opens', (WidgetTester tester) async {
    await _openAuth(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot Password'), findsAtLeastNWidgets(1));
    expect(find.text('Send Reset Link'), findsOneWidget);
    expect(find.text('Back to Sign In'), findsOneWidget);
  });
}
