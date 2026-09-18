import 'package:flutter/material.dart';

import 'app_card.dart';
import 'confirmation_dialog.dart';
import 'section_header.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection(
      {super.key, required this.title, this.subtitle, required this.child});

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
  const SettingsNavRow(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      this.onTap});

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
  const DestructiveActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.confirmationTitle,
    required this.confirmationMessage,
    required this.confirmLabel,
    required this.onConfirm,
    this.acknowledgeLabel,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String description;
  final String confirmationTitle;
  final String confirmationMessage;
  final String confirmLabel;
  final Future<void> Function() onConfirm;

  /// When set, the confirmation cannot be completed until this is ticked.
  final String? acknowledgeLabel;

  /// A disabled row is inert and reads as inert: nothing to tap by accident
  /// when there is nothing to destroy, or while a previous run is in flight.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = enabled ? scheme.error : scheme.onSurfaceVariant;
    final acknowledge = acknowledgeLabel;
    Future<void> confirm() async {
      final confirmed = acknowledge == null
          ? await confirmDestructive(
              context,
              title: confirmationTitle,
              message: confirmationMessage,
              confirmLabel: confirmLabel,
            )
          : await confirmDestructiveWithAcknowledgement(
              context,
              title: confirmationTitle,
              message: confirmationMessage,
              acknowledgeLabel: acknowledge,
              confirmLabel: confirmLabel,
            );
      if (confirmed) await onConfirm();
    }

    return AppCard(
      color: enabled
          ? scheme.errorContainer.withValues(alpha: .35)
          : scheme.surfaceContainerHighest.withValues(alpha: .35),
      padding: EdgeInsets.zero,
      onTap: enabled ? confirm : null,
      child: ListTile(
        enabled: enabled,
        leading: Icon(icon, color: accent),
        title: Text(
          label,
          style: TextStyle(color: accent, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(description),
      ),
    );
  }
}
