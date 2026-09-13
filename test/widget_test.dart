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
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  Future<AppUser> signInWithGoogle() async => const AppUser(
        id: 'test-user',
        email: 'test@example.com',
      );

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _controller.close();
}

void main() {
  testWidgets('Signed-out app shows Google Sign-In',
      (WidgetTester tester) async {
    final authRepository = _FakeAuthRepository();

    await tester.pumpWidget(
      QazaNamazApp(
        authRepository: authRepository,
        qazaRepository: InMemoryQazaRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Qaza Namaz'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    await authRepository.dispose();
  });
}
