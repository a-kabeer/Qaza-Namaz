import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/language_selector.dart';
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
    if (_working || locale == _selectedLocale) {
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
        .then((_) => ref.read(localeProvider.notifier).persist(locale))
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
      final account = await ref.read(cloudAccountStartupRestoreProvider.future);
      if (!mounted) return;
      if (account.isConnected) {
        _accountConnected = true;
        await _discoverBackup();
      } else if (account.status == CloudAccountStatus.reconnectRequired) {
        // There is an existing cloud opt-in, even though this process has no
        // resolved account. If the user explicitly chooses local-only setup,
        // _continueLocally must also stop that existing scheduled sync.
        _cloudAttempted = true;
      } else if (account.status == CloudAccountStatus.failed) {
        _cloudAttempted = true;
        setState(() => _error = account.message ??
            AppLocalizations.of(context).cloudConnectionFailed);
      }
    } catch (error) {
      _cloudAttempted = true;
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _completeChoice() async {
    await ref.read(appDatabaseProvider).markCloudSetupChoiceComplete();
    ref.invalidate(cloudSetupChoiceCompleteProvider);
  }

  Future<void> _discoverBackup({bool allowInteractive = false}) async {
    final result = await ref.read(cloudSyncProvider).discoverBackup(
          allowInteractive: allowInteractive,
        );
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
      // This follows the explicit "Use Google" tap; automatic restoration
      // never requests Drive consent.
      await _discoverBackup(allowInteractive: true);
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
        } catch (_) {
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
      await _discoverBackup(allowInteractive: true);
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
    final scheme = theme.colorScheme;
    final backupFound =
        _discovery?.status == CloudBackupDiscoveryStatus.backupFound;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LanguageSelector<Locale>(
              key: const Key('cloud_setup_language_selector'),
              options: AppLocalizations.supportedLocales
                  .map(
                    (locale) => LanguageOption<Locale>(
                      value: locale,
                      languageCode: locale.languageCode,
                      scriptCode: locale.scriptCode,
                    ),
                  )
                  .toList(growable: false),
              value: _selectedLocale,
              layout: LanguageSelectorLayout.compact,
              semanticLabel: l10n.profileLanguageTitle,
              optionKeyPrefix: 'cloud_setup_language',
              enabled: !_working,
              onChanged: _selectLanguage,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              shrinkWrap: true,
              children: [
                Center(
                  child: Image.asset(
                    'assets/branding/qaza_namaz_logo.png',
                    width: 88,
                    height: 88,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.cloudSetupChoiceTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.cloudSetupChoiceDescription,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
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
                            color: scheme.primary,
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
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('cloud_setup_connect_google'),
                    onPressed:
                        _working || _accountConnected ? null : _connectGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: scheme.surface,
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(color: scheme.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_working)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const _GoogleGMark(),
                        const SizedBox(width: 12),
                        Text(l10n.cloudSetupUseGoogle),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('cloud_setup_continue_local'),
                    onPressed: _working ? null : _continueLocally,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.cloudSetupContinueLocal),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error),
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

/// Google sign-in mark drawn with the four Google brand colors. Drawing the
/// mark locally avoids a platform-specific monochrome icon or white asset.
class _GoogleGMark extends StatelessWidget {
  const _GoogleGMark();

  @override
  Widget build(BuildContext context) => const CustomPaint(
        key: Key('google_g_mark'),
        size: Size(24, 24),
        painter: _GoogleGMarkPainter(),
      );
}

class _GoogleGMarkPainter extends CustomPainter {
  const _GoogleGMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.0;
    final radius = size.shortestSide / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    void arc(Color color, double start, double sweep) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    const gap = 0.12;
    arc(const Color(0xFFEA4335), -math.pi / 2 + gap, math.pi / 2 - gap * 2);
    arc(const Color(0xFF4285F4), gap, math.pi / 2 - gap * 2);
    arc(const Color(0xFF34A853), math.pi / 2 + gap, math.pi / 2 - gap * 2);
    arc(const Color(0xFFFBBC05), math.pi + gap, math.pi / 2 - gap * 2);

    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2),
      Offset(size.width - 1, size.height / 2),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGMarkPainter oldDelegate) => false;
}
