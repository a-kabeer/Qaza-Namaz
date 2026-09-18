import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/test_app.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
import '../../support/in_memory_qaza_repository.dart';

void main() {
  testWidgets('primary navigation offers the five destinations',
      (tester) async {
    final repository = InMemoryQazaRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(repository),
          activeUserIdProvider.overrideWithValue('test-user'),
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AppUser(id: 'test-user', email: 'test@example.com'),
            ),
          ),
        ],
        child: const TestApp(home: WorkspaceShell()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final navigationBar =
        tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = navigationBar.destinations
        .whereType<NavigationDestination>()
        .map((destination) => destination.label)
        .toList();

    expect(
        labels, const ['Home', 'Qaza', 'Calculator', 'Knowledge', 'Settings']);
  });
}
