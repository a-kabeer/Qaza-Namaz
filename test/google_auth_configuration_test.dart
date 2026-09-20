import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

    final authConfig =
        File('lib/data/auth/google_auth_config.dart').readAsStringSync();
    expect(authConfig, contains("googleFirebaseProjectId = 'qaza-nmz'"));
    expect(authConfig, contains('com.example.qaza_namaz_task1_flutter'));
    expect(
      authConfig,
      contains(
        '895430705174-alhhbpbn958gt8t7e3d0mr3bqogo19sv.apps.googleusercontent.com',
      ),
    );
  });
}
