import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import 'app_error.dart';

/// The one place a classified failure becomes words.
///
/// Surfaces call this rather than writing their own copy, so the same
/// underlying failure reads the same way wherever the user meets it.
extension AppErrorPresentation on AppError {
  String message(BuildContext context) => messageFor(
        AppLocalizations.of(context),
        kind,
      );

  /// The action to offer alongside the message, or null when the only useful
  /// thing is to dismiss it.
  ///
  /// Retry is offered exactly when [AppErrorKind.isRetryable] says repeating
  /// the action could work — never as decoration on a failure that will
  /// repeat identically.
  String? actionLabel(BuildContext context) => isRetryable
      ? AppLocalizations.of(context).commonRetry
      : switch (kind) {
          AppErrorKind.permission =>
            AppLocalizations.of(context).commonOpenSettings,
          _ => null,
        };
}

/// Resolves a kind to its localized message, without needing a context.
String messageFor(AppLocalizations l10n, AppErrorKind kind) => switch (kind) {
      AppErrorKind.network => l10n.errorNetwork,
      AppErrorKind.timeout => l10n.errorTimeout,
      AppErrorKind.permission => l10n.errorPermission,
      AppErrorKind.authentication => l10n.errorAuthentication,
      AppErrorKind.validation => l10n.errorValidation,
      AppErrorKind.malformedData => l10n.errorMalformedData,
      AppErrorKind.storage => l10n.errorStorage,
      AppErrorKind.unknown => l10n.errorUnknown,
    };
