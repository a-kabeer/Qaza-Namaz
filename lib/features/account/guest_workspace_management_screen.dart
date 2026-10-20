import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../domain/entities/local_account.dart';
import 'guest_workspace_label.dart';
import '../../l10n/app_localizations.dart';

class GuestWorkspaceManagementScreen extends ConsumerStatefulWidget {
  const GuestWorkspaceManagementScreen({super.key});

  @override
  ConsumerState<GuestWorkspaceManagementScreen> createState() =>
      _GuestWorkspaceManagementScreenState();
}

class _GuestWorkspaceManagementScreenState
    extends ConsumerState<GuestWorkspaceManagementScreen> {
  bool _loading = true;
  List<LocalAccount> _workspaces = const [];
  List<LocalWorkspaceDeletionHold> _holds = const [];
  String? _activeWorkspaceId;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_reload);
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final store = ref.read(accountLocalStoreProvider);
      await store.purgeExpiredGuestWorkspaceDeletions();
      final workspaces = await store.listGuestWorkspaces();
      final holds = await store.listGuestWorkspaceDeletionHolds();
      final activeId =
          ref.read(accountSessionManagerProvider).activeLocalAccountId;
      if (!mounted) return;
      setState(() {
        _workspaces = workspaces;
        _holds = holds;
        _activeWorkspaceId = activeId;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _renameWorkspace(LocalAccount workspace) async {
    final controller = TextEditingController(
      text: workspace.displayName ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Guest workspace'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Workspace name',
            hintText: 'Enter a name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(dialogContext).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(AppLocalizations.of(dialogContext).commonContinue),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) {
      _showMessage('Enter a name containing 1–50 characters.');
      return;
    }
    try {
      await ref
          .read(accountLocalStoreProvider)
          .saveWorkspaceDisplayName(workspace.localAccountId, trimmed);
      await _reload();
      if (mounted) _showMessage('Guest workspace renamed.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _deleteWorkspace(LocalAccount workspace) async {
    if (workspace.localAccountId == _activeWorkspaceId) {
      _showMessage('Switch to another workspace before deleting this one.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Guest workspace?'),
        content: const Text(
          'Its records will be kept for seven days. You can undo the deletion '
          'during that period. Afterward, records are permanently removed only '
          'when no backup is pending.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(dialogContext).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(dialogContext).commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final expiry = await ref
          .read(accountLocalStoreProvider)
          .scheduleGuestWorkspaceDeletion(workspace.localAccountId);
      await _reload();
      if (mounted) {
        _showMessage(
          'Deletion scheduled for '
          '${MaterialLocalizations.of(context).formatMediumDate(expiry)}. Undo is available below.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _undoDeletion(LocalWorkspaceDeletionHold hold) async {
    try {
      final undone = await ref
          .read(accountLocalStoreProvider)
          .undoGuestWorkspaceDeletion(hold.localAccountId);
      await _reload();
      if (mounted) {
        _showMessage(
          undone
              ? 'Guest workspace restored.'
              : 'This deletion hold is no longer available.',
        );
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ref.read(appSnackbarServiceProvider).info(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.accountGuestTitle,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Guest workspaces could not be loaded: $_loadError'),
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: _reload,
                        child: Text(l10n.commonRetry),
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      l10n.accountGuestLocalDataSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_workspaces.isEmpty)
                      const ListTile(
                        leading: Icon(Icons.person_outline_rounded),
                        title: Text('No saved Guest workspaces'),
                      ),
                    for (final workspace in _workspaces)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.person_outline_rounded),
                          title: Text(
                            guestWorkspaceDisplayLabel(
                              workspace,
                              _workspaces,
                              fallbackName: l10n.accountGuest,
                            ),
                          ),
                          subtitle: Text(
                            workspace.lifecycleState == AccountLifecycleState.draft
                                ? 'Setup in progress · Resume to continue'
                                : workspace.localAccountId == _activeWorkspaceId
                                    ? 'Current workspace · switch away before deleting'
                                    : 'Created '
                                        '${MaterialLocalizations.of(context).formatMediumDate(workspace.createdAt)}',
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Manage Guest workspace',
                            onSelected: (action) {
                              if (action == 'rename') {
                                _renameWorkspace(workspace);
                              } else if (action == 'delete') {
                                _deleteWorkspace(workspace);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              if (workspace.localAccountId !=
                                  _activeWorkspaceId)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(l10n.commonDelete),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (_holds.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Recently deleted',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Records remain recoverable until the seven-day hold ends.',
                      ),
                      for (final hold in _holds)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.restore_rounded),
                            title: Text(
                              hold.displayName?.isNotEmpty == true
                                  ? hold.displayName!
                                  : l10n.accountGuest,
                            ),
                            subtitle: Text(
                              'Scheduled deletion: '
                              '${MaterialLocalizations.of(context).formatMediumDate(hold.expiresAt)}',
                            ),
                            trailing: TextButton(
                              onPressed: () => _undoDeletion(hold),
                              child: const Text('Undo'),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }
}
