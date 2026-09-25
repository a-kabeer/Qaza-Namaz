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
