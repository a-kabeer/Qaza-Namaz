import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../shell/workspace_shell.dart';

class PreviousQazaChoiceScreen extends StatelessWidget {
  const PreviousQazaChoiceScreen({
    super.key,
    required this.setupScreenBuilder,
  });

  final Widget Function() setupScreenBuilder;

  void _select(BuildContext context, PreviousQazaChoice choice) {
    if (choice == PreviousQazaChoice.skip) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const WorkspaceShell(),
        ),
        (_) => false,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => setupScreenBuilder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingPreviousQazaTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: [
                Icon(
                  Icons.checklist_rtl_rounded,
                  size: 56,
                  color: scheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.onboardingPreviousQazaTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.onboardingPreviousQazaIntro,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                _ChoiceCard(
                  key: const Key('onboarding_previous_qaza_setup'),
                  icon: Icons.calculate_outlined,
                  title: l10n.onboardingPreviousQazaSetUp,
                  subtitle: l10n.onboardingPreviousQazaSetUpDescription,
                  onPressed: () => _select(
                    context,
                    PreviousQazaChoice.setup,
                  ),
                ),
                const SizedBox(height: 12),
                _ChoiceCard(
                  key: const Key('onboarding_previous_qaza_skip'),
                  icon: Icons.arrow_forward_rounded,
                  title: l10n.onboardingPreviousQazaSkip,
                  subtitle: l10n.onboardingPreviousQazaSkipDescription,
                  onPressed: () => _select(
                    context,
                    PreviousQazaChoice.skip,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum PreviousQazaChoice { setup, skip }

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
