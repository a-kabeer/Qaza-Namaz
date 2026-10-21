import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/features/account/guest_workspace_label.dart';

LocalAccount _guest(String id, {String? name}) => LocalAccount(
      localAccountId: id,
      accountMode: AccountMode.local,
      lifecycleState: AccountLifecycleState.active,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
      displayName: name,
    );

void main() {
  test('duplicate Guest names receive a stable disambiguating suffix', () {
    final aminaA = _guest(
      'guest_11111111-1111-4111-8111-111111111111',
      name: 'Amina',
    );
    final aminaB = _guest(
      'guest_22222222-2222-4222-8222-222222222222',
      name: 'Amina',
    );

    expect(
      guestWorkspaceDisplayLabel(
        aminaA,
        [aminaA, aminaB],
        fallbackName: 'Guest',
      ),
      'Amina · 111111',
    );
    expect(
      guestWorkspaceDisplayLabel(
        aminaB,
        [aminaA, aminaB],
        fallbackName: 'Guest',
      ),
      'Amina · 222222',
    );
  });

  test('unnamed duplicate Guest workspaces are also distinguishable', () {
    final first = _guest('guest_first-workspace');
    final second = _guest('guest_second-workspace');

    expect(
      guestWorkspaceDisplayLabel(
        first,
        [first, second],
        fallbackName: 'Guest',
      ),
      isNot(
        guestWorkspaceDisplayLabel(
          second,
          [first, second],
          fallbackName: 'Guest',
        ),
      ),
    );
  });

  test('a unique Guest name stays unchanged', () {
    final amina = _guest(
      'guest_11111111-1111-4111-8111-111111111111',
      name: 'Amina',
    );
    expect(
      guestWorkspaceDisplayLabel(amina, [amina], fallbackName: 'Guest'),
      'Amina',
    );
  });
}
