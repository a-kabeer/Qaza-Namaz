import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/errors/app_error.dart';
import 'package:qaza_namaz/data/data_transfer/qaza_data_transfer_service.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';

import 'support/in_memory_qaza_repository.dart';

/// Task 20 — a backup survives a round trip, and a bad file is explained.
void main() {
  const userId = 'u1';
  final stamp = DateTime(2026, 2, 3, 4, 5);

  QazaRecord record(PrayerType prayer, int day, {QazaStatus? status}) =>
      QazaRecord(
        id: '${userId}_${prayer.name}_2026-02-${day.toString().padLeft(2, '0')}',
        userId: userId,
        prayerType: prayer,
        originalDate: DateTime(2026, 2, day),
        status: status ?? QazaStatus.pending,
        completedAt: status == QazaStatus.completed ? stamp : null,
        createdAt: stamp,
        updatedAt: stamp,
      );

  Future<QazaDataTransferService> serviceWith(List<QazaRecord> records) async {
    final repository = InMemoryQazaRepository();
    if (records.isNotEmpty) await repository.addRecords(records);
    return QazaDataTransferService(repository);
  }

  group('round trip', () {
    test('every record survives export and re-import', () async {
      final original = [
        record(PrayerType.fajr, 1),
        record(PrayerType.asr, 2, status: QazaStatus.completed),
        record(PrayerType.witr, 3),
      ];
      final source = await serviceWith(original);
      final json = await source.exportJson(userId: userId, appVersion: '1.0.0');

      // A fresh, empty ledger receives it.
      final target = await serviceWith(const []);
      final analysis =
          await target.analyzeImport(jsonText: json, userId: userId);

      expect(analysis.totalCount, 3);
      expect(analysis.newCount, 3);
      expect(analysis.unchangedCount, 0);
    });

    test('re-importing the same backup adds nothing the second time', () async {
      final service = await serviceWith([record(PrayerType.fajr, 1)]);
      final json =
          await service.exportJson(userId: userId, appVersion: '1.0.0');

      final analysis =
          await service.analyzeImport(jsonText: json, userId: userId);

      expect(analysis.newCount, 0,
          reason: 'the ledger already holds every record in the file');
      expect(analysis.unchangedCount, 1);
    });
  });

  group('UTF-8 and Urdu', () {
    test('the export is valid UTF-8 JSON and decodes unchanged', () async {
      final service = await serviceWith([record(PrayerType.fajr, 1)]);
      final json =
          await service.exportJson(userId: userId, appVersion: '1.0.0');

      // Through bytes and back, the way a file actually travels.
      final bytes = utf8.encode(json);
      final decoded = utf8.decode(bytes);

      expect(decoded, json);
      expect(() => jsonDecode(decoded), returnsNormally);
    });

    test('an Urdu app version survives the byte round trip', () async {
      // The one free-text field in the envelope. If encoding is mishandled
      // anywhere in export, this is where it shows.
      const urdu = 'قضاء نماز ١.٢.٣';
      final service = await serviceWith([record(PrayerType.fajr, 1)]);
      final json = await service.exportJson(userId: userId, appVersion: urdu);

      final reread =
          jsonDecode(utf8.decode(utf8.encode(json))) as Map<String, dynamic>;

      expect(reread.toString(), contains(urdu));
    });

    test('a file written as UTF-8 bytes imports correctly', () async {
      final source = await serviceWith([
        record(PrayerType.fajr, 1),
        record(PrayerType.maghrib, 2),
      ]);
      final json = await source.exportJson(userId: userId, appVersion: '1.0.0');

      // Exactly what the picker hands back: bytes, decoded as UTF-8.
      final fromDisk = utf8.decode(utf8.encode(json));
      final target = await serviceWith(const []);
      final analysis =
          await target.analyzeImport(jsonText: fromDisk, userId: userId);

      expect(analysis.newCount, 2);
    });
  });

  group('a bad file is explained, not dumped', () {
    test('malformed JSON is classified as damaged data', () async {
      final service = await serviceWith(const []);

      Object? thrown;
      try {
        await service.analyzeImport(jsonText: '{not json', userId: userId);
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isNotNull);
      final classified = AppError.from(thrown!);
      expect(classified.kind, AppErrorKind.malformedData);
      // And the taxonomy says retrying the same file is pointless.
      expect(classified.isRetryable, isFalse);
    });

    test('valid JSON that is not a Qaza backup is rejected', () async {
      final service = await serviceWith(const []);

      Object? thrown;
      try {
        await service.analyzeImport(
          jsonText: jsonEncode({'something': 'else'}),
          userId: userId,
        );
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isNotNull,
          reason: 'a well-formed file of the wrong shape must still be caught');
    });
  });
}
