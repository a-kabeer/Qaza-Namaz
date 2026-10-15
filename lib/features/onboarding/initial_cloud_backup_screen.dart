import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/services/cloud_sync_contracts.dart';
import '../../l10n/app_localizations.dart';
import 'startup_gate.dart';

/// Completes the first cloud backup after local onboarding has committed.
/// The durable pending marker remains set after failures so the next launch
/// can retry without repeating onboarding.
class InitialCloudBackupScreen extends ConsumerStatefulWidget {
  const InitialCloudBackupScreen({super.key});

  @override
  ConsumerState<InitialCloudBackupScreen> createState() =>
      _InitialCloudBackupScreenState();
}

class _InitialCloudBackupScreenState
    extends ConsumerState<InitialCloudBackupScreen> {
  bool _working = false;
  String? _error;
  CloudBackupProgress? _progress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runBackup());
  }

  Future<void> _runBackup() async {
    if (_working || !mounted) return;
    setState(() {
      _working = true;
      _error = null;
      _progress = const CloudBackupProgress.checking();
    });

    final l10n = AppLocalizations.of(context);
    try {
      final result = await ref.read(cloudSyncProvider).backupNow(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (!mounted) return;

      if (result.status == CloudSyncStatus.synced) {
        final database = ref.read(appDatabaseProvider);
        await database.clearPendingInitialCloudBackup();
        ref.invalidate(initialCloudBackupPendingProvider);
        ref.invalidate(appRouteProvider);
        _openStartupGate();
        return;
      }

      setState(() {
        _error = result.message ?? l10n.cloudConnectionFailed;
      });
    } catch (error) {
      if (mounted) setState(() => _error = l10n.cloudConnectionFailed);
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  void _continueToHome() {
    // Defer another automatic attempt for this process only. The persistent
    // pending marker is retained so a later app launch can retry safely.
    ref.read(skipPendingInitialCloudBackupForSessionProvider.notifier).state =
        true;
    ref.invalidate(appRouteProvider);
    _openStartupGate();
  }

  void _openStartupGate() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const StartupGate()),
      (_) => false,
    );
  }

  String _stageLabel(AppLocalizations l10n) {
    final progress = _progress;
    if (progress == null) return l10n.initialCloudBackupStagePreparing;
    return switch (progress.stage) {
      CloudBackupProgressStage.checking => l10n.initialCloudBackupStageChecking,
      CloudBackupProgressStage.downloading =>
        l10n.initialCloudBackupStageDownloading,
      CloudBackupProgressStage.preparing =>
        l10n.initialCloudBackupStagePreparing,
      CloudBackupProgressStage.uploading =>
        l10n.initialCloudBackupStageUploading,
      CloudBackupProgressStage.completed =>
        l10n.initialCloudBackupStageCompleted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final progress = _progress;
    final total = progress?.totalBytes ?? 0;
    final sent = progress?.sentBytes ?? 0;
    final hasByteProgress =
        (progress?.stage == CloudBackupProgressStage.uploading ||
            progress?.stage == CloudBackupProgressStage.downloading) &&
        total > 0;
    final ratio =
        hasByteProgress ? (sent / total).clamp(0.0, 1.0).toDouble() : null;
    // Bytes consumed by the HTTP request are not server confirmation. Hold
    // the visible percentage below 100 until the adapter confirms success.
    final visibleRatio = ratio == null ? null : (ratio >= 1 ? 0.99 : ratio);
    final visiblePercent =
        visibleRatio == null ? null : (visibleRatio * 100).round();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.initialCloudBackupAppBarTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _error == null
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_off_outlined,
                    size: 56,
                    color: _error == null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _error == null
                        ? l10n.initialCloudBackupTitle
                        : l10n.initialCloudBackupFailedTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error == null
                        ? l10n.initialCloudBackupBody
                        : l10n.initialCloudBackupFailedBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_working) ...[
                    Text(_stageLabel(l10n), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: visibleRatio),
                    if (hasByteProgress) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${(sent / (1024 * 1024)).toStringAsFixed(2)} MB / '
                        '${(total / (1024 * 1024)).toStringAsFixed(2)} MB'
                        ' · ${visiblePercent ?? 0}%',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _working ? null : _runBackup,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.initialCloudBackupRetry),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _working ? null : _continueToHome,
                      child: Text(l10n.initialCloudBackupContinueHome),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
