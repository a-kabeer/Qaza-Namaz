import 'package:flutter/material.dart';

import '../../core/widgets/components.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Calculator',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Text('Qaza estimate calculator'),
            SizedBox(height: 12),
            Text('Use this screen for planning and estimation. It does not replace individual Qaza records.'),
            SizedBox(height: 20),
            TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Years of missed prayers')),
            SizedBox(height: 12),
            FilledButton(onPressed: null, child: Text('Calculate')),
          ],
        ),
      );
}
