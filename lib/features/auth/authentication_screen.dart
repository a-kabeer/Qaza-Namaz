import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_user.dart';
import '../../l10n/app_localizations.dart';
import 'guest_session.dart';
import 'guest_upgrade_controller.dart';

class AuthenticationScreen extends ConsumerStatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  ConsumerState<AuthenticationScreen> createState() =>
      _AuthenticationScreenState();
}

class _AuthenticationScreenState extends ConsumerState<AuthenticationScreen> {
  String? notice;

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

    return Scaffold(
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
    );
  }

  Future<void> _confirmAndMerge(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Merge guest progress?',
      body: 'Your guest and Google account Qaza records will be combined. '
          'A matching prayer/date is kept only once, and a completed record '
          'always wins over a pending record. Your guest records are retired '
          'only after the account migration succeeds.',
      confirmLabel: 'Merge Data',
    );
    if (!confirmed || !mounted) return;

    await ref.read(guestUpgradeControllerProvider.notifier).mergeData();
  }

  Future<void> _confirmUseAccount(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Use account data?',
      body: 'Your existing Google account Qaza ledger will be kept unchanged. '
          'Your guest records will be permanently retired from this device '
          'after you confirm. This choice does not merge guest records.',
      confirmLabel: 'Use Account Data',
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

    return Scaffold(
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
              'Guest progress found',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'You signed in as ${account.email}. Your guest Qaza records '
              'are still on this device. Nothing has been merged or deleted.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            _DecisionCard(
              title: 'Merge Data',
              description: 'Combine guest and account records. Duplicate '
                  'prayer/date combinations become one record; completed '
                  'always wins over pending. Guest data is retired only '
                  'after a successful migration.',
              buttonLabel: 'Merge Data',
              icon: Icons.merge_type_rounded,
              onPressed: state.running ? null : onMerge,
              filled: true,
            ),
            const SizedBox(height: 12),
            _DecisionCard(
              title: 'Use Account Data',
              description:
                  'Keep the Google account ledger as-is. Guest records are '
                  'discarded/retired only after you explicitly confirm.',
              buttonLabel: 'Use Account Data',
              icon: Icons.cloud_done_rounded,
              onPressed: state.running ? null : onUseAccount,
            ),
            const SizedBox(height: 12),
            _DecisionCard(
              title: 'Keep Guest Data / Cancel Sign-In',
              description:
                  'Sign out of the Google account and continue in guest mode. '
                  'Your guest records remain unchanged.',
              buttonLabel: 'Keep Guest Data',
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
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({
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
              FilledButton(onPressed: onPressed, child: Text(buttonLabel))
            else
              OutlinedButton(
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
