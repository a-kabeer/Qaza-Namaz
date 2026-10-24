import 'package:flutter/foundation.dart';

/// Records privacy-safe stage durations in debug builds.
///
/// The flow and stage labels are call-site constants. No account identifiers,
/// emails, record counts, backup contents, or authorization tokens are logged.
Future<T> traceAsyncStage<T>({
  required String flow,
  required String stage,
  required Future<T> Function() action,
}) async {
  final timer = Stopwatch()..start();
  var outcome = 'ok';

  if (kDebugMode) {
    debugPrint('[tp-gen-timing] flow=$flow stage=$stage event=start');
  }

  try {
    return await action();
  } catch (_) {
    outcome = 'failed';
    rethrow;
  } finally {
    timer.stop();
    if (kDebugMode) {
      debugPrint(
        '[tp-gen-timing] flow=$flow stage=$stage '
        'outcome=$outcome duration_ms=${timer.elapsedMilliseconds}',
      );
    }
  }
}
