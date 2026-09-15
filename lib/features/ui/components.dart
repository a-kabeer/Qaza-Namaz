// Shared, application-wide UI components.
import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/calendar/calendar_labels.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/qaza_progress.dart';

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.title, required this.child, this.onBack, this.actions = const []});
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(leading: onBack == null ? null : IconButton(tooltip: 'Back', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)), title: Text(title), actions: actions), body: child);
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)]]);
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => icon == null ? FilledButton(onPressed: onPressed, child: Text(label)) : FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label));
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => icon == null ? OutlinedButton(onPressed: onPressed, child: Text(label)) : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label));
}

class IconActionButton extends StatelessWidget {
  const IconActionButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  @override
  Widget build(BuildContext context) => IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon), color: color);
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {this.color, super.key});
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color ?? scheme.onPrimaryContainer.withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: Text(label, style: Theme.of(context).textTheme.labelMedium)); }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.padding = 64, this.message});
  final double padding;
  final String? message;
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.all(padding), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), if (message != null) ...[const SizedBox(height: AppSpacing.md), Text(message!, style: Theme.of(context).textTheme.bodySmall)]])));
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.title = 'Something went wrong', this.icon = Icons.error_outline_rounded});
  final String message;
  final VoidCallback? onRetry;
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: scheme.onErrorContainer)), const SizedBox(height: AppSpacing.lg), Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: AppSpacing.sm), Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall), if (onRetry != null) ...[const SizedBox(height: AppSpacing.lg), SecondaryButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: onRetry)]]))); }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon = Icons.inbox_outlined, this.child});
  final String title;
  final String? message;
  final IconData icon;
  final Widget? child;
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: scheme.primary.withOpacity(.10), borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: scheme.primary)), const SizedBox(height: AppSpacing.lg), Text(title, style: Theme.of(context).textTheme.titleMedium), if (message != null) ...[const SizedBox(height: AppSpacing.sm), Text(message!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)], if (child != null) ...[const SizedBox(height: AppSpacing.lg), child!]]))); }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SectionHeading(title: title, subtitle: subtitle), const SizedBox(height: AppSpacing.sm), Card(child: child)]);
}

class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({super.key, required this.icon, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon), title: Text(title), subtitle: subtitle == null ? null : Text(subtitle!), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap);
}

Future<bool> confirmDestructive(BuildContext context, {required String title, required String message, required String confirmLabel}) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError), onPressed: () => Navigator.pop(dialogContext, true), child: Text(confirmLabel))]));
  return confirmed ?? false;
}

class DestructiveActionRow extends StatelessWidget {
  const DestructiveActionRow({super.key, required this.icon, required this.label, required this.description, required this.confirmationTitle, required this.confirmationMessage, required this.confirmLabel, required this.onConfirm});
  final IconData icon; final String label; final String description; final String confirmationTitle; final String confirmationMessage; final String confirmLabel; final Future<void> Function() onConfirm;
  Future<void> _handleTap(BuildContext context) async { if (await confirmDestructive(context, title: confirmationTitle, message: confirmationMessage, confirmLabel: confirmLabel)) await onConfirm(); }
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return Card(color: scheme.errorContainer.withOpacity(.35), child: ListTile(leading: Icon(icon, color: scheme.error), title: Text(label, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)), subtitle: Text(description), onTap: () => _handleTap(context))); }
}

class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.user, required this.onSignOut});
  final AppUser user; final Future<void> Function() onSignOut;
  String get _name => user.displayName == null || user.displayName!.isEmpty ? user.email : user.displayName!;
  @override
  Widget build(BuildContext context) { final theme = Theme.of(context); final scheme = theme.colorScheme; final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty; return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Row(children: [CircleAvatar(radius: 28, backgroundColor: scheme.primaryContainer, foregroundImage: hasPhoto ? NetworkImage(user.photoUrl!) : null, child: Icon(Icons.person_rounded, color: scheme.onPrimaryContainer)), const SizedBox(width: AppSpacing.lg), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_name, style: theme.textTheme.titleMedium), const SizedBox(height: 2), Text(user.email.isEmpty ? 'Signed in with Google' : user.email, style: theme.textTheme.bodyMedium)]))]))), const SizedBox(height: AppSpacing.lg), const Card(child: Column(children: [ListTile(leading: Icon(Icons.password_rounded), title: Text('Sign-in method'), subtitle: Text('Google authentication')), ListTile(leading: Icon(Icons.verified_user_rounded), title: Text('Account status'), subtitle: Text('Signed in'))])), const SizedBox(height: AppSpacing.lg), Text('Developer context', style: theme.textTheme.titleSmall), const SizedBox(height: AppSpacing.sm), Card(child: ListTile(leading: const Icon(Icons.code_rounded), title: const Text('Firebase UID'), subtitle: Text(user.id.isEmpty ? 'Not available' : user.id))), const SizedBox(height: AppSpacing.xl), DestructiveActionRow(icon: Icons.logout, label: 'Sign out', description: 'Signing out returns you to the welcome screen. Your Qaza records are saved in the cloud and are NOT deleted.', confirmLabel: 'Sign out', confirmationTitle: 'Sign out?', confirmationMessage: 'Signing out returns you to the welcome screen. Your saved Qaza records are NOT deleted and will be restored the next time you sign in.', onConfirm: onSignOut)]); }
}

String formatDate(DateTime? date) => date == null ? '—' : CalendarLabels.formatGregorianDatePadded(date);
String formatDateTime(DateTime? value) => value == null ? '—' : '${CalendarLabels.formatGregorianDatePadded(value)} ${CalendarLabels.formatClockTime(value)}';

extension PrayerTypeVisuals on PrayerType {
  IconData get icon => switch (this) { PrayerType.fajr => Icons.wb_twilight_rounded, PrayerType.zuhr => Icons.wb_sunny_rounded, PrayerType.asr => Icons.wb_sunny_outlined, PrayerType.maghrib => Icons.nights_stay_outlined, PrayerType.isha => Icons.dark_mode_outlined, PrayerType.witr => Icons.brightness_3_outlined };
  String get rakats => switch (this) { PrayerType.fajr => 'Fajr • 2 Rakat Fard', PrayerType.zuhr => 'Zuhr • 4 Rakat Fard', PrayerType.asr => 'Asr • 4 Rakat Fard', PrayerType.maghrib => 'Maghrib • 3 Rakat Fard', PrayerType.isha => 'Isha • 4 Rakat Fard', PrayerType.witr => 'Witr • 3 Rakat Wajib • Independent' };
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value}); final String label; final String value;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 2), Text(label, style: Theme.of(context).textTheme.bodySmall)]);
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, this.size = 72, this.strokeWidth = 6}); final double progress; final double size; final double strokeWidth;
  @override Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return SizedBox(width: size, height: size, child: Stack(alignment: Alignment.center, children: [CircularProgressIndicator(value: progress, strokeWidth: strokeWidth, backgroundColor: scheme.onPrimaryContainer.withOpacity(.18), color: scheme.secondary), Text('${(progress * 100).round()}%', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700))])); }
}

class ProgressOverviewCard extends StatelessWidget {
  const ProgressOverviewCard({super.key, required this.progress, this.header}); final QazaProgress progress; final Widget? header;
  @override Widget build(BuildContext context) { final total = progress.pending + progress.completed; final ratio = total == 0 ? 0.0 : progress.completed / total; return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (header != null) ...[header!, const SizedBox(height: AppSpacing.lg)], Row(children: [Expanded(child: MetricTile(label: 'Pending', value: '${progress.pending}')), Expanded(child: MetricTile(label: 'Completed', value: '${progress.completed}')), Expanded(child: MetricTile(label: 'Total', value: '$total'))]), const SizedBox(height: AppSpacing.lg), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: ratio, minHeight: 10)), const SizedBox(height: AppSpacing.sm), Text(total == 0 ? 'No records yet' : '${(ratio * 100).round()}% completed')])); }
}

class PrayerTile extends StatelessWidget {
  const PrayerTile({super.key, required this.prayer, this.subtitle, this.trailing, this.onTap}); final PrayerType prayer; final String? subtitle; final Widget? trailing; final VoidCallback? onTap;
  @override Widget build(BuildContext context) { final theme = Theme.of(context); return Card(margin: const EdgeInsets.only(bottom: AppSpacing.sm), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md), child: Row(children: [CircleAvatar(child: Icon(prayer.icon)), const SizedBox(width: AppSpacing.md), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(prayer.label, style: theme.textTheme.titleMedium), if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall)])), if (trailing != null) trailing!, const SizedBox(width: AppSpacing.xs), const Icon(Icons.chevron_right_rounded)])))); }
}
}
