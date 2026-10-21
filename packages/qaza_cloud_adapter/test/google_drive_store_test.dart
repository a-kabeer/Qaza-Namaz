import 'dart:convert';

import 'package:crypto/crypto.dart';

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

  test('confirmed upload is read back and verified before success', () async {
    final backup = CloudBackup(
      lineage: CloudLineage(
        deviceId: 'device-A',
        backupId: 'backup-verified',
        baseBackupId: 'backup-100',
        dbRevision: 9,
        createdAt: DateTime.utc(2026, 10, 14),
      ),
      phase1BackupJson:
          '{"metadata":{"app_id":"qaza_namaz_app","db_revision":9,"database_schema_version":25},"data":{}}',
    );
    final bytes = utf8.encode(backup.toJsonString());
    final hash = sha256.convert(bytes).toString();
    final filename = '${cloudBackupFilePrefix}backup-verified.json';
    var createAttempts = 0;
    var readAttempts = 0;

    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/files')) {
        createAttempts++;
        return http.Response(
          jsonEncode(<String, Object?>{
            'id': 'file-verified',
            'name': filename,
            'modifiedTime': '2026-10-14T00:00:00.000Z',
            'version': '3',
            'appProperties': <String, String>{
              'backup_id': 'backup-verified',
              'device_id': 'device-A',
              'base_backup_id': 'backup-100',
              'db_revision': '9',
              'google_account_id': 'test-google-account',
              'workspace_id': 'google_test-google-account',
              'content_sha256': hash,
              'database_schema_version': '25',
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/files/file-verified')) {
        expect(request.url.queryParameters['alt'], 'media');
        readAttempts++;
        return http.Response(
          backup.toJsonString(),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('Unexpected request', 500);
    });
    final store = GoogleDriveAppDataStore(_TestGateway(client));

    final written = await store.write(backup, allowInteractive: false);

    expect(createAttempts, 1);
    expect(readAttempts, 1);
    expect(written.fileId, 'file-verified');
    expect(written.backup.toJsonString(), backup.toJsonString());
    expect(written.backup.lineage.backupId, 'backup-verified');
    client.close();
  });

  test(
    'read-back rejects bytes that do not match the uploaded content hash',
    () async {
      final backup = CloudBackup(
        lineage: CloudLineage(
          deviceId: 'device-A',
          backupId: 'backup-corrupt',
          baseBackupId: null,
          dbRevision: 10,
          createdAt: DateTime.utc(2026, 10, 15),
        ),
        phase1BackupJson:
            '{"metadata":{"app_id":"qaza_namaz_app","db_revision":10,"database_schema_version":25},"data":{}}',
      );
      final bytes = utf8.encode(backup.toJsonString());
      final hash = sha256.convert(bytes).toString();
      final filename = '${cloudBackupFilePrefix}backup-corrupt.json';
      var readAttempts = 0;

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/files')) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'id': 'file-corrupt',
              'name': filename,
              'modifiedTime': '2026-10-15T00:00:00.000Z',
              'version': '4',
              'appProperties': <String, String>{
                'backup_id': 'backup-corrupt',
                'device_id': 'device-A',
                'base_backup_id': '',
                'db_revision': '10',
                'google_account_id': 'test-google-account',
                'workspace_id': 'google_test-google-account',
                'content_sha256': hash,
                'database_schema_version': '25',
              },
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/files/file-corrupt')) {
          readAttempts++;
          return http.Response(
            '{"tampered":true}',
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('Unexpected request', 500);
      });
      final store = GoogleDriveAppDataStore(_TestGateway(client));

      await expectLater(
        store.write(backup, allowInteractive: false),
        throwsA(isA<CloudRemoteFormatException>()),
      );
      expect(readAttempts, 1);
      client.close();
    },
  );

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
          '{"metadata":{"app_id":"qaza_namaz_app","db_revision":7,"database_schema_version":25},"data":{}}',
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
                  'google_account_id': 'test-google-account',
                  'workspace_id': 'google_test-google-account',
                  'content_sha256': sha256
                      .convert(utf8.encode(backup.toJsonString()))
                      .toString(),
                  'database_schema_version': '25',
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
            '{"metadata":{"app_id":"qaza_namaz_app","db_revision":8,"database_schema_version":25},"data":{}}',
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

  // Hostile/corrupt responses on the download path (`_downloadBackup`,
  // reached through `download` and `latest`): every case must fail with a
  // typed CloudAdapterException and return no snapshot, so no partial or
  // attacker-shaped data can be applied by callers.
  group('GoogleDriveAppDataStore hostile downloads', () {
    CloudBackup buildBackup() => CloudBackup(
      lineage: CloudLineage(
        deviceId: 'device-A',
        backupId: 'backup-hostile',
        baseBackupId: 'backup-100',
        dbRevision: 9,
        createdAt: DateTime.utc(2026, 10, 14),
      ),
      phase1BackupJson:
          '{"metadata":{"app_id":"qaza_namaz_app","db_revision":9,"database_schema_version":25},"data":{}}',
    );

    CloudRemoteMetadata buildMetadata(
      List<int> bytes, {
      String? backupId = 'backup-hostile',
      String? googleAccountId = 'test-google-account',
      String? workspaceId = 'google_test-google-account',
      String? databaseSchemaVersion = '25',
      String? contentSha256,
      bool includeSha256 = true,
      String? contentMd5,
      bool includeMd5 = true,
      int? sizeBytes,
    }) => CloudRemoteMetadata(
      fileId: 'file-hostile',
      backupId: backupId,
      remoteVersion: '7',
      modifiedAt: DateTime.utc(2026, 10, 14),
      hasAuthoritativeVersion: true,
      sizeBytes: sizeBytes ?? bytes.length,
      googleAccountId: googleAccountId,
      workspaceId: workspaceId,
      contentSha256: includeSha256
          ? (contentSha256 ?? sha256.convert(bytes).toString())
          : null,
      databaseSchemaVersion: databaseSchemaVersion,
      contentMd5: includeMd5
          ? (contentMd5 ?? md5.convert(bytes).toString())
          : null,
    );

    MockClient downloadClient(List<int> body, {void Function()? onGet}) {
      return MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/files/file-hostile')) {
          onGet?.call();
          return http.Response.bytes(
            body,
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('Unexpected request', 500);
      });
    }

    test(
      'download returns the snapshot when bytes match all metadata',
      () async {
        final bytes = utf8.encode(buildBackup().toJsonString());
        final client = downloadClient(bytes);
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        final snapshot = await store.download(
          buildMetadata(bytes),
          allowInteractive: false,
        );

        expect(snapshot.fileId, 'file-hostile');
        expect(snapshot.backup.lineage.backupId, 'backup-hostile');
        expect(snapshot.backup.toJsonString(), buildBackup().toJsonString());
        client.close();
      },
    );

    test(
      'download rejects a body whose length differs from the metadata size',
      () async {
        // The served bytes are fully self-consistent (hashes, lineage,
        // account, workspace and schema all describe them exactly); only
        // the Drive-reported size is larger, so the rejection must come
        // from the delivered-length check, not a content check.
        final bytes = utf8.encode(buildBackup().toJsonString());
        final client = downloadClient(bytes);
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        await expectLater(
          store.download(
            buildMetadata(bytes, sizeBytes: bytes.length + 4096),
            allowInteractive: false,
          ),
          throwsA(isA<CloudRemoteFormatException>()),
        );
        client.close();
      },
    );

    test(
      'download rejects bytes that fail the SHA-256 metadata check',
      () async {
        final bytes = utf8.encode(buildBackup().toJsonString());
        final client = downloadClient(bytes);
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        await expectLater(
          store.download(
            buildMetadata(
              bytes,
              contentSha256: sha256
                  .convert(utf8.encode('some other content'))
                  .toString(),
            ),
            allowInteractive: false,
          ),
          throwsA(isA<CloudRemoteFormatException>()),
        );
        client.close();
      },
    );

    test(
      'download rejects bytes that fail the Drive MD5 metadata check',
      () async {
        final bytes = utf8.encode(buildBackup().toJsonString());
        final client = downloadClient(bytes);
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        await expectLater(
          store.download(
            buildMetadata(
              bytes,
              includeSha256: false,
              contentMd5: md5
                  .convert(utf8.encode('some other content'))
                  .toString(),
            ),
            allowInteractive: false,
          ),
          throwsA(isA<CloudRemoteFormatException>()),
        );
        client.close();
      },
    );

    test(
      'download rejects a body that is not a backup JSON envelope',
      () async {
        // The metadata hashes describe the served bytes exactly, so the
        // rejection must come from envelope validation, not a hash check.
        final bytes = utf8.encode('this is not a backup envelope');
        final client = downloadClient(bytes);
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        await expectLater(
          store.download(buildMetadata(bytes), allowInteractive: false),
          throwsA(isA<CloudRemoteFormatException>()),
        );
        client.close();
      },
    );

    test(
      'download rejects an envelope with an unsupported schema version',
      () async {
        final decoded =
            jsonDecode(buildBackup().toJsonString()) as Map<String, dynamic>;
        decoded['cloud_schema_version'] = 999;
        final bytes = utf8.encode(jsonEncode(decoded));
        final client = downloadClient(bytes);
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        await expectLater(
          store.download(buildMetadata(bytes), allowInteractive: false),
          throwsA(isA<CloudRemoteFormatException>()),
        );
        client.close();
      },
    );

    test('download rejects metadata naming a different backup ID than the '
        'payload lineage', () async {
      final bytes = utf8.encode(buildBackup().toJsonString());
      final client = downloadClient(bytes);
      final store = GoogleDriveAppDataStore(_TestGateway(client));

      await expectLater(
        store.download(
          buildMetadata(bytes, backupId: 'backup-other'),
          allowInteractive: false,
        ),
        throwsA(isA<CloudRemoteFormatException>()),
      );
      client.close();
    });

    test(
      'download rejects a backup owned by a different Google account',
      () async {
        final bytes = utf8.encode(buildBackup().toJsonString());
        final client = downloadClient(bytes);
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        await expectLater(
          store.download(
            buildMetadata(
              bytes,
              googleAccountId: 'other-google-account',
              workspaceId: 'google_other-google-account',
            ),
            allowInteractive: false,
          ),
          throwsA(isA<CloudAccountIdentityMismatch>()),
        );
        client.close();
      },
    );

    test('download rejects metadata whose workspace does not match its '
        'Google account', () async {
      final bytes = utf8.encode(buildBackup().toJsonString());
      final client = downloadClient(bytes);
      final store = GoogleDriveAppDataStore(_TestGateway(client));

      await expectLater(
        store.download(
          buildMetadata(bytes, workspaceId: 'google_other-google-account'),
          allowInteractive: false,
        ),
        throwsA(isA<CloudRemoteFormatException>()),
      );
      client.close();
    });

    test('download rejects metadata whose schema version differs from the '
        'payload', () async {
      final bytes = utf8.encode(buildBackup().toJsonString());
      final client = downloadClient(bytes);
      final store = GoogleDriveAppDataStore(_TestGateway(client));

      await expectLater(
        store.download(
          buildMetadata(bytes, databaseSchemaVersion: '24'),
          allowInteractive: false,
        ),
        throwsA(isA<CloudRemoteFormatException>()),
      );
      client.close();
    });

    test(
      'download surfaces an HTTP error as a typed, unretried failure',
      () async {
        var getAttempts = 0;
        final client = MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/files/file-hostile')) {
            getAttempts++;
            return http.Response(
              jsonEncode(<String, Object?>{
                'error': <String, Object?>{
                  'code': 404,
                  'message': 'File not found',
                  'errors': <Object?>[
                    <String, Object?>{
                      'domain': 'global',
                      'reason': 'notFound',
                      'message': 'File not found',
                    },
                  ],
                },
              }),
              404,
            );
          }
          return http.Response('Unexpected request', 500);
        });
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        await expectLater(
          store.download(
            buildMetadata(utf8.encode(buildBackup().toJsonString())),
            allowInteractive: false,
          ),
          throwsA(isA<CloudDriveRequestException>()),
        );
        expect(getAttempts, 1);
        client.close();
      },
    );

    test(
      'download retries a transient transport failure, then succeeds',
      () async {
        final bytes = utf8.encode(buildBackup().toJsonString());
        var getAttempts = 0;
        final client = MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/files/file-hostile')) {
            getAttempts++;
            if (getAttempts == 1) {
              throw http.ClientException(
                'Connection closed before full header was received',
                request.url,
              );
            }
            return http.Response.bytes(
              bytes,
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }
          return http.Response('Unexpected request', 500);
        });
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        final snapshot = await store.download(
          buildMetadata(bytes),
          allowInteractive: false,
        );

        expect(getAttempts, 2);
        expect(snapshot.backup.lineage.backupId, 'backup-hostile');
        client.close();
      },
    );

    test(
      'latest rejects a download whose bytes fail the listed SHA-256',
      () async {
        final servedBytes = utf8.encode(buildBackup().toJsonString());
        final client = MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/files/file-hostile')) {
            return http.Response.bytes(
              servedBytes,
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }
          if (request.method == 'GET' && request.url.path.endsWith('/files')) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'files': <Object?>[
                  <String, Object?>{
                    'id': 'file-hostile',
                    'name': '${cloudBackupFilePrefix}backup-hostile.json',
                    'modifiedTime': '2026-10-14T00:00:00.000Z',
                    'version': '7',
                    'size': '${servedBytes.length}',
                    // The MD5 describes the served bytes, so only the
                    // SHA-256 app property can catch this substitution.
                    'md5Checksum': md5.convert(servedBytes).toString(),
                    'appProperties': <String, String>{
                      'backup_id': 'backup-hostile',
                      'google_account_id': 'test-google-account',
                      'workspace_id': 'google_test-google-account',
                      'content_sha256': sha256
                          .convert(utf8.encode('the real backup content'))
                          .toString(),
                      'database_schema_version': '25',
                    },
                  },
                ],
              }),
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }
          return http.Response('Unexpected request', 500);
        });
        final store = GoogleDriveAppDataStore(_TestGateway(client));

        await expectLater(
          store.latest(allowInteractive: false),
          throwsA(isA<CloudRemoteFormatException>()),
        );
        client.close();
      },
    );
  });
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

  @override
  Future<String?> accountIdForAuthorization() async => 'test-google-account';
}
