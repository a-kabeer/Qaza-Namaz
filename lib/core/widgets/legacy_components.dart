import 'package:flutter/material.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/qaza_progress.dart';
import 'app_card.dart';
import 'app_scaffold.dart';
import 'confirmation_dialog.dart';
import 'date_display.dart';
import 'metric_tile.dart';
import 'section_header.dart';

class PageScaffold extends AppScaffold {
  const PageScaffold({
    super.key,
    required String title,
    required Widget child,
    VoidCallback? onBack,
    List<Widget> actions = const <Widget>[],
  }) : super(title: title, body: child, onBack: onBack, actions: actions);
}

class SectionHeading extends SectionHeader {
  const SectionHeading({super.key, required super.title, super.subtitle});
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.check_rounded),
        label: Text(label),
      );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color});
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? scheme.onPrimaryContainer.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 8),
          AppCard(padding: EdgeInsets.zero, child: child),
        ],
      );
}

class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({super.key, required this.icon, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class DestructiveActionRow extends StatelessWidget {
  const DestructiveActionRow({super.key, required this.icon, required this.label, required this.description, required this.confirmationTitle, required this.confirmationMessage, required this.confirmLabel, required this.onConfirm});
  final IconData icon;
  final String label;
  final String description;
  final String confirmationTitle;
  final String confirmationMessage;
  final String confirmLabel;
  final Future<void> Function() onConfirm;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.errorContainer.withValues(alpha: .35),
      padding: EdgeInsets.zero,
      onTap: () async {
        if (await confirmDestructive(context, title: confirmationTitle, message: confirmationMessage, confirmLabel: confirmLabel)) await onConfirm();
      },
      child: ListTile(
        leading: Icon(icon, color: scheme.error),
        title: Text(label, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
        subtitle: Text(description),
      ),
    );
  }
}

class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.user, required this.onSignOut});
  final AppUser user;
  final Future<void> Function() onSignOut;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty;
    final name = user.displayName == null || user.displayName!.isEmpty ? user.email : user.displayName!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(children: [
            CircleAvatar(radius: 28, backgroundColor: scheme.primaryContainer, foregroundImage: hasPhoto ? NetworkImage(user.photoUrl!) : null, child: Icon(Icons.person_rounded, color: scheme.onPrimaryContainer)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: theme.textTheme.titleMedium), const SizedBox(height: 2), Text(user.email.isEmpty ? 'Signed in with Google' : user.email)])),
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(padding: EdgeInsets.zero, child: const Column(children: [ListTile(leading: Icon(Icons.password_rounded), title: Text('Sign-in method'), subtitle: Text('Google authentication')), ListTile(leading: Icon(Icons.verified_user_rounded), title: Text('Account status'), subtitle: Text('Signed in'))])),
        const SizedBox(height: 16),
        Text('Developer context', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        AppCard(padding: EdgeInsets.zero, child: ListTile(leading: const Icon(Icons.code_rounded), title: const Text('Firebase UID'), subtitle: Text(user.id.isEmpty ? 'Not available' : user.id))),
        const SizedBox(height: 24),
        DestructiveActionRow(icon: Icons.logout, label: 'Sign out', description: 'Signing out returns you to the welcome screen. Your Qaza records are saved in the cloud and are NOT deleted.', confirmLabel: 'Sign out', confirmationTitle: 'Sign out?', confirmationMessage: 'Signing out returns you to the welcome screen. Your saved Qaza records are NOT deleted and will be restored the next time you sign in.', onConfirm: onSignOut),
      ],
    );
  }
}

String formatDate(DateTime? date) => formatAppDate(date);
String formatDateTime(DateTime? value) => formatAppDateTime(value);

class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, this.size = 72, this.strokeWidth = 6});
  final double progress;
  final double size;
  final double strokeWidth;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(width: size, height: size, child: Stack(alignment: Alignment.center, children: [CircularProgressIndicator(value: progress, strokeWidth: strokeWidth, backgroundColor: scheme.onPrimaryContainer.withValues(alpha: .18), color: scheme.secondary), Text('${(progress * 100).round()}%', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700))]));
  }
}

class ProgressOverviewCard extends StatelessWidget {
  const ProgressOverviewCard({super.key, required this.progress, this.header});
  final QazaProgress progress;
  final Widget? header;
  @override
  Widget build(BuildContext context) {
    final total = progress.pending + progress.completed;
    final ratio = total == 0 ? 0.0 : progress.completed / total;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (header != null) ...[header!, const SizedBox(height: 16)],
        Row(children: [Expanded(child: MetricTile(label: 'Pending', value: '${progress.pending}')), Expanded(child: MetricTile(label: 'Completed', value: '${progress.completed}')), Expanded(child: MetricTile(label: 'Total', value: '$total'))]),
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: ratio, minHeight: 10)),
        const SizedBox(height: 8),
        Text(total == 0 ? 'No records yet' : '${(ratio * 100).round()}% completed'),
      ]),
    );
  }
}
