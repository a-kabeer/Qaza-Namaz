import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'restore verifies native Drive authorization after process recreation',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final state = SharedPreferencesCloudSyncStateStore(
        preferences: preferences,
      );
      await state.setActiveAccountId('google-account-A');
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_id_v1',
        'google-account-A',
      );
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_email_v1',
        'saved@example.com',
      );
      await state.setCloudSyncEnabled(true);
      await state.setAutomaticSyncEnabled(true);
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_display_name_v1',
        'Saved Google User',
      );
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_email_v1',
        'saved@example.com',
      );

      final gateway = _CountingGateway();
      final scheduler = _CountingScheduler(state: state);
      final provider = GoogleCloudAccountProvider(
        gateway: gateway,
        state: state,
        scheduler: scheduler,
      );

      final snapshot = await provider.restore();

      expect(snapshot.status, CloudAccountStatus.connected);
      expect(snapshot.isConnected, isTrue);
      expect(snapshot.displayName, 'Saved Google User');
      expect(snapshot.email, 'saved@example.com');
      expect(gateway.currentAccountCalls, 1);
      expect(gateway.authorizeDriveCalls, 1);
      expect(scheduler.disconnectCalls, 0);
      expect(scheduler.initializeCalls, 1);
      expect(await state.isCloudSyncEnabled(), isTrue);
      expect(await state.isAutomaticSyncEnabled(), isTrue);
      expect(await state.isReconnectRequired(), isFalse);
    },
  );

  test(
    'missing Drive authorization marks reconnect without disabling backup',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final state = SharedPreferencesCloudSyncStateStore(
        preferences: preferences,
      );
      await state.setActiveAccountId('google-account-A');
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_id_v1',
        'google-account-A',
      );
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_email_v1',
        'saved@example.com',
      );
      await state.setCloudSyncEnabled(true);
      await state.setAutomaticSyncEnabled(true);
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_display_name_v1',
        'Saved Google User',
      );

      final gateway = _CountingGateway(authorizationAvailable: false);
      final scheduler = _CountingScheduler(state: state);
      final provider = GoogleCloudAccountProvider(
        gateway: gateway,
        state: state,
        scheduler: scheduler,
      );

      final snapshot = await provider.restore();

      expect(snapshot.status, CloudAccountStatus.reconnectRequired);
      expect(snapshot.isConnected, isFalse);
      expect(snapshot.displayName, 'Saved Google User');
      expect(await state.isCloudSyncEnabled(), isTrue);
      expect(await state.isAutomaticSyncEnabled(), isTrue);
      expect(await state.isReconnectRequired(), isTrue);
    },
  );

  test(
    'restore defaults an unset automatic-backup choice to Daily ON',
    () async {
      final state = SharedPreferencesCloudSyncStateStore();
      await state.setActiveAccountId('google-account-A');
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_id_v1',
        'google-account-A',
      );
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_email_v1',
        'saved@example.com',
      );
      await state.setCloudSyncEnabled(true);
      final gateway = _CountingGateway();
      final scheduler = _CountingScheduler(state: state);
      final provider = GoogleCloudAccountProvider(
        gateway: gateway,
        state: state,
        scheduler: scheduler,
      );

      final snapshot = await provider.restore();

      expect(snapshot.status, CloudAccountStatus.connected);
      expect(await state.hasAutomaticSyncPreference(), isTrue);
      expect(await state.isAutomaticSyncEnabled(), isTrue);
      expect(await state.backupFrequency(), CloudBackupFrequency.daily);
      expect(scheduler.initializeCalls, 1);
    },
  );

  test(
    'restore preserves an existing explicit automatic-backup OFF choice',
    () async {
      final state = SharedPreferencesCloudSyncStateStore();
      await state.setActiveAccountId('google-account-A');
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_id_v1',
        'google-account-A',
      );
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_email_v1',
        'saved@example.com',
      );
      await state.setCloudSyncEnabled(true);
      await state.setAutomaticSyncEnabled(false);
      final gateway = _CountingGateway();
      final scheduler = _CountingScheduler(state: state);
      final provider = GoogleCloudAccountProvider(
        gateway: gateway,
        state: state,
        scheduler: scheduler,
      );

      final snapshot = await provider.restore();

      expect(snapshot.status, CloudAccountStatus.connected);
      expect(await state.isAutomaticSyncEnabled(), isFalse);
      expect(scheduler.initializeCalls, 0);
    },
  );

  test(
    'account restore stays connected when the same verified identity is restored',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final state = SharedPreferencesCloudSyncStateStore(
        preferences: preferences,
      );
      await state.setActiveAccountId('google-account-A');
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_id_v1',
        'google-account-A',
      );
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_email_v1',
        'saved@example.com',
      );
      await preferences.setString(
        'qaza_cloud_adapter.cached_account_display_name_v1',
        'Saved Google User',
      );
      await state.setCloudSyncEnabled(true);
      await state.setAutomaticSyncEnabled(true);

      final gateway = _CountingGateway(
        restoredAccount: _FakeGoogleSignInAccount(
          id: 'google-account-A',
          email: 'saved@example.com',
        ),
      );
      final scheduler = _CountingScheduler(state: state);
      final provider = GoogleCloudAccountProvider(
        gateway: gateway,
        state: state,
        scheduler: scheduler,
      );

      final snapshot = await provider.restore();

      expect(snapshot.status, CloudAccountStatus.connected);
      expect(snapshot.isConnected, isTrue);
      expect(gateway.lightweightRestoreCalls, 1);
      expect(gateway.currentAccountCalls, 1);
      expect(gateway.authorizeDriveCalls, 1);
      expect(await state.isReconnectRequired(), isFalse);
    },
  );

  test('restore while cloud is disabled does not call Google APIs', () async {
    final state = SharedPreferencesCloudSyncStateStore();
    final gateway = _CountingGateway();
    final scheduler = _CountingScheduler(state: state);
    final provider = GoogleCloudAccountProvider(
      gateway: gateway,
      state: state,
      scheduler: scheduler,
    );

    final snapshot = await provider.restore();

    expect(snapshot.status, CloudAccountStatus.disconnected);
    expect(gateway.currentAccountCalls, 0);
    expect(gateway.authorizeDriveCalls, 0);
    expect(scheduler.disconnectCalls, 0);
    expect(scheduler.initializeCalls, 0);
  });
}

class _CountingGateway extends GoogleSignInGateway {
  _CountingGateway({this.authorizationAvailable = true, this.restoredAccount})
    : super();

  final bool authorizationAvailable;
  final GoogleSignInAccount? restoredAccount;
  int lightweightRestoreCalls = 0;
  int currentAccountCalls = 0;
  int authorizeDriveCalls = 0;

  @override
  Future<GoogleSignInAccount?> currentAccount() async {
    currentAccountCalls++;
    return restoredAccount;
  }

  @override
  Future<GoogleSignInAccount?> restoreLightweightAuthentication() async {
    lightweightRestoreCalls++;
    return restoredAccount;
  }

  @override
  Future<String?> accountIdForAuthorization() async {
    final account = restoredAccount;
    if (account != null) return account.id;
    // Keep the process-recreation fallback deterministic without initializing
    // the real Google Sign-In plugin from this provider-level unit test.
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('qaza_cloud_adapter.cached_account_id_v1');
  }

  @override
  Future<http.Client?> authorizeDrive({required bool allowInteractive}) async {
    authorizeDriveCalls++;
    expect(allowInteractive, isFalse);
    if (!authorizationAvailable) {
      throw const CloudAuthorizationUnavailable();
    }
    return http.Client();
  }
}

class _FakeGoogleSignInAccount implements GoogleSignInAccount {
  _FakeGoogleSignInAccount({required this.id, required this.email});

  @override
  final String id;

  @override
  final String email;

  @override
  String? get displayName => 'Saved Google User';

  @override
  String? get photoUrl => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
