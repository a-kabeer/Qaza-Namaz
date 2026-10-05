import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/local_account.dart';
import '../../l10n/app_localizations.dart';

class AccountChoiceScreen extends ConsumerWidget {
  const AccountChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = ref.watch(accountSessionManagerProvider);
    final busy = session.state.phase == AccountSessionPhase.connecting;

    ref.listen(
      accountSessionManagerProvider,
      (previous, next) {
        if (previous?.state.phase == AccountSessionPhase.connecting &&
            next.state.phase == AccountSessionPhase.ready &&
            next.state.message != null &&
            context.mounted) {
          ref
              .read(appSnackbarServiceProvider)
              .error(l10n.accountChoiceGoogleFailed);
        }
      },
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              children: [
                Container(
                  width: 88,
                  height: 88,
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Icon(
                    Icons.mosque_rounded,
                    size: 48,
                    color: scheme.primary,
                    semanticLabel: l10n.appTitle,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.appTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.accountChoiceHeadline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.accountChoiceDescription,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => ref
                          .read(accountSessionManagerProvider.notifier)
                          .connectGoogle(),
                  icon: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const _GoogleGIcon(),
                  label: Text(l10n.accountChoiceContinueGoogle),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => ref
                          .read(accountSessionManagerProvider.notifier)
                          .continueAsGuest(),
                  child: Text(l10n.accountChoiceContinueGuest),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.accountChoiceGuestDescription,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 20,
      child: CustomPaint(
        painter: _GoogleGPainter(),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .33;
    final strokeWidth = size.width * .16;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final segments = <(double, double, Color)>[
      (-math.pi * .96, math.pi * .50, const Color(0xFF4285F4)),
      (math.pi * .50, math.pi * .98, const Color(0xFF34A853)),
      (math.pi * .98, math.pi * 1.46, const Color(0xFFFBBC04)),
      (math.pi * 1.46, math.pi * 2.10, const Color(0xFFEA4335)),
      (math.pi * 2.10, math.pi * 2.50, const Color(0xFF4285F4)),
    ];

    final rect = Rect.fromCircle(center: center, radius: radius);
    for (final (start, end, color) in segments) {
      paint.color = color;
      canvas.drawArc(rect, start, end - start, false, paint);
    }

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - strokeWidth / 2,
        size.width * .38,
        strokeWidth,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
