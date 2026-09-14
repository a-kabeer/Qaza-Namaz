// Shared, application-wide UI components.
//
// These widgets centralize the visual patterns that repeat across the Qaza
// Namaz app (page scaffolds, section headings, buttons, status chips, metrics,
// empty/loading/error states, settings rows, the account section, destructive
// confirmation dialogs and date display). They render with the ambient theme
// from lib/core/theme/app_theme.dart, so Light/Dark/System switching re-themes
// every screen that uses them.

import 'package:flutter/material.dart';

import '../../domain/entities/app_user.dart';

/// Shared spacing tokens used across screens.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// A scaffold with a standard app bar for secondary pages.
///
/// [onBack] adds a back button; [actions] can carry page-level actions.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final Widget? leading;
    if (onBack != null) {
      leading = IconButton(
        tooltip: 'Back',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      );
    } else {
      leading = null;
    }
    return Scaffold(
      appBar: AppBar(leading: leading, title: Text(title), actions: actions),
      body: child,
    );
  }
}

/// A section heading used to structure long pages such as Settings.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// The app's filled, primary call-to-action button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      child: Text(label),
    );
    if (icon == null) return button;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// The app's outlined, secondary button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// A small round icon button with a tooltip.
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: color,
    );
  }
}

/// A compact status pill (pending / fulfilled / etc).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {this.color, super.key});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? scheme.onPrimaryContainer.withOpacity(.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// A label/value metric used in overview rows and cards.
class Metric extends StatelessWidget {
  const Metric(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// A centered spinner used while data loads.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.padding = 64, this.message});

  final double padding;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(message!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// A centered error message with an optional retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Something went wrong',
    this.icon = Icons.error_outline_rounded,
  });

  final String message;
  final VoidCallback? onRetry;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: scheme.onErrorContainer),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A centered empty-state message with an optional trailing [child].
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.child,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (child != null) ...[
              const SizedBox(height: AppSpacing.lg),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A titled settings block wrapping its rows/controls in a card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: title, subtitle: subtitle),
        const SizedBox(height: AppSpacing.sm),
        Card(child: child),
      ],
    );
  }
}

/// A tappable row used inside [SettingsSection] cards.
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// Shows a confirmation dialog for a destructive or account-changing action.
///
/// Returns `true` only when the user explicitly confirms.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// A settings row that triggers [confirmDestructive] before running
/// [onConfirm]. Used for account-changing actions such as sign-out.
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

  Future<void> _handleTap(BuildContext context) async {
    final confirmed = await confirmDestructive(
      context,
      title: confirmationTitle,
      message: confirmationMessage,
      confirmLabel: confirmLabel,
    );
    if (!confirmed) return;
    await onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer.withOpacity(.35),
      child: ListTile(
        leading: Icon(icon, color: scheme.error),
        title: Text(label, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        onTap: () => _handleTap(context),
      ),
    );
  }
}

/// The signed-in account summary: identity, status and sign-out.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final Future<void> Function() onSignOut;

  String get _name {
    final name = user.displayName;
    if (name == null || name.isEmpty) return user.email;
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primaryContainer,
                  foregroundImage: hasPhoto ? NetworkImage(user.photoUrl!) : null,
                  child: Icon(Icons.person_rounded, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        user.email.isEmpty ? 'Signed in with Google' : user.email,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.password_rounded),
                title: Text('Sign-in method'),
                subtitle: Text('Google authentication'),
              ),
              ListTile(
                leading: Icon(Icons.verified_user_rounded),
                title: Text('Account status'),
                subtitle: Text('Signed in'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Developer context', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('Firebase UID'),
            subtitle: Text(user.id.isEmpty ? 'Not available' : user.id),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        DestructiveActionRow(
          icon: Icons.logout,
          label: 'Sign out',
          description:
              'Signing out returns you to the welcome screen. Your Qaza '
              'records are saved in the cloud and are NOT deleted.',
          confirmLabel: 'Sign out',
          confirmationTitle: 'Sign out?',
          confirmationMessage:
              'Signing out returns you to the welcome screen. Your saved '
              'Qaza records are NOT deleted and will be restored the next '
              'time you sign in.',
          onConfirm: onSignOut,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Date display
// ---------------------------------------------------------------------------

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a date as `05 Sep 2026`. Returns '—' for null values.
String formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
}

/// Formats a date and time as `05 Sep 2026 3:45 PM`. Returns '—' for null.
String formatDateTime(DateTime? value) {
  if (value == null) return '—';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '${formatDate(value)} $hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}



