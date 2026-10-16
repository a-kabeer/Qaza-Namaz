import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/calendar/hijri_date_service.dart';
import '../../core/time/local_date_service.dart';
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
    this.showDailyQazaTarget = false,
  });

  final UserProfile initialProfile;
  final Future<void> Function(UserProfile profile) onSubmit;
  final VoidCallback? onCancel;
  final ValueChanged<UserProfile>? onChanged;
  final String? submitLabel;
  final bool showIntro;
  final bool showDailyQazaTarget;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late UserProfile _profile;
  ProfileValidationError? _error;
  bool _saving = false;
  bool _dobExpanded = false;
  bool _islamAcceptanceExpanded = false;
  bool _pubertyDateExpanded = false;
  bool _startPrayingDateExpanded = false;

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
    if (next.pubertyInputMode == ProfileInputMode.ageEstimate &&
        age != null &&
        !ProfileRules.isPubertyAgeAllowed(gender, age)) {
      next = next.copyWith(clearPubertyAge: true);
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

  DateTime _initialDobDate(DateTime now) {
    final defaultYear = now.year - 18;
    final finalDayInDefaultMonth = DateTime(defaultYear, now.month + 1, 0).day;
    final initial = _profile.dateOfBirth ??
        DateTime(
          defaultYear,
          now.month,
          now.day <= finalDayInDefaultMonth ? now.day : finalDayInDefaultMonth,
        );
    var initialDate = DateTime(initial.year, initial.month, initial.day);
    if (initialDate.year < 1900) initialDate = DateTime(1900, 1, 1);
    if (initialDate.isAfter(now)) initialDate = now;
    return initialDate;
  }

  void _toggleDobPicker() {
    setState(() => _dobExpanded = !_dobExpanded);
  }

  DateTime _initialIslamAcceptanceDate(DateTime today) {
    var initial = LocalDateService.dateOnly(
      _profile.islamAcceptanceDate ?? today,
    );
    final dob = _profile.dateOfBirth;
    if (dob != null &&
        LocalDateService.compareCalendarDates(initial, dob) < 0) {
      initial = LocalDateService.dateOnly(dob);
    }
    if (LocalDateService.compareCalendarDates(initial, today) > 0) {
      initial = LocalDateService.dateOnly(today);
    }
    return initial;
  }

  Future<void> _submit() async {
    final validation = ProfileRules.validate(
      _profile,
      today: LocalDateService.today(),
    );
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
    final today = LocalDateService.today();
    final pubertyOptions = ProfileRules.availablePubertyAgeOptions(
      profile,
      today: today,
    );
    final currentAge = profile.dateOfBirth == null
        ? null
        : ProfileRules.currentAge(
            profile.dateOfBirth!,
            today,
          );
    final availableStartOptions = ProfileRules.startPrayingAgeOptions(
      profile,
      today: today,
    );
    final startOptions =
        profile.isNewMuslim &&
            profile.islamAcceptanceDate != null &&
            profile.dateOfBirth != null
        ? [
            for (final age in availableStartOptions)
              if (LocalDateService.compareCalendarDates(
                    ProfileRules.fixedMilestoneDate(profile.dateOfBirth!, age),
                    profile.islamAcceptanceDate!,
                  ) >=
                  0)
                age,
          ]
        : availableStartOptions;
    final showPubertyInput = ProfileRules.requiresPubertyInput(profile);
    final canEditWitr = ProfileRules.isWitrEditable(madhab);
    final pubertyDateMin = ProfileRules.minimumPubertyDate(profile);
    final pubertyDateMax = ProfileRules.maximumPubertyDate(
      profile,
      today: today,
    );
    var startPrayingDateMin = ProfileRules.minimumStartPrayingDate(profile);
    final acceptedDate = profile.isNewMuslim ? profile.islamAcceptanceDate : null;
    if (acceptedDate != null &&
        (startPrayingDateMin == null ||
            LocalDateService.compareCalendarDates(
                  acceptedDate, startPrayingDateMin) >
                0)) {
      startPrayingDateMin = LocalDateService.dateOnly(acceptedDate);
    }
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
          onPressed: _toggleDobPicker,
          icon: const Icon(Icons.event_outlined),
          label: Text(
            profile.dateOfBirth == null
                ? l10n.profileSelectDate
                : _formatDate(profile.dateOfBirth!),
          ),
        ),
        if (_dobExpanded) ...[
          const SizedBox(height: 12),
          _DateOfBirthPickerInline(
            key: const Key('profile_dob_picker_panel'),
            initialDate: _initialDobDate(today),
            today: today,
            title: l10n.profileDateOfBirth,
            helpText: l10n.profileSelectDobHelp,
            dayLabel: l10n.profileDobDay,
            monthLabel: l10n.profileDobMonth,
            yearLabel: l10n.profileDobYear,
            cancelLabel: l10n.commonCancel,
            confirmLabel: l10n.commonDone,
            onCancel: () => setState(() => _dobExpanded = false),
            onConfirm: (picked) {
              final updated = ProfileRules.normalize(
                _profile.copyWith(
                  dateOfBirth: DateTime(picked.year, picked.month, picked.day),
                ),
              );
              setState(() {
                _error = null;
                _profile = updated;
                _dobExpanded = false;
              });
              widget.onChanged?.call(updated);
            },
          ),
        ],
        if (profile.dateOfBirth != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.formatHijriDate(profile.dateOfBirth!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 20),
        const SizedBox(height: 20),
        Text(
          l10n.profileIslamicBackground,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        RadioListTile<bool>(
          key: const Key('profile_muslim_from_childhood'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: false,
          groupValue: profile.isNewMuslim,
          title: Text(l10n.profileMuslimFromChildhood),
          onChanged: (value) {
            if (value == null) return;
            _update(
              _profile.copyWith(
                isNewMuslim: false,
                clearIslamAcceptanceDate: true,
              ),
            );
            setState(() {
              _islamAcceptanceExpanded = false;
              _startPrayingDateExpanded = false;
            });
          },
        ),
        RadioListTile<bool>(
          key: const Key('profile_accepted_islam_later'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: true,
          groupValue: profile.isNewMuslim,
          title: Text(l10n.profileAcceptedIslamLater),
          onChanged: (value) {
            if (value != null) {
              _update(_profile.copyWith(isNewMuslim: true));
            }
          },
        ),
        if (profile.isNewMuslim) ...[
          const SizedBox(height: 4),
          Text(
            l10n.profileIslamAcceptanceDate,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('profile_islam_acceptance_date'),
            onPressed: profile.dateOfBirth == null
                ? null
                : () => setState(
                      () => _islamAcceptanceExpanded =
                          !_islamAcceptanceExpanded,
                    ),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              profile.islamAcceptanceDate == null
                  ? l10n.profileSelectDate
                  : _formatDate(profile.islamAcceptanceDate!),
            ),
          ),
          if (_islamAcceptanceExpanded) ...[
            const SizedBox(height: 12),
            _DateOfBirthPickerInline(
              key: const Key('profile_islam_acceptance_picker_panel'),
              keyPrefix: 'profile_islam_acceptance',
              initialDate: _initialIslamAcceptanceDate(today),
              today: today,
              minimumDate: profile.dateOfBirth,
              maximumDate: today,
              initialDateIsSelected: profile.islamAcceptanceDate != null &&
                  profile.dateOfBirth != null &&
                  !profile.islamAcceptanceDate!.isBefore(profile.dateOfBirth!) &&
                  !profile.islamAcceptanceDate!.isAfter(today),
              title: l10n.profileIslamAcceptanceDate,
              helpText: l10n.profileNewMuslimQazaHelp,
              dayLabel: l10n.profileDobDay,
              monthLabel: l10n.profileDobMonth,
              yearLabel: l10n.profileDobYear,
              cancelLabel: l10n.commonCancel,
              confirmLabel: l10n.commonDone,
              onCancel: () =>
                  setState(() => _islamAcceptanceExpanded = false),
              onConfirm: (picked) {
                _update(
                  _profile.copyWith(
                    islamAcceptanceDate:
                        DateTime(picked.year, picked.month, picked.day),
                  ),
                );
                setState(() => _islamAcceptanceExpanded = false);
              },
            ),
          ],
          if (profile.islamAcceptanceDate != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.formatHijriDate(profile.islamAcceptanceDate!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.profileNewMuslimQazaHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (showPubertyInput) ...[
        Text(
          l10n.profilePubertyAge,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<ProfileInputMode>(
          key: const Key('profile_puberty_input_mode'),
          segments: [
            ButtonSegment(
              value: ProfileInputMode.rememberedDate,
              label: Text(l10n.profileRememberDate),
            ),
            ButtonSegment(
              value: ProfileInputMode.ageEstimate,
              label: Text(l10n.profileEstimateUsingAge),
            ),
          ],
          selected: {profile.pubertyInputMode},
          onSelectionChanged: (values) {
            if (values.isNotEmpty) {
              setState(() => _pubertyDateExpanded = false);
              _update(_profile.copyWith(pubertyInputMode: values.first));
            }
          },
        ),
        const SizedBox(height: 8),
        if (profile.pubertyInputMode == ProfileInputMode.ageEstimate)
          _buildAgeSelector(
            fieldKey: const Key('profile_puberty_age'),
            decrementKey: const Key('profile_puberty_age_decrement'),
            incrementKey: const Key('profile_puberty_age_increment'),
            value: profile.pubertyAge,
            options: pubertyOptions,
            enabled: gender != null,
            labelText: l10n.profilePubertyAge,
            helperText: gender == null ? l10n.profileSelectGenderFirst : null,
            onChanged: (value) {
              _update(_profile.copyWith(pubertyAge: value));
            },
          )
        else ...[
          OutlinedButton.icon(
            key: const Key('profile_puberty_date'),
            onPressed: pubertyDateMin != null &&
                    pubertyDateMax != null &&
                    !pubertyDateMin.isAfter(pubertyDateMax)
                ? () => setState(
                      () => _pubertyDateExpanded = !_pubertyDateExpanded,
                    )
                : null,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              profile.pubertyDateOverride == null
                  ? l10n.profileSelectDate
                  : _formatDate(profile.pubertyDateOverride!),
            ),
          ),
          if (_pubertyDateExpanded &&
              pubertyDateMin != null &&
              pubertyDateMax != null &&
              !pubertyDateMin.isAfter(pubertyDateMax)) ...[
            const SizedBox(height: 12),
            _DateOfBirthPickerInline(
              key: const Key('profile_puberty_date_picker'),
              keyPrefix: 'profile_puberty_date',
              initialDate: _boundedInitialDate(
                profile.pubertyDateOverride,
                pubertyDateMin,
                pubertyDateMax,
              ),
              today: today,
              minimumDate: pubertyDateMin,
              maximumDate: pubertyDateMax,
              initialDateIsSelected: profile.pubertyDateOverride != null &&
                  !profile.pubertyDateOverride!.isBefore(pubertyDateMin) &&
                  !profile.pubertyDateOverride!.isAfter(pubertyDateMax),
              title: l10n.profilePubertyAge,
              helpText: l10n.profileSelectDate,
              dayLabel: l10n.profileDobDay,
              monthLabel: l10n.profileDobMonth,
              yearLabel: l10n.profileDobYear,
              cancelLabel: l10n.commonCancel,
              confirmLabel: l10n.commonDone,
              onCancel: () => setState(() => _pubertyDateExpanded = false),
              onConfirm: (picked) {
                _update(_profile.copyWith(pubertyDateOverride: picked));
                setState(() => _pubertyDateExpanded = false);
              },
            ),
          ],
        ],
        ],
        const SizedBox(height: 20),
        Text(
          l10n.profileStartPrayingAge,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<ProfileInputMode>(
          key: const Key('profile_start_praying_input_mode'),
          segments: [
            ButtonSegment(
              value: ProfileInputMode.rememberedDate,
              label: Text(l10n.profileRememberDate),
            ),
            ButtonSegment(
              value: ProfileInputMode.ageEstimate,
              label: Text(l10n.profileEstimateUsingAge),
            ),
          ],
          selected: {profile.startPrayingInputMode},
          onSelectionChanged: (values) {
            if (values.isNotEmpty) {
              setState(() => _startPrayingDateExpanded = false);
              _update(_profile.copyWith(startPrayingInputMode: values.first));
            }
          },
        ),
        const SizedBox(height: 8),
        if (profile.startPrayingInputMode == ProfileInputMode.ageEstimate)
          _buildAgeSelector(
            fieldKey: const Key('profile_start_praying_age'),
            decrementKey: const Key('profile_start_praying_age_decrement'),
            incrementKey: const Key('profile_start_praying_age_increment'),
            value: profile.startPrayingAge,
            options: startOptions,
            enabled: startOptions.isNotEmpty,
            labelText: l10n.profileStartPrayingAge,
            helperText:
                profile.dateOfBirth == null ? l10n.profileSelectDobFirst : null,
            onChanged: (value) {
              _update(_profile.copyWith(startPrayingAge: value));
            },
          )
        else ...[
          OutlinedButton.icon(
            key: const Key('profile_start_praying_date'),
            onPressed: startPrayingDateMin != null &&
                    !startPrayingDateMin.isAfter(today)
                ? () => setState(
                      () => _startPrayingDateExpanded =
                          !_startPrayingDateExpanded,
                    )
                : null,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              profile.startPrayingDateOverride == null
                  ? l10n.profileSelectDate
                  : _formatDate(profile.startPrayingDateOverride!),
            ),
          ),
          if (_startPrayingDateExpanded &&
              startPrayingDateMin != null &&
              !startPrayingDateMin.isAfter(today)) ...[
            const SizedBox(height: 12),
            _DateOfBirthPickerInline(
              key: const Key('profile_start_praying_date_picker'),
              keyPrefix: 'profile_start_praying_date',
              initialDate: _boundedInitialDate(
                profile.startPrayingDateOverride,
                startPrayingDateMin,
                today,
              ),
              today: today,
              minimumDate: startPrayingDateMin,
              maximumDate: today,
              initialDateIsSelected: profile.startPrayingDateOverride != null &&
                  !profile.startPrayingDateOverride!
                      .isBefore(startPrayingDateMin) &&
                  !profile.startPrayingDateOverride!.isAfter(today),
              title: l10n.profileStartPrayingAge,
              helpText: l10n.profileSelectDate,
              dayLabel: l10n.profileDobDay,
              monthLabel: l10n.profileDobMonth,
              yearLabel: l10n.profileDobYear,
              cancelLabel: l10n.commonCancel,
              confirmLabel: l10n.commonDone,
              onCancel: () => setState(() => _startPrayingDateExpanded = false),
              onConfirm: (picked) {
                _update(_profile.copyWith(startPrayingDateOverride: picked));
                setState(() => _startPrayingDateExpanded = false);
              },
            ),
          ],
        ],
        if (widget.showDailyQazaTarget) ...[
          const SizedBox(height: 20),
          Text(
            l10n.homeDailyTarget,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: const Key('profile_daily_qaza_target'),
            initialValue: UserProfile.dailyQazaTargetOptions.contains(
              profile.dailyQazaTarget,
            )
                ? profile.dailyQazaTarget
                : null,
            items: [
              for (final value in UserProfile.dailyQazaTargetOptions)
                DropdownMenuItem<int>(
                  value: value,
                  child: Text(l10n.homePerDay(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                _update(_profile.copyWith(dailyQazaTarget: value));
              }
            },
            decoration: InputDecoration(
              labelText: l10n.homeDailyTarget,
            ),
          ),
          const SizedBox(height: 20),
        ],
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

  Widget _buildAgeSelector({
    required Key fieldKey,
    required Key decrementKey,
    required Key incrementKey,
    required int? value,
    required List<int> options,
    required bool enabled,
    required String labelText,
    required String? helperText,
    required ValueChanged<int> onChanged,
  }) {
    final selected = value != null && options.contains(value) ? value : null;
    final min = options.isEmpty ? null : options.first;
    final max = options.isEmpty ? null : options.last;
    final canDecrease =
        enabled && selected != null && min != null && selected > min;
    final canIncrease = enabled &&
        ((selected == null && options.isNotEmpty) ||
            (selected != null && max != null && selected < max));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          height: 56,
          child: IconButton(
            key: decrementKey,
            tooltip: '$labelText −',
            onPressed: canDecrease ? () => onChanged(selected - 1) : null,
            icon: const Icon(Icons.remove),
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<int>(
            key: fieldKey,
            initialValue: selected,
            items: [
              for (final age in options)
                DropdownMenuItem(value: age, child: Text(age.toString())),
            ],
            onChanged: enabled && options.isNotEmpty
                ? (next) {
                    if (next != null) onChanged(next);
                  }
                : null,
            decoration: InputDecoration(
              labelText: labelText,
              helperText: helperText,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          height: 56,
          child: IconButton(
            key: incrementKey,
            tooltip: '$labelText +',
            onPressed: canIncrease
                ? () =>
                    onChanged(selected == null ? options.first : selected + 1)
                : null,
            icon: const Icon(Icons.add),
          ),
        ),
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
        ProfileValidationError.islamAcceptanceDateMissing ||
        ProfileValidationError.islamAcceptanceDateInvalid =>
          l10n.profileErrorIslamAcceptanceDate,
        ProfileValidationError.pubertyMissing ||
        ProfileValidationError.pubertyInvalid =>
          l10n.profileErrorPuberty,
        ProfileValidationError.startPrayingAgeMissing ||
        ProfileValidationError.startPrayingAgeInvalid =>
          l10n.profileErrorStartPraying,
        ProfileValidationError.witrInvalid => l10n.profileErrorWitr,
        null => null,
      };

  DateTime _boundedInitialDate(
    DateTime? current,
    DateTime minimum,
    DateTime maximum,
  ) {
    final candidate = current == null
        ? minimum
        : DateTime(current.year, current.month, current.day);
    if (candidate.isBefore(minimum)) return minimum;
    if (candidate.isAfter(maximum)) return maximum;
    return candidate;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _DateOfBirthPickerInline extends StatefulWidget {
  const _DateOfBirthPickerInline({
    super.key,
    required this.initialDate,
    required this.today,
    this.minimumDate,
    this.maximumDate,
    this.keyPrefix = 'profile_dob',
    this.initialDateIsSelected = true,
    required this.title,
    required this.helpText,
    required this.dayLabel,
    required this.monthLabel,
    required this.yearLabel,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  final DateTime initialDate;
  final DateTime today;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final String keyPrefix;
  final bool initialDateIsSelected;
  final String title;
  final String helpText;
  final String dayLabel;
  final String monthLabel;
  final String yearLabel;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<_DateOfBirthPickerInline> createState() =>
      _DateOfBirthPickerInlineState();
}

class _DateOfBirthPickerInlineState extends State<_DateOfBirthPickerInline> {
  late int _day;
  late int _month;
  late int _year;
  late bool _canConfirm;

  DateTime get _minimumDate => DateTime(
        widget.minimumDate?.year ?? 1900,
        widget.minimumDate?.month ?? 1,
        widget.minimumDate?.day ?? 1,
      );
  DateTime get _maximumDate => DateTime(
        widget.maximumDate?.year ?? widget.today.year,
        widget.maximumDate?.month ?? widget.today.month,
        widget.maximumDate?.day ?? widget.today.day,
      );
  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;
  int get _earliestMonth => _year == _minimumDate.year ? _minimumDate.month : 1;
  int get _latestMonth => _year == _maximumDate.year ? _maximumDate.month : 12;
  int get _earliestDay =>
      _year == _minimumDate.year && _month == _minimumDate.month
          ? _minimumDate.day
          : 1;
  int get _latestDay =>
      _year == _maximumDate.year && _month == _maximumDate.month
          ? _maximumDate.day
          : _daysInMonth;

  List<int> get _years => [
        for (var year = _maximumDate.year; year >= _minimumDate.year; year--)
          year,
      ];
  List<int> get _months => [
        for (var month = _earliestMonth; month <= _latestMonth; month++) month,
      ];
  List<int> get _days => [
        for (var day = _earliestDay; day <= _latestDay; day++) day,
      ];

  @override
  void initState() {
    super.initState();
    var initial = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    if (initial.isBefore(_minimumDate)) initial = _minimumDate;
    if (initial.isAfter(_maximumDate)) initial = _maximumDate;
    _year = initial.year;
    _month = initial.month;
    _day = initial.day;
    _canConfirm = widget.initialDateIsSelected;
    _clampDay();
  }

  void _setYear(int year) {
    setState(() {
      _canConfirm = true;
      _year = year;
      if (_month > _latestMonth) _month = _latestMonth;
      if (_month < _earliestMonth) _month = _earliestMonth;
      _clampDay();
    });
  }

  void _setMonth(int month) {
    setState(() {
      _canConfirm = true;
      _month = month;
      _clampDay();
    });
  }

  void _clampDay() {
    if (_day > _latestDay) _day = _latestDay;
    if (_day < _earliestDay) _day = _earliestDay;
  }

  Widget _selector<T>({
    required Key key,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: key,
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          isDense: true,
          menuMaxHeight: 320,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeName = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              widget.helpText,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _selector<int>(
                    key: Key('${widget.keyPrefix}_day'),
                    label: widget.dayLabel,
                    value: _day,
                    items: [
                      for (final day in _days)
                        DropdownMenuItem<int>(
                          value: day,
                          child: Text(day.toString()),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _day = value;
                          _canConfirm = true;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _selector<int>(
                    key: Key('${widget.keyPrefix}_month'),
                    label: widget.monthLabel,
                    value: _month,
                    items: [
                      for (final month in _months)
                        DropdownMenuItem<int>(
                          value: month,
                          child: Text(
                            DateFormat.MMMM(localeName).format(
                              DateTime(2000, month, 1),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _setMonth(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _selector<int>(
                    key: Key('${widget.keyPrefix}_year'),
                    label: widget.yearLabel,
                    value: _year,
                    items: [
                      for (final year in _years)
                        DropdownMenuItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _setYear(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: Key('${widget.keyPrefix}_cancel'),
                  onPressed: widget.onCancel,
                  child: Text(widget.cancelLabel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: Key('${widget.keyPrefix}_confirm'),
                  onPressed: _canConfirm
                      ? () => widget.onConfirm(DateTime(_year, _month, _day))
                      : null,
                  child: Text(widget.confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
