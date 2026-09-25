import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_user.dart';
import '../../l10n/app_localizations.dart';
import 'guest_session.dart';
import 'guest_upgrade_controller.dart';

class AuthenticationScreen extends ConsumerStatefulWidget {
  const AuthenticationScreen({super.key, this.closeWhenDecided = false});

  /// Pop this route once the guest data decision is settled.
  ///
  /// Set when the screen is pushed from inside the app - from Settings, say -
  /// purely to collect the Merge / Use Account / Keep Guest choice. The
  /// startup journey leaves it false, because there `AuthGate` decides what
  /// comes next and this route is not on anyone's stack.
  final bool closeWhenDecided;

  @override
  ConsumerState<AuthenticationScreen> createState() =>
      _AuthenticationScreenState();
}

class _AuthenticationScreenState extends ConsumerState<AuthenticationScreen> {
  String? notice;

  /// Closes an in-app decision route as soon as the decision is settled.
  void _popWhenDecided(GuestUpgradeState? previous, GuestUpgradeState next) {
    if (!widget.closeWhenDecided) return;
    if (previous?.awaitingDecision != true) return;
    if (next.awaitingDecision || next.running) return;
    if (!mounted) return;
    // Merge, Use Account and Keep Guest all land here; whichever it was, the
    // caller reports the outcome on the screen underneath.
    Navigator.of(context).maybePop();
  }

  Future<void> _google() async {
    if (ref.read(guestUpgradeControllerProvider).running) return;
    setState(() => notice = null);

    final ok = await ref
        .read(guestUpgradeControllerProvider.notifier)
        .signInAndMigrate();

    if (!mounted || ok) return;
    final error = ref.read(guestUpgradeControllerProvider).error;
    // Genuine Google cancellation is intentionally silent. Configuration,
    // Firebase, and platform failures still carry their diagnostic error.
    if (error == null) return;
    setState(() => notice = error);
  }

  Future<void> _continueAsGuest() async {
    if (ref.read(guestUpgradeControllerProvider).running) return;
    await ref.read(guestSessionProvider.notifier).start();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    final upgrade = ref.watch(guestUpgradeControllerProvider);
    ref.listen<GuestUpgradeState>(guestUpgradeControllerProvider, _popWhenDecided);

    if (upgrade.restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (upgrade.pendingAccount != null) {
      return _GuestAccountChoice(
        account: upgrade.pendingAccount!,
        state: upgrade,
        onMerge: () => _confirmAndMerge(context),
        onUseAccount: () => _confirmUseAccount(context),
        onCancel: () => ref
            .read(guestUpgradeControllerProvider.notifier)
            .cancelAndKeepGuest(),
      );
    }

    final loading = upgrade.running;

    return PopScope<void>(
      canPop: !loading,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: loading ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(l10n.authTitle),
          actions: [
            IconButton(
              onPressed: () => _showHelp(context),
              tooltip: l10n.authHelpTooltip,
              icon: const Icon(Icons.help_outline_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 28),
                    Text(
                      l10n.authWelcomeBack,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.authSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (upgrade.error != null || notice != null) ...[
                      _Notice(
                        message: upgrade.error ?? notice!,
                        onClose: () => setState(() => notice = null),
                      ),
                      const SizedBox(height: 14),
                    ],
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: loading ? null : _google,
                        icon: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.g_mobiledata_rounded),
                        label: Text(
                          loading
                              ? l10n.authSigningIn
                              : l10n.authContinueWithGoogle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      key: const Key('auth_continue_as_guest'),
                      onPressed: loading ? null : _continueAsGuest,
                      child: Text(l10n.authContinueAsGuest),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.authGuestNote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.authProviderNote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndMerge(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Keep previous records and add new ones?',
      body: 'Your current Qaza records will be added to the records already '
          'saved to your account. The same prayer on the same date is kept '
          'only once, and completed records take precedence.',
      confirmLabel: 'Keep Previous + Add New',
    );
    if (!confirmed || !mounted) return;

    await ref.read(guestUpgradeControllerProvider.notifier).mergeData();
  }

  Future<void> _confirmUseAccount(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Keep previous records?',
      body: 'Your records already saved to your account will be kept. The '
          'records currently on this device will be removed after you confirm.',
      confirmLabel: 'Keep Previous Records',
    );
    if (!confirmed || !mounted) return;

    await ref.read(guestUpgradeControllerProvider.notifier).useAccountData();
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: Key(confirmLabel.replaceAll(' ', '_').toLowerCase()),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.authHelpTitle),
        content: Text(l10n.authHelpBody),
        actions: const [CloseButton()],
      ),
    );
  }
}

class _GuestAccountChoice extends StatelessWidget {
  const _GuestAccountChoice({
    required this.account,
    required this.state,
    required this.onMerge,
    required this.onUseAccount,
    required this.onCancel,
  });

  final AppUser account;
  final GuestUpgradeState state;
  final VoidCallback onMerge;
  final VoidCallback onUseAccount;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope<void>(
      canPop: !state.running,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed:
                state.running ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: AppLocalizations.of(context).commonBack,
          ),
          title: const Text('Choose what to do'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                'Previous Qaza records found',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'You signed in as ${account.email}. We found Qaza records '
                'on this device that are separate from the records saved to '
                'your account. Nothing has been changed yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              _AccountDataSummary(summary: state.summary),
              const SizedBox(height: 20),
              _DecisionCard(
                actionKey: const Key('guest_decision_merge'),
                title: 'Keep Previous + Add New',
                description: 'Keep the records already saved to your account '
                    'and add the records from this device. The same prayer '
                    'and date is kept only once.',
                buttonLabel: 'Keep Previous + Add New',
                icon: Icons.add_to_photos_rounded,
                onPressed: state.running ? null : onMerge,
                filled: true,
              ),
              const SizedBox(height: 12),
              _DecisionCard(
                actionKey: const Key('guest_decision_use_account'),
                title: 'Keep Previous Records',
                description:
                    'Use the records already saved to your account. The '
                    'records currently on this device will be removed.',
                buttonLabel: 'Keep Previous Records',
                icon: Icons.cloud_done_rounded,
                onPressed: state.running ? null : onUseAccount,
              ),
              const SizedBox(height: 12),
              _DecisionCard(
                actionKey: const Key('guest_decision_keep_guest'),
                title: 'Cancel',
                description:
                    'Cancel sign-in and continue with the records currently '
                    'on this device. Nothing will be merged or deleted.',
                buttonLabel: 'Cancel',
                icon: Icons.undo_rounded,
                onPressed: state.running ? null : onCancel,
              ),
              if (state.running) ...[
                const SizedBox(height: 18),
                const Center(child: CircularProgressIndicator()),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 18),
                _Notice(
                  message: state.error!,
                  onClose: () {},
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDataSummary extends StatelessWidget {
  const _AccountDataSummary({required this.summary});

  final GuestDataSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Qaza records', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Previous account',
              total: summary.accountCount,
              completed: summary.accountCompleted,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'This device',
              total: summary.localCount,
              completed: summary.localCompleted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.total,
    required this.completed,
  });

  final String label;
  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '$total total • $completed completed',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({
    required this.actionKey,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final Key actionKey;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 14),
            if (filled)
              FilledButton(
                key: actionKey,
                onPressed: onPressed,
                child: Text(buttonLabel),
              )
            else
              OutlinedButton(
                key: actionKey,
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.mosque_rounded,
            size: 36,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context).appTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 2),
        Text(
          'قضاء نماز',
          style: AppTypography.of(context)
              .urdu
              .bodyMedium
              ?.copyWith(color: scheme.secondary),
        ),
        const SizedBox(height: 2),
        Text(
          AppLocalizations.of(context).welcomeTagline,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: AppLocalizations.of(context).authDismiss,
          ),
        ],
      ),
    );
  }
}
