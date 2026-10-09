import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';

class CloudSetupChoiceScreen extends ConsumerStatefulWidget {
  const CloudSetupChoiceScreen({super.key});

  @override
  ConsumerState<CloudSetupChoiceScreen> createState() =>
      _CloudSetupChoiceScreenState();
}

class _CloudSetupChoiceScreenState
    extends ConsumerState<CloudSetupChoiceScreen> {
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restoreExistingAccount);
  }

  Future<void> _restoreExistingAccount() async {
    try {
      final account = await ref.read(cloudAccountStartupRestoreProvider.future);
      if (account.isConnected && mounted) {
        await _completeChoice();
      }
    } catch (_) {
      // Restoration failures must not block the explicit local-only choice.
    }
  }

  Future<void> _completeChoice() async {
    await ref.read(appDatabaseProvider).markCloudSetupChoiceComplete();
    ref.invalidate(cloudSetupChoiceCompleteProvider);
  }

  Future<void> _continueLocally() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await _completeChoice();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _connectGoogle() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final account = await ref.read(cloudAccountProvider).signIn();
      if (!account.isConnected) {
        if (mounted) {
          setState(() {
            _error = account.message ??
                AppLocalizations.of(context).cloudConnectionFailed;
          });
        }
        return;
      }
      await _completeChoice();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cloudSetupChoiceTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.cloudSetupChoiceTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.cloudSetupChoiceDescription,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  key: const Key('cloud_setup_connect_google'),
                  onPressed: _working ? null : _connectGoogle,
                  icon: _working
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_outlined),
                  label: Text(l10n.cloudSetupUseGoogle),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('cloud_setup_continue_local'),
                  onPressed: _working ? null : _continueLocally,
                  child: Text(l10n.cloudSetupContinueLocal),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
