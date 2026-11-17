import 'package:flutter/material.dart';

import '../../data/powersync/guest_data_adoption_service.dart';

class AdoptionConflictDialog extends StatelessWidget {
  const AdoptionConflictDialog({
    super.key,
    required this.guestCount,
    required this.cloudCount,
  });

  final int guestCount;
  final int cloudCount;

  static Future<AdoptionResolution?> show(
    BuildContext context, {
    required int guestCount,
    required int cloudCount,
  }) {
    return showDialog<AdoptionResolution>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdoptionConflictDialog(
        guestCount: guestCount,
        cloudCount: cloudCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Existing Cloud Data Found'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your cloud account already has $cloudCount recorded prayers, '
              'and this device has $guestCount local Guest prayers.\n\n'
              'How would you like to handle your records?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _ResolutionOptionTile(
              key: const Key('adoption_resolution_keep_both'),
              icon: Icons.merge_type_rounded,
              title: 'Combine Both (Recommended)',
              subtitle: 'Merges local and cloud prayers so no prayer is lost.',
              isRecommended: true,
              onTap: () => Navigator.of(context).pop(AdoptionResolution.keepBoth),
            ),
            const SizedBox(height: 8),
            _ResolutionOptionTile(
              key: const Key('adoption_resolution_keep_cloud'),
              icon: Icons.cloud_download_outlined,
              title: 'Keep Cloud Data',
              subtitle: 'Use cloud prayers and discard local guest records.',
              isRecommended: false,
              onTap: () => Navigator.of(context).pop(AdoptionResolution.keepCloud),
            ),
            const SizedBox(height: 8),
            _ResolutionOptionTile(
              key: const Key('adoption_resolution_keep_local'),
              icon: Icons.cloud_upload_outlined,
              title: 'Keep Local Data',
              subtitle: 'Upload device records and overwrite cloud data.',
              isRecommended: false,
              onTap: () => Navigator.of(context).pop(AdoptionResolution.keepLocal),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolutionOptionTile extends StatelessWidget {
  const _ResolutionOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isRecommended,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isRecommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isRecommended
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isRecommended ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isRecommended
              ? theme.colorScheme.primaryContainer.withAlpha(50)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isRecommended
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isRecommended ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
