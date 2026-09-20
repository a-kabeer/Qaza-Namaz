import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../notifications/notification_controller.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationSettingsProvider.notifier).refreshPermissionStatus();
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_working) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _working = true);
    try {
      final ok = await ref
          .read(notificationSettingsProvider.notifier)
          .setEnabled(enabled);
      if (!mounted || ok) return;

      final value = ref.read(notificationSettingsProvider).valueOrNull;
      if (!enabled && value?.schedulerAvailable == false) {
        return;
      }

      final message = switch (value?.permissionStatus) {
              NotificationPermissionStatus.denied =>
                l10n.notificationsBlockedDetail,
              NotificationPermissionStatus.permanentlyDenied =>
                l10n.notificationsEnableInSettings,
              NotificationPermissionStatus.unavailable =>
                l10n.notificationsUnavailableDetail,
              _ => l10n.notificationsEnableFailed,
            };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickTime(NotificationSettingsState value) async {
    if (_working || !value.enabled) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
      helpText: AppLocalizations.of(context).notificationsChooseTime,
    );
    if (picked == null || !mounted) return;

    setState(() => _working = true);
    try {
      await ref
          .read(notificationSettingsProvider.notifier)
          .setTime(picked.hour, picked.minute);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openSystemSettings() async {
    if (_working) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _working = true);
    try {
      final opened = await ref
          .read(notificationSettingsProvider.notifier)
          .openSystemSettings();
      if (!mounted || opened) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationsEnableInSettings)),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _sendTest() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await ref
          .read(notificationSettingsProvider.notifier)
          .sendTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).notificationsTestSent),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).notificationsTestFailed('$error'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(notificationSettingsProvider);

    return AppScaffold(
      title: l10n.notificationsTitle,
      body: settings.when(
        loading: () => LoadingState(
          key: const Key('notifications_loading_state'),
          message: l10n.notificationsLoading,
        ),
        error: (error, stack) => ErrorState(
          key: const Key('notifications_error_state'),
          message: l10n.notificationsLoadError('$error'),
          onRetry: () =>
              ref.read(notificationSettingsProvider.notifier).reload(),
        ),
        data: (value) {
          final theme = Theme.of(context);
          final permission = value.permissionStatus;

          final permissionTitle = switch (permission) {
            NotificationPermissionStatus.granted => l10n.notificationsAllowed,
            NotificationPermissionStatus.notRequested =>
              l10n.notificationsPermissionNeeded,
            NotificationPermissionStatus.denied => l10n.notificationsBlocked,
            NotificationPermissionStatus.permanentlyDenied =>
              l10n.notificationsBlocked,
            NotificationPermissionStatus.appNotificationsDisabled =>
              l10n.notificationsAppDisabled,
            NotificationPermissionStatus.reminderChannelDisabled =>
              l10n.notificationsChannelDisabled,
            NotificationPermissionStatus.unavailable =>
              l10n.notificationsUnavailable,
            NotificationPermissionStatus.restricted =>
              l10n.notificationsRestricted,
          };

          final permissionMessage = switch (permission) {
            NotificationPermissionStatus.granted =>
              l10n.notificationsDeviceCanDeliver,
            NotificationPermissionStatus.notRequested =>
              l10n.notificationsAllowPrompt,
            NotificationPermissionStatus.denied =>
              l10n.notificationsAllowPrompt,
            NotificationPermissionStatus.permanentlyDenied =>
              l10n.notificationsEnableInSettings,
            NotificationPermissionStatus.appNotificationsDisabled =>
              l10n.notificationsAppDisabledDetail,
            NotificationPermissionStatus.reminderChannelDisabled =>
              l10n.notificationsChannelDisabledDetail,
            NotificationPermissionStatus.unavailable =>
              l10n.notificationsUnavailableDetail,
            NotificationPermissionStatus.restricted =>
              l10n.notificationsRestrictedDetail,
          };

          final permissionIcon = switch (permission) {
            NotificationPermissionStatus.granted =>
              Icons.check_circle_outline_rounded,
            NotificationPermissionStatus.notRequested =>
              Icons.notifications_active_outlined,
            NotificationPermissionStatus.denied =>
              Icons.notifications_off_outlined,
            NotificationPermissionStatus.permanentlyDenied =>
              Icons.notifications_off_outlined,
            NotificationPermissionStatus.appNotificationsDisabled =>
              Icons.notifications_off_outlined,
            NotificationPermissionStatus.reminderChannelDisabled =>
              Icons.notifications_off_outlined,
            NotificationPermissionStatus.unavailable =>
              Icons.error_outline_rounded,
            NotificationPermissionStatus.restricted =>
              Icons.lock_outline_rounded,
          };

          final reminderEnabled = value.enabled && !_working;
          final testEnabled =
              value.schedulerAvailable &&
              permission != NotificationPermissionStatus.unavailable &&
              permission != NotificationPermissionStatus.restricted &&
              permission != NotificationPermissionStatus.permanentlyDenied &&
              permission != NotificationPermissionStatus.appNotificationsDisabled &&
              permission != NotificationPermissionStatus.reminderChannelDisabled &&
              !_working;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                l10n.notificationsDailyToggle,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.notificationsDailySubtitle,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  key: const Key('daily_notification_switch'),
                  value: value.enabled,
                  title: Text(l10n.notificationsDailyTitle),
                  subtitle: Text(
                    !value.enabled
                        ? l10n.notificationsOff
                        : !value.pendingCountKnown
                            ? l10n.notificationsPendingUnknown
                            : value.hasPendingQaza
                                ? l10n.notificationsOnAt(value.formattedTime)
                                : l10n.notificationsOnPendingWait,
                  ),
                  onChanged: _working ? null : _setEnabled,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  key: const Key('reminder_time_tile'),
                  leading: Icon(
                    Icons.schedule_outlined,
                    color: reminderEnabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                  title: Text(l10n.notificationsReminderTime),
                  subtitle: Text(
                    value.enabled
                        ? l10n.notificationsEveryDayAt(value.formattedTime)
                        : l10n.notificationsEnableToChangeTime,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: reminderEnabled,
                  onTap: reminderEnabled ? () => _pickTime(value) : null,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  key: const Key('notification_permission_status'),
                  leading: Icon(permissionIcon),
                  title: Text(permissionTitle),
                  subtitle: Text(permissionMessage),
                  trailing: switch (permission) {
                    NotificationPermissionStatus.notRequested => TextButton(
                        key: const Key('notification_permission_allow'),
                        onPressed: _working ? null : () => _setEnabled(true),
                        child: Text(l10n.notificationsAllow),
                      ),
                    NotificationPermissionStatus.denied => TextButton(
                        key: const Key('notification_permission_retry'),
                        onPressed: _working ? null : () => _setEnabled(true),
                        child: Text(l10n.notificationsTryAgain),
                      ),
                    NotificationPermissionStatus.permanentlyDenied ||
                    NotificationPermissionStatus.appNotificationsDisabled ||
                    NotificationPermissionStatus.reminderChannelDisabled =>
                      TextButton(
                        key: const Key('notification_open_settings'),
                        onPressed: _working ? null : _openSystemSettings,
                        child: Text(
                          permission ==
                                  NotificationPermissionStatus.reminderChannelDisabled
                              ? l10n.notificationsEnableReminderNotifications
                              : l10n.notificationsOpenSettings,
                        ),
                      ),
                    _ => null,
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  key: const Key('notification_schedule_status'),
                  leading: Icon(
                    value.enabled && value.hasPendingQaza
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined,
                  ),
                  title: Text(l10n.notificationsStatusHeading),
                  subtitle: Text(_scheduleText(l10n, value)),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  key: const Key('test_notification_action'),
                  leading: const Icon(Icons.send_outlined),
                  title: Text(l10n.notificationsSendTest),
                  subtitle: Text(l10n.notificationsSendTestSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: testEnabled,
                  onTap: testEnabled ? _sendTest : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _scheduleText(AppLocalizations l10n, NotificationSettingsState value) {
    if (!value.enabled) return l10n.notificationsOffStatus;
    if (!value.schedulerAvailable) {
      return l10n.notificationsUnavailableDetail;
    }
    switch (value.permissionStatus) {
      case NotificationPermissionStatus.appNotificationsDisabled:
        return l10n.notificationsAppDisabledDetail;
      case NotificationPermissionStatus.reminderChannelDisabled:
        return l10n.notificationsChannelDisabledDetail;
      case NotificationPermissionStatus.permanentlyDenied:
      case NotificationPermissionStatus.denied:
      case NotificationPermissionStatus.notRequested:
        return l10n.notificationsPermissionRequired;
      case NotificationPermissionStatus.granted:
      case NotificationPermissionStatus.unavailable:
      case NotificationPermissionStatus.restricted:
        break;
    }
    if (!value.canSendNotifications) {
      return l10n.notificationsPermissionRequired;
    }
    if (!value.pendingCountKnown) return l10n.notificationsPendingUnknown;
    if (!value.hasPendingQaza) return l10n.notificationsNoPending;
    return l10n.notificationsScheduledAt(value.formattedTime);
  }
}
