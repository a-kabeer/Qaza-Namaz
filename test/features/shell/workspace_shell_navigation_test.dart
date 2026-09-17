import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/shell/workspace_shell.dart';

void main() {
  testWidgets('existing primary navigation contract remains unchanged', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkspaceShell()));

    final navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = navigationBar.destinations
        .whereType<NavigationDestination>()
        .map((destination) => destination.label)
        .toList();

    expect(labels, const ['Home', 'Calculator', 'Logs', 'Settings']);
  });
}
