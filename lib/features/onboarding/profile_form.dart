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
    final now = LocalDateService.today();
    final defaultYear = now.year - 18;
    final finalDayInDefaultMonth = DateTime(defaultYear, now.month + 1, 0).day;
    final initial = _profile.dateOfBirth ??
        DateTime(
          defaultYear,
          now.month,
          now.day <= finalDayInDefaultMonth
              ? now.day
              : finalDayInDefaultMonth,
        );
    var initialDate = DateTime(initial.year, initial.month, initial.day);
    if (initialDate.year < 1900) initialDate = DateTime(1900, 1, 1);
    if (initialDate.isAfter(now)) initialDate = now;

    final l10n = AppLocalizations.of(context);
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _DateOfBirthPickerDialog(
        initialDate: initialDate,
        today: now,
        title: l10n.profileDateOfBirth,
        helpText: l10n.profileSelectDobHelp,
        dayLabel: l10n.profileDobDay,
        monthLabel: l10n.profileDobMonth,
        yearLabel: l10n.profileDobYear,
        cancelLabel: l10n.commonCancel,
        confirmLabel: l10n.commonDone,
      ),
    );
    if (picked != null) {
      _update(
        _profile.copyWith(
          dateOfBirth: DateTime(picked.year, picked.month, picked.day),
        ),
      );
    }
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
    final startOptions = ProfileRules.startPrayingAgeOptions(
      profile,
      today: today,
    );
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
          Text(
            l10n.formatHijriDate(profile.dateOfBirth!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 20),
        Text(
          l10n.profilePubertyAge,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
        ),
        const SizedBox(height: 20),
        Text(
          l10n.profileStartPrayingAge,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _buildAgeSelector(
          fieldKey: const Key('profile_start_praying_age'),
          decrementKey: const Key('profile_start_praying_age_decrement'),
          incrementKey: const Key('profile_start_praying_age_increment'),
          value: profile.startPrayingAge,
          options: startOptions,
          enabled: startOptions.isNotEmpty,
          labelText: l10n.profileStartPrayingAge,
          helperText: profile.pubertyAge == null
              ? l10n.profileSelectPubertyFirst
              : currentAge == null
                  ? l10n.profileSelectDobFirst
                  : null,
          onChanged: (value) {
            _update(_profile.copyWith(startPrayingAge: value));
          },
        ),
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
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}


class _DateOfBirthPickerDialog extends StatefulWidget {
  const _DateOfBirthPickerDialog({
    required this.initialDate,
    required this.today,
    required this.title,
    required this.helpText,
    required this.dayLabel,
    required this.monthLabel,
    required this.yearLabel,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final DateTime initialDate;
  final DateTime today;
  final String title;
  final String helpText;
  final String dayLabel;
  final String monthLabel;
  final String yearLabel;
  final String cancelLabel;
  final String confirmLabel;

  @override
  State<_DateOfBirthPickerDialog> createState() =>
      _DateOfBirthPickerDialogState();
}

class _DateOfBirthPickerDialogState extends State<_DateOfBirthPickerDialog> {
  late int _day;
  late int _month;
  late int _year;

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;
  int get _latestMonth => _year == widget.today.year ? widget.today.month : 12;

  int get _latestDay {
    if (_year == widget.today.year && _month == widget.today.month) {
      return widget.today.day;
    }
    return _daysInMonth;
  }

  List<int> get _years => [
        for (var year = widget.today.year; year >= 1900; year--) year,
      ];
  List<int> get _months => [
        for (var month = 1; month <= _latestMonth; month++) month,
      ];
  List<int> get _days => [
        for (var day = 1; day <= _latestDay; day++) day,
      ];

  @override
  void initState() {
    super.initState();
    var initial = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    final today = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day,
    );
    if (initial.year < 1900) initial = DateTime(1900, 1, 1);
    if (initial.isAfter(today)) initial = today;
    _year = initial.year;
    _month = initial.month;
    _day = initial.day;
    _clampDay();
  }

  void _setYear(int year) {
    setState(() {
      _year = year;
      if (_month > _latestMonth) _month = _latestMonth;
      _clampDay();
    });
  }

  void _setMonth(int month) {
    setState(() {
      _month = month;
      _clampDay();
    });
  }

  void _clampDay() {
    if (_day > _latestDay) _day = _latestDay;
    if (_day < 1) _day = 1;
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
    return AlertDialog(
      key: const Key('profile_dob_picker_dialog'),
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.helpText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _selector<int>(
                      key: const Key('profile_dob_day'),
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
                        if (value != null) setState(() => _day = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _selector<int>(
                      key: const Key('profile_dob_month'),
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
                      key: const Key('profile_dob_year'),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          key: const Key('profile_dob_confirm'),
          onPressed: () =>
              Navigator.of(context).pop(DateTime(_year, _month, _day)),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
