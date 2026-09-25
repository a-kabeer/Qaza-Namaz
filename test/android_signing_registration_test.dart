import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/auth/android_signing_identity.dart';
import 'package:qaza_namaz/data/auth/google_auth_config.dart';

/// Whether this build can possibly complete Google Sign-In.
///
/// Play services matches the caller by package name *and* signing certificate
/// before it will mint an ID token. When the certificate is not registered the
/// account chooser still opens, the user still picks an account, and the only
/// thing that comes back is "[16] Account reauth failed". Everything here
/// exists so the app can say which fingerprint is missing instead.
void main() {
  const registered = '3ab6c8b508a68579254d31983716f5d2babd418d';
  const unregistered = 'abababababababababababababababababababab';

  AndroidSigningIdentity identity({
    String package = googleAndroidApplicationId,
    List<String> sha1 = const [registered],
  }) =>
      AndroidSigningIdentity(
        packageName: package,
        sha1Fingerprints: sha1,
        sha256Fingerprints: const ['f68891'],
      );

  group('the registered fingerprints', () {
    test('are exactly what google-services.json lists', () {
      final config = jsonDecode(
        File('android/app/google-services.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      final hashes = <String>[];
      for (final client
          in (config['client'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        final info = (client['client_info']
                as Map<String, dynamic>)['android_client_info']
            as Map<String, dynamic>;
        if (info['package_name'] != googleAndroidApplicationId) continue;
        for (final oauth in (client['oauth_client'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
          if (oauth['client_type'] != 1) continue;
          final androidInfo = oauth['android_info'] as Map<String, dynamic>;
          if (androidInfo['package_name'] != googleAndroidApplicationId) {
            continue;
          }
          hashes.add(
            AndroidSigningIdentity.normalizeFingerprint(
              androidInfo['certificate_hash'] as String,
            ),
          );
        }
      }

      expect(hashes, isNotEmpty,
          reason: 'Google Sign-In needs an Android OAuth client');
      expect(
        googleAndroidCertificateSha1s
            .map(AndroidSigningIdentity.normalizeFingerprint)
            .toSet(),
        hashes.toSet(),
        reason: 'the Dart list must not drift from google-services.json',
      );
    });
  });

  group('checking a build against them', () {
    test('a registered certificate passes', () {
      expect(
        checkAndroidSigningRegistration(identity()),
        AndroidSigningRegistration.registered,
      );
    });

    test('separators and case do not matter', () {
      expect(
        checkAndroidSigningRegistration(
          identity(
              sha1: const [
            '3A:B6:C8:B5:08:A6:85:79:25:4D:31:98:37:16:F5:D2:BA:BD:41:8D'
          ].map(AndroidSigningIdentity.normalizeFingerprint).toList()),
        ),
        AndroidSigningRegistration.registered,
        reason: 'keytool prints colon-separated uppercase; Firebase does not',
      );
    });

    test('an unregistered certificate is named', () {
      expect(
        checkAndroidSigningRegistration(identity(sha1: const [unregistered])),
        AndroidSigningRegistration.unregisteredCertificate,
      );
    });

    test('one matching certificate among several is enough', () {
      expect(
        checkAndroidSigningRegistration(
          identity(sha1: const [unregistered, registered]),
        ),
        AndroidSigningRegistration.registered,
        reason: 'a rotated signing history keeps older certificates',
      );
    });

    test('a different package is named separately', () {
      expect(
        checkAndroidSigningRegistration(identity(package: 'com.other.app')),
        AndroidSigningRegistration.unexpectedPackage,
      );
    });

    test('an identity the platform could not read enforces nothing', () {
      expect(
        checkAndroidSigningRegistration(
          const AndroidSigningIdentity(
            packageName: '',
            sha1Fingerprints: [],
            sha256Fingerprints: [],
          ),
        ),
        AndroidSigningRegistration.unknown,
        reason: 'failing to introspect must never block a working sign-in',
      );
      expect(
        checkAndroidSigningRegistration(identity(), registeredSha1s: const []),
        AndroidSigningRegistration.unknown,
      );
    });
  });

  group('reading the identity from the platform', () {
    test('normalizes what the channel returns', () {
      final parsed = AndroidSigningIdentity.fromPlatform(<Object?, Object?>{
        'packageName': googleAndroidApplicationId,
        'sha1': <Object?>['3A:B6:C8', '', '  ', 42],
        'sha256': <Object?>['F6:88:91'],
      });

      expect(parsed.packageName, googleAndroidApplicationId);
      expect(parsed.sha1Fingerprints, ['3ab6c8'],
          reason: 'blank and non-string entries are dropped');
      expect(parsed.sha256Fingerprints, ['f68891']);
      expect(parsed.isUnknown, isFalse);
    });

    test('a missing platform implementation reads as "cannot tell"', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('qaza_namaz/signing_identity_absent');
      // Nothing is registered for this channel, so invoking it throws
      // MissingPluginException, which must surface as null rather than
      // an error.
      const service = AndroidSigningIdentityService(channel: channel);
      expect(await service.read(), isNull);
    });
  });
}
