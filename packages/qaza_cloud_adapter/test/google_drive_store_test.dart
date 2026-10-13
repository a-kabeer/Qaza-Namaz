import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

void main() {
  group('GoogleDriveAppDataStore retry policy', () {
    for (final status in <int>[408, 429, 500, 502, 503, 504]) {
      test('retries transient HTTP $status response', () async {
        var attempts = 0;
        final client = MockClient((request) async {
          attempts++;
          if (attempts == 1) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'error': <String, Object?>{
                  'code': status,
                  'message': 'temporary failure',
                },
              }),
              status,
              headers: const <String, String>{'retry-after': '0'},
            );
          }
          return _fileListResponse();
        });
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        final metadata = await store.latestMetadata(allowInteractive: false);

        expect(attempts, 2);
        expect(metadata?.backupId, 'backup-100');
        expect(metadata?.remoteVersion, '1');
        client.close();
      });
    }

    for (final reason in <String>[
      'rateLimitExceeded',
      'userRateLimitExceeded',
    ]) {
      test('retries Drive 403 $reason only', () async {
        var attempts = 0;
        final client = MockClient((request) async {
          attempts++;
          if (attempts == 1) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'error': <String, Object?>{
                  'code': 403,
                  'message': 'rate limited',
                  'errors': <Object?>[
                    <String, Object?>{
                      'domain': 'usageLimits',
                      'reason': reason,
                      'message': 'rate limited',
                    },
                  ],
                },
              }),
              403,
              headers: const <String, String>{'retry-after': '0'},
            );
          }
          return _fileListResponse();
        });
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        final metadata = await store.latestMetadata(allowInteractive: false);

        expect(attempts, 2);
        expect(metadata?.backupId, 'backup-100');
        client.close();
      });
    }

    test('does not retry permanent Drive permission failures', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        return http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'code': 403,
              'message': 'permission denied',
              'errors': <Object?>[
                <String, Object?>{
                  'domain': 'global',
                  'reason': 'insufficientPermissions',
                  'message': 'permission denied',
                },
              ],
            },
          }),
          403,
        );
      });
      final store = GoogleDriveAppDataStore(_TestGateway(client));

      await expectLater(
        store.latestMetadata(allowInteractive: false),
        throwsA(isA<CloudDriveRequestException>()),
      );
      expect(attempts, 1);
      client.close();
    });

    test('retries a transient transport failure on a read', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          throw http.ClientException(
            'Connection closed before full header was received',
            request.url,
          );
        }
        return _fileListResponse();
      });
      final store = GoogleDriveAppDataStore(_TestGateway(client));

      final metadata = await store.latestMetadata(allowInteractive: false);

      expect(attempts, 2);
      expect(metadata?.backupId, 'backup-100');
      client.close();
    });
  });

  test('reconciles an ambiguous create without posting twice', () async {
    final backup = CloudBackup(
      lineage: CloudLineage(
        deviceId: 'device-A',
        backupId: 'backup-ambiguous',
        baseBackupId: 'backup-100',
        dbRevision: 7,
        createdAt: DateTime.utc(2026, 10, 12),
      ),
      phase1BackupJson:
          '{"metadata":{"app_id":"qaza_namaz_app","db_revision":7},"data":{}}',
    );
    final filename = '${cloudBackupFilePrefix}backup-ambiguous.json';
    var createAttempts = 0;
    var reconciled = false;

    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/files')) {
        createAttempts++;
        // Model Drive persisting the upload but losing the response.
        throw http.ClientException(
          'Connection closed before full header was received',
          request.url,
        );
      }

      if (request.method == 'GET' &&
          request.url.path.endsWith('/files/file-created')) {
        expect(request.url.queryParameters['alt'], 'media');
        return http.Response(
          backup.toJsonString(),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      if (request.method == 'GET' && request.url.path.endsWith('/files')) {
        expect(request.url.queryParameters['q'], contains(filename));
        reconciled = true;
        return http.Response(
          jsonEncode(<String, Object?>{
            'files': <Object?>[
              <String, Object?>{
                'id': 'file-created',
                'name': filename,
                'modifiedTime': '2026-10-12T00:00:00.000Z',
                'version': '2',
                'appProperties': <String, String>{
                  'backup_id': 'backup-ambiguous',
                  'device_id': 'device-A',
                  'base_backup_id': 'backup-100',
                  'db_revision': '7',
                },
              },
            ],
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }

      return http.Response(
        'Unexpected request: ${request.method} ${request.url}',
        500,
      );
    });

    final store = GoogleDriveAppDataStore(_TestGateway(client));
    final written = await store.write(backup, allowInteractive: false);

    expect(createAttempts, 1);
    expect(reconciled, isTrue);
    expect(written.fileId, 'file-created');
    expect(written.backup.lineage.backupId, 'backup-ambiguous');
    client.close();
  });
  test(
    'does not issue a second create when reconciliation finds no upload',
    () async {
      final backup = CloudBackup(
        lineage: CloudLineage(
          deviceId: 'device-A',
          backupId: 'backup-not-confirmed',
          baseBackupId: 'backup-100',
          dbRevision: 8,
          createdAt: DateTime.utc(2026, 10, 13),
        ),
        phase1BackupJson:
            '{"metadata":{"app_id":"qaza_namaz_app","db_revision":8},"data":{}}',
      );
      var createAttempts = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/files')) {
          createAttempts++;
          throw http.ClientException(
            'Connection closed before full header was received',
            request.url,
          );
        }
        if (request.method == 'GET' && request.url.path.endsWith('/files')) {
          return http.Response(
            jsonEncode(<String, Object?>{'files': <Object?>[]}),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('Unexpected request', 500);
      });
      final store = GoogleDriveAppDataStore(_TestGateway(client));

      await expectLater(
        store.write(backup, allowInteractive: false),
        throwsA(isA<CloudDriveRequestException>()),
      );
      expect(createAttempts, 1);
      client.close();
    },
  );
}

http.Response _fileListResponse() => http.Response(
  jsonEncode(<String, Object?>{
    'files': <Object?>[
      <String, Object?>{
        'id': 'file-backup-100',
        'name': '${cloudBackupFilePrefix}backup-100.json',
        'modifiedTime': '2026-10-12T00:00:00.000Z',
        'version': '1',
        'appProperties': <String, String>{'backup_id': 'backup-100'},
      },
    ],
  }),
  200,
  headers: const <String, String>{'content-type': 'application/json'},
);

class _TestGateway extends GoogleSignInGateway {
  _TestGateway(this.client);

  final http.Client client;

  @override
  Future<http.Client?> authorizeDrive({required bool allowInteractive}) async =>
      client;
}
