import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qaza_namaz/features/qaza/qaza_import_controller.dart';

void main() {
  test('profile Qaza apply reports progress through the shared controller', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(qazaImportProvider.notifier);
    final finished = Completer<void>();
    final progress = <(int, int)>[];

    expect(
      controller.startProfilePlanApply(
        total: 10,
        operation: (onProgress) async {
          onProgress(0, 10);
          progress.add((0, 10));
          await Future<void>.value();
          onProgress(5, 10);
          progress.add((5, 10));
          await Future<void>.value();
          onProgress(10, 10);
          progress.add((10, 10));
          finished.complete();
        },
      ),
      isTrue,
    );

    await finished.future;

    expect(progress, [(0, 10), (5, 10), (10, 10)]);
    expect(
      container.read(qazaImportProvider).phase,
      QazaImportTaskPhase.completed,
    );
    expect(container.read(qazaImportProvider).processed, 10);
    expect(container.read(qazaImportProvider).total, 10);
  });

  test('profile Qaza apply can retry after an atomic failure', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(qazaImportProvider.notifier);
    var attempts = 0;

    expect(
      controller.startProfilePlanApply(
        total: 1,
        operation: (onProgress) async {
          attempts++;
          if (attempts == 1) {
            throw StateError('first attempt failed');
          }
          onProgress(1, 1);
        },
      ),
      isTrue,
    );

    await Future<void>.value();
    await Future<void>.value();

    expect(
      container.read(qazaImportProvider).phase,
      QazaImportTaskPhase.failed,
    );

    expect(controller.retry(), isTrue);

    await Future<void>.value();
    await Future<void>.value();

    expect(attempts, 2);
    expect(
      container.read(qazaImportProvider).phase,
      QazaImportTaskPhase.completed,
    );
  });
}
