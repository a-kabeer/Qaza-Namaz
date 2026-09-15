import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/app_metadata.dart';
import '../../data/data_transfer/qaza_data_transfer_service.dart';
import '../sync/sync_status_bar.dart';
import 'components.dart';

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
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) {
      _showMessage('Sign in before exporting your Qaza data.');
      return;
    }

    setState(() => _busy = true);
    try {
      final json = await ref.read(qazaDataTransferServiceProvider).exportJson(
            userId: userId,
            appVersion: appVersion,
          );
      final bytes = Uint8List.fromList(json.codeUnits);
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Qaza data export',
        fileName: 'qaza_namaz_export_v1.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );

      if (!mounted) return;
      _showMessage(savedPath == null || savedPath.isEmpty
          ? 'Export canceled. Your data was not changed.'
          : 'Export saved successfully.');
    } catch (error) {
      if (mounted) _showMessage('Export failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) {
      _showMessage('Sign in before importing data.');
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) _showMessage('Import canceled. Your data was not changed.');
        return;
      }

      final picked = result.files.single;
      final bytes = picked.bytes ??
          (picked.path == null ? null : await File(picked.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('The selected file is empty or unreadable.');
      }

      final jsonText = String.fromCharCodes(bytes);
      final analysis =
          await ref.read(qazaDataTransferServiceProvider).analyzeImport(
                jsonText: jsonText,
                userId: userId,
              );

      if (!mounted) return;
      final confirmed = await _confirmImport(analysis);
      if (!confirmed || !mounted) return;

      final applied =
          await ref.read(qazaDataTransferServiceProvider).applyImport(analysis);
      await ref.read(qazaRecordsProvider.notifier).refresh();
      if (mounted) {
        _showMessage(
          'Import complete: ${applied.addedCount} added, '
          '${applied.completedCount} completed, '
          '${applied.unchangedCount} unchanged.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Import rejected: $error\nNo partial import was applied.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmImport(QazaImportAnalysis analysis) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review data import'),
        content: Text(
          '${analysis.totalCount} valid records found.\n\n'
          'New: ${analysis.newCount}\n'
          'Will be marked completed: ${analysis.completionCount}\n'
          'Already present/unchanged: ${analysis.unchangedCount}\n\n'
          'Existing records are never blindly overwritten. Imported data is '
          'associated with your currently signed-in account.\n\n'
          'Import does not delete cloud or local records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
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
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Export & Import',
      onBack: () => Navigator.maybePop(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SyncStatusBar(),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('Export data'),
                  subtitle: const Text(
                    'Save a versioned JSON copy of your Qaza ledger. Nothing '
                    'is uploaded by the export action.',
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: _busy ? null : _export,
                    child: const Text('Export'),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('Import data'),
                  subtitle: const Text(
                    'Open a JSON export, validate it completely, preview the '
                    'merge, then apply it to this account.',
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: _busy ? null : _import,
                    child: const Text('Import'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data safety'),
                  SizedBox(height: 8),
                  Text(
                    'Export does not delete cloud data. Import does not erase '
                    'existing records. Sign-out is not data deletion, and '
                    'uninstalling the app does not delete cloud records.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Imported records are remapped to the currently signed-in '
                    'account. The existing local-first sync layer then confirms '
                    'changes with Firestore in the background.',
                  ),
                ],
              ),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LoadingState(message: 'Processing data…'),
          ],
        ],
      ),
    );
  }
}
