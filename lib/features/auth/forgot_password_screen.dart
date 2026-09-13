import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final email = TextEditingController();
  String? message;

  @override
  void dispose() { email.dispose(); super.dispose(); }

  void submit() {
    final value = email.text.trim();
    if (!value.contains('@')) { setState(() => message = 'Please enter a valid email address.'); return; }
    setState(() => message = 'Password reset is not connected yet.');
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(Icons.lock_reset_rounded, size: 52, color: s.primary),
        const SizedBox(height: 18),
        Text('Forgot Password', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Enter your email address and we will use the configured password-reset service when email authentication is connected.'),
        const SizedBox(height: 24),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined))),
        if (message != null) ...[const SizedBox(height: 12), Text(message!, style: TextStyle(color: s.error))],
        const SizedBox(height: 20),
        SizedBox(height: 52, child: FilledButton(onPressed: submit, child: const Text('Send Reset Link'))),
        const SizedBox(height: 12),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Sign In')),
      ]))))),
    );
  }
}
