import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/widgets/app_snackbar.dart';
import 'package:qaza_namaz/domain/services/qaza_undo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppSnackbarService', () {
    late GlobalKey<AppScaffoldMessengerState> messengerKey;
    late AppSnackbarService service;
    late DateTime now;

    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: Colors.indigo,
              behavior: SnackBarBehavior.floating,
            ),
          ),
          builder: (context, child) => AppScaffoldMessenger(
            key: messengerKey,
            child: child!,
          ),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );
      await tester.pump();
    }

    setUp(() {
      messengerKey = GlobalKey<AppScaffoldMessengerState>();
      now = DateTime(2026, 9, 26, 11, 0);
      service = AppSnackbarService(
        messengerKey: messengerKey,
        now: () => now,
      );
    });

    testWidgets('new Snackbar immediately replaces the current one', (
      tester,
    ) async {
      await pumpHost(tester);

      service.info('First');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('First'), findsOneWidget);

      final firstKey =
          tester.widget<SnackBar>(find.byType(SnackBar)).key;

      service.info('Second');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);

      final secondKey =
          tester.widget<SnackBar>(find.byType(SnackBar)).key;
      expect(secondKey, isNot(equals(firstKey)));
    });

    testWidgets('duplicate consecutive messages are suppressed', (
      tester,
    ) async {
      await pumpHost(tester);

      service.info('Same message');
      await tester.pump(const Duration(milliseconds: 300));
      final firstKey =
          tester.widget<SnackBar>(find.byType(SnackBar)).key;

      service.info('Same message');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).key,
        equals(firstKey),
      );

      now = now.add(AppSnackBarPolicy.duplicateWindow + const Duration(
        milliseconds: 1,
      ));
      service.info('Same message');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).key,
        isNot(equals(firstKey)),
      );
    });

    testWidgets('all severity APIs use the same five-second policy', (
      tester,
    ) async {
      await pumpHost(tester);

      final calls = <void Function(String)>[
        service.success,
        service.error,
        service.info,
        service.warning,
      ];

      for (var index = 0; index < calls.length; index++) {
        calls[index]('message-$index');
        await tester.pump(const Duration(milliseconds: 300));

        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snack.duration, const Duration(seconds: 5));
        expect(snack.persist, isFalse);
        expect(snack.behavior, SnackBarBehavior.floating);
        expect(snack.backgroundColor, Colors.indigo);

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.size, 20);
      }
    });

    testWidgets(
      'defensive messenger normalizes duration, persistence, and styling',
      (tester) async {
        await pumpHost(tester);

        messengerKey.currentState!.showSnackBar(
          SnackBar(
            content: const Text('Unsafe direct Snackbar'),
            duration: const Duration(seconds: 1),
            persist: true,
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snack.duration, const Duration(seconds: 5));
        expect(snack.persist, isFalse);
        expect(snack.backgroundColor, Colors.indigo);
        expect(snack.behavior, SnackBarBehavior.floating);
      },
    );

    testWidgets('Undo action is exposed through the centralized API', (
      tester,
    ) async {
      await pumpHost(tester);
      var invoked = false;

      service.undo(
        message: 'Completed',
        actionLabel: 'Undo',
        onUndo: () => invoked = true,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(invoked, isTrue);
    });
  });

  group('Qaza Undo domain timeout', () {
    test('expiry is independent of visual Snackbar lifetime', () {
      final expiry = DateTime(2026, 9, 26, 11, 0, 5);
      final batch = QazaUndoBatch(
        entries: [
          QazaUndoEntry(
            recordId: 'record-1',
            completionId: 'completion-1',
            prayerType: PrayerType.fajr,
            originalDate: DateTime(2026, 9, 1),
          ),
        ],
        expiresAt: expiry,
      );

      expect(batch.isExpired(expiry.subtract(const Duration(milliseconds: 1))), isFalse);
      expect(batch.isExpired(expiry), isTrue);
      expect(batch.isExpired(expiry.add(const Duration(minutes: 1))), isTrue);
    });

    test('persisted expired Undo batch is discarded', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final expiry = DateTime(2026, 9, 26, 10, 59, 59);
      final batch = QazaUndoBatch(
        entries: const [
          QazaUndoEntry(
            recordId: 'record-1',
            completionId: 'completion-1',
            prayerType: PrayerType.fajr,
            originalDate: DateTime(2026, 9, 1),
          ),
        ],
        expiresAt: expiry,
      );
      await prefs.setString(
        'qaza_undo_v2_local',
        jsonEncode(batch.toJson()),
      );

      final store = const QazaUndoStore();
      final loaded = await store.load(
        userId: 'local',
        now: DateTime(2026, 9, 26, 11, 0),
      );

      expect(loaded, isNull);
      expect(prefs.getString('qaza_undo_v2_local'), isNull);
    });
  });

  test('feature layer contains no direct Snackbar management', () {
    final root = Directory('lib');
    const infrastructurePath = 'lib/core/widgets/app_snackbar.dart';
    final forbidden = RegExp(
      r'ScaffoldMessenger(?:\.of|\.maybeOf)|'
      r'showSnackBar|'
      r'(?<![A-Za-z])SnackBar\s*\(|'
      r'hideCurrentSnackBar|'
      r'removeCurrentSnackBar|'
      r'clearSnackBars',
    );

    final violations = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith('.dart') ||
          entity.path == infrastructurePath) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (forbidden.hasMatch(source)) {
        violations.add(entity.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Feature files must use AppSnackbarService instead: $violations',
    );
  });

  test('workspace navigation does not own Snackbar lifecycle', () {
    final source =
        File('lib/features/shell/workspace_shell.dart').readAsStringSync();
    expect(source, isNot(contains('ScaffoldMessenger')));
    expect(source, isNot(contains('SnackBar')));
  });
}
