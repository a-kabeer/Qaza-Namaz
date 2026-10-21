import '../../domain/entities/local_account.dart';

/// Stable labels keep duplicate Guest workspaces distinguishable in chooser
/// and management screens without exposing the full internal workspace ID.
String guestWorkspaceDisplayLabel(
  LocalAccount workspace,
  Iterable<LocalAccount> workspaces, {
  required String fallbackName,
}) {
  String baseName(LocalAccount account) {
    final name = account.displayName?.trim();
    return name == null || name.isEmpty ? fallbackName : name;
  }

  final base = baseName(workspace);
  final matches = workspaces
      .where(
        (account) => baseName(account).toLowerCase() == base.toLowerCase(),
      )
      .toList(growable: false);
  if (matches.length < 2) return base;

  String suffix(LocalAccount account) {
    final separator = account.localAccountId.lastIndexOf('_');
    final token = separator >= 0
        ? account.localAccountId.substring(separator + 1)
        : account.localAccountId;
    return token.length <= 6 ? token : token.substring(token.length - 6);
  }

  final currentSuffix = suffix(workspace);
  final suffixCollisions =
      matches.where((account) => suffix(account) == currentSuffix).length;
  if (suffixCollisions == 1) return '$base · $currentSuffix';

  final index = matches.indexWhere(
    (account) => account.localAccountId == workspace.localAccountId,
  );
  return '$base · Workspace ${index + 1}';
}
