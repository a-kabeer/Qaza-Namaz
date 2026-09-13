import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/services/qaza_service.dart';

enum _VerificationState { idle, running, success, failure }

class FirestoreVerificationPage extends StatefulWidget {
  const FirestoreVerificationPage({
    required this.userId,
    required this.repository,
    super.key,
  });

  final String userId;
  final QazaRepository repository;

  @override
  State<FirestoreVerificationPage> createState() =>
      _FirestoreVerificationPageState();
}

class _FirestoreVerificationPageState
    extends State<FirestoreVerificationPage> {
  late final QazaService _service;

  _VerificationState _state = _VerificationState.idle;
  String _message = 'Creates one real test record, reads it back, then deletes it.';

  @override
  void initState() {
    super.initState();
    _service = QazaService(widget.repository);
  }

  Future<void> _runVerification() async {
    if (_state == _VerificationState.running) return;

    setState(() {
      _state = _VerificationState.running;
      _message = 'Writing test record to Firestore...';
    });

    final testDate = DateTime(2000, 1, 1);
    final recordId =
        '${widget.userId}_${PrayerType.fajr.name}_2000-01-01';
    final record = QazaRecord(
      id: recordId,
      userId: widget.userId,
      prayerType: PrayerType.fajr,
      originalDate: testDate,
      status: QazaStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await widget.repository.addRecord(record);
      setState(() => _message = 'Write succeeded. Reading it back...');

      final records = await widget.repository.getRecords(
        userId: widget.userId,
        prayerType: PrayerType.fajr,
      );
      final found = records.any((item) => item.id == recordId);
      if (!found) {
        throw StateError('The test record was not returned by Firestore.');
      }

      setState(() => _message = 'Read succeeded. Cleaning up test record...');
      await widget.repository.completeRecord(
        userId: widget.userId,
        recordId: recordId,
        completedAt: DateTime.now(),
      );

      setState(() {
        _state = _VerificationState.success;
        _message =
            'Firestore write, read, security rules, and completion update succeeded.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _VerificationState.failure;
        _message = 'Verification failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final success = _state == _VerificationState.success;
    final failure = _state == _VerificationState.failure;

    return Scaffold(
      appBar: AppBar(title: const Text('Firestore Verification')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  success
                      ? Icons.cloud_done
                      : failure
                          ? Icons.error_outline
                          : Icons.cloud_queue,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  'Firestore Connection Test',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(_message, textAlign: TextAlign.center),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _state == _VerificationState.running
                      ? null
                      : _runVerification,
                  icon: _state == _VerificationState.running
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _state == _VerificationState.running
                        ? 'Testing...'
                        : 'Run Firestore Test',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
