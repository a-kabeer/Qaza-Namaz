import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/auth/firebase_auth_repository.dart';

void main() {
  test('Android Firebase configuration matches the application ID and app',
      () async {
    final gradle = await File('android/app/build.gradle').readAsString();
    final json = jsonDecode(
      await File('android/app/google-services.json').readAsString(),
    ) as Map<String, dynamic>;

    final applicationMatch =
        RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle);
    expect(applicationMatch, isNotNull);
    final applicationId = applicationMatch!.group(1)!;
    expect(gradle, contains('buildTypes'));
    expect(
      gradle,
      contains('release {'),
      reason: 'The Android module must define an explicit release build type.',
    );
    expect(
      gradle,
      contains('signingConfig = signingConfigs.release'),
      reason:
          'Release builds must use the explicit production release signing configuration.',
    );
    expect(
      gradle,
      isNot(contains('signingConfig = signingConfigs.debug')),
      reason:
          'Release builds must never fall back to the debug signing key.',
    );

    final clients =
        (json['client'] as List<dynamic>).cast<Map<String, dynamic>>();
    final matching = clients.firstWhere(
      (client) =>
          (client['client_info'] as Map<String, dynamic>)['android_client_info']
              ['package_name'] ==
          applicationId,
    );

    final clientInfo = matching['client_info'] as Map<String, dynamic>;
    final oauthClients = (matching['oauth_client'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final androidOauth = oauthClients.firstWhere(
      (oauth) =>
          oauth['client_type'] == 1 &&
          (oauth['android_info'] as Map<String, dynamic>)['package_name'] ==
              applicationId,
    );

    expect(
      clientInfo['mobilesdk_app_id'],
      '1:895430705174:android:1e8d352d65428a4a3c7537',
    );
    final androidInfo =
        androidOauth['android_info'] as Map<String, dynamic>;
    expect(androidInfo['certificate_hash'], isNotEmpty);
    final firebaseOptions =
        File('lib/firebase_options.dart').readAsStringSync();
    expect(firebaseOptions, contains(clientInfo['mobilesdk_app_id'] as String));
    expect(firebaseOptions, contains("projectId: 'qaza-nmz'"));

    final webOauth =
        oauthClients.where((oauth) => oauth['client_type'] == 3).toList();
    expect(webOauth, isNotEmpty);
    expect(
      webOauth.map((oauth) => oauth['client_id']),
      contains(
        '895430705174-alhhbpbn958gt8t7e3d0mr3bqogo19sv.apps.googleusercontent.com',
      ),
    );

    final repository =
        File('lib/data/auth/firebase_auth_repository.dart').readAsStringSync();
    expect(
      repository,
      contains('GoogleSignIn.instance'),
      reason: 'Google Sign-In 7.x requires the singleton instance.',
    );
    expect(
      repository,
      contains('initialize()'),
      reason:
          'Android Google Sign-In should read the Web client from google-services.json.',
    );
    expect(
      repository,
      contains('await _googleSignIn.authenticate()'),
      reason: 'Android interactive authentication must use authenticate() in 7.x.',
    );
    expect(
      repository,
      contains('authenticateOnce()'),
      reason: 'The interactive flow is entered through one named call.',
    );
    expect(
      repository,
      isNot(contains('return _googleSignIn.authenticate();')),
      reason:
          'A second authenticate() is a second account chooser for one tap. '
          'google_sign_in_single_chooser_test pins the behaviour; this keeps '
          'the retry from being reintroduced by hand.',
    );
    expect(
      repository,
      contains('await requireRegisteredBuild();'),
      reason:
          'The build must be checked against the registered OAuth clients '
          'before an account chooser can open.',
    );

    expect(
      repository,
      isNot(contains('_googleSignIn.signIn()')),
      reason: 'The pre-7.x signIn() API must not be used.',
    );
    expect(
      repository,
      contains('GoogleSignInExceptionCode.canceled'),
      reason: 'Google cancellation must be handled explicitly.',
    );
    expect(
      repository,
      contains('userInitiated'),
      reason:
          'Genuine user cancellation must remain distinct from diagnosable failures.',
    );
    expect(
      repository,
      contains('Structured GoogleSignInException'),
      reason: 'Raw Google exception context must be preserved for diagnosis.',
    );

    final authConfig =
        File('lib/data/auth/google_auth_config.dart').readAsStringSync();
    expect(authConfig, contains("googleFirebaseProjectId = 'qaza-nmz'"));
    expect(authConfig, contains('com.example.qaza_namaz_task1_flutter'));
    expect(
      authConfig,
      isNot(contains('googleServerClientId')),
      reason:
          'The Web OAuth client ID must not be duplicated as a second Dart source of truth.',
    );

    expect(
      FirebaseAuthRepository.isCredentialManagerReauthFailure(
        '[16] Account reauth failed.',
      ),
      isTrue,
    );
    expect(
      FirebaseAuthRepository.isCredentialManagerReauthFailure(
        'User canceled the account chooser.',
      ),
      isFalse,
    );
    expect(
      FirebaseAuthRepository.isCredentialManagerReauthFailure(null),
      isFalse,
      reason: 'A missing Google exception description is not a Credential Manager reauth failure.',
    );
  });
}
