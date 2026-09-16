import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_widgets.dart';
import '../notifications/notification_controller.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
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
    setState(() => _working = true);
    try {
      final ok = await ref
          .read(notificationSettingsProvider.notifier)
          .setEnabled(enabled);
      if (!mounted || ok || !enabled) return;
      final value = ref.read(notificationSettingsProvider).valueOrNull;
      final message = value?.permissionStatus ==
              NotificationPermissionStatus.denied
          ? 'Notifications are blocked. Allow them in system settings, then try again.'
          : 'Notifications could not be enabled on this device.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickTime(NotificationSettingsState value) async {
    if (_working || !value.enabled) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
      helpText: 'Choose daily reminder time',
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

  Future<void> _sendTest() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await ref.read(notificationSettingsProvider.notifier).sendTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test notification failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    return AppScaffold(
      title: 'Notifications',
      body: settings.when(
        loading: () =>
            const LoadingState(message: 'Loading notification settings…'),
        error: (error, stack) => ErrorState(
          message: 'Notification settings could not be loaded: $error',
          onRetry: () => ref.invalidate(notificationSettingsProvider),
        ),
        data: (value) {
          final theme = Theme.of(context);
          final permission = value.permissionStatus;
          final permissionTitle = switch (permission) {
            NotificationPermissionStatus.granted => 'Notifications allowed',
            NotificationPermissionStatus.notRequested => 'Permission needed',
            NotificationPermissionStatus.denied => 'Notifications blocked',
            NotificationPermissionStatus.unavailable => 'Notifications unavailable',
          };
          final permissionMessage = switch (permission) {
            NotificationPermissionStatus.granted => 'This device can deliver your reminder.',
            NotificationPermissionStatus.notRequested => 'Allow notifications so the app can remind you.',
            NotificationPermissionStatus.denied => 'Enable notifications in system settings to use reminders.',
            NotificationPermissionStatus.unavailable => 'Notifications are not available on this device.',
          };
          final permissionIcon = switch (permission) {
            NotificationPermissionStatus.granted => Icons.check_circle_outline_rounded,
            NotificationPermissionStatus.notRequested => Icons.notifications_active_outlined,
            NotificationPermissionStatus.denied => Icons.notifications_off_outlined,
            NotificationPermissionStatus.unavailable => Icons.error_outline_rounded,
          };
          final reminderEnabled = value.enabled && !_working;
          final testEnabled = value.canSendNotifications && !_working;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'Daily reminder',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Get one gentle reminder to continue pending Qaza prayers.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  key: const Key('daily_notification_switch'),
                  value: value.enabled,
                  title: const Text('Daily Qaza reminder'),
                  subtitle: Text(
                    value.enabled
                        ? value.hasPendingQaza
                            ? 'On • ${value.formattedTime}'
                            : 'On • starts when pending Qaza exists'
                        : 'Off',
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
                  title: const Text('Reminder time'),
                  subtitle: Text(
                    value.enabled
                        ? 'Every day at ${value.formattedTime}'
                        : 'Enable the reminder to change the time',
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
                  trailing: permission ==
                          NotificationPermissionStatus.notRequested ||
                      permission == NotificationPermissionStatus.denied
                      ? TextButton(
                          onPressed: _working ? null : () => _setEnabled(true),
                          child: Text(
                            permission == NotificationPermissionStatus.denied
                                ? 'Try again'
                                : 'Allow',
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: Icon(
                    value.enabled && value.hasPendingQaza
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined,
                  ),
                  title: const Text('Reminder status'),
                  subtitle: Text(_scheduleText(value)),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  key: const Key('test_notification_action'),
                  leading: const Icon(Icons.send_outlined),
                  title: const Text('Send test notification'),
                  subtitle: const Text('Send one notification now to check delivery.'),
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

  String _scheduleText(NotificationSettingsState value) {
    if (!value.enabled) return 'Reminder is off.';
    if (!value.canSendNotifications) return 'Notification permission is required.';
    if (!value.hasPendingQaza) return 'No pending Qaza. No reminder is scheduled.';
    return 'Scheduled daily at ${value.formattedTime}.';
  }
}
