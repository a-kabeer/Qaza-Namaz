import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qaza_namaz/features/qaza/qaza_import_controller.dart';

void main() {
  test('profile Qaza apply reports progress through the shared controller', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(qazaImportProvider.notifier);
    final completed = Completer<void>();
    final progress = <(int, int)>[];
    final subscription = container.listen(
      qazaImportProvider,
      (_, next) {
        if (next.phase == QazaImportTaskPhase.completed &&
            !completed.isCompleted) {
          completed.complete();
        }
      },
    );
    addTearDown(subscription.close);

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

        },
      ),
      isTrue,
    );

    await completed.future;

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
    final failed = Completer<void>();
    final completed = Completer<void>();
    final subscription = container.listen(
      qazaImportProvider,
      (_, next) {
        if (next.phase == QazaImportTaskPhase.failed && !failed.isCompleted) {
          failed.complete();
        }
        if (next.phase == QazaImportTaskPhase.completed &&
            !completed.isCompleted) {
          completed.complete();
        }
      },
    );
    addTearDown(subscription.close);

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

    await failed.future;

    expect(
      container.read(qazaImportProvider).phase,
      QazaImportTaskPhase.failed,
    );

    expect(controller.retry(), isTrue);

    await completed.future;

    expect(attempts, 2);
    expect(
      container.read(qazaImportProvider).phase,
      QazaImportTaskPhase.completed,
    );
  });
}
