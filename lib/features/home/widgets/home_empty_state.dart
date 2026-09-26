import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../qaza/qaza_navigation.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key, this.onAddQaza});

  final VoidCallback? onAddQaza;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      key: const Key('home_empty_state'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, AppSpacing.fabClearance),
      children: [
        const SizedBox(height: 6),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: l10n.homeHeadingSetup,
              message: l10n.homeSetupMessage,
              child: FilledButton.icon(
                key: const Key('home_empty_add_qaza'),
                onPressed: onAddQaza ?? () => openAddQaza(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.homeAddQaza),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
