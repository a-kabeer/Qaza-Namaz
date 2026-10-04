
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/local_account.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../l10n/app_localizations.dart';

class AccountChoiceScreen extends ConsumerWidget {
  const AccountChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(accountSessionManagerProvider).state.phase ==
        AccountSessionPhase.connecting;

    return AppScaffold(
      title: l10n.accountTitle,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.accountTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => ref
                        .read(accountSessionManagerProvider.notifier)
                        .connectGoogle(),
                icon: const Icon(Icons.login_rounded),
                label: Text(l10n.accountConnectGoogle),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy
                    ? null
                    : () => ref
                        .read(accountSessionManagerProvider.notifier)
                        .continueAsGuest(),
                child: Text(l10n.accountGuest),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
