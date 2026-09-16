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
  }

  Future<void> _pickTime(NotificationSettingsState value) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
      helpText: 'Choose daily reminder time',
    );
    if (picked == null || !mounted) return;
    await ref
        .read(notificationSettingsProvider.notifier)
        .setTime(picked.hour, picked.minute);
  }

  Future<void> _sendTest() async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    return AppScaffold(
      title: 'Notifications',
      body: settings.when(
        loading: () => const LoadingState(message: 'Loading notification settings…'),
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Card(
                child: SwitchListTile(
                  key: const Key('daily_notification_switch'),
                  value: value.enabled,
                  title: const Text('Daily Qaza reminder'),
                  subtitle: Text(
                    value.enabled
                        ? value.hasPendingQaza
                            ? 'Reminds you every day at ${value.formattedTime} while you have pending Qaza.'
                            : 'Enabled. It will resume automatically when pending Qaza exists.'
                        : 'Get one daily reminder to continue your Qaza routine.',
                  ),
                  onChanged: _setEnabled,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Reminder time'),
                  subtitle: Text(value.formattedTime),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: value.enabled,
                  onTap: value.enabled ? () => _pickTime(value) : null,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(permissionIcon, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              permissionTitle,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(permissionMessage),
                      if (permission == NotificationPermissionStatus.notRequested ||
                          permission == NotificationPermissionStatus.denied) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: OutlinedButton.icon(
                            key: const Key('notification_permission_action'),
                            onPressed: () => _setEnabled(true),
                            icon: const Icon(Icons.notifications_active_outlined),
                            label: Text(
                              permission == NotificationPermissionStatus.denied
                                  ? 'Try again'
                                  : 'Allow notifications',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Test notifications', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const Text('Send a notification now to confirm delivery is working.'),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Send test notification',
                        icon: Icons.send_outlined,
                        onPressed: value.canSendNotifications ? _sendTest : null,
                        expand: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Only one daily reminder is scheduled. It is automatically cancelled when there is no pending Qaza and restored when pending Qaza returns.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
