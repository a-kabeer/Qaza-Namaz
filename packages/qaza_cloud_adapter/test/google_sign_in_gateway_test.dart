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

  test(
    'normal sign out does not invoke Google authorization revocation',
    () async {
      final googleSignIn = _FakeGoogleSignIn();
      final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);

      await gateway.signOut();

      expect(googleSignIn.initializeCalls, 1);
      expect(googleSignIn.signOutCalls, 1);
      expect(googleSignIn.disconnectCalls, 0);
    },
  );

  test(
    'same-account reconnect reuses valid silent Drive authorization',
    () async {
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
              'identitySource': 'googleId',
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
    },
  );

  test(
    'silent authorization rejects an account mismatch without a picker',
    () async {
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
        throwsA(isA<CloudAccountIdentityMismatch>()),
      );
      expect(googleSignIn.authenticateCalls, 0);
    },
  );

  test(
    'missing native identity data is rejected without opening the picker',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authorizationChannel, (call) async {
            return <String, Object?>{
              'status': 'authorized',
              'accessToken': 'unverified-token',
              'grantedScopes': <String>[_driveScope],
            };
          });

      final googleSignIn = _FakeGoogleSignIn();
      final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);

      await expectLater(
        gateway.authorizeDrive(allowInteractive: true),
        throwsA(isA<CloudAccountIdentityMismatch>()),
      );
      expect(googleSignIn.authenticateCalls, 0);
    },
  );

  test(
    'required Drive consent never authorizes background work or opens a picker',
    () async {
      var authorizationCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authorizationChannel, (call) async {
            authorizationCalls++;
            return <String, Object?>{'status': 'interactionRequired'};
          });

      final googleSignIn = _FakeGoogleSignIn();
      final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);

      await expectLater(
        gateway.authorizeDrive(allowInteractive: false),
        throwsA(isA<CloudAuthorizationUnavailable>()),
      );
      expect(authorizationCalls, 1);
      expect(googleSignIn.authenticateCalls, 0);
    },
  );

  test(
    'native email match restores authorization when legacy result omits Google ID',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authorizationChannel, (call) async {
            return <String, Object?>{
              'status': 'authorized',
              'accountId': 'google-id-A',
              'accountEmail': 'a@example.com',
              'identitySource': 'targetAccountEmail',
              'accessToken': 'test-access-token',
              'grantedScopes': <String>[_driveScope],
            };
          });

      final googleSignIn = _FakeGoogleSignIn();
      final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);

      final client = await gateway.authorizeDrive(allowInteractive: true);
      client?.close();

      expect(googleSignIn.authenticateCalls, 0);
    },
  );

  test(
    'rejects email-only native authorization for a different account',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authorizationChannel, (call) async {
            return <String, Object?>{
              'status': 'authorized',
              'accountId': 'google-id-A',
              'accountEmail': 'b@example.com',
              'identitySource': 'targetAccountEmail',
              'accessToken': 'wrong-account-token',
              'grantedScopes': <String>[_driveScope],
            };
          });

      final googleSignIn = _FakeGoogleSignIn();
      final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);

      await expectLater(
        gateway.authorizeDrive(allowInteractive: true),
        throwsA(isA<CloudAccountIdentityMismatch>()),
      );
      expect(googleSignIn.authenticateCalls, 0);
    },
  );

  test('missing saved identity cannot authorize background work', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('qaza_cloud_adapter.cached_account_id_v1');
    await preferences.remove('qaza_cloud_adapter.cached_account_email_v1');
    var nativeAuthorizationCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_authorizationChannel, (call) async {
          nativeAuthorizationCalls++;
          return <String, Object?>{
            'status': 'authorized',
            'accountId': 'google-id-A',
            'accountEmail': 'a@example.com',
            'identitySource': 'googleId',
            'accessToken': 'test-access-token',
            'grantedScopes': <String>[_driveScope],
          };
        });

    final googleSignIn = _FakeGoogleSignIn();
    final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);

    await expectLater(
      gateway.authorizeDrive(allowInteractive: false),
      throwsA(isA<CloudAuthorizationUnavailable>()),
    );
    expect(nativeAuthorizationCalls, 0);
    expect(googleSignIn.authenticateCalls, 0);
  });

  test(
    'passive restore does not attempt lightweight sign-in UI',
    () async {
      final googleSignIn = _FakeGoogleSignIn();
      final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);

      expect(await gateway.restoreLightweightAuthentication(), isNull);
      expect(googleSignIn.lightweightAuthenticationCalls, 0);
      expect(googleSignIn.authenticateCalls, 0);
    },
  );

  test(
    'verified in-memory account bypasses brittle native identity conversion',
    () async {
      var nativeAuthorizationCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_authorizationChannel, (call) async {
            nativeAuthorizationCalls++;
            return <String, Object?>{'status': 'accountMismatch'};
          });
      final googleSignIn = _FakeGoogleSignIn()
        ..authenticatedAccount = _FakeGoogleSignInAccount(
          id: 'google-id-A',
          email: 'a@example.com',
        );
      final gateway = GoogleSignInGateway(googleSignIn: googleSignIn);
      await gateway.authenticate();

      await expectLater(
        gateway.authorizeDrive(allowInteractive: false),
        throwsA(isA<CloudAuthorizationUnavailable>()),
      );

      expect(nativeAuthorizationCalls, 0);
      expect(googleSignIn.authenticateCalls, 1);
    },
  );
}

class _FakeGoogleSignIn implements GoogleSignIn {
  int initializeCalls = 0;
  int signOutCalls = 0;
  int disconnectCalls = 0;
  int authenticateCalls = 0;
  int lightweightAuthenticationCalls = 0;
  GoogleSignInAccount? authenticatedAccount;

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
    if (invocation.memberName == #attemptLightweightAuthentication) {
      lightweightAuthenticationCalls++;
      return Future<GoogleSignInAccount?>.value(null);
    }
    if (invocation.memberName == #supportsAuthenticate) return true;
    if (invocation.memberName == #authenticate) {
      authenticateCalls++;
      final account = authenticatedAccount;
      if (account != null) return Future<GoogleSignInAccount>.value(account);
      return Future<GoogleSignInAccount>.error(
        StateError('Unexpected interactive authentication in this test.'),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeGoogleSignInAccount implements GoogleSignInAccount {
  _FakeGoogleSignInAccount({required this.id, required this.email});

  @override
  final String id;

  @override
  final String email;

  @override
  String? get displayName => 'Test Google User';

  @override
  String? get photoUrl => null;

  @override
  GoogleSignInAuthorizationClient get authorizationClient =>
      _FakeGoogleSignInAuthorizationClient();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoogleSignInAuthorizationClient
    implements GoogleSignInAuthorizationClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authorizationForScopes) {
      return Future<GoogleSignInClientAuthorization?>.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

