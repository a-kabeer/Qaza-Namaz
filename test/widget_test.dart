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

void main() {
  testWidgets('Signed-out app shows welcome and authentication entry', (WidgetTester tester) async {
    final authRepository = _FakeAuthRepository();

    await tester.pumpWidget(
      QazaNamazApp(
        authRepository: authRepository,
        qazaRepository: InMemoryQazaRepository(),
      ),
    );

    // Advance past the splash timer and allow the timer callback to rebuild.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('Qaza Namaz'), findsOneWidget);
    expect(find.text('Track your missed prayers with clarity and consistency.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pump();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Phone'), findsOneWidget);
    expect(find.text('Continue with WhatsApp'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    await authRepository.dispose();
  });
}
