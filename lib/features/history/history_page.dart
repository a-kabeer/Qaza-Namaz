import 'package:flutter/material.dart';

import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/services/qaza_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({required this.userId, required this.repository, super.key});
  final String userId;
  final QazaRepository repository;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final QazaService _service;
  List<QazaRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _service = QazaService(widget.repository); _load(); }
  Future<void> _load() async { try { final records = await _service.history(widget.userId); if (mounted) setState(() { _records = records; _loading = false; }); } catch (_) { if (mounted) setState(() => _loading = false); } }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_records.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_stories_outlined, size: 48, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text('No Records Found', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8), const Text('Completed Qaza prayers will appear here as a permanent ledger.', textAlign: TextAlign.center)])));

    final grouped = <String, List<QazaRecord>>{};
    for (final record in _records) {
      final date = record.completedAt ?? record.updatedAt;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(record);
    }
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      Text('Ledger', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text('${_records.length} completed records', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 20),
      for (final entry in grouped.entries) ...[
        Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(_formatGroup(entry.key), style: Theme.of(context).textTheme.titleMedium)),
        for (final record in entry.value) Card(child: ListTile(leading: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.tertiary), title: Text(record.prayerType.label), subtitle: Text('Original date: ${_formatDate(record.originalDate)}'), trailing: Text(record.completedAt == null ? 'Completed' : _formatTime(record.completedAt!)))),
        const SizedBox(height: 12),
      ],
    ]));
  }

  String _formatGroup(String value) { final parts = value.split('-'); return '${parts[2]}/${parts[1]}/${parts[0]}'; }
  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
