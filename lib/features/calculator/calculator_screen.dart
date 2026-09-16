import 'package:flutter/material.dart';

import '../../core/widgets/app_scaffold.dart';
import 'qaza_calculation.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

enum _BalighInputMode { age, exactDate }
enum _PrayerStartInputMode { age, exactDate }

class _CalculatorScreenState extends State<CalculatorScreen> {
  int _step = 0;
  DateTime? _dob;
  _BalighInputMode _balighInputMode = _BalighInputMode.age;
  int _balighAge = 12;
  DateTime? _balighDate;
  _PrayerStartInputMode _prayerStartInputMode = _PrayerStartInputMode.age;
  int _prayerStartAge = 18;
  DateTime? _prayerStartDate;
  bool _includeWitr = false;
  QazaCalculation? _calculation;

  static const steps = <String>['About You', 'Prayer History', 'Result'];

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int? get _currentAge {
    final dob = _dob;
    if (dob == null) return null;
    final today = _today;
    var age = today.year - dob.year;
    final birthday = DateTime(today.year, dob.month, dob.day);
    if (today.isBefore(birthday)) age--;
    return age;
  }

  DateTime? get _estimatedBalighDate {
    final dob = _dob;
    if (dob == null || _balighInputMode != _BalighInputMode.age) return null;
    return DateTime(dob.year + _balighAge, dob.month, dob.day);
  }

  DateTime? get _effectiveBalighDate =>
      _balighInputMode == _BalighInputMode.exactDate ? _balighDate : _estimatedBalighDate;

  DateTime? get _estimatedPrayerStartDate {
    final dob = _dob;
    if (dob == null || _prayerStartInputMode != _PrayerStartInputMode.age) return null;
    return DateTime(dob.year + _prayerStartAge, dob.month, dob.day);
  }

  DateTime? get _effectivePrayerStartDate =>
      _prayerStartInputMode == _PrayerStartInputMode.exactDate
          ? _prayerStartDate
          : _estimatedPrayerStartDate;

  String? get _dobError {
    if (_dob == null) return 'Select your date of birth.';
    if (_dob!.isAfter(_today)) return 'Date of birth cannot be in the future.';
    return null;
  }

  String? get _balighError {
    final date = _balighDate;
    final dob = _dob;
    if (_balighInputMode == _BalighInputMode.age || dob == null || date == null) return null;
    if (date.isBefore(dob)) return 'Baligh date cannot be before your date of birth.';
    if (date.isAfter(_today)) return 'Baligh date cannot be in the future.';
    return null;
  }

  String? get _prayerStartError {
    final dob = _dob;
    final baligh = _effectiveBalighDate;
    final start = _effectivePrayerStartDate;
    if (dob == null || baligh == null || start == null) return null;
    if (start.isBefore(baligh)) return 'Prayer start cannot be before the Baligh date.';
    if (start.isAfter(_today)) return 'Prayer start cannot be in the future.';
    if (start.isBefore(dob)) return 'Prayer start cannot be before your date of birth.';
    return null;
  }

  bool get _step1Valid => _dobError == null && _balighError == null && _effectiveBalighDate != null;
  bool get _step2Valid => _step1Valid && _effectivePrayerStartDate != null && _prayerStartError == null;

  void _next() {
    if (_step == 0 && !_step1Valid) {
      setState(() {});
      return;
    }
    if (_step == 1) {
      if (!_step2Valid) {
        setState(() {});
        return;
      }
      _calculate();
      return;
    }
    if (_step < steps.length - 1) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _calculate() {
    final start = _effectiveBalighDate;
    final end = _effectivePrayerStartDate;
    if (start == null || end == null || end.isBefore(start)) {
      setState(() {});
      return;
    }
    setState(() {
      _calculation = calculateQaza(
        startDate: start,
        endDate: end,
        includeWitr: _includeWitr,
      );
      _step = 2;
    });
  }

  Future<void> _pickDob() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(_today.year - 18, _today.month, _today.day),
      firstDate: DateTime(1900),
      lastDate: _today,
      helpText: 'Select your date of birth',
    );
    if (date != null) {
      setState(() {
        _dob = DateTime(date.year, date.month, date.day);
        _calculation = null;
      });
    }
  }

  Future<void> _pickBalighDate() async {
    final dob = _dob;
    if (dob == null) return;
    final current = _balighDate;
    final initial = current != null && !current.isBefore(dob) && !current.isAfter(_today) ? current : dob;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: dob,
      lastDate: _today,
      helpText: 'Select exact Baligh date',
    );
    if (date != null) {
      setState(() {
        _balighDate = DateTime(date.year, date.month, date.day);
        _calculation = null;
      });
    }
  }

  Future<void> _pickPrayerStartDate() async {
    final baligh = _effectiveBalighDate;
    if (baligh == null || baligh.isAfter(_today)) return;
    final current = _prayerStartDate;
    final initial = current != null && !current.isBefore(baligh) && !current.isAfter(_today) ? current : baligh;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: baligh,
      lastDate: _today,
      helpText: 'Select exact prayer start date',
    );
    if (date != null) {
      setState(() {
        _prayerStartDate = DateTime(date.year, date.month, date.day);
        _calculation = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'Calculator',
        body: SafeArea(
          child: Column(
            children: [
              _ProgressIndicator(step: _step),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _stepContent(),
                ),
              ),
              _StepActions(
                step: _step,
                canContinue: _step == 0 ? _step1Valid : _step == 1 ? _step2Valid : true,
                onBack: _step == 0 ? null : _back,
                onContinue: _next,
              ),
            ],
          ),
        ),
      );

  Widget _stepContent() => switch (_step) {
        0 => _aboutYouStep(),
        1 => _prayerHistoryStep(),
        _ => _resultStep(),
      };

  Widget _aboutYouStep() {
    final effectiveBalighDate = _effectiveBalighDate;
    final age = _currentAge;
    return ListView(
      key: const ValueKey('calculator_step_0'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Step 1 of 3', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text('About You', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Start with your date of birth and Baligh information.'),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date of birth', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('calculator_dob_picker'),
                  onPressed: _pickDob,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(_dob == null ? 'Select date' : _formatDate(_dob!)),
                ),
                if (_dobError != null) ...[
                  const SizedBox(height: 6),
                  Text(_dobError!, key: const Key('calculator_dob_error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (age != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(label: 'Current age', value: '$age years'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Baligh information', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SegmentedButton<_BalighInputMode>(
                  key: const Key('calculator_baligh_mode'),
                  segments: const [
                    ButtonSegment(value: _BalighInputMode.age, label: Text('Age'), icon: Icon(Icons.numbers_rounded)),
                    ButtonSegment(value: _BalighInputMode.exactDate, label: Text('Exact date'), icon: Icon(Icons.event_rounded)),
                  ],
                  selected: {_balighInputMode},
                  onSelectionChanged: (value) {
                    setState(() {
                      _balighInputMode = value.first;
                      if (_balighInputMode == _BalighInputMode.age) _balighDate = null;
                      _calculation = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (_balighInputMode == _BalighInputMode.age)
                  DropdownButtonFormField<int>(
                    key: const Key('calculator_baligh_age'),
                    initialValue: _balighAge,
                    decoration: const InputDecoration(labelText: 'Baligh age (years)'),
                    items: [
                      for (var value = 9; value <= 18; value++)
                        DropdownMenuItem(value: value, child: Text('$value years')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() { _balighAge = value; _calculation = null; });
                    },
                  )
                else
                  OutlinedButton.icon(
                    key: const Key('calculator_baligh_date_picker'),
                    onPressed: _dob == null ? null : _pickBalighDate,
                    icon: const Icon(Icons.event_rounded),
                    label: Text(_balighDate == null ? 'Select exact date' : _formatDate(_balighDate!)),
                  ),
                if (_balighError != null) ...[
                  const SizedBox(height: 6),
                  Text(_balighError!, key: const Key('calculator_baligh_error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (effectiveBalighDate != null) ...[
                  const SizedBox(height: 12),
                  _DateInfoBox(
                    text: _balighInputMode == _BalighInputMode.age
                        ? 'Estimated Baligh date: ${_formatDate(effectiveBalighDate)}'
                        : 'Exact Baligh date: ${_formatDate(effectiveBalighDate)}',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _prayerHistoryStep() {
    final baligh = _effectiveBalighDate;
    final prayerStart = _effectivePrayerStartDate;
    final years = baligh != null && prayerStart != null && !prayerStart.isBefore(baligh)
        ? _calendarYearsBetween(baligh, prayerStart)
        : null;
    final days = baligh != null && prayerStart != null && !prayerStart.isBefore(baligh)
        ? prayerStart.difference(baligh).inDays
        : null;

    return ListView(
      key: const ValueKey('calculator_step_1'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Step 2 of 3', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text('Prayer History', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Tell us when regular prayer started so we can calculate the Qaza period.'),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Regular prayer start', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SegmentedButton<_PrayerStartInputMode>(
                  key: const Key('calculator_prayer_start_mode'),
                  segments: const [
                    ButtonSegment(value: _PrayerStartInputMode.age, label: Text('Age'), icon: Icon(Icons.numbers_rounded)),
                    ButtonSegment(value: _PrayerStartInputMode.exactDate, label: Text('Exact date'), icon: Icon(Icons.event_rounded)),
                  ],
                  selected: {_prayerStartInputMode},
                  onSelectionChanged: (value) {
                    setState(() {
                      _prayerStartInputMode = value.first;
                      if (_prayerStartInputMode == _PrayerStartInputMode.age) _prayerStartDate = null;
                      _calculation = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (_prayerStartInputMode == _PrayerStartInputMode.age)
                  DropdownButtonFormField<int>(
                    key: const Key('calculator_prayer_start_age'),
                    initialValue: _prayerStartAge,
                    decoration: const InputDecoration(labelText: 'Regular prayer start age (years)'),
                    items: [
                      for (var value = 12; value <= 60; value++)
                        DropdownMenuItem(value: value, child: Text('$value years')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() { _prayerStartAge = value; _calculation = null; });
                    },
                  )
                else
                  OutlinedButton.icon(
                    key: const Key('calculator_prayer_start_date_picker'),
                    onPressed: baligh == null ? null : _pickPrayerStartDate,
                    icon: const Icon(Icons.event_rounded),
                    label: Text(_prayerStartDate == null ? 'Select exact date' : _formatDate(_prayerStartDate!)),
                  ),
                if (prayerStart != null) ...[
                  const SizedBox(height: 12),
                  _DateInfoBox(
                    text: _prayerStartInputMode == _PrayerStartInputMode.age
                        ? 'Estimated prayer-start date: ${_formatDate(prayerStart)}'
                        : 'Exact prayer-start date: ${_formatDate(prayerStart)}',
                  ),
                ],
                if (_prayerStartError != null) ...[
                  const SizedBox(height: 8),
                  Text(_prayerStartError!, key: const Key('calculator_prayer_start_error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          key: const Key('calculator_qaza_period_summary'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Qaza period', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (baligh != null) _InfoRow(label: 'Baligh date', value: _formatDate(baligh)),
                if (prayerStart != null) _InfoRow(label: 'Prayer-start date', value: _formatDate(prayerStart)),
                if (years != null && days != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Calendar period', value: '$years years • $days days'),
                ] else
                  const Text('Complete valid dates to calculate the Qaza period.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultStep() {
    final result = _calculation;
    if (result == null) {
      return ListView(
        key: const ValueKey('calculator_step_2'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Step 3 of 3', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text('Result', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text('Calculate a valid prayer period to view your Qaza estimate.'),
        ],
      );
    }

    return ListView(
      key: const ValueKey('calculator_step_2'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Step 3 of 3', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text('Result', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        _SourceChip(exact: _balighInputMode == _BalighInputMode.exactDate || _prayerStartInputMode == _PrayerStartInputMode.exactDate),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ResultMetric(label: 'Qaza period', value: '${result.calendarYears} years • ${result.remainingDays} days'),
                _ResultMetric(label: 'Elapsed days', value: _formatNumber(result.totalDays)),
                _ResultMetric(label: 'Estimated prayers', value: _formatNumber(result.totalPrayers), prominent: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prayer breakdown', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                for (final prayer in result.prayerBreakdown.keys)
                  _InfoRow(label: prayer.label, value: _formatNumber(result.prayerBreakdown[prayer]!)),
                const Divider(height: 24),
                SwitchListTile.adaptive(
                  key: const Key('calculator_include_witr'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Witr separately'),
                  subtitle: const Text('Witr is counted independently from the five daily prayers.'),
                  value: _includeWitr,
                  onChanged: (value) {
                    setState(() {
                      _includeWitr = value;
                      _calculation = calculateQaza(
                        startDate: result.startDate,
                        endDate: result.endDate,
                        includeWitr: value,
                      );
                    });
                  },
                ),
                if (result.includeWitr) _InfoRow(label: 'Witr', value: _formatNumber(result.witrCount)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String _formatNumber(int value) => value.toString().replaceAllMapped(RegExp(r'(?<!^)(?=(\d{3})+$)'), (_) => ',');

  int _calendarYearsBetween(DateTime start, DateTime end) {
    var years = end.year - start.year;
    final anniversary = DateTime(end.year, start.month, start.day);
    if (anniversary.isAfter(end)) years--;
    return years;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: Theme.of(context).textTheme.titleSmall)]),
      );
}

class _DateInfoBox extends StatelessWidget {
  const _DateInfoBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.secondaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [Icon(Icons.info_outline_rounded, color: colors.onSecondaryContainer), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(color: colors.onSecondaryContainer)))]),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.exact});
  final bool exact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(exact ? Icons.event_available_rounded : Icons.auto_awesome_rounded, color: colors.onSecondaryContainer),
        label: Text(exact ? 'Based on exact dates' : 'Estimated calculation'),
        backgroundColor: colors.secondaryContainer,
        labelStyle: TextStyle(color: colors.onSecondaryContainer),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value, this.prominent = false});
  final String label;
  final String value;
  final bool prominent;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: prominent ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.titleMedium)]),
      );
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(children: [
        for (var index = 0; index < 3; index++) ...[
          if (index > 0) Expanded(child: Container(height: 2, color: index <= step ? colors.primary : colors.outlineVariant)),
          Semantics(
            label: 'Step ${index + 1}: ${_CalculatorScreenState.steps[index]}',
            selected: index == step,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: index <= step ? colors.primary : colors.surfaceContainerHighest,
              child: Text('${index + 1}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: index <= step ? colors.onPrimary : colors.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ),
          ),
          if (index < 2) const SizedBox(width: 6),
        ],
      ]),
    );
  }
}

class _StepActions extends StatelessWidget {
  const _StepActions({required this.step, required this.canContinue, required this.onBack, required this.onContinue});
  final int step;
  final bool canContinue;
  final VoidCallback? onBack;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Row(children: [
          if (onBack != null) ...[
            OutlinedButton(key: const Key('calculator_back'), onPressed: onBack, child: const Text('Back')),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(
              key: Key(step == 0 ? 'calculator_continue' : step == 1 ? 'calculator_calculate' : 'calculator_add_to_tracker'),
              onPressed: canContinue ? onContinue : null,
              child: Text(step == 0 ? 'Continue' : step == 1 ? 'Calculate' : 'Add to Tracker'),
            ),
          ),
        ]),
      );
}
