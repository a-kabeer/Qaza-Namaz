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
  });

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
        if (await confirmDestructive(
          context,
          title: confirmationTitle,
          message: confirmationMessage,
          confirmLabel: confirmLabel,
        )) {
          await onConfirm();
        }
      },
      child: ListTile(
        leading: Icon(icon, color: scheme.error),
        title: Text(
          label,
          style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(description),
      ),
    );
  }
}
