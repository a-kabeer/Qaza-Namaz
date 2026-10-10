import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

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
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/branding/qaza_namaz_logo.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 20),
              Text(AppLocalizations.of(context).appTitle,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('قضاء نماز',
                  style: AppTypography.of(context)
                      .urdu
                      .titleMedium
                      ?.copyWith(color: scheme.secondary)),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).splashTagline,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 28),
              // Keep startup splash static. Required local work is performed
              // before this gate becomes routable; remote restoration never
              // owns the splash lifetime.
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
