import 'package:flutter/material.dart';

import 'forgot_password_screen.dart';
import 'verification_screen.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({required this.onGoogleSignIn, super.key});
  final Future<void> Function() onGoogleSignIn;

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  bool signInMode = true;
  bool loading = false;
  String? notice;
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  @override
  void dispose() { email.dispose(); password.dispose(); confirm.dispose(); super.dispose(); }

  Future<void> _google() async {
    setState(() { loading = true; notice = null; });
    try { await widget.onGoogleSignIn(); }
    catch (_) { if (mounted) setState(() => notice = 'Unable to sign in. Please try again.'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  void _email() {
    final value = email.text.trim();
    if (!value.contains('@')) { setState(() => notice = 'Please enter a valid email address.'); return; }
    if (password.text.isEmpty) { setState(() => notice = 'Please enter your password.'); return; }
    if (!signInMode && password.text.length < 6) { setState(() => notice = 'Password must be at least 6 characters.'); return; }
    if (!signInMode && password.text != confirm.text) { setState(() => notice = 'Passwords do not match.'); return; }
    setState(() => notice = 'Email authentication is not connected yet.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Authentication')),
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _BrandHeader(),
        const SizedBox(height: 20),
        SegmentedButton<bool>(segments: const [ButtonSegment(value: true, icon: Icon(Icons.login_rounded), label: Text('Sign In')), ButtonSegment(value: false, icon: Icon(Icons.person_add_alt_1_rounded), label: Text('Create Account'))], selected: {signInMode}, onSelectionChanged: (v) => setState(() { signInMode = v.first; notice = null; })),
        const SizedBox(height: 24),
        Text(signInMode ? 'Welcome back' : 'Create your account', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(signInMode ? 'Sign in to continue to your Qaza Namaz tracker.' : 'Create an account to securely keep your Qaza progress available across your devices.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
        const SizedBox(height: 18),
        if (notice != null) ...[_Notice(message: notice!, onClose: () => setState(() => notice = null)), const SizedBox(height: 12)],
        SizedBox(height: 52, child: OutlinedButton.icon(onPressed: loading ? null : _google, icon: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.g_mobiledata_rounded), label: Text(loading ? 'Signing in...' : 'Continue with Google'))),
        const SizedBox(height: 10),
        SizedBox(height: 52, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationScreen(channel: 'Phone'))), icon: const Icon(Icons.phone_iphone_rounded), label: const Text('Continue with Phone'))),
        const SizedBox(height: 10),
        SizedBox(height: 52, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationScreen(channel: 'WhatsApp'))), icon: const Icon(Icons.chat_rounded), label: const Text('Continue with WhatsApp'))),
        const SizedBox(height: 22),
        const _Divider(),
        const SizedBox(height: 18),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded))),
        if (!signInMode) ...[const SizedBox(height: 12), TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.verified_user_outlined)))],
        if (signInMode) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())), child: const Text('Forgot password?'))),
        const SizedBox(height: 8),
        SizedBox(height: 52, child: FilledButton(onPressed: _email, child: Text(signInMode ? 'Sign In' : 'Create Account'))),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, children: [Text(signInMode ? "Don't have an account? " : 'Already have an account? '), TextButton(onPressed: () => setState(() { signInMode = !signInMode; notice = null; }), child: Text(signInMode ? 'Create Account' : 'Sign In'))]),
        const SizedBox(height: 8),
        Text('Google is the currently connected authentication provider. Other methods are represented for their planned UI flows.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ])))));
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) { final s = Theme.of(context).colorScheme; return Column(children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: s.primary.withOpacity(.10), borderRadius: BorderRadius.circular(18)), child: Icon(Icons.mosque_rounded, size: 36, color: s.primary)), const SizedBox(height: 10), Text('Qaza Namaz', style: Theme.of(context).textTheme.titleLarge), Text('قضاء نماز', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: s.secondary)), Text('Spiritual Devotion & Prayer Accountability', style: Theme.of(context).textTheme.bodySmall)]); }
}

class _Divider extends StatelessWidget { const _Divider(); @override Widget build(BuildContext context) => Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or continue with email', style: Theme.of(context).textTheme.bodySmall)), const Expanded(child: Divider())]); }
class _Notice extends StatelessWidget { const _Notice({required this.message, required this.onClose}); final String message; final VoidCallback onClose; @override Widget build(BuildContext context) { final s = Theme.of(context).colorScheme; return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: s.errorContainer, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(Icons.info_outline_rounded, color: s.onErrorContainer), const SizedBox(width: 10), Expanded(child: Text(message, style: TextStyle(color: s.onErrorContainer))), IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded))])); } }
