import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.onGetStarted, super.key});
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(.10),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.mosque_rounded, size: 46, color: scheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text('Qaza Namaz', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('قضاء نماز', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.secondary)),
                  const SizedBox(height: 28),
                  Text('Track your missed prayers with clarity and consistency.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(height: 1.25)),
                  const SizedBox(height: 12),
                  Text('Record, complete, and keep track of your Qaza Namaz — one prayer at a time.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.5)),
                  const SizedBox(height: 36),
                  SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: onGetStarted, icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Get Started'))),
                  const SizedBox(height: 8),
                  TextButton(onPressed: onGetStarted, child: const Text('Already have an account? Sign In')),
                  const SizedBox(height: 18),
                  Text('Spiritual Devotion & Prayer Accountability', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
