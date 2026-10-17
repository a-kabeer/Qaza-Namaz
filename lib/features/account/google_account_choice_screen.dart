import 'package:flutter/material.dart';

import '../../core/widgets/app_scaffold.dart';
import '../../domain/services/cloud_sync_contracts.dart';
import '../../l10n/app_localizations.dart';

/// Opens account selection and returns a remembered stable account ID, an
/// empty string for a new Google account, or null when the user cancels.
Future<String?> showGoogleAccountChoiceScreen(
  BuildContext context,
  CloudAccountProvider provider,
) async {
  final accounts = await provider.rememberedAccounts();
  if (!context.mounted) return null;
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (_) => GoogleAccountChoiceScreen(accounts: accounts),
    ),
  );
}

class GoogleAccountChoiceScreen extends StatelessWidget {
  const GoogleAccountChoiceScreen({super.key, required this.accounts});

  final List<RememberedCloudAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.cloudAccountChoiceTitle,
      onBack: () => Navigator.of(context).pop(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.cloudAccountChoiceDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final email = account.email?.trim();
                      final label = account.label;
                      return ListTile(
                        key: ValueKey('remembered_google_account_${account.accountId}'),
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: CircleAvatar(
                          backgroundImage: _safePhoto(account.photoUrl) == null
                              ? null
                              : NetworkImage(_safePhoto(account.photoUrl)!),
                          child: _safePhoto(account.photoUrl) == null
                              ? const Icon(Icons.person_outline_rounded)
                              : null,
                        ),
                        title: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: email == null || email.isEmpty || email == label
                            ? null
                            : Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).pop(account.accountId),
                      );
                    },
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('continue_with_new_google_account'),
                onPressed: () => Navigator.of(context).pop(''),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.cloudContinueNewAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _safePhoto(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
      return null;
    }
    return raw;
  }
}
