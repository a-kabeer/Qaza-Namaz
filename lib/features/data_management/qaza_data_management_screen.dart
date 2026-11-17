import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/workspace_refresh.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_widgets.dart';
import '../../data/data_transfer/local_backup_service.dart';
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
    final l10n = AppLocalizations.of(context);
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
          l10n.dataBackupSavedSuccess,
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
          l10n.dataBackupSaveFailed,
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked == null) {
        if (mounted) {
          _showMessage(l10n.dataImportCanceled);
        }
        return;
      }

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw LocalBackupException(l10n.dataImportFileEmpty);
      }

      final jsonText = utf8.decode(bytes, allowMalformed: false);
      final service = ref.read(localBackupServiceProvider);
      final analysis = await service.analyzeImport(jsonText);

      if (!mounted) return;
      final confirmed = await _confirmImport(analysis);
      if (!confirmed || !mounted) return;

      final restored = await service.importJson(jsonText);
      await refreshWorkspaceAfterRestore(ref);

      if (mounted) {
        _showMessage(
          l10n.dataImportSuccessWithCount(restored.recordCount),
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
        final message = error is LocalBackupException
            ? error.message
            : l10n.dataImportFailedMessage;
        _showMessage(message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmImport(LocalBackupAnalysis analysis) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.dataImportConfirmPrompt),
        content: Text(
          l10n.dataImportConfirmBody(analysis.recordCount),
          textAlign: TextAlign.start,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.dataImportConfirmAction),
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppScaffold(
      title: l10n.dataBackupAndRestoreTitle,
      onBack: () => Navigator.maybePop(context),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: Text(l10n.dataSaveBackupTitle),
                  subtitle: Text(l10n.dataSaveBackupSubtitle),
                  trailing: FilledButton.tonal(
                    onPressed: _busy ? null : _export,
                    child: Text(l10n.dataSaveBackupAction),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(l10n.dataRestoreBackupTitle),
                  subtitle: Text(l10n.dataRestoreBackupSubtitle),
                  trailing: FilledButton.tonal(
                    onPressed: _busy ? null : _import,
                    child: Text(l10n.dataRestoreBackupAction),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.dataLocalBackupNote),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            LoadingState(message: l10n.dataProcessingWaiting),
          ],
        ],
      ),
    );
  }
}
