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
  _CountingGateway({this.authorizationAvailable = true}) : super();

  final bool authorizationAvailable;
  int currentAccountCalls = 0;
  int authorizeDriveCalls = 0;

  @override
  Future<GoogleSignInAccount?> currentAccount() async {
    currentAccountCalls++;
    return null;
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
