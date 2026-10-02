import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/calendar/hijri_date_service.dart';
import 'package:qaza_namaz/domain/services/profile_qaza_plan_reconciliation_service.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:qaza_namaz/features/settings/profile_qaza_change_dialog.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

QazaPlan _plan({
  required DateTime start,
  required DateTime end,
  required int total,
}) {
  return QazaPlan(
    startDate: start,
    endDate: end,
    totalDays: end.difference(start).inDays,
    includeWitr: false,
    totalPrayers: total,
    prayerBreakdown: const {},
  );
}

void main() {
  testWidgets(
    'profile Qaza change dialog keeps plan details vertical and localized',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final oldPlan = _plan(
        start: DateTime(2026, 8, 23),
        end: DateTime(2026, 8, 26),
        total: 2124,
      );
      final newPlan = _plan(
        start: DateTime(2026, 8, 12),
        end: DateTime(2026, 8, 14),
        total: 4260,
      );

      final preview = ProfileQazaPlanPreview(
        oldPlan: oldPlan,
        newPlan: newPlan,
        oldRevision: null,
        previousProfileSnapshot: const {},
        calculationChanged: true,
        existingCompletedInNewPlan: 0,
        pendingToAdd: 136,
        pendingToRemove: 24,
        pendingAdditionKeys: const [],
        removalRecordIds: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showProfileQazaChangeDialog(
                    context: context,
                    preview: preview,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byKey(const Key('profile_qaza_apply'))),
      );

      expect(find.text(l10n.profileQazaPreviousTotal), findsOneWidget);
      expect(find.text('2,124 Qaza'), findsOneWidget);
      expect(find.text('23 Aug 2026 – 25 Aug 2026'), findsOneWidget);
      expect(
        find.text(
          '${HijriDateService.format(oldPlan.startDate, l10n)} – '
          '${HijriDateService.format(oldPlan.endDate.subtract(const Duration(days: 1)), l10n)}',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.profileQazaNewTotal), findsOneWidget);
      expect(find.text('4,260 Qaza'), findsOneWidget);
      expect(find.text('12 Aug 2026 – 13 Aug 2026'), findsOneWidget);

      expect(find.text(l10n.profileQazaImpact), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('136'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.byKey(const Key('profile_qaza_cancel')), findsOneWidget);
      expect(find.byKey(const Key('profile_qaza_apply')), findsOneWidget);
    },
  );
}
