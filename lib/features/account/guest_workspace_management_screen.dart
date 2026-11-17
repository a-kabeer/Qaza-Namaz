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

  Future<void> _resumeWorkspace(LocalAccount workspace) async {
    final l10n = AppLocalizations.of(context);
    if (workspace.localAccountId == _activeWorkspaceId) {
      _showMessage(l10n.guestAlreadyActive);
      return;
    }
    try {
      // Workspace switching is local-only. End any in-memory Google identity
      // session, then activate the selected Guest without deleting any data.
      final identity = ref.read(googleIdentityProvider);
      if (identity.isSupported) await identity.signOut();
      if (!mounted) return;
      await ref
          .read(accountSessionManagerProvider)
          .activateLocalAccount(workspace.localAccountId);

      ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = true;

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
      final name = guestWorkspaceDisplayLabel(
        workspace,
        _workspaces,
        fallbackName: l10n.accountGuest,
      );
      _showMessage(l10n.guestSwitchedMessage(name));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _startNewGuestWorkspace() async {
    try {
      final store = ref.read(accountLocalStoreProvider);
      final newId = await store.startFreshGuestWorkspace();
      final identity = ref.read(googleIdentityProvider);
      if (identity.isSupported) await identity.signOut();
      if (!mounted) return;
      await ref.read(accountSessionManagerProvider).activateLocalAccount(newId);
      ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = true;
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _renameWorkspace(LocalAccount workspace) async {
    final l10n = AppLocalizations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameGuestWorkspaceDialog(
        initialName: workspace.displayName ?? '',
      ),
    );
    if (name == null || !mounted) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) {
      _showMessage(l10n.guestRenameValidation);
      return;
    }
    try {
      await ref
          .read(accountLocalStoreProvider)
          .saveWorkspaceDisplayName(workspace.localAccountId, trimmed);
      await _reload();
      if (mounted) _showMessage(l10n.guestRenameSuccess);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _deleteWorkspace(LocalAccount workspace) async {
    final l10n = AppLocalizations.of(context);
    if (workspace.localAccountId == _activeWorkspaceId) {
      _showMessage(l10n.guestDeleteActiveError);
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
        title: Text(l10n.guestDeleteTitle),
        content: Text(
          l10n.guestDeleteDialogMessage(
            l10n.guestQazaRecordCount(counts.qazaRecords),
            l10n.guestDailySalahRecordCount(counts.dailySalahRecords),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.commonDelete),
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
          l10n.guestDeleteScheduled(
            MaterialLocalizations.of(context).formatMediumDate(expiry),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _undoDeletion(LocalWorkspaceDeletionHold hold) async {
    final l10n = AppLocalizations.of(context);
    try {
      final undone = await ref
          .read(accountLocalStoreProvider)
          .undoGuestWorkspaceDeletion(hold.localAccountId);
      await _reload();
      if (mounted) {
        _showMessage(
          undone ? l10n.guestUndoSuccess : l10n.guestUndoUnavailable,
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
    final theme = Theme.of(context);
    return AppScaffold(
      title: l10n.accountGuestTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: l10n.guestCreateNewAction,
          onPressed: _startNewGuestWorkspace,
        ),
      ],
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
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_workspaces.isEmpty)
                      ListTile(
                        leading: const Icon(Icons.person_outline_rounded),
                        title: Text(l10n.guestNoWorkspaces),
                      ),
                    for (final workspace in _workspaces) ...[
                      () {
                        final isActive =
                            workspace.localAccountId == _activeWorkspaceId;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isActive
                                ? BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 1.5,
                                  )
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            key: Key(
                              'guest_workspace_${workspace.localAccountId}',
                            ),
                            onTap: () => _resumeWorkspace(workspace),
                            leading: Icon(
                              isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.person_outline_rounded,
                              color:
                                  isActive ? theme.colorScheme.primary : null,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    guestWorkspaceDisplayLabel(
                                      workspace,
                                      _workspaces,
                                      fallbackName: l10n.accountGuest,
                                    ),
                                    style: TextStyle(
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      l10n.guestActiveBadge,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              workspace.lifecycleState ==
                                      AccountLifecycleState.draft
                                  ? l10n.guestSetupInProgress
                                  : isActive
                                      ? l10n.guestActiveWorkspaceDescription
                                      : l10n.guestCreatedDate(
                                          MaterialLocalizations.of(context)
                                              .formatMediumDate(
                                            workspace.createdAt,
                                          ),
                                        ),
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: l10n.guestRenameTitle,
                              onSelected: (action) {
                                if (action == 'rename') {
                                  _renameWorkspace(workspace);
                                } else if (action == 'delete') {
                                  _deleteWorkspace(workspace);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text(l10n.guestRenameAction),
                                ),
                                if (!isActive)
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.commonDelete),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }(),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: _startNewGuestWorkspace,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.guestCreateNewAction),
                    ),
                    if (_holds.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        l10n.guestRecentlyDeletedTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.guestRecentlyDeletedSubtitle,
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
                              l10n.guestScheduledDeletion(
                                MaterialLocalizations.of(context)
                                    .formatMediumDate(hold.expiresAt),
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () => _undoDeletion(hold),
                              child: Text(l10n.guestUndoAction),
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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.guestRenameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 50,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: l10n.guestRenameLabel,
          hintText: l10n.guestRenameHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.commonContinue),
        ),
      ],
    );
  }
}
