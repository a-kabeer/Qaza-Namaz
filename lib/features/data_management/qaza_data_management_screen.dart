import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_widgets.dart';
import '../../data/data_transfer/local_backup_service.dart';
import '../../features/home/providers/home_providers.dart';
import '../../l10n/app_localizations.dart';

class QazaDataManagementScreen extends ConsumerStatefulWidget {
  const QazaDataManagementScreen({super.key});

  @override
  ConsumerState<QazaDataManagementScreen> createState() =>
      _QazaDataManagementScreenState();
}

class _QazaDataManagementScreenState
    extends ConsumerState<QazaDataManagementScreen> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = await ref.read(localBackupServiceProvider).exportJson();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/qaza_backup_latest.json');
      await file.writeAsString(json, encoding: utf8);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
        ),
      );
      if (mounted) {
        _showMessage(
          AppLocalizations.of(context).dataExportSaved,
          success: true,
        );
      }
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.importData,
            'local_backup_export_failed',
            error,
            stack: stack,
          );
      if (mounted) {
        _showMessage(
          AppLocalizations.of(context).dataExportFailed(error.toString()),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked == null) {
        if (mounted) {
          _showMessage(AppLocalizations.of(context).dataImportCanceled);
        }
        return;
      }

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw const LocalBackupException(
          'The selected backup file is empty or unreadable.',
        );
      }

      final jsonText = utf8.decode(bytes, allowMalformed: false);
      final service = ref.read(localBackupServiceProvider);
      final analysis = await service.analyzeImport(jsonText);

      if (!mounted) return;
      final confirmed = await _confirmImport(analysis);
      if (!confirmed || !mounted) return;

      final restored = await service.importJson(jsonText);
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(appRouteProvider);
      ref.invalidate(homeDashboardActivityProvider);
      ref.invalidate(homeDailyProgressProvider);
      ref.invalidate(homeQazaActivityCurrentWeekProvider);
      ref.invalidate(homeQazaActivityDailyGoalsProvider);
      ref.invalidate(homeFallbackPendingProvider);

      if (mounted) {
        _showMessage(
          'Backup restored successfully. ${restored.recordCount} Qaza records restored.',
          success: true,
        );
      }
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.importData,
            'local_backup_import_failed',
            error,
            stack: stack,
          );
      if (mounted) {
        _showMessage(error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmImport(LocalBackupAnalysis analysis) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Restore local backup?'),
        content: Text(
          'This backup contains ${analysis.recordCount} Qaza records and '
          '${analysis.accountCount} local account(s).\n\n'
          'Restoring will replace the current local application data on this '
          'device with the selected backup. The device identity used for local '
          'security is preserved.\n\n'
          'Backup revision: ${analysis.dbRevision}\n'
          'Onboarding completed: ${analysis.onboardingCompleted ? 'Yes' : 'No'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore backup'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showMessage(
    String message, {
    bool success = false,
    bool error = false,
  }) {
    final snackbar = ref.read(appSnackbarServiceProvider);
    if (error) {
      snackbar.error(message);
    } else if (success) {
      snackbar.success(message);
    } else {
      snackbar.info(message);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: AppLocalizations.of(context).dataTitle,
        onBack: () => Navigator.maybePop(context),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: Text(AppLocalizations.of(context).dataExportTitle),
                    subtitle: Text(AppLocalizations.of(context).dataExportBody),
                    trailing: FilledButton.tonal(
                      onPressed: _busy ? null : _export,
                      child: Text(
                        AppLocalizations.of(context).dataExportAction,
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: Text(AppLocalizations.of(context).dataImportTitle),
                    subtitle: Text(AppLocalizations.of(context).dataImportBody),
                    trailing: FilledButton.tonal(
                      onPressed: _busy ? null : _import,
                      child: Text(
                        AppLocalizations.of(context).dataImportAction,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Local backup only. No cloud sync, authentication, or network service is used by this screen.',
                ),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              LoadingState(
                message: AppLocalizations.of(context).dataProcessing,
              ),
            ],
          ],
        ),
      );
}
