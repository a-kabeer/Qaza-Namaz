import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.onGetStarted, super.key});
  final VoidCallback onGetStarted;
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const SizedBox(height: 40),
    Icon(Icons.mosque_rounded, size: 76),
    const SizedBox(height: 22),
    Text('Qaza Namaz', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
    const SizedBox(height: 6),
    const Text('قضاء نماز', textAlign: TextAlign.center),
    const SizedBox(height: 26),
    Text('Track your missed prayers with clarity and consistency.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 12),
    const Text('Record, complete, and keep track of your Qaza Namaz — one prayer at a time.', textAlign: TextAlign.center),
    const SizedBox(height: 34),
    SizedBox(width: double.infinity, child: FilledButton(onPressed: onGetStarted, child: const Text('Get Started'))),
    const SizedBox(height: 8),
    TextButton(onPressed: onGetStarted, child: const Text('Already have an account? Sign In')),
    const SizedBox(height: 34),
  ])))));
}

class FirstTimeSetupScreen extends StatefulWidget {
  const FirstTimeSetupScreen({required this.onDone, super.key});
  final VoidCallback onDone;
  @override State<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}
class _FirstTimeSetupScreenState extends State<FirstTimeSetupScreen> {
  bool urdu = false;
  ThemeMode theme = ThemeMode.system;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('First-Time Setup')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
    Text('Welcome to Your Sanctuary', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 24),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Language'), const SizedBox(height: 10), SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('English')), ButtonSegment(value: true, label: Text('اردو'))], selected: {urdu}, onSelectionChanged: (v) => setState(() => urdu = v.first))])),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Appearance'), const SizedBox(height: 10), SegmentedButton<ThemeMode>(segments: const [ButtonSegment(value: ThemeMode.system, label: Text('System')), ButtonSegment(value: ThemeMode.light, label: Text('Light')), ButtonSegment(value: ThemeMode.dark, label: Text('Dark'))], selected: {theme}, onSelectionChanged: (v) => setState(() => theme = v.first))])),
    const SizedBox(height: 26),
    FilledButton(onPressed: widget.onDone, child: const Text('Start Tracking')),
  ])));
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.mosque_rounded, size: 72, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 18), Text('Qaza Namaz', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 6), const Text('قضاء نماز'), const SizedBox(height: 24), const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))]));
}
