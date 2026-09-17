import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/shell/workspace_shell.dart';

void main() {
  test('existing primary navigation contract remains unchanged', () {
    expect(
      workspaceNavigationLabels,
      const ['Dashboard', 'Calculator', 'Logs', 'Settings'],
    );
  });
}
