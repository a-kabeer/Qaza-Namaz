import 'package:flutter/material.dart';

enum AppSnackbarSeverity {
  success,
  error,
  info,
  warning,
}

/// Global Snackbar policy for the Qaza Namaz app.
///
/// The canonical API is [AppSnackbarService]. [AppScaffoldMessenger] is a
/// defensive enforcement layer for accidental direct ScaffoldMessenger use.
abstract final class AppSnackBarPolicy {
  static const Duration duration = Duration(seconds: 5);
  static const Duration duplicateWindow = Duration(seconds: 1);

  static SnackBar normalize(
    SnackBar snackBar,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final snackTheme = theme.snackBarTheme;
    final scheme = theme.colorScheme;

    final action = snackBar.action;
    final normalizedAction = action == null
        ? null
        : SnackBarAction(
            label: action.label,
            onPressed: action.onPressed,
            textColor: snackTheme.actionTextColor,
            disabledTextColor: snackTheme.disabledActionTextColor,
          );

    return SnackBar(
      key: snackBar.key,
      content: snackBar.content,
      backgroundColor: snackTheme.backgroundColor ?? scheme.inverseSurface,
      elevation: snackTheme.elevation ?? 6,
      margin: snackTheme.margin,
      padding: snackTheme.padding,
      width: snackTheme.width,
      shape: snackTheme.shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
      behavior: snackTheme.behavior ?? SnackBarBehavior.floating,
      action: normalizedAction,
      actionOverflowThreshold: snackTheme.actionOverflowThreshold,
      showCloseIcon: snackTheme.showCloseIcon ?? false,
      closeIconColor: snackTheme.closeIconColor,
      duration: duration,
      persist: false,
      hitTestBehavior: snackBar.hitTestBehavior,
      animation: snackBar.animation,
      onVisible: snackBar.onVisible,
      dismissDirection: snackBar.dismissDirection,
      clipBehavior: snackBar.clipBehavior,
    );
  }
}

/// Global Snackbar host and defensive enforcement layer.
class AppScaffoldMessenger extends ScaffoldMessenger {
  const AppScaffoldMessenger({
    super.key,
    required super.child,
  });

  @override
  AppScaffoldMessengerState createState() => AppScaffoldMessengerState();
}

class AppScaffoldMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    // Flutter queues SnackBars by default. The app explicitly does not.
    clearSnackBars();
    removeCurrentSnackBar();

    return super.showSnackBar(
      AppSnackBarPolicy.normalize(snackBar, context),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }
}

/// Stable handle used by the application-wide Snackbar service.
final appScaffoldMessengerKey = GlobalKey<AppScaffoldMessengerState>();

/// Canonical application Snackbar API.
///
/// Feature code supplies only the localized message (and, for Undo, the
/// action callback). All lifecycle, styling, duration, persistence, queue,
/// and duplicate rules are centralized here.
class AppSnackbarService {
  AppSnackbarService({
    required GlobalKey<AppScaffoldMessengerState> messengerKey,
    DateTime Function()? now,
  })  : _messengerKey = messengerKey,
        _now = now ?? DateTime.now;

  final GlobalKey<AppScaffoldMessengerState> _messengerKey;
  final DateTime Function() _now;

  String? _lastFingerprint;
  DateTime? _lastShownAt;

  void success(String message) =>
      _show(AppSnackbarSeverity.success, message);

  void error(String message) =>
      _show(AppSnackbarSeverity.error, message);

  void info(String message) =>
      _show(AppSnackbarSeverity.info, message);

  void warning(String message) =>
      _show(AppSnackbarSeverity.warning, message);

  void undo({
    required String message,
    required String actionLabel,
    required VoidCallback onUndo,
  }) {
    _show(
      AppSnackbarSeverity.success,
      message,
      actionLabel: actionLabel,
      onAction: onUndo,
    );
  }

  void _show(
    AppSnackbarSeverity severity,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) return;

    final messenger = _messengerKey.currentState;
    if (messenger == null) return;

    final fingerprint =
        '${severity.name}|$normalizedMessage|${actionLabel ?? ''}';
    final now = _now();
    final lastShownAt = _lastShownAt;
    if (_lastFingerprint == fingerprint &&
        lastShownAt != null &&
        now.difference(lastShownAt) < AppSnackBarPolicy.duplicateWindow) {
      return;
    }

    _lastFingerprint = fingerprint;
    _lastShownAt = now;

    messenger.showSnackBar(
      SnackBar(
        key: UniqueKey(),
        content: _AppSnackbarContent(
          severity: severity,
          message: normalizedMessage,
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
              ),
      ),
    );
  }
}

class _AppSnackbarContent extends StatelessWidget {
  const _AppSnackbarContent({
    required this.severity,
    required this.message,
  });

  final AppSnackbarSeverity severity;
  final String message;

  IconData get _icon => switch (severity) {
        AppSnackbarSeverity.success => Icons.check_circle_outline_rounded,
        AppSnackbarSeverity.error => Icons.error_outline_rounded,
        AppSnackbarSeverity.info => Icons.info_outline_rounded,
        AppSnackbarSeverity.warning => Icons.warning_amber_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snackTheme = theme.snackBarTheme;
    final foreground =
        snackTheme.contentTextStyle?.color ??
        theme.colorScheme.onInverseSurface;

    return Row(
      children: [
        Icon(_icon, size: 20, color: foreground),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: snackTheme.contentTextStyle,
          ),
        ),
      ],
    );
  }
}
