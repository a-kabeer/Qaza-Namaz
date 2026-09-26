import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending Qaza completion is swipe-only in both directions', () {
    final source =
        File('lib/features/qaza/qaza_tracker_screen.dart').readAsStringSync();

    expect(source, contains('direction: DismissDirection.horizontal'));
    expect(source, contains('DismissDirection.startToEnd: 0.32'));
    expect(source, contains('DismissDirection.endToStart: 0.32'));
    expect(source, contains('secondaryBackground: const _CompletionSwipeBackground'));
    expect(source, contains('Swipe left or right to complete. Long press to select.'));
    expect(source, contains('onTap: onTap'));
    expect(
      source,
      isNot(contains('Tap to complete. Swipe to complete. Long press to select.')),
    );
  });
}
