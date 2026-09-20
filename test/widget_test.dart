import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/app.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';
import 'package:qaza_namaz/data/notifications/local_notification_service.dart';
import 'package:qaza_namaz/features/notifications/notification_controller.dart';
import 'package:qaza_namaz/features/auth/authentication_screen.dart';
import 'package:qaza_namaz/features/auth/guest_upgrade_controller.dart';
import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

class _TestNotificationScheduler implements NotificationScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NotificationPermissionInfo> getPermissionInfo({
    required bool permissionRequested,
  }) async {
    return const NotificationPermissionInfo(
      granted: true,
      canRequest: true,
      permanentlyDenied: false,
      supported: true,
      sdkInt: 35,
      shouldShowRationale: false,
    );
  }

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool> openSystemNotificationSettings() async => true;

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required NotificationContent content,
  }) async {}

  @override
  Future<void> cancelDaily() async {}

  @override
  Future<void> showTestNotification(NotificationContent content) async {}
}

class _FakeGuestUpgradeController extends GuestUpgradeController {
  _FakeGuestUpgradeController(this.initialState);

  final GuestUpgradeState initialState;

  @override
  GuestUpgradeState build() => initialState;
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AppUser? get currentUser => null;
  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(null);
  @override
  Future<AppUser> signInWithGoogle() async =>
      const AppUser(id: 'test-user', email: 'test@example.com');
  @override
  Future<void> signOut() async {}
}

Future<void> _openAuth(WidgetTester tester, {
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
mport 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/app.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';
import 'package:qaza_namaz/data/notifications/local_notification_service.dart';
import 'package:qaza_namaz/features/notifications/notification_controller.dart';
import 'package:qaza_namaz/features/auth/authentication_screen.dart';
import 'package:qaza_namaz/features/auth/guest_upgrade_controller.dart';
import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

class _TestNotificationScheduler implements NotificationScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NotificationPermissionInfo> getPermissionInfo({
    required bool permissionRequested,
  }) async {
    return const NotificationPermissionInfo(
      granted: true,
      canRequest: true,
      permanentlyDenied: false,
      supported: true,
      sdkInt: 35,
      shouldShowRationale: false,
    );
  }

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool> openSystemNotificationSettings() async => true;

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required NotificationContent content,
  }) async {}

  @override
  Future<void> cancelDaily() async {}

  @override
  Future<void> showTestNotification(NotificationContent content) async {}
}

class _FakeGuestUpgradeController extends GuestUpgradeController {
  _FakeGuestUpgradeController(this.initialState);

  final GuestUpgradeState initialState;

  @override
  GuestUpgradeState build() => initialState;
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AppUser? get currentUser => null;
  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(null);
  @override
  Future<AppUser> signInWithGoogle() async =>
      const AppUser(id: 'test-user', email: 'test@example.com');
  @override
  Future<void> signOut() async {}
}

Future<void> _openAuth(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
    qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
    notificationSchedulerProvider.overrideWithValue(
      _TestNotificationScheduler(),
    )
  ], child: const TestApp(home: AuthenticationScreen())));
  await tester.pump();
  for (var i = 0; i < 10 && find.text('Welcome back').evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
      'Signed-out onboarding opens connected Google authentication entry',
      (WidgetTester tester) async {
    await _openAuth(tester);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(
        find.text(
            'Google is the currently connected authentication provider. Sign-in status is restored automatically from Firebase.'),
        findsOneWidget);
  });

  testWidgets('Authentication help explains the connected sign-in method',
      (WidgetTester tester) async {
    await _openAuth(tester);
    await tester.tap(find.byTooltip('Authentication help'));
    await tester.pumpAndSettle();
    expect(find.text('Authentication'), findsOneWidget);
    expect(
        find.textContaining(
            'Google Sign-In is the connected authentication method'),
        findsOneWidget);
    expect(find.byType(CloseButton), findsOneWidget);
  });
}
