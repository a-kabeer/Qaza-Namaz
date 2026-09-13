import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../data/repositories/in_memory_qaza_repository.dart';
import '../../domain/services/qaza_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = QazaService(InMemoryQazaRepository());
  static const _userId = 'demo-user';

  int _pending = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = await _service.overallProgress(_userId);
    if (!mounted) return;
    setState(() {
      _pending = progress.pending;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qaza Namaz')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Task 1 Core Workflow',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Pending Qaza: $_pending'),
                  const SizedBox(height: 24),
                  const Text(
                    'Frontend is intentionally minimal.\n'
                    'Replace this screen with the Google Stitch UI.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final prayer in allPrayerTypes)
                        Chip(label: Text(prayer.label)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
