import 'backup_failure.dart';
import 'firebase_backup_service.dart';
import 'firebase_services.dart';
import '../local/account_local_store.dart';

class FirebaseBackupHealthResult {
  const FirebaseBackupHealthResult({
    required this.firebase,
    required this.auth,
    required this.uidMatch,
    required this.appCheck,
    required this.appCheckToken,
    required this.firestoreRead,
    required this.cloudRoot,
    required this.cloudGeneration,
    required this.backupProbe,
    required this.firestoreWrite,
    required this.rules,
    this.failure,
  });

  final bool firebase;
  final bool auth;
  final bool uidMatch;
  final bool appCheck;
  final bool appCheckToken;
  final bool firestoreRead;
  final CloudRootStatus cloudRoot;
  final int? cloudGeneration;
  final bool backupProbe;
  final bool firestoreWrite;
  final bool rules;
  final BackupFailure? failure;

  bool get passed =>
      firebase &&
      auth &&
      uidMatch &&
      appCheck &&
      appCheckToken &&
      firestoreRead &&
      cloudRoot != CloudRootStatus.unavailable &&
      backupProbe &&
      firestoreWrite &&
      rules;
}

class FirebaseBackupHealthService {
  FirebaseBackupHealthService({
    required FirebaseServices firebase,
    required FirebaseBackupService backupService,
    required AccountLocalStore accountStore,
  })  : _firebase = firebase,
        _backup = backupService,
        _accountStore = accountStore;

  final FirebaseServices _firebase;
  final FirebaseBackupService _backup;
  final AccountLocalStore _accountStore;

  Future<FirebaseBackupHealthResult> check({
    required String localAccountId,
    required String uid,
    bool runBackupProbe = false,
  }) async {
    try {
      final initialization = await _firebase.initializeDetailed();
      if (!initialization.firebaseCoreInitialized) {
        throw const BackupFailure(
          category: BackupFailureCategory.firebaseInitializationFailed,
          message: 'Firebase Core initialization failed.',
        );
      }

      final authUser = _firebase.auth.currentUser;
      final auth = authUser != null;
      final uidMatch = authUser?.uid == uid;
      if (!auth) {
        throw const BackupFailure(
          category: BackupFailureCategory.authenticationUnavailable,
          message: 'Firebase authentication session is unavailable.',
        );
      }
      if (!uidMatch) {
        throw const BackupFailure(
          category: BackupFailureCategory.authenticationUidMismatch,
          message: 'Firebase authentication UID does not match the active account.',
        );
      }

      // Health checks are explicit diagnostics, so they may inspect the
      // current cached App Check token without force-refreshing it. Normal
      // backup operations do not perform this preflight.
      await _firebase.ensureAppCheckTokenAvailable(forceRefresh: false);

      final root = await _backup.readCloudRootResult(uid);
      if (!root.isAvailable) {
        throw root.failure ??
            const BackupFailure(
              category: BackupFailureCategory.unknown,
              message: 'Cloud root could not be read.',
            );
      }

      final generation = (root.data?['cloudGeneration'] as num?)?.toInt();
      final account = await _accountStore.getAccount(localAccountId);
      if (account == null) {
        throw const BackupFailure(
          category: BackupFailureCategory.authenticationUnavailable,
          message: 'Local backup account is unavailable.',
        );
      }
      if (generation != null && generation != account.cloudGeneration) {
        throw const BackupFailure(
          category: BackupFailureCategory.cloudGenerationMismatch,
          message: 'Cloud generation does not match the active local account.',
        );
      }
      final datasetState = root.data?['datasetState'] as String? ?? 'empty';
      if (datasetState == 'deleting' || datasetState == 'deleted') {
        throw BackupFailure(
          category: BackupFailureCategory.cloudDatasetInvalidState,
          message: 'Cloud dataset is not writable in state $datasetState.',
        );
      }

      if (runBackupProbe) {
        if (root.status == CloudRootStatus.missing) {
          throw const BackupFailure(
            category: BackupFailureCategory.firestoreNotFound,
            message: 'A backup probe requires an existing cloud root.',
          );
        }
        await _backup.snapshotAccount(
          localAccountId: localAccountId,
          uid: uid,
          generation: account.cloudGeneration,
        );
      }

      return FirebaseBackupHealthResult(
        firebase: true,
        auth: auth,
        uidMatch: uidMatch,
        appCheck: initialization.appCheckInitialized,
        appCheckToken: _firebase.appCheckTokenAvailable,
        firestoreRead: true,
        cloudRoot: root.status,
        cloudGeneration: generation,
        backupProbe: runBackupProbe,
        firestoreWrite: runBackupProbe,
        rules: runBackupProbe,
      );
    } catch (error, stack) {
      final failure = classifyBackupFailure(error, stackTrace: stack);
      final initialization = _firebase.initializationResult;
      final authUser = _firebase.firebaseCoreInitialized
          ? _firebase.auth.currentUser
          : null;
      final root = authUser?.uid == uid
          ? await _backup.readCloudRootResult(uid)
          : const CloudRootReadResult(status: CloudRootStatus.unavailable);

      return FirebaseBackupHealthResult(
        firebase: initialization.firebaseCoreInitialized,
        auth: authUser != null,
        uidMatch: authUser?.uid == uid,
        appCheck: initialization.appCheckInitialized,
        appCheckToken: _firebase.appCheckTokenAvailable,
        firestoreRead: root.isAvailable,
        cloudRoot: root.status,
        cloudGeneration:
            (root.data?['cloudGeneration'] as num?)?.toInt(),
        backupProbe: false,
        firestoreWrite: false,
        rules: false,
        failure: failure,
      );
    }
  }
}
