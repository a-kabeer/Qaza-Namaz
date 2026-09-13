import 'package:flutter/material.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({required this.channel, super.key});
  final String channel;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  bool codeStep = false;
  String? error;

  @override
  void dispose() { phone.dispose(); code.dispose(); super.dispose(); }

  void continueToCode() {
    if (phone.text.trim().length < 7) { setState(() => error = 'Please enter a valid phone number.'); return; }
    setState(() { codeStep = true; error = null; });
  }

  void verify() {
    if (code.text.trim().length != 6) { setState(() => error = 'Enter the 6-digit verification code.'); return; }
    setState(() => error = 'Verification is not connected yet.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.channel} verification')),
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: codeStep ? _code() : _phone()))),
    );
  }

  Widget _phone() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Verify your ${widget.channel.toLowerCase()} number', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 8),
    const Text('Enter your number to continue. This is the planned verification UI; provider logic is separate.'),
    const SizedBox(height: 24),
    DropdownButtonFormField<String>(initialValue: '+92', decoration: const InputDecoration(labelText: 'Country code'), items: const [DropdownMenuItem(value: '+92', child: Text('+92'))], onChanged: (_) {}),
    const SizedBox(height: 12),
    TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_iphone_rounded))),
    if (error != null) ...[const SizedBox(height: 10), Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
    const SizedBox(height: 20),
    SizedBox(height: 52, child: FilledButton(onPressed: continueToCode, child: Text(widget.channel == 'WhatsApp' ? 'Continue with WhatsApp' : 'Send verification code'))),
  ]);

  Widget _code() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Enter verification code', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 8),
    Text('Enter the 6-digit code for your ${widget.channel.toLowerCase()} verification.', style: Theme.of(context).textTheme.bodyLarge),
    const SizedBox(height: 24),
    TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit code', prefixIcon: Icon(Icons.password_rounded))),
    if (error != null) ...[const SizedBox(height: 10), Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
    const SizedBox(height: 8),
    TextButton(onPressed: () => setState(() => error = 'A new code can be requested when this provider is connected.'), child: const Text('Resend code')),
    const SizedBox(height: 8),
    SizedBox(height: 52, child: FilledButton(onPressed: verify, child: const Text('Verify'))),
  ]);
}
