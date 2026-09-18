import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';

class AuthenticationScreen extends ConsumerStatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  ConsumerState<AuthenticationScreen> createState() =>
      _AuthenticationScreenState();
}

class _AuthenticationScreenState extends ConsumerState<AuthenticationScreen> {
  bool loading = false;
  String? notice;

  Future<void> _google() async {
    setState(() {
      loading = true;
      notice = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (_) {
      if (mounted)
        setState(() => notice = AppLocalizations.of(context).authFailed);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded)),
        title: Text(l10n.authTitle),
        actions: [
          IconButton(
              onPressed: () => _showHelp(context),
              tooltip: l10n.authHelpTooltip,
              icon: const Icon(Icons.help_outline_rounded))
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
                  Text(l10n.authWelcomeBack,
                      style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(l10n.authSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant, height: 1.45)),
                  const SizedBox(height: 18),
                  if (notice != null) ...[
                    _Notice(
                        message: notice!,
                        onClose: () => setState(() => notice = null)),
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
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.g_mobiledata_rounded),
                      label: Text(loading
                          ? l10n.authSigningIn
                          : l10n.authContinueWithGoogle),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(l10n.authProviderNote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
                color: scheme.primary.withOpacity(.10),
                borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.mosque_rounded, size: 36, color: scheme.primary)),
        const SizedBox(height: 12),
        Text(AppLocalizations.of(context).appTitle,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text('قضاء نماز',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.secondary)),
        const SizedBox(height: 2),
        Text(AppLocalizations.of(context).welcomeTagline,
            style: Theme.of(context).textTheme.bodySmall),
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
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: scheme.onErrorContainer))),
          IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              tooltip: AppLocalizations.of(context).authDismiss),
        ],
      ),
    );
  }
}
