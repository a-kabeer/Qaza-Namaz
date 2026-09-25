import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/app_metadata.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_messages.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../data/data_transfer/qaza_data_transfer_service.dart';

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
    final userId = ref.read(requiredUserIdProvider);
    final dialogTitle = AppLocalizations.of(context).dataExportDialogTitle;
    setState(() => _busy = true);
    try {
      final json = await ref
          .read(qazaDataTransferServiceProvider)
          .exportJson(userId: userId, appVersion: appVersion);
      final bytes = Uint8List.fromList(json.codeUnits);
      final savedUri = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: 'qaza_namaz_export_v1.json',
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (!mounted) return;
      _showMessage(
        savedUri == null
            ? AppLocalizations.of(context).dataExportCanceled
            : AppLocalizations.of(context).dataExportSaved,
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          AppLocalizations.of(context).dataExportFailed(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final userId = ref.read(requiredUserIdProvider);
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
        throw const FormatException(
          'The selected file is empty or unreadable.',
        );
      }

      final analysis =
          await ref.read(qazaDataTransferServiceProvider).analyzeImport(
                jsonText: String.fromCharCodes(bytes),
                userId: userId,
              );
      if (!mounted) return;

      final confirmed = await _confirmImport(analysis);
      if (!confirmed || !mounted) return;

      final applied =
          await ref.read(qazaDataTransferServiceProvider).applyImport(analysis);
      ref.invalidate(progressSummaryProvider);
      if (mounted) {
        _showMessage(
          'Import complete: ${applied.addedCount} added, ${applied.completedCount} completed, ${applied.unchangedCount} unchanged.',
        );
      }
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.importData,
            'import_failed',
            error,
            stack: stack,
          );
      if (mounted) {
        _showMessage(AppError.from(error).message(context));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmImport(QazaImportAnalysis analysis) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).dataImportReviewTitle),
        content: Text(
          '${analysis.totalCount} valid records found.\n\nNew: ${analysis.newCount}\nWill be marked completed: ${analysis.completionCount}\nAlready present/unchanged: ${analysis.unchangedCount}\n\nExisting records are never blindly overwritten.\n\nImport changes only the local Qaza ledger on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).dataImportAction),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).dataSafetyTitle),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context).dataSafetyBody),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context).dataRemapNote),
                  ],
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
