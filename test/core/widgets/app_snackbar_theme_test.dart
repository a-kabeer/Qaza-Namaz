import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/core/widgets/app_snackbar.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Undo snackbar follows semantic colors in $brightness mode',
      (tester) async {
        final theme =
            brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
        final messengerKey = GlobalKey<AppScaffoldMessengerState>();
        var undoPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: AppScaffoldMessenger(
              key: messengerKey,
              child: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () {
                        AppSnackbarService(
                          messengerKey: messengerKey,
                        ).undo(
                          message: 'Qaza completed',
                          actionLabel: 'Undo',
                          onUndo: () => undoPressed = true,
                        );
                      },
                      child: const Text('Show Undo'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Undo'));
        await tester.pumpAndSettle();

        final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
        final scheme = theme.colorScheme;
        expect(snackbar.backgroundColor, scheme.surfaceContainerHigh);
        expect(snackbar.action?.textColor, scheme.primary);

        final message = tester.widget<Text>(find.text('Qaza completed'));
        expect(message.style?.color, scheme.onSurface);

        final icon = tester.widget<Icon>(
          find.byIcon(Icons.check_circle_outline_rounded),
        );
        expect(icon.color, scheme.onSurface);

        await tester.tap(find.text('Undo'));
        await tester.pump();
        expect(undoPressed, isTrue);
      },
    );
  }
}
