import 'package:flutter/material.dart';

import '../../core/widgets/app_scaffold.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  int _step = 0;

  static const steps = <String>['About You', 'Prayer History', 'Result'];

  void _next() {
    if (_step < steps.length - 1) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
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
                  child: _StepContent(key: ValueKey(_step), step: _step),
                ),
              ),
              _StepActions(
                step: _step,
                onBack: _step == 0 ? null : _back,
                onContinue: _next,
              ),
            ],
          ),
        ),
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
                backgroundColor: index <= step
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: index <= step
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final data = switch (step) {
      0 => (
          title: 'About You',
          description: 'Enter your personal dates and baligh information.',
        ),
      1 => (
          title: 'Prayer History',
          description: 'Tell us when regular prayer started so we can calculate the Qaza period.',
        ),
      _ => (
          title: 'Result',
          description: 'Your calculated Qaza estimate will appear here.',
        ),
    };

    return ListView(
      key: ValueKey('calculator_step_$step'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Step ${step + 1} of 3', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(data.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(data.description),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'This step is ready for the next implementation part.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepActions extends StatelessWidget {
  const _StepActions({required this.step, required this.onBack, required this.onContinue});

  final int step;
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
                onPressed: onContinue,
                child: Text(step == 0 ? 'Continue' : step == 1 ? 'Calculate' : 'Add to Tracker'),
              ),
            ),
          ],
        ),
      );
}
