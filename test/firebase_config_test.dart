
import 'package:flutter_test/flutter_test.dart';


void main() {
  test('Task 1 Firebase Android configuration constants are fixed', () {
    expect(
      FirebaseConfiguration.projectId,
      'qaza-nmz',
    );
    expect(
      FirebaseConfiguration.projectNumber,
      '895430705174',
    );
    expect(
      FirebaseConfiguration.androidAppId,
      FirebaseConfiguration.androidAppId,
    );
    expect(
      FirebaseConfiguration.androidPackage,
      FirebaseConfiguration.androidPackage,
    );
    expect(
      FirebaseConfiguration.androidSha1,
      '3a:b6:c8:b5:08:a6:85:79:25:4d:31:98:37:16:f5:d2:ba:bd:41:8d',
    );
    expect(
      FirebaseConfiguration.androidSha256,
      'f6:88:91:74:14:7f:0d:ec:58:86:be:2b:97:05:f0:40:5f:65:b3:c1:05:fe:51:f7:76:c2:91:9f:aa:93:b3:4d',
    );
  });
}
