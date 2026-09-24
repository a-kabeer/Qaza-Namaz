import 'package:flutter/material.dart';

/// Global Snackbar policy for the Qaza Namaz app.
///
/// Flutter puts Snackbar timing on each SnackBar rather than
/// SnackBarThemeData. The app-level ScaffoldMessenger normalizes every
/// SnackBar so individual call sites cannot accidentally use a longer timeout
/// or a persistent action Snackbar.
abstract final class AppSnackBarPolicy {
  static const Duration duration = Duration(seconds: 5);

  static SnackBar normalize(SnackBar snackBar) {
    return SnackBar(
      key: snackBar.key,
      content: snackBar.content,
      backgroundColor: snackBar.backgroundColor,
      elevation: snackBar.elevation,
      margin: snackBar.margin,
      padding: snackBar.padding,
      width: snackBar.width,
      shape: snackBar.shape,
      behavior: snackBar.behavior,
      action: snackBar.action,
      actionOverflowThreshold: snackBar.actionOverflowThreshold,
      showCloseIcon: snackBar.showCloseIcon,
      closeIconColor: snackBar.closeIconColor,
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

/// App-scoped ScaffoldMessenger that enforces [AppSnackBarPolicy].
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
    return super.showSnackBar(
      AppSnackBarPolicy.normalize(snackBar),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }
}
