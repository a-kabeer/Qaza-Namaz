import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/widgets/fatal_error_screen.dart';

void main() {
  testWidgets('retry-failed message is hidden before retry is attempted',
      (tester) async {
    await tester.pumpWidget(
      FatalDatabaseErrorApp(
        error: StateError('initial database open failed'),
        onRetry: () async {},
      ),
    );

    expect(find.textContaining('The retry also failed'), findsNothing);
  });

  testWidgets('retry-failed message appears only after retry throws',
      (tester) async {
    await tester.pumpWidget(
      FatalDatabaseErrorApp(
        error: StateError('initial database open failed'),
        onRetry: () async => throw StateError('retry failed'),
      ),
    );

    expect(find.textContaining('The retry also failed'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.textContaining('The retry also failed'), findsOneWidget);
  });
}
