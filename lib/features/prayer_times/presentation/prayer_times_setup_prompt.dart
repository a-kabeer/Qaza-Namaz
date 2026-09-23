import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import 'prayer_location_picker_screen.dart';
import '../prayer_times_providers.dart';
import 'prayer_times_controller.dart';
import '../data/location/prayer_location_service.dart';
import 'prayer_times_localizations.dart';

class PrayerTimesSetupPromptPreferences {
  const PrayerTimesSetupPromptPreferences(this._preferencesFuture);

  static const storageKey = 'prayer_times_setup_prompt_seen_v1';

  final Future<SharedPreferences> _preferencesFuture;

  Future<bool> hasSeen() async {
    final preferences = await _preferencesFuture;
    return preferences.getBool(storageKey) ?? false;
  }

  Future<void> markSeen() async {
    final preferences = await _preferencesFuture;
    await preferences.setBool(storageKey, true);
  }
}

final prayerTimesSetupPromptPreferencesProvider =
    Provider<PrayerTimesSetupPromptPreferences>((ref) {
  return PrayerTimesSetupPromptPreferences(SharedPreferences.getInstance());
});

class PrayerTimesSetupPromptGate extends ConsumerStatefulWidget {
  const PrayerTimesSetupPromptGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<PrayerTimesSetupPromptGate> createState() =>
      _PrayerTimesSetupPromptGateState();
}

class _PrayerTimesSetupPromptGateState
    extends ConsumerState<PrayerTimesSetupPromptGate> {
  bool _checking = false;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShow();
    });
  }

  Future<void> _maybeShow() async {
    if (_checking || _shown || !mounted) return;
    _checking = true;

    try {
      if (ref.read(activeUserIdProvider) == null) return;

      final preferences =
          ref.read(prayerTimesSetupPromptPreferencesProvider);
      if (await preferences.hasSeen()) return;

      final location =
          await ref.read(prayerTimesRepositoryProvider).getSavedLocation();
      if (location != null) return;

      if (!mounted) return;
      _shown = true;
      await _showPrompt();
    } finally {
      _checking = false;
    }
  }

  Future<void> _showPrompt() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const _PrayerTimesSetupDialog(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PrayerTimesSetupDialog extends ConsumerStatefulWidget {
  const _PrayerTimesSetupDialog();

  @override
  ConsumerState<_PrayerTimesSetupDialog> createState() =>
      _PrayerTimesSetupDialogState();
}

class _PrayerTimesSetupDialogState
    extends ConsumerState<_PrayerTimesSetupDialog> {
  bool _busy = false;

  Future<void> _markSeenAndClose() async {
    await ref
        .read(prayerTimesSetupPromptPreferencesProvider)
        .markSeen();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _useLocation() async {
    if (_busy) return;
    setState(() => _busy = true);

    await ref
        .read(prayerTimesControllerProvider.notifier)
        .useMyLocation();

    if (!mounted) return;
    final state = ref.read(prayerTimesControllerProvider);

    if (state.hasData && state.status != PrayerTimesStatus.locationError) {
      await _markSeenAndClose();
      return;
    }

    setState(() => _busy = false);
  }

  Future<void> _chooseCity() async {
    if (_busy) return;

    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PrayerLocationPickerScreen(),
      ),
    );

    if (!mounted) return;
    final location =
        await ref.read(prayerTimesRepositoryProvider).getSavedLocation();
    if (location != null) {
      await ref
          .read(prayerTimesSetupPromptPreferencesProvider)
          .markSeen();
    }
  }

  Future<void> _openSettings() async {
    await ref
        .read(prayerTimesControllerProvider.notifier)
        .openRelevantSettings();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prayerTimesControllerProvider);
    final errorKind = state.status == PrayerTimesStatus.locationError
        ? state.locationErrorKind
        : null;
    final theme = Theme.of(context);

    return AlertDialog(
      key: const Key('prayer_times_setup_prompt'),
      title: Text(PrayerTimesStrings.setupTitle(context)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(PrayerTimesStrings.setupMessage(context)),
          if (errorKind != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage(context, errorKind),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (errorKind == PrayerLocationErrorKind.permissionPermanentlyDenied)
          TextButton(
            onPressed: _busy ? null : _openSettings,
            child: Text(PrayerTimesStrings.openSettings(context)),
          ),
        TextButton(
          onPressed: _busy ? null : _chooseCity,
          child: Text(PrayerTimesStrings.setupChooseCity(context)),
        ),
        TextButton(
          onPressed: _busy ? null : _markSeenAndClose,
          child: Text(PrayerTimesStrings.setupNotNow(context)),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _useLocation,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded),
          label: Text(PrayerTimesStrings.setupUseLocation(context)),
        ),
      ],
    );
  }

  String _errorMessage(
    BuildContext context,
    PrayerLocationErrorKind kind,
  ) {
    return switch (kind) {
      PrayerLocationErrorKind.serviceDisabled =>
        PrayerTimesStrings.locationServiceDisabled(context),
      PrayerLocationErrorKind.permissionDenied =>
        PrayerTimesStrings.permissionDenied(context),
      PrayerLocationErrorKind.permissionPermanentlyDenied =>
        PrayerTimesStrings.permissionPermanentlyDenied(context),
      _ => PrayerTimesStrings.locationError(context),
    };
  }
}
