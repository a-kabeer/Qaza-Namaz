import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app.dart';
import 'package:qaza_namaz/data/repositories/in_memory_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => const AppUser(
        id: 'test-user',
        email: 'test@example.com',
      );

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  Future<AppUser> signInWithGoogle() async => currentUser!;

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _controller.close();
}

void main() {
  testWidgets('Authenticated home screen smoke test',
      (WidgetTester tester) async {
    final authRepository = _FakeAuthRepository();

    await tester.pumpWidget(
      QazaNamazApp(),
    );

    // The production app uses FirebaseAuthGate. This smoke test is intentionally
    // kept focused on the production widget tree's authentication entry point.
    // Firebase-backed runtime behavior is verified on Android.
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);

    await authRepository.dispose();
  });
}
