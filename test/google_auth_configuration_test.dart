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

    final clients = (json['client'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final matching = clients.firstWhere(
      (client) =>
          (client['client_info'] as Map<String, dynamic>)['android_client_info']
              ['package_name'] ==
          applicationId,
    );

    final clientInfo = matching['client_info'] as Map<String, dynamic>;
    final oauthClients =
        (matching['oauth_client'] as List<dynamic>).cast<Map<String, dynamic>>();
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
    expect(androidOauth['certificate_hash'], isNotEmpty);
    expect(
      File('lib/firebase_options.dart').readAsStringSync(),
      contains(clientInfo['mobilesdk_app_id'] as String),
    );
    expect(
      File('lib/firebase_options.dart').readAsStringSync(),
      contains('projectId: \'qaza-nmz\''),
    );
  });
}
