// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app.dart';

void main() {
  testWidgets('Home screen smoke test', (WidgetTester tester) async {
    // Build our app and pump until the async home-screen load settles.
    await tester.pumpWidget(const QazaNamazApp());
    await tester.pumpAndSettle();

    // The app bar carries the app title.
    expect(find.widgetWithText(AppBar, 'Qaza Namaz'), findsOneWidget);

    // The home screen core workflow text is rendered.
    expect(find.text('Task 1 Core Workflow'), findsOneWidget);

    // The pending counter is shown.
    expect(find.textContaining('Pending Qaza:'), findsOneWidget);

    // All six prayer type chips are rendered.
    for (final label in ['Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha', 'Witr']) {
      expect(find.widgetWithText(Chip, label), findsOneWidget);
    }
  });
}
