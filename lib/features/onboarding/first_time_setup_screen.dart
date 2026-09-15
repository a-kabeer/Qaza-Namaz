import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';

class FirstTimeSetupScreen extends ConsumerStatefulWidget {
  const FirstTimeSetupScreen({required this.onDone, super.key});
  final VoidCallback onDone;

  @override
  ConsumerState<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends ConsumerState<FirstTimeSetupScreen> {
  bool urdu = false;
  AppThemeMode theme = AppThemeMode.system;

  void _setTheme(AppThemeMode value) {
    setState(() => theme = value);
    ref.read(themeModeProvider.notifier).set(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onDone, icon: const Icon(Icons.close_rounded)),
        title: const Text('First-Time Setup'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text('Welcome to Your Sanctuary', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Choose your language and appearance. You can change these later in Settings.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.45)),
            const SizedBox(height: 24),
            _SetupCard(
              icon: Icons.translate_rounded,
              title: 'Language',
              subtitle: 'Choose the language used across the app.',
              child: SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('English')), ButtonSegment(value: true, label: Text('اردو'))],
                selected: {urdu},
                onSelectionChanged: (value) => setState(() => urdu = value.first),
              ),
            ),
            const SizedBox(height: 14),
            _SetupCard(
              icon: Icons.brightness_6_outlined,
              title: 'Appearance',
              subtitle: 'Use the system setting or choose a theme.',
              child: SegmentedButton<AppThemeMode>(
                segments: const [ButtonSegment(value: AppThemeMode.system, label: Text('System')), ButtonSegment(value: AppThemeMode.light, label: Text('Light')), ButtonSegment(value: AppThemeMode.dark, label: Text('Dark'))],
                selected: {theme},
                onSelectionChanged: (value) => _setTheme(value.first),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.primary.withOpacity(.14)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 22),
                  SizedBox(width: 12),
                  Expanded(child: Text('These choices control the initial presentation. Cloud sync and account data are handled independently.')),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(height: 52, child: FilledButton(onPressed: widget.onDone, child: const Text('Start Tracking'))),
          ],
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.icon, required this.title, required this.subtitle, required this.child});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: scheme.primary.withOpacity(.10), child: Icon(icon, color: scheme.primary)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 2), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
