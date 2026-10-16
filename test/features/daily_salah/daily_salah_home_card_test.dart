import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/widgets/app_snackbar.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_home_card.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_tracking_providers.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_tracking_service.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  late AppDatabase database;
  late OfflineFirstQazaRepository repository;
  late QazaService qazaService;
  late DailySalahTrackingService tracking;
  late _RecordingSnackbarService snackbar;
  const userId = 'daily-salah-home-card-test-user';

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    repository = OfflineFirstQazaRepository(
      localStore: DriftQazaLocalStore(database: database),
    );
    await repository.setActiveUser(userId);
    qazaService = QazaService(repository);
    tracking = DailySalahTrackingService(
      database: database,
      qazaService: qazaService,
    );
    snackbar = _RecordingSnackbarService();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
      'Skip for now hides setup, persists dismissal, and uses app snackbar',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          qazaServiceProvider.overrideWithValue(qazaService),
          activeUserIdProvider.overrideWithValue(userId),
          dailySalahTrackingServiceProvider.overrideWithValue(tracking),
          dailySalahTrackingDateProvider.overrideWith(
            (ref) => DateTime(2026, 10, 16),
          ),
          appSnackbarServiceProvider.overrideWithValue(snackbar),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DailySalahHomeCard(onOpen: _noOp),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('daily_salah_enable_tracking')), findsOneWidget);
    expect(find.byKey(const Key('daily_salah_skip_tracking')), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily_salah_skip_tracking')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily_salah_home_card')), findsNothing);
    expect(await tracking.isEnabled(), isFalse);
    expect(await tracking.isSetupDismissed(), isTrue);
    expect(
      snackbar.infoMessage,
      'Daily Namaz Tracking skipped. You can enable it anytime from Profile.',
    );
  });
}

void _noOp() {}

class _RecordingSnackbarService extends AppSnackbarService {
  _RecordingSnackbarService()
      : super(messengerKey: GlobalKey<AppScaffoldMessengerState>());

  String? infoMessage;

  @override
  void info(String message) {
    infoMessage = message;
  }
}
