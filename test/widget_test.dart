import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/auth/authentication_screen.dart';
import 'package:qaza_namaz/features/auth/guest_upgrade_controller.dart';
import 'support/test_app.dart';

class _FakeGuestUpgradeController extends GuestUpgradeController {
  _FakeGuestUpgradeController(this.initialState);

  final GuestUpgradeState initialState;

  @override
  GuestUpgradeState build() => initialState;
}

Future<void> _openAuth(
  WidgetTester tester, {
  GuestUpgradeState state = const GuestUpgradeState(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        guestUpgradeControllerProvider.overrideWith(
          () => _FakeGuestUpgradeController(state),
        ),
      ],
      child: const TestApp(home: AuthenticationScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'Signed-out onboarding opens connected Google authentication entry',
    (WidgetTester tester) async {
      await _openAuth(tester);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        find.text(
          'Google is the currently connected authentication provider. '
          'Sign-in status is restored automatically from Firebase.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Authentication help explains the connected sign-in method',
    (WidgetTester tester) async {
      await _openAuth(tester);
      await tester.tap(find.byTooltip('Authentication help'));
      await tester.pumpAndSettle();
      expect(find.text('Authentication'), findsOneWidget);
      expect(
        find.textContaining(
          'Google Sign-In is the connected authentication method',
        ),
        findsOneWidget,
      );
      expect(find.byType(CloseButton), findsOneWidget);
    },
  );
}
