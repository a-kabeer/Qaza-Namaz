import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/services/cloud_sync_contracts.dart';
import '../../l10n/app_localizations.dart';

class CloudSetupChoiceScreen extends ConsumerStatefulWidget {
  const CloudSetupChoiceScreen({super.key});

  @override
  ConsumerState<CloudSetupChoiceScreen> createState() =>
      _CloudSetupChoiceScreenState();
}

class _CloudSetupChoiceScreenState
    extends ConsumerState<CloudSetupChoiceScreen> {
  late Locale _selectedLocale;
  Future<void> _languagePersistence = Future<void>.value();
  bool _working = false;
  bool _accountConnected = false;
  bool _cloudAttempted = false;
  String? _error;
  CloudBackupDiscoverySnapshot? _discovery;

  @override
  void initState() {
    super.initState();
    _selectedLocale = ref.read(localeProvider);
    Future<void>.microtask(_restoreExistingAccount);
  }

  void _selectLanguage(Locale locale) {
    if (_working || locale.languageCode == _selectedLocale.languageCode) {
      return;
    }
    setState(() {
      _selectedLocale = locale;
      _error = null;
    });
    // Update MaterialApp immediately; serialize writes so rapid language
    // changes cannot complete out of order in SharedPreferences.
    ref.read(localeProvider.notifier).preview(locale);
    _languagePersistence = _languagePersistence
        .then((_) => ref.read(localeProvider.notifier).set(locale))
        .catchError((Object error) {
      if (mounted) setState(() => _error = error.toString());
    });
  }

  Future<void> _persistSelectedLanguage() async {
    await _languagePersistence;
    await ref.read(localeProvider.notifier).set(_selectedLocale);
  }

  Future<void> _restoreExistingAccount() async {
    if (!mounted || _working) return;
    setState(() => _working = true);
    try {
      final account =
          await ref.read(cloudAccountStartupRestoreProvider.future);
      if (!mounted) return;
      if (account.isConnected) {
        _accountConnected = true;
        await _discoverBackup();
      } else if (account.status == CloudAccountStatus.failed) {
        setState(() => _error = account.message ??
            AppLocalizations.of(context).cloudConnectionFailed);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _completeChoice() async {
    await ref.read(appDatabaseProvider).markCloudSetupChoiceComplete();
    ref.invalidate(cloudSetupChoiceCompleteProvider);
  }

  Future<void> _discoverBackup() async {
    final result = await ref.read(cloudSyncProvider).discoverBackup();
    if (!mounted) return;

    switch (result.status) {
      case CloudBackupDiscoveryStatus.unavailable:
      case CloudBackupDiscoveryStatus.failed:
      case CloudBackupDiscoveryStatus.invalidBackup:
        setState(() {
          _discovery = null;
          _error = result.message ??
              AppLocalizations.of(context).cloudConnectionFailed;
        });
        return;
      case CloudBackupDiscoveryStatus.noBackup:
        setState(() {
          _discovery = result;
          _error = null;
        });
        await _completeChoice();
        return;
      case CloudBackupDiscoveryStatus.backupFound:
        setState(() {
          _discovery = result;
          _error = null;
        });
        return;
    }
  }

  Future<void> _connectGoogle() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
      _discovery = null;
    });
    try {
      await _persistSelectedLanguage();
      _cloudAttempted = true;
      final account = await ref.read(cloudAccountProvider).signIn();
      if (!mounted) return;
      if (!account.isConnected) {
        setState(() {
          _accountConnected = false;
          _error = account.message ??
              AppLocalizations.of(context).cloudConnectionFailed;
        });
        return;
      }
      _accountConnected = true;
      await _discoverBackup();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _continueLocally() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await _persistSelectedLanguage();
      // If Google was connected but discovery failed or the user declines a
      // discovered backup, stop cloud scheduling and disconnect before routing
      // to local onboarding. The remote backup is left untouched.
      if (_accountConnected || _cloudAttempted) {
        try {
          await ref.read(cloudAccountProvider).disconnect();
        } catch (error) {
          // Failed interactive sign-in must not trap the user on this screen.
          // If a session had actually connected, require disconnect to finish.
          if (_accountConnected) rethrow;
        }
        _accountConnected = false;
      }
      await _completeChoice();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restoreBackup() async {
    final conflict = _discovery?.conflict;
    if (_working || conflict == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloudUseRemoteConfirmTitle),
        content: Text(l10n.cloudUseRemoteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final result = await ref.read(cloudSyncProvider).resolveConflict(
            conflict: conflict,
            choice: CloudConflictChoice.useRemote,
            confirmed: true,
          );
      if (!mounted) return;

      if (result.status != CloudSyncStatus.synced ||
          !result.restoredRemoteBackup) {
        if (result.status == CloudSyncStatus.synced) {
          // A stale conflict may have been recomputed into an upload/no-op.
          // Rediscover instead of treating that as a successful restoration.
          await _discoverBackup();
        } else if (mounted) {
          setState(() {
            _error = result.message ?? l10n.cloudConnectionFailed;
          });
        }
        return;
      }

      // Backup import replaces local account/session/profile rows. Reload the
      // active session and providers before StartupGate chooses a destination.
      await ref.read(accountSessionManagerProvider).refresh();
      ref.invalidate(appRouteProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(qazaRepositoryProvider);
      ref.invalidate(qazaAdditionRepositoryProvider);
      ref.invalidate(qazaPlanRevisionRepositoryProvider);
      await _completeChoice();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _retry() async {
    if (_working) return;
    if (!_accountConnected) {
      await _connectGoogle();
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await _persistSelectedLanguage();
      await _discoverBackup();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final backupFound =
        _discovery?.status == CloudBackupDiscoveryStatus.backupFound;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cloudSetupChoiceTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Icon(
                  Icons.nightlight_round,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.appTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.profileLanguageTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.profileLanguageIntro,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final locale in AppLocalizations.supportedLocales)
                      ChoiceChip(
                        key: Key(
                          'cloud_setup_language_${locale.languageCode}',
                        ),
                        label: Text(
                          locale.languageCode == 'ur'
                              ? l10n.languageUrdu
                              : l10n.languageEnglish,
                        ),
                        selected: locale.languageCode ==
                            _selectedLocale.languageCode,
                        onSelected: _working
                            ? null
                            : (selected) {
                                if (selected) _selectLanguage(locale);
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.cloudSetupChoiceDescription,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (backupFound) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_download_outlined,
                            size: 30,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.cloudBackupConflictTitle,
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.cloudBackupConflictMessage,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const Key('cloud_setup_restore_backup'),
                              onPressed: _working ? null : _restoreBackup,
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: Text(l10n.cloudUseRemote),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('cloud_setup_connect_google'),
                  onPressed: _working ? null : _connectGoogle,
                  icon: _working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(l10n.cloudSetupUseGoogle),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('cloud_setup_continue_local'),
                  onPressed: _working ? null : _continueLocally,
                  child: Text(l10n.cloudSetupContinueLocal),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _working ? null : _retry,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
