import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/services/qaza_service.dart';

class FinalAuthPage extends StatefulWidget {
  const FinalAuthPage({required this.onGoogleSignIn, super.key});

  final Future<void> Function() onGoogleSignIn;

  @override
  State<FinalAuthPage> createState() => _FinalAuthPageState();
}

class _FinalAuthPageState extends State<FinalAuthPage> {
  bool loading = false;

  Future<void> _google() async {
    setState(() => loading = true);
    try {
      await widget.onGoogleSignIn();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _notConfigured(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label authentication is not connected yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.mosque_rounded, size: 58, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Qaza Namaz', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  const Text('قضاء نماز', textAlign: TextAlign.center),
                  const SizedBox(height: 26),
                  Text('Welcome back', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  const Text('Sign in to continue your Qaza Namaz tracker.'),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: loading ? null : _google,
                    icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold)),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: loading ? null : () => _notConfigured('Phone'),
                    icon: const Icon(Icons.phone_iphone_rounded),
                    label: const Text('Continue with Phone'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: loading ? null : () => _notConfigured('WhatsApp'),
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Continue with WhatsApp'),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => _notConfigured('Email password'),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _notConfigured('Email'),
                    child: const Text('Sign In'),
                  ),
                  if (loading) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Google Sign-In is the connected authentication method. Other methods are UI only until their dedicated integration is implemented.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FinalAppShell extends StatefulWidget {
  const FinalAppShell({
    required this.userId,
    required this.repository,
    required this.onSignOut,
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final String userId;
  final QazaRepository repository;
  final Future<void> Function() onSignOut;
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;

  @override
  State<FinalAppShell> createState() => _FinalAppShellState();
}

class _FinalAppShellState extends State<FinalAppShell> {
  int index = 0;

  late final QazaService service = QazaService(widget.repository);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(userId: widget.userId, service: service, open: _open),
      const CalculatorScreen(),
      HistoryScreen(userId: widget.userId, repository: widget.repository),
      SettingsScreen(
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        onSignOut: widget.onSignOut,
        open: _open,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate_rounded), label: 'Calculator'),
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories_rounded), label: 'Logs'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({required this.title, required this.child, this.actions, super.key});

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: child),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.userId, required this.service, required this.open, super.key});

  final String userId;
  final QazaService service;
  final void Function(Widget) open;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QazaProgress>(
      future: service.overallProgress(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load Qaza progress.'));
        }
        final progress = snapshot.data!;
        final total = progress.pending + progress.completed;
        final value = total == 0 ? 0.0 : progress.completed / total;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assalamu Alaikum', style: Theme.of(context).textTheme.titleMedium),
                      Text('Qaza Completion', style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Data & Cloud',
                  onPressed: () => open(const DataCloudScreen()),
                  icon: const Icon(Icons.cloud_outlined),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${progress.pending} pending', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: value, minHeight: 9),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Completed ${progress.completed}'),
                        Text('Total $total'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(onPressed: () => open(AddQazaScreen(service: service, userId: userId)), icon: const Icon(Icons.add), label: const Text('Add Qaza')),
                OutlinedButton.icon(onPressed: () => open(CompleteQazaScreen(service: service, userId: userId)), icon: const Icon(Icons.check_circle_outline), label: const Text('Complete Qaza')),
                OutlinedButton.icon(onPressed: () => open(NamazWiseScreen(service: service, userId: userId)), icon: const Icon(Icons.view_list_rounded), label: const Text('Namaz-wise')),
              ],
            ),
            const SizedBox(height: 24),
            Text('Prayer Ledger', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...PrayerType.values.map(
              (prayer) => FutureBuilder<PrayerProgress>(
                future: service.prayerProgress(userId, prayer),
                builder: (context, prayerSnapshot) => PrayerCard(
                  prayer: prayer,
                  progress: prayerSnapshot.data,
                  onComplete: () => open(CompleteQazaScreen(service: service, userId: userId, initialPrayer: prayer)),
                  onDates: () => open(PendingDatesScreen(service: service, userId: userId, prayer: prayer)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class PrayerCard extends StatelessWidget {
  const PrayerCard({required this.prayer, required this.progress, required this.onComplete, required this.onDates, super.key});

  final PrayerType prayer;
  final PrayerProgress? progress;
  final VoidCallback onComplete;
  final VoidCallback onDates;

  @override
  Widget build(BuildContext context) {
    final data = progress?.progress;
    final total = data == null ? 0 : data.pending + data.completed;
    final value = total == 0 ? 0.0 : data!.completed / total;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(prayer.label.substring(0, 1)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(prayer.label, style: Theme.of(context).textTheme.titleMedium)),
                Text(data == null ? '…' : '${data.pending} pending'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: value),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Completed ${data?.completed ?? 0}'),
                const Spacer(),
                TextButton(onPressed: onDates, child: const Text('View Dates')),
                FilledButton.tonal(onPressed: data == null || data.pending == 0 ? null : onComplete, child: const Text('Complete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddQazaScreen extends StatefulWidget {
  const AddQazaScreen({required this.service, required this.userId, super.key});

  final QazaService service;
  final String userId;

  @override
  State<AddQazaScreen> createState() => _AddQazaScreenState();
}

class _AddQazaScreenState extends State<AddQazaScreen> {
  bool hijri = false;
  bool range = false;
  bool saving = false;
  DateTime start = DateTime.now();
  DateTime end = DateTime.now();
  final selected = <PrayerType>{};

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Add Qaza',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Calendar & Selection', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Gregorian')),
              ButtonSegment(value: true, label: Text('Hijri')),
            ],
            selected: {hijri},
            onSelectionChanged: (value) => setState(() => hijri = value.first),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Single Date')),
              ButtonSegment(value: true, label: Text('Date Range')),
            ],
            selected: {range},
            onSelectionChanged: (value) => setState(() => range = value.first),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: Text(range ? 'Start date' : 'Selected date'),
                  subtitle: Text(_formatDate(start)),
                  onTap: () => _pickDate(false),
                ),
                if (range)
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text('End date'),
                    subtitle: Text(_formatDate(end)),
                    onTap: () => _pickDate(true),
                  ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(hijri ? 'Hijri calendar selected' : 'Gregorian calendar selected'),
                  subtitle: const Text('Hijri conversion will be supplied by the calendar task.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Missed Prayers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...PrayerType.values.map(
            (prayer) => CheckboxListTile(
              value: selected.contains(prayer),
              onChanged: (value) => setState(() {
                if (value == true) {
                  selected.add(prayer);
                } else {
                  selected.remove(prayer);
                }
              }),
              title: Text(prayer.label),
              subtitle: Text(prayer == PrayerType.witr ? 'Independent prayer' : 'Individual Qaza record'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: saving || selected.isEmpty ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'Saving…' : 'Review & Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool isEnd) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      initialDate: isEnd ? end : start,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isEnd) {
        end = picked;
      } else {
        start = picked;
        if (end.isBefore(start)) end = start;
      }
    });
  }

  Future<void> _save() async {
    if (range && end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date must be on or after the start date.')));
      return;
    }

    setState(() => saving = true);
    final dates = <DateTime>[];
    if (!range) {
      dates.add(DateTime(start.year, start.month, start.day));
    } else {
      for (var date = DateTime(start.year, start.month, start.day); !date.isAfter(end); date = date.add(const Duration(days: 1))) {
        dates.add(date);
      }
    }

    if (range && dates.length > 1) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Qaza Records'),
          content: Text('Create Qaza records for ${dates.length} days?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create Records')),
          ],
        ),
      );
      if (confirmed != true) {
        if (mounted) setState(() => saving = false);
        return;
      }
    }

    await widget.service.recordQazaForDates(
      userId: widget.userId,
      dates: dates,
      prayerTypes: selected,
    );
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Qaza records added successfully.')));
    Navigator.pop(context);
  }
}

class CompleteQazaScreen extends StatefulWidget {
  const CompleteQazaScreen({required this.service, required this.userId, this.initialPrayer, super.key});

  final QazaService service;
  final String userId;
  final PrayerType? initialPrayer;

  @override
  State<CompleteQazaScreen> createState() => _CompleteQazaScreenState();
}

class _CompleteQazaScreenState extends State<CompleteQazaScreen> {
  late PrayerType prayer;
  QazaRecord? record;
  bool loading = true;
  bool working = false;

  @override
  void initState() {
    super.initState();
    prayer = widget.initialPrayer ?? PrayerType.fajr;
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    record = await widget.service.oldestPending(userId: widget.userId, prayerType: prayer);
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Complete Qaza',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('The oldest pending Qaza is selected by default.'),
          const SizedBox(height: 14),
          DropdownButtonFormField<PrayerType>(
            value: prayer,
            decoration: const InputDecoration(labelText: 'Prayer'),
            items: PrayerType.values.map((value) => DropdownMenuItem(value: value, child: Text(value.label))).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => prayer = value);
                _load();
              }
            },
          ),
          const SizedBox(height: 18),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (record == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48),
                    SizedBox(height: 12),
                    Text('No Pending Qaza'),
                    SizedBox(height: 6),
                    Text('There are no pending Qaza records for this prayer.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prayer.label, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    _InfoRow('Original Qaza Date', _formatDate(record!.originalDate)),
                    _InfoRow('Completion Date/Time', _formatDateTime(DateTime.now())),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: working ? null : _complete,
                      icon: const Icon(Icons.check_circle),
                      label: Text(working ? 'Completing…' : 'Mark as Completed'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _complete() async {
    setState(() => working = true);
    final completed = await widget.service.completeOldestPending(userId: widget.userId, prayerType: prayer);
    if (!mounted) return;
    setState(() => working = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(completed ? 'Qaza completed successfully.' : 'No pending Qaza found.')));
    if (completed) _load();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))],
      ),
    );
  }
}

class NamazWiseScreen extends StatefulWidget {
  const NamazWiseScreen({required this.service, required this.userId, super.key});

  final QazaService service;
  final String userId;

  @override
  State<NamazWiseScreen> createState() => _NamazWiseScreenState();
}

class _NamazWiseScreenState extends State<NamazWiseScreen> {
  PrayerType prayer = PrayerType.fajr;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Namaz-wise',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Select one prayer and choose multiple pending dates.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 14),
          DropdownButtonFormField<PrayerType>(
            value: prayer,
            decoration: const InputDecoration(labelText: 'Prayer'),
            items: PrayerType.values.map((value) => DropdownMenuItem(value: value, child: Text(value.label))).toList(),
            onChanged: (value) => setState(() => prayer = value ?? prayer),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => PendingDatesScreen(service: widget.service, userId: widget.userId, prayer: prayer))),
            icon: const Icon(Icons.list_alt),
            label: const Text('View Pending Dates'),
          ),
        ],
      ),
    );
  }
}

class PendingDatesScreen extends StatefulWidget {
  const PendingDatesScreen({required this.service, required this.userId, required this.prayer, super.key});

  final QazaService service;
  final String userId;
  final PrayerType prayer;

  @override
  State<PendingDatesScreen> createState() => _PendingDatesScreenState();
}

class _PendingDatesScreenState extends State<PendingDatesScreen> {
  List<QazaRecord> records = [];
  final selected = <String>{};
  bool loading = true;
  bool working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await widget.service.repository.getRecords(
      userId: widget.userId,
      prayerType: widget.prayer,
      status: QazaStatus.pending,
    );
    if (!mounted) return;
    setState(() {
      records = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '${widget.prayer.label} — Pending Qaza',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? const Center(child: Text('No pending dates.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${selected.length} selected', style: Theme.of(context).textTheme.titleMedium)),
                        TextButton(onPressed: () => setState(selected.clear), child: const Text('Clear')),
                      ],
                    ),
                    ...records.map(
                      (record) => CheckboxListTile(
                        value: selected.contains(record.id),
                        onChanged: (value) => setState(() {
                          if (value == true) {
                            selected.add(record.id);
                          } else {
                            selected.remove(record.id);
                          }
                        }),
                        title: Text(_formatDate(record.originalDate)),
                        subtitle: const Text('Original Qaza Date'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: working || selected.isEmpty ? null : _complete,
                      child: Text(working ? 'Completing…' : 'Mark as Completed'),
                    ),
                  ],
                ),
    );
  }

  Future<void> _complete() async {
    setState(() => working = true);
    final count = await widget.service.completeSelected(userId: widget.userId, recordIds: selected.toList());
    if (!mounted) return;
    setState(() => working = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count Qaza record${count == 1 ? '' : 's'} completed.')));
    Navigator.pop(context);
  }
}

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Text('Precision Qaza Engine', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Planning and estimation only. It does not directly create Qaza records.'),
        const SizedBox(height: 18),
        _section(context, 'Age of Puberty / Baligh', Icons.person_outline, ['Age / date input', 'Calculation method']),
        _section(context, 'Valid Deductions / Rukhsah', Icons.tune, ['Add deduction period', 'Review deductions']),
        _section(context, 'Estimated Qaza', Icons.calculate_outlined, ['Estimated result', 'Breakdown']),
        _section(context, 'Pace & Target Simulator', Icons.speed_outlined, ['Daily target', 'Estimated completion time']),
        _section(context, 'Lifeline Milestones', Icons.flag_outlined, ['Progress milestones']),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Fiqh calculations may vary by personal circumstances and scholarly guidance.'),
          ),
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title, IconData icon, List<String> rows) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        children: rows.map((row) => ListTile(title: Text(row), trailing: const Icon(Icons.chevron_right))).toList(),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.userId, required this.repository, super.key});

  final String userId;
  final QazaRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  PrayerType? filter;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QazaRecord>>(
      future: QazaService(widget.repository).history(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load history.'));
        }
        var records = snapshot.data ?? <QazaRecord>[];
        if (filter != null) records = records.where((record) => record.prayerType == filter).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            Row(
              children: [
                Expanded(child: Text('History Ledger', style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(onPressed: () => _pickFilter(context), icon: const Icon(Icons.filter_list)),
              ],
            ),
            const SizedBox(height: 10),
            if (records.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off, size: 44),
                      SizedBox(height: 10),
                      Text('No Records Found'),
                      SizedBox(height: 4),
                      Text('Completed Qaza prayers will appear here.', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            else
              ...records.map(
                (record) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.check_circle),
                    title: Text(record.prayerType.label),
                    subtitle: Text('Original: ${_formatDate(record.originalDate)}\nCompleted: ${_formatDateTime(record.completedAt)}'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickFilter(BuildContext context) async {
    final value = await showModalBottomSheet<PrayerType?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Filter History')),
            ListTile(title: const Text('All'), onTap: () => Navigator.pop(sheetContext, null)),
            ...PrayerType.values.map((prayer) => ListTile(title: Text(prayer.label), onTap: () => Navigator.pop(sheetContext, prayer))),
          ],
        ),
      ),
    );
    if (mounted) setState(() => filter = value);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.themeMode, required this.onThemeModeChanged, required this.onSignOut, required this.open, super.key});

  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final Future<void> Function() onSignOut;
  final void Function(Widget) open;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _tile(context, 'Account', 'Profile and sign-in status', Icons.account_circle_outlined, () => open(const AccountScreen())),
        _tile(context, 'Appearance & Theme', 'System, Light, Dark', Icons.dark_mode_outlined, () => _themeSheet(context)),
        _tile(context, 'Language', 'English / اردو (RTL)', Icons.translate, () => _languageSheet(context)),
        _tile(context, 'Prayer & Fiqh Rules', 'Preferences and calculation method', Icons.menu_book_outlined, () => open(const FiqhScreen())),
        _tile(context, 'Notifications', 'Reminder preferences', Icons.notifications_none, () => open(const NotificationsScreen())),
        _tile(context, 'Data & Cloud', 'Sync, export and import', Icons.cloud_outlined, () => open(const DataCloudScreen())),
        _tile(context, 'Progress', 'Detailed prayer progress', Icons.insights_outlined, () => open(const ProgressScreen())),
        _tile(context, 'About', 'Version and information', Icons.info_outline, () => open(const AboutScreen())),
        const SizedBox(height: 18),
        OutlinedButton.icon(onPressed: onSignOut, icon: const Icon(Icons.logout), label: const Text('Sign Out')),
      ],
    );
  }

  Widget _tile(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _themeSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Appearance & Theme')),
            ...AppThemeMode.values.map(
              (mode) => RadioListTile<AppThemeMode>(
                value: mode,
                groupValue: themeMode,
                title: Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
                onChanged: (value) {
                  if (value != null) {
                    onThemeModeChanged(value);
                    Navigator.pop(sheetContext);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _languageSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Language')),
            ListTile(title: const Text('English'), trailing: const Icon(Icons.check), onTap: () => Navigator.pop(sheetContext)),
            ListTile(title: const Text('اردو'), subtitle: const Text('Right-to-left layout'), onTap: () => Navigator.pop(sheetContext)),
          ],
        ),
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Account',
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          CircleAvatar(radius: 36, child: Icon(Icons.person, size: 38)),
          SizedBox(height: 16),
          ListTile(title: Text('Signed-in account'), subtitle: Text('Google authentication')),
          ListTile(title: Text('Account security'), subtitle: Text('Managed by the authentication provider')),
        ],
      ),
    );
  }
}

class FiqhScreen extends StatelessWidget {
  const FiqhScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Prayer & Fiqh Rules',
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ListTile(title: Text('Calculation Method'), subtitle: Text('Choose the method applicable to your circumstances.')),
          ListTile(title: Text('Baligh / Puberty'), subtitle: Text('Used by the planning calculator.')),
          ListTile(title: Text('Witr'), subtitle: Text('Witr remains an independent prayer category.')),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Notifications',
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          SwitchListTile(value: false, onChanged: null, title: Text('Daily reminder'), subtitle: Text('Notification support will be implemented in the notifications task.')),
        ],
      ),
    );
  }
}

class DataCloudScreen extends StatelessWidget {
  const DataCloudScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Data & Cloud',
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(child: ListTile(leading: Icon(Icons.cloud_done_outlined), title: Text('Cloud Sync'), subtitle: Text('Sync status will be provided by the sync task.'))),
          SizedBox(height: 10),
          Card(child: ListTile(title: Text('Export / Import'), subtitle: Text('JSON and CSV controls will be connected by the data task.'))),
        ],
      ),
    );
  }
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Progress',
      child: Center(child: Text('Detailed progress will use live Qaza records.')),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'About',
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ListTile(title: Text('Qaza Namaz'), subtitle: Text('Islamic Prayer Qaza Tracker')),
          ListTile(title: Text('Version'), subtitle: Text('0.2.0')),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

String _formatDateTime(DateTime? date) {
  if (date == null) return '—';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_formatDate(date)} $hour:$minute';
}
