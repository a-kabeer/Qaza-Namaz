import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/auth/supabase_auth_service.dart';
import '../../data/powersync/guest_data_adoption_service.dart';
import '../../domain/entities/local_account.dart';
import '../../l10n/app_localizations.dart';
import 'adoption_conflict_dialog.dart';

/// Clean, non-technical authentication dialog for Email sign-in and registration.
class SupabaseAuthDialog extends ConsumerStatefulWidget {
  const SupabaseAuthDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SupabaseAuthDialog(),
    );
  }

  @override
  ConsumerState<SupabaseAuthDialog> createState() => _SupabaseAuthDialogState();
}

class _SupabaseAuthDialogState extends ConsumerState<SupabaseAuthDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successNotice;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _mapFriendlyError(AppLocalizations l10n, String? raw) {
    if (raw == null || raw.isEmpty) {
      return l10n.authErrorGeneric;
    }
    final lower = raw.toLowerCase();
    if (lower.contains('over_email_send_rate_limit') || lower.contains('rate limit')) {
      return l10n.authErrorRateLimit;
    }
    if (lower.contains('invalid login credentials') || lower.contains('invalid credentials')) {
      return l10n.authErrorInvalidCredentials;
    }
    if (lower.contains('already registered') || lower.contains('user already exists')) {
      return l10n.authErrorAlreadyRegistered;
    }
    if (lower.contains('email not confirmed')) {
      return l10n.authErrorEmailNotConfirmed;
    }
    if (lower.contains('password should be at least') || lower.contains('weak_password')) {
      return l10n.authErrorWeakPassword;
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('client is not initialized')) {
      return l10n.authErrorNetwork;
    }
    return l10n.authErrorGeneric;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successNotice = null;
    });

    final authService = ref.read(supabaseAuthServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final result = _isSignUp
          ? await authService.signUp(email: email, password: password)
          : await authService.signInWithPassword(email: email, password: password);

      if (!mounted) return;

      if (result.isSuccess && result.user != null) {
        final user = result.user!;

        // If email confirmation is required and session is null
        if (result.session == null && _isSignUp) {
          setState(() {
            _isLoading = false;
            _isSignUp = false;
            _successNotice = l10n.authConfirmationSentNotice;
          });
          return;
        }

        final sessionManager = ref.read(accountSessionManagerProvider);
        final activeWorkspaceId = sessionManager.activeLocalAccountId;

        if (activeWorkspaceId != null && isGuestLocalWorkspaceId(activeWorkspaceId)) {
          final adoptionService = ref.read(guestDataAdoptionServiceProvider);
          final evaluation = await adoptionService.evaluate(
            guestWorkspaceId: activeWorkspaceId,
            supabaseUserId: user.id,
          );

          if (evaluation.canAutoAdopt) {
            await adoptionService.executeAdoption(
              guestWorkspaceId: activeWorkspaceId,
              supabaseUserId: user.id,
              resolution: AdoptionResolution.keepBoth,
            );
          } else if (evaluation.requiresResolution) {
            if (mounted) {
              final choice = await AdoptionConflictDialog.show(
                context,
                guestCount: evaluation.guestRecordCount,
                cloudCount: evaluation.cloudRecordCount,
              );
              if (choice != null) {
                await adoptionService.executeAdoption(
                  guestWorkspaceId: activeWorkspaceId,
                  supabaseUserId: user.id,
                  resolution: choice,
                );
              }
            }
          }
        }

        await sessionManager.activateSupabaseAccount(user.id);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = _mapFriendlyError(l10n, result.errorMessage);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _mapFriendlyError(l10n, e.toString());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Column(
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: false,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: Text(
                  l10n.authSignIn,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text(
                  l10n.authSignUp,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            selected: {_isSignUp},
            onSelectionChanged: _isLoading
                ? null
                : (selection) {
                    setState(() {
                      _isSignUp = selection.first;
                      _errorMessage = null;
                      _successNotice = null;
                    });
                  },
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                _isSignUp ? l10n.authSignUpSubtitle : l10n.authSignInSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              if (_successNotice != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successNotice!,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              TextFormField(
                key: const Key('supabase_auth_email_input'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.authEmailAddressLabel,
                  hintText: 'example@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return l10n.authEmailRequired;
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return l10n.authEmailInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                key: const Key('supabase_auth_password_input'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: l10n.authPasswordLabel,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return l10n.authPasswordRequired;
                  }
                  if (val.length < 6) {
                    return l10n.authPasswordMinLength;
                  }
                  return null;
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('supabase_auth_submit_button'),
          onPressed: _isLoading ? null : _submit,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _isSignUp ? l10n.authSignUp : l10n.authSignIn,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
