import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

const _authorizationChannel = MethodChannel(
  'qaza_cloud_adapter/google_drive_authorization',
);
const _driveScope = 'https://www.googleapis.com/auth/drive.appdata';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'qaza_cloud_adapter.cached_account_id_v1': 'google-id-A',
      'qaza_cloud_adapter.cached_account_email_v1': 'a@example.com',
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_authorizationChannel, null);
  });

  test('normal sign out does not invoke Google authorization revocation', () async {
    final googleSignIn = _FakeGoogleSignIn();
    final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);

    await gateway.signOut();

    expect(googleSignIn.initializeCalls, 1);
    expect(googleSignIn.signOutCalls, 1);
    expect(googleSignIn.disconnectCalls, 0);
  });

  test('same-account reconnect reuses valid silent Drive authorization', () async {
    var authorizationCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_authorizationChannel, (call) async {
          authorizationCalls++;
          expect(call.method, 'authorizeDriveSilently');
          expect(call.arguments, <String, Object?>{
            'accountId': 'google-id-A',
            'accountEmail': 'a@example.com',
          });
          return <String, Object?>{
            'status': 'authorized',
            'accountId': 'google-id-A',
            'accountEmail': 'a@example.com',
            'accessToken': 'test-access-token',
            'grantedScopes': <String>[_driveScope],
          };
        });

    final googleSignIn = _FakeGoogleSignIn();
    final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);
    final client = await gateway.authorizeDrive(allowInteractive: true);
    client?.close();

    expect(authorizationCalls, 1);
    expect(googleSignIn.authenticateCalls, 0);
  });

  test('silent authorization rejects an account mismatch without a picker', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_authorizationChannel, (call) async {
          return <String, Object?>{
            'status': 'authorized',
            'accountId': 'google-id-B',
            'accountEmail': 'b@example.com',
            'accessToken': 'wrong-account-token',
            'grantedScopes': <String>[_driveScope],
          };
        });

    final googleSignIn = _FakeGoogleSignIn();
    final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);

    await expectLater(
      gateway.authorizeDrive(allowInteractive: true),
      throwsA(isA<CloudAuthorizationUnavailable>()),
    );
    expect(googleSignIn.authenticateCalls, 0);
  });
}

class _FakeGoogleSignIn implements GoogleSignIn {
  int initializeCalls = 0;
  int signOutCalls = 0;
  int disconnectCalls = 0;
  int authenticateCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      initializeCalls++;
      return Future<void>.value();
    }
    if (invocation.memberName == #signOut) {
      signOutCalls++;
      return Future<void>.value();
    }
    if (invocation.memberName == #disconnect) {
      disconnectCalls++;
      return Future<void>.value();
    }
    if (invocation.memberName == #supportsAuthenticate) return true;
    if (invocation.memberName == #authenticate) {
      authenticateCalls++;
      return Future<GoogleSignInAccount>.error(
        StateError('Unexpected interactive authentication in this test.'),
      );
    }
    return super.noSuchMethod(invocation);
  }
}
