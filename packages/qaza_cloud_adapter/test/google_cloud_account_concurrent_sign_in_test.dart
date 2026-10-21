import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scenario 14 (provider level) — duplicate/concurrent authentication.
///
/// Two `signIn()` calls fired while the first is still in flight. The
/// account provider itself keeps no in-flight future, so each call runs
/// its own authentication; what makes this safe is the gateway, which
/// serializes every native call — the second authentication cannot start
/// until the first has finished, so the platform sign-in UI is never
/// driven twice at once and both calls settle on the same account with
/// consistent persisted state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('concurrent signIn calls never overlap at the gateway and both '
      'complete with consistent state', () async {
    final preferences = await SharedPreferences.getInstance();
    final state = SharedPreferencesCloudSyncStateStore(
      preferences: preferences,
    );
    final googleSignIn = _GatedGoogleSignIn();
    final gateway = _DriveAuthorizingGateway(googleSignIn: googleSignIn);
    final scheduler = _CountingScheduler(state: state);
    final provider = GoogleCloudAccountProvider(
      gateway: gateway,
      state: state,
      scheduler: scheduler,
    );

    // Fire a second sign-in while the first is still in flight.
    final first = provider.signIn();
    final second = provider.signIn();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // The first authentication is parked inside the gated plugin call.
    // The second call has not reached the plugin at all: the real
    // gateway serializes its operations, so it is still queued.
    expect(googleSignIn.authenticateCalls, 1);
    expect(googleSignIn.maxConcurrentAuthentications, 1);

    googleSignIn.releaseAuthentication();
    final results = await Future.wait([first, second]);

    // Both calls complete successfully against the same account.
    for (final result in results) {
      expect(result.status, CloudAccountStatus.connected);
      expect(result.isConnected, isTrue);
      expect(result.accountId, 'google-id-A');
    }
    // Neither call was deduplicated — each performed its own full
    // authentication — but they ran strictly one after another.
    expect(googleSignIn.authenticateCalls, 2);
    expect(googleSignIn.maxConcurrentAuthentications, 1);
    expect(gateway.authorizeDriveCalls, 2);

    // The persisted state is singular and consistent: one active
    // account, sync enabled, no reconnect pending.
    expect(await state.activeAccountId(), 'google-id-A');
    expect(await state.isCloudSyncEnabled(), isTrue);
    expect(await state.isReconnectRequired(), isFalse);
    expect(scheduler.initializeCalls, 2);
    expect(scheduler.disconnectCalls, 0);
  });
}

/// The real gateway (with its serialized operation chain), with only the
/// Drive authorization step stubbed to hand back a plain HTTP client.
class _DriveAuthorizingGateway extends GoogleSignInGateway {
  _DriveAuthorizingGateway({required super.googleSignIn});

  int authorizeDriveCalls = 0;

  @override
  Future<http.Client?> authorizeDrive({required bool allowInteractive}) async {
    authorizeDriveCalls++;
    return http.Client();
  }
}

/// A GoogleSignIn whose interactive authentication blocks until the test
/// releases it, recording how many authentications run at once.
class _GatedGoogleSignIn implements GoogleSignIn {
  int initializeCalls = 0;
  int authenticateCalls = 0;
  int maxConcurrentAuthentications = 0;
  int _activeAuthentications = 0;
  final Completer<void> _gate = Completer<void>();

  void releaseAuthentication() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      initializeCalls++;
      return Future<void>.value();
    }
    if (invocation.memberName == #supportsAuthenticate) return true;
    if (invocation.memberName == #authenticate) {
      authenticateCalls++;
      _activeAuthentications++;
      if (_activeAuthentications > maxConcurrentAuthentications) {
        maxConcurrentAuthentications = _activeAuthentications;
      }
      return _gate.future.then((_) {
        _activeAuthentications--;
        return _FakeGoogleSignInAccount(
          id: 'google-id-A',
          email: 'a@example.com',
        );
      });
    }
    if (invocation.memberName == #signOut) {
      return Future<void>.value();
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

class _CountingScheduler extends CloudSyncScheduler {
  _CountingScheduler({required CloudSyncStateStore state})
    : super(state: state);

  int initializeCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<void> initializeAndSchedule({
    Duration frequency = const Duration(days: 1),
    String? serverClientId,
  }) async {
    initializeCalls++;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}
