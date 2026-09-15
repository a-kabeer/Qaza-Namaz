import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_widgets.dart';
import '../notifications/notification_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    return AppScaffold(
      title: 'Notifications',
      body: settings.when(
        loading: () => const LoadingState(message: 'Loading notification settings…'),
        error: (error, stack) => ErrorState(
          message: 'Notification settings could not be loaded: $error',
          onRetry: () => ref.invalidate(notificationSettingsProvider),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: SwitchListTile(
                key: const Key('daily_notification_switch'),
                value: value.enabled,
                title: const Text('Daily reminder'),
                subtitle: Text(value.enabled ? 'Reminder scheduled for ${value.formattedTime}.' : 'Turn on a daily reminder to continue your Qaza routine.'),
                onChanged: (enabled) async {
                  final ok = await ref.read(notificationSettingsProvider.notifier).setEnabled(enabled);
                  if (!enabled || ok || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission was not granted.')));
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Reminder time'),
                subtitle: Text(value.formattedTime),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: value.hour, minute: value.minute));
                  if (picked == null || !context.mounted) return;
                  await ref.read(notificationSettingsProvider.notifier).setTime(picked.hour, picked.minute);
                },
              ),
            ),
            const SizedBox(height: 12),
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('The reminder is stored on this device. Turning it off cancels the scheduled notification. No cloud notification service is used.'))),
          ],
        ),
      ),
    );
  }
}
