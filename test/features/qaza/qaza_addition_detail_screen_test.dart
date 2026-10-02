import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/calendar/hijri_date_service.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_addition.dart';
import 'package:qaza_namaz/features/qaza/qaza_addition_detail_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  testWidgets('Single mode shows Gregorian + Hijri date and one day', (
    tester,
  ) async {
    final date = DateTime(2025, 3, 12);
    final detail = _detail(
      mode: QazaAdditionMode.single,
      selectedDates: [date],
      selectedPrayers: [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
      ],
      pendingCount: 18,
      completedCount: 6,
    );

    await _pumpDetail(tester, detail);

    final context = tester.element(find.byType(QazaAdditionDetailScreen));
    final l10n = AppLocalizations.of(context);

    expect(find.byType(Card), findsOneWidget);
    expect(find.text('24 Records'), findsOneWidget);
    expect(find.text('18 Pending · 6 Completed'), findsOneWidget);
    final gregorian = find.text(
      MaterialLocalizations.of(context).formatMediumDate(date),
    );
    final hijri = find.text(HijriDateService.format(date, l10n));
    expect(gregorian, findsOneWidget);
    expect(hijri, findsOneWidget);
    expect(tester.getTopLeft(gregorian).dy, lessThan(tester.getTopLeft(hijri).dy));
    expect(find.text('1 day'), findsOneWidget);
    expect(find.text('5 ${l10n.addQazaPrayersLabel}'), findsOneWidget);
    expect(find.text('Revision'), findsNothing);
  });

  testWidgets('Range mode shows both Gregorian/Hijri endpoints and inclusive days', (
    tester,
  ) async {
    final start = DateTime(2025, 3, 12);
    final end = DateTime(2025, 3, 18);
    final detail = _detail(
      mode: QazaAdditionMode.range,
      selectedDates: [start, end],
      selectedPrayers: [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
      ],
      pendingCount: 18,
      completedCount: 6,
    );

    await _pumpDetail(tester, detail);

    final context = tester.element(find.byType(QazaAdditionDetailScreen));
    final l10n = AppLocalizations.of(context);
    final gregorian =
        '${MaterialLocalizations.of(context).formatMediumDate(start)} → '
        '${MaterialLocalizations.of(context).formatMediumDate(end)}';
    final hijri =
        '${HijriDateService.format(start, l10n)} → '
        '${HijriDateService.format(end, l10n)}';

    expect(find.text(gregorian), findsOneWidget);
    expect(find.text(hijri), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('35 requested slots'), findsOneWidget);
  });

  testWidgets('Multiple mode pairs every date with its Hijri date', (
    tester,
  ) async {
    final dates = [
      DateTime(2025, 3, 12),
      DateTime(2025, 3, 15),
      DateTime(2025, 3, 20),
    ];
    final detail = _detail(
      mode: QazaAdditionMode.multiple,
      selectedDates: dates,
      selectedPrayers: [PrayerType.fajr, PrayerType.witr],
      pendingCount: 2,
      completedCount: 1,
    );

    await _pumpDetail(tester, detail);

    final context = tester.element(find.byType(QazaAdditionDetailScreen));
    final l10n = AppLocalizations.of(context);

    for (final date in dates) {
      final line =
          '${MaterialLocalizations.of(context).formatMediumDate(date)} · '
          '${HijriDateService.format(date, l10n)}';
      expect(find.text(line), findsOneWidget);
    }
    expect(find.text('3 dates'), findsOneWidget);
    expect(find.text('6 requested slots'), findsOneWidget);
  });

  testWidgets('Prayer chips use canonical order and include Witr', (tester) async {
    final detail = _detail(
      mode: QazaAdditionMode.single,
      selectedDates: [DateTime(2025, 3, 12)],
      selectedPrayers: [
        PrayerType.witr,
        PrayerType.asr,
        PrayerType.fajr,
        PrayerType.zuhr,
      ],
      pendingCount: 4,
      completedCount: 0,
    );

    await _pumpDetail(
      tester,
      detail,
      size: const Size(640, 900),
    );

    final fajr = tester.getTopLeft(find.text('Fajr'));
    final zuhr = tester.getTopLeft(find.text('Zuhr'));
    final asr = tester.getTopLeft(find.text('Asr'));
    final witr = tester.getTopLeft(find.text('Witr'));

    final positions = [fajr, zuhr, asr, witr];
    for (var i = 1; i < positions.length; i++) {
      expect(_isAfter(positions[i - 1], positions[i]), isFalse);
    }
    expect(find.text('Witr'), findsOneWidget);
    expect(find.text('4 prayers'), findsOneWidget);
  });

  testWidgets('Urdu locale uses localized prayer names', (tester) async {
    final detail = _detail(
      mode: QazaAdditionMode.single,
      selectedDates: [DateTime(2025, 3, 12)],
      selectedPrayers: [PrayerType.fajr, PrayerType.zuhr],
      pendingCount: 2,
    );

    await _pumpDetail(
      tester,
      detail,
      locale: const Locale('ur'),
    );

    expect(find.text('فجر'), findsOneWidget);
    expect(find.text('ظہر'), findsOneWidget);
  });

  testWidgets('Large Multiple selections remain usable without overflow', (
    tester,
  ) async {
    final dates = [
      for (var i = 0; i < 30; i++) DateTime(2025, 1, 1 + i),
    ];
    final detail = _detail(
      mode: QazaAdditionMode.multiple,
      selectedDates: dates,
      selectedPrayers: [PrayerType.fajr],
      pendingCount: 30,
    );

    await _pumpDetail(
      tester,
      detail,
      size: const Size(360, 800),
    );

    expect(tester.takeException(), isNull);

    final last = dates.last;
    final context = tester.element(find.byType(QazaAdditionDetailScreen));
    final l10n = AppLocalizations.of(context);
    final lastLine =
        '${MaterialLocalizations.of(context).formatMediumDate(last)} · '
        '${HijriDateService.format(last, l10n)}';
    expect(find.text(lastLine), findsOneWidget);

    await tester.ensureVisible(find.text(lastLine));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Completed-only additions hide edit/delete while keeping view records', (
    tester,
  ) async {
    final detail = _detail(
      mode: QazaAdditionMode.single,
      selectedDates: [DateTime(2025, 3, 12)],
      selectedPrayers: [PrayerType.fajr],
      pendingCount: 0,
      completedCount: 1,
    );

    await _pumpDetail(tester, detail);

    expect(find.text('View Records'), findsOneWidget);
    expect(find.text('Edit Addition'), findsNothing);
    expect(find.text('Delete Addition'), findsNothing);
  });

  testWidgets('Pending additions show both edit and delete actions', (tester) async {
    final detail = _detail(
      mode: QazaAdditionMode.single,
      selectedDates: [DateTime(2025, 3, 12)],
      selectedPrayers: [PrayerType.fajr],
      pendingCount: 1,
      completedCount: 1,
    );

    await _pumpDetail(tester, detail);

    expect(find.text('View Records'), findsOneWidget);
    expect(find.text('Edit Addition'), findsOneWidget);
    expect(find.text('Delete Addition'), findsOneWidget);
  });
}

QazaAdditionDetail _detail({
  required QazaAdditionMode mode,
  required List<DateTime> selectedDates,
  required List<PrayerType> selectedPrayers,
  int pendingCount = 0,
  int completedCount = 0,
}) {
  final snapshot = QazaAdditionInputSnapshot(
    schemaVersion: 1,
    mode: mode,
    selectedDates: selectedDates,
    selectedPrayers: selectedPrayers,
  );
  final now = DateTime(2026, 10, 2);

  return QazaAdditionDetail(
    addition: QazaAddition(
      id: 'addition-1',
      userId: 'local',
      mode: mode,
      currentInputSnapshot: snapshot,
      revision: 2,
      createdAt: now,
      updatedAt: now,
    ),
    activeCount: pendingCount + completedCount,
    pendingCount: pendingCount,
    completedCount: completedCount,
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  QazaAdditionDetail detail, {
  Locale locale = const Locale('en'),
  Size size = const Size(412, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        qazaAdditionDetailProvider(
          detail.addition.id,
        ).overrideWith((ref) async => detail),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: QazaAdditionDetailScreen(additionId: detail.addition.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _isAfter(Offset previous, Offset current) {
  const epsilon = 0.1;
  if ((current.dy - previous.dy).abs() > epsilon) {
    return current.dy >= previous.dy;
  }
  return current.dx >= previous.dx;
}
