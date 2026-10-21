import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../domain/entities/local_account.dart';
import 'guest_workspace_label.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/startup_gate.dart';

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

  Future<void> _resumeWorkspace(LocalAccount workspace) async {
    // A local workspace must not be presented as the active Google workspace.
    // Ask the user to disconnect first; that sign-out flow preserves records
    // and returns through StartupGate, where this saved Guest can be selected.
    final cloudAccount = await ref.read(cloudAccountProvider).restore();
    if (!mounted) return;
    if (cloudAccount.isConnected) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sign out before switching Guest workspaces'),
          content: const Text(
            'Disconnect the Google account from Account settings first. '
            'This keeps local Guest records separate from the Google workspace '
            'and does not delete the Drive backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(dialogContext).commonContinue),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await ref
          .read(accountSessionManagerProvider)
          .activateLocalAccount(workspace.localAccountId);

      // The selected workspace is now active. Keep the current root route and
      // let its account-scoped providers settle before removing the settings
      // routes. Pushing a second StartupGate while invalidating its async
      // dependencies can strand the user on a blank/loading route with no
      // workspace navigation.
      ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = true;
      ref.invalidate(appRouteProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(qazaRepositoryProvider);
      ref.invalidate(qazaAdditionRepositoryProvider);
      ref.invalidate(qazaPlanRevisionRepositoryProvider);

      // These providers are used by StartupGate on the root route. Wait for
      // the newly selected workspace's routing/profile state to finish loading
      // while the Guest-management screen is still visible.
      try {
        await ref.read(appRouteProvider.future);
      } catch (_) {
        // StartupGate presents its retryable error boundary if this fails.
      }
      try {
        await ref.read(userProfileProvider.future);
      } catch (_) {
        // Keep navigation recoverable; StartupGate presents profile-load errors.
      }

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _renameWorkspace(LocalAccount workspace) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameGuestWorkspaceDialog(
        initialName: workspace.displayName ?? '',
      ),
    );
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
    final GuestWorkspaceRecordCounts counts;
    try {
      counts = await ref
          .read(accountLocalStoreProvider)
          .countWorkspaceRecords(workspace.localAccountId);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Guest workspace?'),
        content: Text(
          'Deleting this workspace removes its profile, '
          '${counts.qazaRecords} '
          '${counts.qazaRecords == 1 ? 'Qaza record' : 'Qaza records'} and '
          '${counts.dailySalahRecords} '
          '${counts.dailySalahRecords == 1 ? 'daily Salah record' : 'daily Salah records'}. '
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
                          key: Key(
                              'guest_workspace_${workspace.localAccountId}'),
                          onTap: () => _resumeWorkspace(workspace),
                          leading: const Icon(Icons.person_outline_rounded),
                          title: Text(
                            guestWorkspaceDisplayLabel(
                              workspace,
                              _workspaces,
                              fallbackName: l10n.accountGuest,
                            ),
                          ),
                          subtitle: Text(
                            workspace.lifecycleState ==
                                    AccountLifecycleState.draft
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

/// Rename prompt that owns its [TextEditingController].
///
/// The controller must outlive the dialog's exit animation: disposing it as
/// soon as the `showDialog` future resolves leaves the still-mounted
/// [TextField] holding a disposed controller. Owning the controller in this
/// widget's state ties disposal to the route's actual teardown.
class _RenameGuestWorkspaceDialog extends StatefulWidget {
  const _RenameGuestWorkspaceDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameGuestWorkspaceDialog> createState() =>
      _RenameGuestWorkspaceDialogState();
}

class _RenameGuestWorkspaceDialogState
    extends State<_RenameGuestWorkspaceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Guest workspace'),
      content: TextField(
        controller: _controller,
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
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(AppLocalizations.of(context).commonContinue),
        ),
      ],
    );
  }
}
