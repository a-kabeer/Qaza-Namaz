import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(Icons.mosque_rounded, size: 48, color: scheme.primary),
              ),
              const SizedBox(height: 20),
              Text('Qaza Namaz', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('قضاء نماز', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.secondary)),
              const SizedBox(height: 8),
              Text('A calm place for prayer accountability', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 28),
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }
}
