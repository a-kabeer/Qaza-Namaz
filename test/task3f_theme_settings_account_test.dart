import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/core/widgets/components.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/auth_repository.dart';
import 'package:qaza_namaz/features/settings/settings_screens.dart';
import 'support/in_memory_qaza_repository.dart';

const _testUser = AppUser(id: 'uid-abc', email: 'kabeer@example.com', displayName: 'Abdul Kabeer');

class _FakeAuthRepository implements AuthRepository {
  int signOutCalls = 0;
  @override AppUser? get currentUser => _testUser;
  @override Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(_testUser);
  @override Future<AppUser> signInWithGoogle() async => _testUser;
  @override Future<void> signOut() async => signOutCalls++;
}

void main() {
  test('Light and dark themes derive from the Stitch palette', () {
    final light = AppTheme.light();
    expect(light.brightness, Brightness.light);
    expect(light.colorScheme.primary, AppTheme.interactive);
    expect(light.colorScheme.secondary, AppTheme.amber);
    expect(light.colorScheme.tertiary, AppTheme.mint);
    expect(light.colorScheme.surface, AppTheme.lightBase);
    expect(light.colorScheme.surfaceContainerLow, AppTheme.lightSurfaceLow);
    expect(light.colorScheme.surfaceContainer, AppTheme.lightSurface);
    final dark = AppTheme.dark();
    expect(dark.brightness, Brightness.dark);
    expect(dark.colorScheme.primary, AppTheme.darkPrimary);
    expect(dark.colorScheme.surface, AppTheme.darkBase);
    expect(dark.colorScheme.surfaceContainerLow, AppTheme.darkSurfaceLow);
    expect(dark.colorScheme.surfaceContainerHigh, AppTheme.darkSurfaceHigh);
    expect(dark.scaffoldBackgroundColor, AppTheme.darkBase);
  });

  Brightness? lastBrightness;
  Future<void> pumpSettings(WidgetTester tester, ThemeMode mode) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(overrides: [authStateProvider.overrideWith((ref) => Stream.value(_testUser))], child: MaterialApp(theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: mode, home: Builder(builder: (context) { lastBrightness = Theme.of(context).brightness; return const SettingsScreen(); }))));
    await tester.pumpAndSettle();
  }

  testWidgets('Light theme propagates to the whole app', (tester) async { await pumpSettings(tester, ThemeMode.light); expect(lastBrightness, Brightness.light); });
  testWidgets('Dark theme propagates to the whole app', (tester) async { await pumpSettings(tester, ThemeMode.dark); expect(lastBrightness, Brightness.dark); });
  testWidgets('System theme follows the platform brightness', (tester) async { tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark; addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue); await pumpSettings(tester, ThemeMode.system); expect(lastBrightness, Brightness.dark); });

  testWidgets('Switching theme from Settings propagates globally', (tester) async {
    tester.view.physicalSize = const Size(800, 1600); tester.view.devicePixelRatio = 1; addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(overrides: [authStateProvider.overrideWith((ref) => Stream.value(_testUser))], child: Consumer(builder: (context, ref, _) { final mode = ref.watch(themeModeProvider).materialMode; return MaterialApp(theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: mode, home: Builder(builder: (context) { lastBrightness = Theme.of(context).brightness; return const SettingsScreen(); })); })));
    await tester.pumpAndSettle();
    expect(lastBrightness, Brightness.light);
    await tester.tap(find.text('Dark')); await tester.pumpAndSettle(); expect(lastBrightness, Brightness.dark);
    await tester.tap(find.text('Light')); await tester.pumpAndSettle(); expect(lastBrightness, Brightness.light);
    await tester.tap(find.text('System')); await tester.pumpAndSettle(); expect(lastBrightness, Brightness.light);
  });

  testWidgets('Settings navigation opens Account and lists companion sections', (tester) async {
    await pumpSettings(tester, ThemeMode.light);
    expect(find.text('Account'), findsOneWidget); expect(find.text('Prayer & Fiqh Rules'), findsOneWidget); expect(find.text('Notifications'), findsOneWidget); expect(find.text('Data & Cloud'), findsOneWidget); expect(find.text('About'), findsOneWidget); expect(find.byType(SettingsNavRow), findsNWidgets(5));
    await tester.tap(find.text('Account')); await tester.pumpAndSettle();
    expect(find.text('Sign-in method'), findsOneWidget); expect(find.text('Account status'), findsOneWidget); expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Account screen renders real user identity and sign-out', (tester) async {
    final auth = _FakeAuthRepository(); tester.view.physicalSize = const Size(800, 1600); tester.view.devicePixelRatio = 1; addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(overrides: [authRepositoryProvider.overrideWithValue(auth)], child: MaterialApp(theme: AppTheme.light(), home: const AccountScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Abdul Kabeer'), findsOneWidget); expect(find.text('kabeer@example.com'), findsOneWidget); expect(find.text('uid-abc'), findsOneWidget); expect(find.text('Google authentication'), findsOneWidget); expect(find.text('Signed in'), findsOneWidget); expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Sign out requires confirmation and never deletes Qaza data', (tester) async {
    final repository = InMemoryQazaRepository(); final auth = _FakeAuthRepository(); final now = DateTime(2026, 9, 13);
    await repository.addRecords([QazaRecord(id: 'rec_fajr', userId: 'uid-abc', prayerType: PrayerType.fajr, originalDate: DateTime(2026, 9, 1), createdAt: now, updatedAt: now), QazaRecord(id: 'rec_isha', userId: 'uid-abc', prayerType: PrayerType.isha, originalDate: DateTime(2026, 9, 2), createdAt: now, updatedAt: now)]);
    tester.view.physicalSize = const Size(800, 1600); tester.view.devicePixelRatio = 1; addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(overrides: [authRepositoryProvider.overrideWithValue(auth)], child: MaterialApp(theme: AppTheme.light(), home: const AccountScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out')); await tester.pumpAndSettle(); expect(find.text('Sign out?'), findsOneWidget); expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('NOT deleted')), findsOneWidget);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(auth.signOutCalls, 0);
    await tester.tap(find.text('Sign out')); await tester.pumpAndSettle(); await tester.tap(find.widgetWithText(FilledButton, 'Sign out')); await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1); final records = await repository.getRecords(userId: 'uid-abc'); expect(records.length, 2); expect(records.every((r) => r.status == QazaStatus.pending), isTrue);
  });

  testWidgets('Empty, loading and error states render clearly', (tester) async {
    tester.view.physicalSize = const Size(800, 1600); tester.view.devicePixelRatio = 1; addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Column(children: [const Expanded(child: LoadingState(message: 'Loading your ledger...')), const Expanded(child: EmptyState(title: 'No Qaza records yet', message: 'Add your first record.')), Expanded(child: ErrorState(message: 'We could not load your Qaza ledger.', onRetry: () {}))]))));
    await tester.pump(); await tester.pump();
    expect(find.text('Loading your ledger...'), findsOneWidget); expect(find.text('No Qaza records yet'), findsOneWidget); expect(find.text('We could not load your Qaza ledger.'), findsOneWidget); expect(find.text('Retry'), findsOneWidget);
  });
}
