import 'package:flutter/material.dart';

/// Standalone recovery boundary used when encrypted local persistence cannot
/// be opened or migrated. It deliberately does not create Riverpod state,
/// repositories, Firebase clients, or account-scoped UI.
class FatalDatabaseErrorApp extends StatefulWidget {
  const FatalDatabaseErrorApp({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final Future<void> Function() onRetry;

  @override
  State<FatalDatabaseErrorApp> createState() => _FatalDatabaseErrorAppState();
}

class _FatalDatabaseErrorAppState extends State<FatalDatabaseErrorApp> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.error;
  }
  bool _retrying = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 56,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Local data could not be opened',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Qaza Namaz could not safely open or migrate its encrypted '
                      'local database. Your existing data has not been replaced.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'The retry also failed. Close and reopen the app after '
                        'checking the device storage, or use the app recovery '
                        'path if one is available.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _retrying ? null : _retry,
                      icon: _retrying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(_retrying ? 'Retrying…' : 'Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _error = null;
    });

    try {
      await widget.onRetry();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _retrying = false;
      });
    }
  }
}
