import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../l10n/app_localizations.dart';
import 'app_lock_controller.dart';

class AppLockSettingsScreen extends ConsumerWidget {
  const AppLockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(appLockControllerProvider);
    final controller = ref.read(appLockControllerProvider.notifier);

    if (!state.initialized) {
      return AppScaffold(
        title: l10n.settingsAppLock,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final timeoutEnabled = state.enabled && !state.authenticating;

    return AppScaffold(
      title: l10n.settingsAppLock,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          SettingsSection(
            title: l10n.settingsPrivacySecurity,
            subtitle: l10n.settingsPrivacySecuritySubtitle,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  key: const Key('app_lock_enabled'),
                  title: Text(l10n.settingsAppLock),
                  subtitle: Text(l10n.settingsAppLockSubtitle),
                  value: state.enabled,
                  onChanged: state.authenticating
                      ? null
                      : (enabled) => controller.setEnabled(
                            enabled: enabled,
                            localizedReason: enabled
                                ? l10n.appLockEnableReason
                                : l10n.appLockDisableReason,
                          ),
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      _errorMessage(l10n, state.error!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(l10n.settingsAppLockWhen),
                  subtitle: Text(_timeoutLabel(l10n, state.timeout)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _timeoutTile(
                  state: state,
                  controller: controller,
                  value: AppLockTimeout.immediate,
                  title: l10n.settingsAppLockImmediate,
                  enabled: timeoutEnabled,
                ),
                _timeoutTile(
                  state: state,
                  controller: controller,
                  value: AppLockTimeout.oneMinute,
                  title: l10n.settingsAppLockOneMinute,
                  enabled: timeoutEnabled,
                ),
                _timeoutTile(
                  state: state,
                  controller: controller,
                  value: AppLockTimeout.fiveMinutes,
                  title: l10n.settingsAppLockFiveMinutes,
                  enabled: timeoutEnabled,
                ),
                _timeoutTile(
                  state: state,
                  controller: controller,
                  value: AppLockTimeout.never,
                  title: l10n.settingsAppLockNever,
                  enabled: timeoutEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.settingsAppLockDeviceNote,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _timeoutTile({
    required AppLockState state,
    required AppLockController controller,
    required AppLockTimeout value,
    required String title,
    required bool enabled,
  }) {
    return RadioListTile<AppLockTimeout>(
      value: value,
      groupValue: state.timeout,
      onChanged: enabled
          ? (selected) {
              if (selected != null) {
                controller.setTimeout(selected);
              }
            }
          : null,
      title: Text(title),
    );
  }

  String _timeoutLabel(
    AppLocalizations l10n,
    AppLockTimeout timeout,
  ) {
    return switch (timeout) {
      AppLockTimeout.immediate => l10n.settingsAppLockImmediate,
      AppLockTimeout.oneMinute => l10n.settingsAppLockOneMinute,
      AppLockTimeout.fiveMinutes => l10n.settingsAppLockFiveMinutes,
      AppLockTimeout.never => l10n.settingsAppLockNever,
    };
  }

  String _errorMessage(AppLocalizations l10n, AppLockError error) {
    return switch (error) {
      AppLockError.unavailable => l10n.appLockUnavailable,
      AppLockError.canceled => l10n.appLockCanceled,
      AppLockError.temporarilyLocked => l10n.appLockTemporarilyLocked,
      AppLockError.failed => l10n.appLockFailed,
    };
  }
}
