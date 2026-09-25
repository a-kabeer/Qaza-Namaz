
import 'package:flutter/material.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/services/profile_rules.dart';
import '../../l10n/app_localizations.dart';

class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.initialProfile,
    required this.onSubmit,
    this.onCancel,
    this.onChanged,
    this.submitLabel,
    this.showIntro = true,
  });

  final UserProfile initialProfile;
  final Future<void> Function(UserProfile profile) onSubmit;
  final VoidCallback? onCancel;
  final ValueChanged<UserProfile>? onChanged;
  final String? submitLabel;
  final bool showIntro;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late UserProfile _profile;
  ProfileValidationError? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = ProfileRules.normalize(widget.initialProfile);
  }

  void _update(UserProfile profile) {
    setState(() {
      _error = null;
      _profile = ProfileRules.normalize(profile);
    });
    widget.onChanged?.call(_profile);
  }

  void _setGender(Gender gender) {
    var next = _profile.copyWith(gender: gender);
    final age = next.pubertyAge;
    if (age != null && !ProfileRules.isPubertyAgeAllowed(gender, age)) {
      next = next.copyWith(clearPubertyAge: true, clearStartPrayingAge: true);
    }
    _update(next);
  }

  void _setMadhab(Madhab madhab) {
    var next = _profile.copyWith(madhab: madhab);
    next = next.copyWith(
      witrIncluded: ProfileRules.effectiveWitr(next),
    );
    _update(next);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _profile.dateOfBirth ??
        DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: AppLocalizations.of(context).profileSelectDobHelp,
    );
    if (picked != null) {
      _update(_profile.copyWith(dateOfBirth: picked));
    }
  }

  Future<void> _submit() async {
    final validation = ProfileRules.validate(_profile, today: DateTime.now());
    if (!validation.isValid) {
      setState(() => _error = validation.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        _profile.copyWith(
          witrIncluded: ProfileRules.effectiveWitr(_profile),
          onboardingCompleted: true,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = _profile;
    final gender = profile.gender;
    final madhab = profile.madhab;
    final pubertyOptions = ProfileRules.pubertyAgeOptions(gender);
    final currentAge = profile.dateOfBirth == null
        ? null
        : ProfileRules.currentAge(profile.dateOfBirth!, DateTime.now());
    final startOptions = currentAge == null || profile.pubertyAge == null
        ? const <int>[]
        : [
            for (var age = profile.pubertyAge!; age <= currentAge; age++) age,
          ];
    final canEditWitr = ProfileRules.isWitrEditable(madhab);
    final errorText = _errorText(l10n, _error);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (widget.showIntro) ...[
          Text(
            l10n.profileIntro,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
        ],
        Text(
          l10n.profileGender,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<Gender>(
          key: const Key('profile_gender'),
          segments: [
            ButtonSegment(value: Gender.male, label: Text(l10n.profileMale)),
            ButtonSegment(
              value: Gender.female,
              label: Text(l10n.profileFemale),
            ),
          ],
          selected: gender == null ? const <Gender>{} : {gender},
          emptySelectionAllowed: true,
          onSelectionChanged: (value) {
            if (value.isNotEmpty) _setGender(value.first);
          },
        ),
        const SizedBox(height: 20),
        Text(
          l10n.profileMadhab,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Madhab>(
          key: const Key('profile_madhab'),
          initialValue: madhab,
          items: [
            DropdownMenuItem(
              value: Madhab.hanafi,
              child: Text(l10n.profileHanafi),
            ),
            DropdownMenuItem(
              value: Madhab.shafi,
              child: Text(l10n.profileShafi),
            ),
            DropdownMenuItem(
              value: Madhab.maliki,
              child: Text(l10n.profileMaliki),
            ),
            DropdownMenuItem(
              value: Madhab.hanbali,
              child: Text(l10n.profileHanbali),
            ),
            DropdownMenuItem(
              value: Madhab.other,
              child: Text(l10n.profileOther),
            ),
          ],
          onChanged: (value) {
            if (value != null) _setMadhab(value);
          },
          decoration: InputDecoration(labelText: l10n.profileMadhab),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.profileDateOfBirth,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('profile_dob'),
          onPressed: _pickDob,
          icon: const Icon(Icons.event_outlined),
          label: Text(
            profile.dateOfBirth == null
                ? l10n.profileSelectDate
                : _formatDate(profile.dateOfBirth!),
          ),
        ),
        if (profile.dateOfBirth != null) ...[
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final hijri = HijriCalendar.fromDate(profile.dateOfBirth!);
              return Text(
                '${l10n.profileHijriHint} ${hijri.hDay}/${hijri.hMonth}/${hijri.hYear}H',
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        Text(
          l10n.profilePubertyAge,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: const Key('profile_puberty_age'),
          initialValue: pubertyOptions.contains(profile.pubertyAge)
              ? profile.pubertyAge
              : null,
          items: [
            for (final age in pubertyOptions)
              DropdownMenuItem(value: age, child: Text(age.toString())),
          ],
          onChanged: gender == null
              ? null
              : (value) {
                  if (value != null) {
                    _update(_profile.copyWith(pubertyAge: value));
                  }
                },
          decoration: InputDecoration(
            labelText: l10n.profilePubertyAge,
            helperText:
                gender == null ? l10n.profileSelectGenderFirst : null,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.profileStartPrayingAge,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: const Key('profile_start_praying_age'),
          initialValue: startOptions.contains(profile.startPrayingAge)
              ? profile.startPrayingAge
              : null,
          items: [
            for (final age in startOptions)
              DropdownMenuItem(value: age, child: Text(age.toString())),
          ],
          onChanged: startOptions.isEmpty
              ? null
              : (value) {
                  if (value != null) {
                    _update(_profile.copyWith(startPrayingAge: value));
                  }
                },
          decoration: InputDecoration(
            labelText: l10n.profileStartPrayingAge,
            helperText: profile.pubertyAge == null
                ? l10n.profileSelectPubertyFirst
                : currentAge == null
                    ? l10n.profileSelectDobFirst
                    : null,
          ),
        ),
        const SizedBox(height: 20),
        if (canEditWitr)
          SwitchListTile.adaptive(
            key: const Key('profile_witr'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.profileWitr),
            subtitle: Text(l10n.profileWitrOptional),
            value: profile.witrIncluded ?? false,
            onChanged: (value) =>
                _update(_profile.copyWith(witrIncluded: value)),
          )
        else if (madhab != null)
          ListTile(
            key: const Key('profile_witr_fixed'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.profileWitr),
            subtitle: Text(
              ProfileRules.effectiveWitr(profile)
                  ? l10n.profileWitrIncluded
                  : l10n.profileWitrExcluded,
            ),
            trailing: Icon(
              ProfileRules.effectiveWitr(profile)
                  ? Icons.check_circle_outline
                  : Icons.remove_circle_outline,
            ),
          ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText,
            key: const Key('profile_validation_error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('profile_submit'),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel ?? l10n.commonContinue),
        ),
        if (widget.onCancel != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : widget.onCancel,
            child: Text(l10n.commonCancel),
          ),
        ],
      ],
    );
  }

  String? _errorText(
    AppLocalizations l10n,
    ProfileValidationError? error,
  ) =>
      switch (error) {
        ProfileValidationError.languageMissing => l10n.profileErrorLanguage,
        ProfileValidationError.genderMissing => l10n.profileErrorGender,
        ProfileValidationError.madhabMissing => l10n.profileErrorMadhab,
        ProfileValidationError.dobMissing ||
        ProfileValidationError.dobFuture =>
          l10n.profileErrorDob,
        ProfileValidationError.pubertyMissing ||
        ProfileValidationError.pubertyInvalid =>
          l10n.profileErrorPuberty,
        ProfileValidationError.startPrayingAgeMissing ||
        ProfileValidationError.startPrayingAgeInvalid =>
          l10n.profileErrorStartPraying,
        ProfileValidationError.witrInvalid => l10n.profileErrorWitr,
        null => null,
      };

  String _formatDate(DateTime date) =>
      date.day.toString().padLeft(2, '0') +
      '/' +
      date.month.toString().padLeft(2, '0') +
      '/' +
      date.year.toString();
}
