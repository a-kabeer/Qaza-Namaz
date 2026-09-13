import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/services/qaza_service.dart';
import '../firestore_verification/firestore_verification_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.userId, required this.repository, required this.onSignOut, super.key});
  final String userId;
  final QazaRepository repository;
  final Future<void> Function() onSignOut;
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final QazaService _service;
  int _pending = 0;
  bool _loading = true;
  bool _signingOut = false;
  @override void initState() { super.initState(); _service = QazaService(widget.repository); _load(); }
  Future<void> _load() async {
    try {
      final progress = await _service.overallProgress(widget.userId);
      if (!mounted) return;
      setState(() { _pending = progress.pending; _loading = false; });
    } catch (_) { if (!mounted) return; setState(() => _loading = false); }
  }
  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try { await widget.onSignOut(); } finally { if (mounted) setState(() => _signingOut = false); }
  }
  void _openFirestoreVerification() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FirestoreVerificationPage(userId: widget.userId, repository: widget.repository)));
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qaza Namaz'), actions: [
        IconButton(tooltip: 'Sign out', onPressed: _signingOut ? null : _signOut, icon: _signingOut ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.logout)),
      ]),
      body: Center(child: _loading ? const CircularProgressIndicator() : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Qaza Namaz', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('Pending Qaza: $_pending'),
          const SizedBox(height: 24),
          const Text('Your records are now loaded through your signed-in account.\nThe complete Google Stitch interface will be added in Task 3.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Wrap(spacing: 8, children: [for (final prayer in allPrayerTypes) Chip(label: Text(prayer.label))]),
          const SizedBox(height: 24),
          OutlinedButton.icon(onPressed: _openFirestoreVerification, icon: const Icon(Icons.cloud_sync), label: const Text('Firestore Verification')),
        ],
      )),
    );
  }
}
