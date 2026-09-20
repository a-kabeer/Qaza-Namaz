import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'app_lock_controller.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  bool _promptedForCurrentLock = false;

  void _scheduleUnlockPrompt() {
    if (_promptedForCurrentLock || !mounted) return;
    _promptedForCurrentLock = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      await ref.read(appLockControllerProvider.notifier).unlock(
            localizedReason: l10n.appLockAuthenticationReason,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppLockState>(
      appLockControllerProvider,
      (previous, next) {
        if (!next.locked) {
          _promptedForCurrentLock = false;
        }
        if (next.initialized &&
            next.enabled &&
            next.locked &&
            previous?.locked != true) {
          _scheduleUnlockPrompt();
        }
      },
    );

    final appLock = ref.watch(appLockControllerProvider);
    if (!appLock.initialized) {
      return const ColoredBox(
        color: Colors.transparent,
        child: SizedBox.expand(),
      );
    }

    if (!appLock.enabled || !appLock.locked) {
      return widget.child;
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(appLockControllerProvider.notifier);

    return PopScope<void>(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.appLockLockedTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.appLockLockedBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: appLock.authenticating
                          ? null
                          : () => controller.unlock(
                                localizedReason:
                                    l10n.appLockAuthenticationReason,
                              ),
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: Text(
                        appLock.authenticating
                            ? l10n.appLockUnlocking
                            : l10n.appLockUnlock,
                      ),
                    ),
                    if (appLock.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage(l10n, appLock.error!),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n, AppLockError error) {
    return switch (error) {
      AppLockError.unavailable => l10n.appLockUnavailable,
      AppLockError.canceled => l10n.appLockCanceled,
      AppLockError.temporarilyLocked => l10n.appLockTemporarilyLocked,
      AppLockError.failed => l10n.appLockFailed,
    };
  }
}
