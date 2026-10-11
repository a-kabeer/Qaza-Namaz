import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_cloud_adapter/src/google_drive_store.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';

void main() {
  test('upload stream yields chunks and reports monotonic byte progress', () async {
    final bytes = List<int>.generate(5200, (index) => index % 256);
    final progress = <CloudBackupProgress>[];
    final received = <int>[];

    await for (final chunk in cloudUploadProgressStream(
      bytes,
      onProgress: progress.add,
    )) {
      received.addAll(chunk);
    }

    expect(received, bytes);
    expect(progress.length, greaterThan(2));
    expect(progress.first.sentBytes, 0);
    expect(progress.every((item) => item.totalBytes == bytes.length), isTrue);
    for (var index = 1; index < progress.length; index++) {
      expect(
        progress[index].sentBytes,
        greaterThanOrEqualTo(progress[index - 1].sentBytes),
      );
    }
    expect(progress.last.sentBytes, bytes.length);
  });

  test('zero-byte source does not claim completion', () async {
    final progress = <CloudBackupProgress>[];
    final chunks = await cloudUploadProgressStream(
      const <int>[],
      onProgress: progress.add,
    ).toList();

    expect(chunks, isEmpty);
    expect(progress.single.sentBytes, 0);
    expect(progress.single.totalBytes, 0);
  });
}
