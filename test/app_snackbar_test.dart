import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/widgets/app_snackbar.dart';

void main() {
  test('normalizes duration and disables persistence', () {
    final action = SnackBarAction(
      label: 'Undo',
      onPressed: () {},
    );
    final original = SnackBar(
      content: const Text('Message'),
      duration: const Duration(seconds: 20),
      persist: true,
      action: action,
    );

    final normalized = AppSnackBarPolicy.normalize(original);

    expect(normalized.duration, const Duration(seconds: 5));
    expect(normalized.persist, isFalse);
    expect(normalized.action, same(action));
    expect(normalized.content, same(original.content));
  });

  testWidgets(
    'global messenger auto-dismisses an action Snackbar after 5 seconds',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffoldMessenger(
            child: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Global Snackbar'),
                        duration: const Duration(seconds: 30),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {},
                        ),
                      ),
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Global Snackbar'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4, milliseconds: 900));
      expect(find.text('Global Snackbar'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Global Snackbar'), findsNothing);
      expect(find.text('Undo'), findsNothing);
    },
  );
}
