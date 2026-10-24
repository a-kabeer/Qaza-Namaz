import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_labels.dart';
import '../../core/widgets/language_selector.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/services/google_identity_contracts.dart';
import '../../l10n/app_localizations.dart';
import '../account/guest_workspace_label.dart';
import 'startup_gate.dart';

class AccountChoiceScreen extends ConsumerStatefulWidget {
  const AccountChoiceScreen({super.key});

  @override
  ConsumerState<AccountChoiceScreen> createState() =>
      _AccountChoiceScreenState();
}

class _AccountChoiceScreenState extends ConsumerState<AccountChoiceScreen> {
  late Locale _selectedLocale;
  bool _working = false;
  String? _error;
  static const String _startFreshChoice = '__start_fresh__';

  @override
  void initState() {
    super.initState();
    _selectedLocale = ref.read(localeProvider);
    Future<void>.microtask(_restoreExistingIdentity);
  }

  Future<void> _restoreExistingIdentity() async {
    if (!mounted || _working) return;
    setState(() => _working = true);
    try {
      final identity =
          await ref.read(googleIdentityStartupRestoreProvider.future);
      if (!mounted || !identity.isSignedIn) return;
      await _completeGoogleIdentity(identity);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = AppLocalizations.of(context).accountChoiceGoogleFailed);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _selectLanguage(Locale locale) {
    if (_working || locale == _selectedLocale) return;
    setState(() => _selectedLocale = locale);
    ref.read(localeProvider.notifier).preview(locale);
    ref.read(localeProvider.notifier).persist(locale);
  }

  Future<void> _activateGoogleWorkspace(
    String stableGoogleId,
    String? displayName,
  ) async {
    await ref.read(accountSessionManagerProvider).initialize();
    final id = stableGoogleId.trim();
    if (id.isEmpty) throw StateError('Google returned an empty account ID.');
    await ref.read(accountSessionManagerProvider).activateGoogleAccount(id);
    final workspaceId =
        ref.read(accountSessionManagerProvider).activeLocalAccountId;
    final name = displayName?.trim();
    if (workspaceId != null && name != null && name.isNotEmpty) {
      await ref
          .read(accountLocalStoreProvider)
          .saveWorkspaceDisplayName(workspaceId, name);
    }
    ref.invalidate(appRouteProvider);
  }

  Future<void> _connectGoogle() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref.read(localeProvider.notifier).set(_selectedLocale);
      final identity = await ref.read(googleIdentityProvider).signIn();
      if (!mounted || identity.status == GoogleIdentityStatus.cancelled) return;
      if (!identity.isSignedIn) {
        setState(() => _error = identity.message ??
            AppLocalizations.of(context).accountChoiceGoogleFailed);
        return;
      }
      await _completeGoogleIdentity(identity);
    } catch (_) {
      try {
        await ref.read(accountSessionManagerProvider).refresh();
      } catch (_) {
        // A failed local adoption is recovered through the existing startup
        // journal; never discard the Guest source or its recovery snapshot.
      }
      if (mounted) {
        setState(() =>
            _error = AppLocalizations.of(context).accountChoiceGoogleFailed);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _completeGoogleIdentity(
    GoogleIdentitySnapshot identity,
  ) async {
    final stableId = identity.accountId?.trim();
    if (stableId == null || stableId.isEmpty) {
      throw StateError('Google returned an empty account ID.');
    }

    await ref.read(accountSessionManagerProvider).initialize();
    final store = ref.read(accountLocalStoreProvider);
    final targetId = googleLocalWorkspaceId(stableId);
    final googleWorkspaceExists = await store.getAccount(targetId) != null;

    var selectedSource = _startFreshChoice;
    if (!googleWorkspaceExists) {
      final guests = await store.listGuestWorkspaces();
      if (guests.isNotEmpty) {
        final choice = await _chooseGuestAdoption(guests);
        if (!mounted || choice == null) {
          await ref.read(googleIdentityProvider).signOut();
          return;
        }
        selectedSource = choice;
      }
    }

    if (googleWorkspaceExists || selectedSource == _startFreshChoice) {
      await _activateGoogleWorkspace(stableId, identity.displayName);
      await _completeChoice();
      return;
    }

    // Provision the empty, account-isolated Google target first; then make the
    // chosen Guest active because the local adoption journal requires that
    // source to remain authoritative until the transaction commits.
    await ref
        .read(accountSessionManagerProvider)
        .activateGoogleAccount(stableId);
    await ref
        .read(accountSessionManagerProvider)
        .activateLocalAccount(selectedSource);
    await ref.read(localBackupServiceProvider).adoptGuestWorkspace(
          sourceLocalAccountId: selectedSource,
          targetGoogleLocalAccountId: targetId,
          googleDisplayName: identity.displayName?.trim() ?? '',
        );
    // Adoption updates the durable local session and DatabaseManager. Refresh
    // Riverpod's session mirror only after the local transaction commits.
    await ref.read(accountSessionManagerProvider).refresh();
    ref.invalidate(appRouteProvider);
    await _completeChoice();
  }

  Future<String?> _chooseGuestAdoption(List<LocalAccount> guests) {
    final l10n = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountChoiceAdoptGuestTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.accountChoiceAdoptGuestMessage),
              const SizedBox(height: 8),
              for (final guest in guests)
                ListTile(
                  key: Key('google_adopt_guest_${guest.localAccountId}'),
                  leading: const Icon(Icons.move_to_inbox_outlined),
                  title: Text(guestWorkspaceDisplayLabel(
                    guest,
                    guests,
                    fallbackName: l10n.accountGuest,
                  )),
                  subtitle: Text(l10n.accountChoiceAdoptGuestOption),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(guest.localAccountId),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('google_workspace_start_fresh'),
            onPressed: () => Navigator.of(dialogContext).pop(_startFreshChoice),
            child: Text(l10n.accountChoiceGoogleStartFresh),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Future<String?> _chooseGuestWorkspace(List<LocalAccount> guests) {
    final l10n = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountChoiceContinueGuest),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.accountChoiceGuestDescription),
              const SizedBox(height: 8),
              for (final guest in guests)
                ListTile(
                  key: Key('guest_workspace_choice_${guest.localAccountId}'),
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(guestWorkspaceDisplayLabel(
                    guest,
                    guests,
                    fallbackName: l10n.accountGuest,
                  )),
                  subtitle: Text(
                    guest.lifecycleState == AccountLifecycleState.draft
                        ? 'Setup in progress · Continue this workspace'
                        : l10n.accountChoiceGuestDescription,
                  ),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(guest.localAccountId),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('guest_workspace_start_fresh'),
            onPressed: () => Navigator.of(dialogContext).pop(_startFreshChoice),
            child: const Text('Start Fresh'),
          ),
        ],
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref.read(localeProvider.notifier).set(_selectedLocale);
      await ref.read(accountSessionManagerProvider).initialize();
      final store = ref.read(accountLocalStoreProvider);
      final guests = await store.listGuestWorkspaces();
      String selectedId;
      if (guests.isEmpty) {
        selectedId = await store.startFreshGuestWorkspace();
      } else {
        final choice = await _chooseGuestWorkspace(guests);
        if (!mounted || choice == null) return;
        selectedId = choice == _startFreshChoice
            ? await store.startFreshGuestWorkspace()
            : choice;
      }
      await ref
          .read(accountSessionManagerProvider)
          .activateLocalAccount(selectedId);
      ref.invalidate(appRouteProvider);
      await _completeChoice();
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).errorUnknown);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _completeChoice() async {
    final database = ref.read(appDatabaseProvider);
    await database.clearReturningAccountChoicePending();
    // This existing durable marker now means the local account-choice flow has
    // completed; it does not imply any cloud service is configured.
    await database.markAccountChoiceComplete();
    ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = true;
    ref.invalidate(startupAccountWorkspaceRestoreProvider);
    ref.invalidate(returningAccountChoicePendingProvider);
    ref.invalidate(accountChoiceCompleteProvider);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const StartupGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        actions: [
          PopupMenuButton<AppThemeMode>(
            key: const Key('account_choice_theme_selector'),
            tooltip: l10n.settingsThemeSelector,
            onSelected: ref.read(themeModeProvider.notifier).set,
            itemBuilder: (context) => AppThemeMode.values
                .map((value) => PopupMenuItem<AppThemeMode>(
                      value: value,
                      child: Row(
                        children: [
                          Expanded(child: Text(appThemeModeLabel(l10n, value))),
                          if (value == mode) const Icon(Icons.check_rounded),
                        ],
                      ),
                    ))
                .toList(growable: false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                '${l10n.settingsThemeSelector}: ${appThemeModeLabel(l10n, mode)}',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LanguageSelector<Locale>(
              key: const Key('account_choice_language_selector'),
              options: AppLocalizations.supportedLocales
                  .map((locale) => LanguageOption<Locale>(
                        value: locale,
                        languageCode: locale.languageCode,
                        scriptCode: locale.scriptCode,
                      ))
                  .toList(growable: false),
              value: _selectedLocale,
              layout: LanguageSelectorLayout.compact,
              semanticLabel: l10n.profileLanguageTitle,
              optionKeyPrefix: 'account_choice_language',
              enabled: !_working,
              onChanged: _selectLanguage,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              children: [
                Center(
                  child: Image.asset(
                    'assets/branding/qaza_namaz_logo.png',
                    width: 88,
                    height: 88,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.accountChoiceHeadline,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.accountChoiceDescription,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    key: const Key('account_choice_google_login'),
                    onPressed: _working ? null : _connectGoogle,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: Text(l10n.accountChoiceContinueGoogle),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('account_choice_continue_guest'),
                    onPressed: _working ? null : _continueAsGuest,
                    child: Text(l10n.accountChoiceContinueGuest),
                  ),
                ),
                if (_working) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
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
