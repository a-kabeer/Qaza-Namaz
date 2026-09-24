import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The build-time gate on Google Sign-In.
///
/// An Android artifact signed with a certificate the Firebase project does not
/// know completes the account chooser and then returns no ID token. Nothing in
/// the Dart code can detect that, and on a device it is indistinguishable from
/// the app simply being broken, so it has to be caught where the artifact is
/// produced.
void main() {
  final workflow = File('.github/workflows/flutter-ci.yml').readAsStringSync();
  final auditTool = File('tools/android_signing_audit.py').readAsStringSync();

  group('the audit tool', () {
    test('can fail a build, not only warn', () {
      expect(auditTool, contains('--require-firebase-match'));
      expect(
        auditTool,
        contains('Signing certificate is not registered in Firebase.'),
        reason: 'the failure has to say what to do about it',
      );
      expect(
        auditTool,
        contains('def print_firebase_comparison'),
      );
    });

    test('refuses an APK whose package is not the expected one', () {
      expect(
        auditTool,
        contains('does not match the expected '),
        reason: 'a mismatched package ID can never match a registered SHA-1',
      );
    });

    test('reports both fingerprints and the package', () {
      for (final line in const [
        'Package ID:',
        'APK SHA-1:',
        'APK SHA-256:',
      ]) {
        expect(auditTool, contains(line), reason: line);
      }
    });
  });

  group('the Android CI job', () {
    test('builds a real debug APK and reads its identity back', () {
      expect(workflow, contains('flutter build apk --debug'));
      expect(
        workflow,
        contains('--apk build/app/outputs/flutter-apk/app-debug.apk'),
        reason: 'the identity must come from the artifact, not the project',
      );
      expect(workflow, contains('Extract debug APK signing identity'));
    });

    test('fails when a supplied debug certificate is unregistered', () {
      expect(workflow, contains('Enforce debug certificate registration'));
      expect(workflow, contains('ANDROID_DEBUG_KEYSTORE_BASE64'));
      expect(
        workflow,
        contains('is not registered as an Android OAuth client in Firebase'),
      );
    });

    test('release artifacts are verified strictly', () {
      final release = workflow.substring(
        workflow.indexOf('Audit signed release APK'),
      );
      expect(
        release,
        contains('--require-firebase-match'),
        reason: 'a release build is what users install; a mismatch is fatal',
      );
      // The pre-build keystore audit stays in place alongside it.
      expect(workflow, contains('Audit production release signing identity'));
      expect(workflow, contains('--keystore android/release-keystore.jks'));
    });

    test('no signing secret is ever echoed into the log', () {
      expect(
        auditTool,
        isNot(contains('print(store_password')),
      );
      expect(
        auditTool,
        contains('never passwords or private'),
        reason: 'the tool documents the boundary it keeps',
      );
    });
  });

  test('the expected package is the one the app actually ships', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    final applicationId =
        RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)!.group(1)!;

    expect(
      workflow,
      contains('--firebase-package $applicationId'),
      reason: 'auditing a different package would always pass vacuously',
    );

    // And that package really is the one with an Android OAuth client.
    final config = jsonDecode(
      File('android/app/google-services.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final client = (config['client'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (c) =>
              ((c['client_info'] as Map<String, dynamic>)['android_client_info']
                  as Map<String, dynamic>)['package_name'] ==
              applicationId,
        );
    final androidOauth = (client['oauth_client'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((o) => o['client_type'] == 1)
        .toList();
    expect(androidOauth, isNotEmpty,
        reason: 'Google Sign-In needs an Android OAuth client (client_type 1)');
    expect(
      (androidOauth.first['android_info']
          as Map<String, dynamic>)['certificate_hash'],
      isNotEmpty,
    );
  });
}
