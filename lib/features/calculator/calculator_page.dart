import 'package:flutter/material.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  double _age = 14;
  int _deductionDays = 0;
  int _dailyTarget = 5;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.calculate_rounded, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calculator', style: Theme.of(context).textTheme.headlineSmall),
                Text('Estimate your Qaza starting point', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lifeline Milestones', style: Theme.of(context).textTheme.titleLarge),
                    const Chip(label: Text('Step 1 of 3')),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Age of Puberty (Baligh / بلوغ)', style: Theme.of(context).textTheme.labelLarge),
                Slider(
                  value: _age,
                  min: 9,
                  max: 20,
                  divisions: 11,
                  label: _age.round().toString(),
                  onChanged: (v) => setState(() => _age = v),
                ),
                Text('${_age.round()} lunar years', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Valid Deductions (Rukhsah)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Enter days you should exclude from the estimate.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '0',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Deduction days',
                    prefixIcon: Icon(Icons.remove_circle_outline),
                  ),
                  onChanged: (v) => _deductionDays = int.tryParse(v) ?? 0,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pace & Target Simulator', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Choose a sustainable daily completion target.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1')),
                    ButtonSegment(value: 5, label: Text('5')),
                    ButtonSegment(value: 10, label: Text('10')),
                    ButtonSegment(value: 20, label: Text('20')),
                  ],
                  selected: {_dailyTarget},
                  onSelectionChanged: (s) => setState(() => _dailyTarget = s.first),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Target: $_dailyTarget record${_dailyTarget == 1 ? '' : 's'} per day',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Calculator inputs are presented as a UI workflow here. Fiqh calculation rules will be implemented only in the dedicated business-logic task.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
