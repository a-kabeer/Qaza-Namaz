import 'package:flutter/material.dart';

import '../../core/widgets/app_scaffold.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

enum _BalighInputMode { age, exactDate }

class _CalculatorScreenState extends State<CalculatorScreen> {
  int _step = 0;
  DateTime? _dob;
  _BalighInputMode _balighInputMode = _BalighInputMode.age;
  int _balighAge = 12;
  DateTime? _balighDate;

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

  bool get _step1Valid => _dobError == null && _balighError == null && _effectiveBalighDate != null;

  void _next() {
    if (_step == 0 && !_step1Valid) {
      setState(() {});
      return;
    }
    if (_step < steps.length - 1) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _pickDob() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(_today.year - 18, _today.month, _today.day),
      firstDate: DateTime(1900),
      lastDate: _today,
      helpText: 'Select your date of birth',
    );
    if (date != null) setState(() => _dob = DateTime(date.year, date.month, date.day));
  }

  Future<void> _pickBalighDate() async {
    final dob = _dob;
    if (dob == null) return;
    final current = _balighDate;
    final initial = current != null && !current.isBefore(dob) && !current.isAfter(_today)
        ? current
        : (dob.isAfter(_today) ? _today : dob);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: dob,
      lastDate: _today,
      helpText: 'Select exact Baligh date',
    );
    if (date != null) setState(() => _balighDate = DateTime(date.year, date.month, date.day));
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
                canContinue: _step != 0 || _step1Valid,
                onBack: _step == 0 ? null : _back,
                onContinue: _next,
              ),
            ],
          ),
        ),
      );

  Widget _stepContent() {
    return switch (_step) {
      0 => _aboutYouStep(),
      1 => _placeholderStep(
          step: 1,
          title: 'Prayer History',
          description: 'Tell us when regular prayer started so we can calculate the Qaza period.',
        ),
      _ => _placeholderStep(
          step: 2,
          title: 'Result',
          description: 'Your calculated Qaza estimate will appear here.',
        ),
    };
  }

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
                      if (_balighInputMode == _BalighInputMode.age) {
                        _balighDate = null;
                      }
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
                      for (var age = 9; age <= 18; age++)
                        DropdownMenuItem(value: age, child: Text('$age years')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _balighAge = value);
                    },
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
                if (effectiveBalighDate != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.onSecondaryContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _balighInputMode == _BalighInputMode.age
                                ? 'Estimated Baligh date: ${_formatDate(effectiveBalighDate)}'
                                : 'Exact Baligh date: ${_formatDate(effectiveBalighDate)}',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholderStep({required int step, required String title, required String description}) => ListView(
        key: ValueKey('calculator_step_$step'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Step ${step + 1} of 3', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(description),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('This step will be implemented next.', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
      );

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
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
      child: Row(
        children: [
          for (var index = 0; index < 3; index++) ...[
            if (index > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: index <= step ? colors.primary : colors.outlineVariant,
                ),
              ),
            Semantics(
              label: 'Step ${index + 1}: ${_CalculatorScreenState.steps[index]}',
              selected: index == step,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: index <= step ? colors.primary : colors.surfaceContainerHighest,
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: index <= step ? colors.onPrimary : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            if (index < 2) const SizedBox(width: 6),
          ],
        ],
      ),
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
        child: Row(
          children: [
            if (onBack != null) ...[
              OutlinedButton(
                key: const Key('calculator_back'),
                onPressed: onBack,
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                key: Key(step == 0 ? 'calculator_continue' : step == 1 ? 'calculator_calculate' : 'calculator_add_to_tracker'),
                onPressed: canContinue ? onContinue : null,
                child: Text(step == 0 ? 'Continue' : step == 1 ? 'Calculate' : 'Add to Tracker'),
              ),
            ),
          ],
        ),
      );
}
