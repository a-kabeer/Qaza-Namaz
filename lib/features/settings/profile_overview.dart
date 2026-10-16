import 'package:flutter/material.dart';

import '../../core/calendar/hijri_date_service.dart';
import '../../core/utils/date_formatters.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/profile_rules.dart';
import '../../l10n/app_localizations.dart';
import '../daily_salah/daily_salah_tracking_settings_tile.dart';

class ProfileOverview extends StatelessWidget {
  const ProfileOverview({
    super.key,
    required this.profile,
    required this.onEdit,
  });

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dateOfBirth = profile.dateOfBirth;

    return ListView(
      key: const Key('profile_overview'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          l10n.profileSettingsSubtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const DailySalahTrackingSettingsTile(),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _ProfileDetailRow(
                key: const Key('profile_overview_gender'),
                icon: Icons.person_outline,
                label: l10n.profileGender,
                value: switch (profile.gender) {
                  Gender.male => l10n.profileMale,
                  Gender.female => l10n.profileFemale,
                  null => '—',
                },
              ),
              const _DetailDivider(),
              _ProfileDetailRow(
                key: const Key('profile_overview_madhab'),
                icon: Icons.menu_book_outlined,
                label: l10n.profileMadhab,
                value: _madhabLabel(l10n, profile.madhab),
              ),
              const _DetailDivider(),
              _ProfileDetailRow(
                key: const Key('profile_overview_dob'),
                icon: Icons.calendar_month_outlined,
                label: l10n.profileDateOfBirth,
                value: dateOfBirth == null
                    ? '—'
                    : DateFormatters.formatGregorianFull(dateOfBirth),
                secondaryValue: dateOfBirth == null
                    ? null
                    : l10n.formatHijriDate(dateOfBirth),
              ),
              if (profile.isNewMuslim) ...[
                const _DetailDivider(),
                _ProfileDetailRow(
                  key: const Key('profile_overview_islam_acceptance_date'),
                  icon: Icons.event_available_outlined,
                  label: l10n.profileIslamAcceptanceDate,
                  value: profile.islamAcceptanceDate == null
                      ? '—'
                      : DateFormatters.formatGregorianFull(
                          profile.islamAcceptanceDate!,
                        ),
                  secondaryValue: profile.islamAcceptanceDate == null
                      ? null
                      : l10n.formatHijriDate(profile.islamAcceptanceDate!),
                ),
              ],
              if (!profile.isNewMuslim ||
                  profile.pubertyAge != null ||
                  profile.pubertyDate != null) ...[
                const _DetailDivider(),
                _ProfileDetailRow(
                  key: const Key('profile_overview_puberty_age'),
                  icon: Icons.timelapse_outlined,
                  label: profile.isNewMuslim &&
                          profile.pubertyInputMode ==
                              PubertyInputMode.rememberDate
                      ? l10n.profilePubertyDate
                      : l10n.profilePubertyAge,
                  value: profile.isNewMuslim &&
                          profile.pubertyInputMode ==
                              PubertyInputMode.rememberDate
                      ? profile.pubertyDate == null
                          ? '—'
                          : DateFormatters.formatGregorianFull(
                              profile.pubertyDate!,
                            )
                      : profile.pubertyAge == null
                          ? '—'
                          : l10n.profileAgeYears(profile.pubertyAge!),
                  secondaryValue: profile.isNewMuslim &&
                          profile.pubertyInputMode ==
                              PubertyInputMode.rememberDate &&
                          profile.pubertyDate != null
                      ? l10n.formatHijriDate(profile.pubertyDate!)
                      : null,
                ),
              ],
              const _DetailDivider(),
              if (profile.isNewMuslim)
                _ProfileDetailRow(
                  key: const Key('profile_overview_start_date'),
                  icon: Icons.schedule_outlined,
                  label: l10n.profileStartPrayingDate,
                  value: profile.startPrayingDate == null
                      ? '—'
                      : DateFormatters.formatGregorianFull(
                          profile.startPrayingDate!,
                        ),
                  secondaryValue: profile.startPrayingDate == null
                      ? null
                      : l10n.formatHijriDate(profile.startPrayingDate!),
                )
              else
                _ProfileDetailRow(
                  key: const Key('profile_overview_start_age'),
                  icon: Icons.schedule_outlined,
                  label: l10n.profileStartPrayingAge,
                  value: profile.startPrayingAge == null
                      ? '—'
                      : l10n.profileAgeYears(profile.startPrayingAge!),
                ),
              const _DetailDivider(),
              _ProfileDetailRow(
                key: const Key('profile_overview_witr'),
                icon: Icons.check_circle_outline,
                label: l10n.profileWitr,
                value: ProfileRules.effectiveWitr(profile)
                    ? l10n.profileWitrIncluded
                    : l10n.profileWitrExcluded,
              ),
              const _DetailDivider(),
              _ProfileDetailRow(
                key: const Key('profile_overview_daily_target'),
                icon: Icons.flag_outlined,
                label: l10n.homeDailyTarget,
                value: l10n.homePerDay(profile.dailyQazaTarget),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('profile_edit'),
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.profileEdit),
        ),
      ],
    );
  }

  static String _madhabLabel(AppLocalizations l10n, Madhab? madhab) {
    return switch (madhab) {
      Madhab.hanafi => l10n.profileHanafi,
      Madhab.shafi => l10n.profileShafi,
      Madhab.maliki => l10n.profileMaliki,
      Madhab.hanbali => l10n.profileHanbali,
      Madhab.other => l10n.profileOther,
      null => '—',
    };
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.secondaryValue,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? secondaryValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.onSurfaceVariant, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (secondaryValue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondaryValue!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: 52);
}
