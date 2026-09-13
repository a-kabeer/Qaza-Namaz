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

  Future<void> _signIn() async {
    setState(() => loading = true);
    try {
      await widget.onGoogleSignIn();
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
                    onPressed: loading ? null : _signIn,
                    icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold)),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: loading ? null : () => _message(context, 'Phone authentication is not connected yet.'),
                    icon: const Icon(Icons.phone_iphone_rounded),
                    label: const Text('Continue with Phone'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: loading ? null : () => _message(context, 'WhatsApp authentication is not connected yet.'),
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Continue with WhatsApp'),
                  ),
                  const SizedBox(height: 20),
                  const TextField(
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 12),
                  const TextField(
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: loading ? null : () => _message(context, 'Email authentication is not connected yet.'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class FinalAppShell extends StatefulWidget {
  const FinalAppShell({
    required this.repository,
    required this.userId,
    required this.onSignOut,
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final QazaRepository repository;
  final String userId;
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
      DashboardScreen(service: service, userId: widget.userId),
      const CalculatorScreen(),
      HistoryScreen(service: service, userId: widget.userId),
      SettingsScreen(onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'Calculator'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Logs'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.service, required this.userId, super.key});
  final QazaService service;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Qaza Namaz',
      child: FutureBuilder<QazaProgress>(
        future: service.overallProgress(userId),
        builder: (context, snapshot) {
          final progress = snapshot.data ?? const QazaProgress(pending: 0, completed: 0);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Your spiritual ledger', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('Track each missed prayer as an individual record.'),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.pending_actions),
                  title: const Text('Pending Qaza'),
                  subtitle: Text('${progress.completed} completed'),
                  trailing: Text('${progress.pending}', style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<QazaRecord>>(
                future: service.getPendingForUser(userId: userId),
                builder: (context, pendingSnapshot) {
                  final records = pendingSnapshot.data ?? <QazaRecord>[];
                  return Column(
                    children: [
                      for (final prayer in PrayerType.values)
                        Card(
                          child: ListTile(
                            title: Text(prayer.label),
                            trailing: Text('${records.where((r) => r.prayerType == prayer).length}'),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddQazaScreen(service: service, userId: userId))),
                icon: const Icon(Icons.add),
                label: const Text('Add Qaza'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompleteQazaScreen(service: service, userId: userId))),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Complete Qaza'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NamazWiseScreen(service: service, userId: userId))),
                icon: const Icon(Icons.format_list_bulleted),
                label: const Text('Namaz-wise'),
              ),
            ],
          );
        },
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
  DateTime selectedDate = DateTime.now();
  final Set<PrayerType> selectedPrayers = {};
  bool saving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(1950), lastDate: DateTime.now(), initialDate: selectedDate);
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _save() async {
    if (selectedPrayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one prayer.')));
      return;
    }
    setState(() => saving = true);
    try {
      final date = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      await widget.service.recordQazaForDates(
        userId: widget.userId,
        dates: [date],
        prayerTypes: selectedPrayers,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Add Qaza',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Gregorian date'),
              subtitle: Text(_formatDate(selectedDate)),
              trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: saving ? null : _pickDate),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Missed prayers'),
          for (final prayer in PrayerType.values)
            CheckboxListTile(
              value: selectedPrayers.contains(prayer),
              onChanged: saving ? null : (value) => setState(() {
                if (value == true) {
                  selectedPrayers.add(prayer);
                } else {
                  selectedPrayers.remove(prayer);
                }
              }),
              title: Text(prayer.label),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Saving...' : 'Save')),
        ],
      ),
    );
  }
}

class CompleteQazaScreen extends StatefulWidget {
  const CompleteQazaScreen({required this.service, required this.userId, super.key});
  final QazaService service;
  final String userId;

  @override
  State<CompleteQazaScreen> createState() => _CompleteQazaScreenState();
}

class _CompleteQazaScreenState extends State<CompleteQazaScreen> {
  PrayerType prayer = PrayerType.fajr;
  bool working = false;

  Future<void> _completeOldest() async {
    setState(() => working = true);
    try {
      final completed = await widget.service.completeOldestPending(userId: widget.userId, prayerType: prayer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(completed ? '${prayer.label} oldest pending Qaza completed.' : 'No pending Qaza for ${prayer.label}.')),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Complete Qaza',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<PrayerType>(
            value: prayer,
            items: [for (final item in PrayerType.values) DropdownMenuItem(value: item, child: Text(item.label))],
            onChanged: working ? null : (value) {
              if (value != null) setState(() => prayer = value);
            },
            decoration: const InputDecoration(labelText: 'Prayer'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: working ? null : _completeOldest,
            icon: const Icon(Icons.check),
            label: Text(working ? 'Completing...' : 'Complete oldest pending'),
          ),
        ],
      ),
    );
  }
}

class NamazWiseScreen extends StatelessWidget {
  const NamazWiseScreen({required this.service, required this.userId, super.key});
  final QazaService service;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Namaz-wise',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final prayer in PrayerType.values)
            Card(
              child: ListTile(
                title: Text(prayer.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PendingDatesScreen(service: service, userId: userId, prayer: prayer),
                  ),
                ),
              ),
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
  final Set<String> selected = {};
  bool working = false;

  Future<void> _completeSelected() async {
    if (selected.isEmpty) return;
    setState(() => working = true);
    try {
      final count = await widget.service.completeSelected(userId: widget.userId, recordIds: selected.toList());
      if (mounted) {
        setState(() => selected.clear());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count Qaza record(s) completed.')));
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '${widget.prayer.label} Qaza',
      child: FutureBuilder<List<QazaRecord>>(
        future: widget.service.getPendingForPrayer(userId: widget.userId, prayerType: widget.prayer),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? <QazaRecord>[];
          if (records.isEmpty) return const Center(child: Text('No pending Qaza records.'));
          records.sort((a, b) => a.originalDate.compareTo(b.originalDate));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final record in records)
                CheckboxListTile(
                  value: selected.contains(record.id),
                  onChanged: working ? null : (value) => setState(() {
                    if (value == true) {
                      selected.add(record.id);
                    } else {
                      selected.remove(record.id);
                    }
                  }),
                  title: Text(_formatDate(record.originalDate)),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: working || selected.isEmpty ? null : _completeSelected,
                child: Text(working ? 'Completing...' : 'Mark ${selected.length} as completed'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Calculator',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Qaza estimate calculator'),
          const SizedBox(height: 12),
          const Text('Use this screen for planning and estimation. It does not replace individual Qaza records.'),
          const SizedBox(height: 20),
          const TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Years of missed prayers')),
          const SizedBox(height: 12),
          const FilledButton(onPressed: null, child: Text('Calculate')),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({required this.service, required this.userId, super.key});
  final QazaService service;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'History',
      child: FutureBuilder<List<QazaRecord>>(
        future: service.getRecords(userId: userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final records = snapshot.data ?? <QazaRecord>[];
          if (records.isEmpty) return const Center(child: Text('No Qaza history yet.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final record in records)
                Card(
                  child: ListTile(
                    title: Text(record.prayerType.label),
                    subtitle: Text('Original: ${_formatDate(record.originalDate)}\nStatus: ${record.status.name}'),
                    trailing: record.completedAt == null ? null : Text(_formatDate(record.completedAt)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.onSignOut, super.key});
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Settings',
      child: ListView(
        children: [
          ListTile(title: const Text('Account'), leading: const Icon(Icons.account_circle_outlined), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountScreen(onSignOut: onSignOut)))),
          ListTile(title: const Text('Prayer & Fiqh Rules'), leading: const Icon(Icons.menu_book_outlined), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FiqhScreen()))),
          ListTile(title: const Text('Notifications'), leading: const Icon(Icons.notifications_none), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
          ListTile(title: const Text('Data & Cloud'), leading: const Icon(Icons.cloud_outlined), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataCloudScreen()))),
          ListTile(title: const Text('Progress'), leading: const Icon(Icons.insights_outlined), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProgressScreen()))),
          ListTile(title: const Text('About'), leading: const Icon(Icons.info_outline), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()))),
        ],
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({required this.onSignOut, super.key});
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Account',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 38)),
          const SizedBox(height: 16),
          const ListTile(title: Text('Signed-in account'), subtitle: Text('Google authentication')),
          const ListTile(title: Text('Account security'), subtitle: Text('Managed by the authentication provider')),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await onSignOut();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class FiqhScreen extends StatelessWidget {
  const FiqhScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Prayer & Fiqh Rules',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(title: Text('Calculation Method'), subtitle: Text('Choose the method applicable to your circumstances.')),
        ListTile(title: Text('Baligh / Puberty'), subtitle: Text('Used by the planning calculator.')),
        ListTile(title: Text('Witr'), subtitle: Text('Witr remains an independent prayer category.')),
      ],
    ),
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Notifications',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: const [SwitchListTile(value: false, onChanged: null, title: Text('Daily reminder'), subtitle: Text('Notification support will be implemented in the notifications task.'))],
    ),
  );
}

class DataCloudScreen extends StatelessWidget {
  const DataCloudScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Data & Cloud',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(child: ListTile(leading: Icon(Icons.cloud_done_outlined), title: Text('Cloud Sync'), subtitle: Text('Sync status will be provided by the sync task.'))),
        SizedBox(height: 10),
        Card(child: ListTile(title: Text('Export / Import'), subtitle: Text('Data export and import will be connected by the data task.'))),
      ],
    ),
  );
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Progress',
    child: const Center(child: Text('Detailed progress will use live Qaza records.')),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'About',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: const [ListTile(title: Text('Qaza Namaz'), subtitle: Text('Islamic Prayer Qaza Tracker')), ListTile(title: Text('Version'), subtitle: Text('0.2.0'))],
    ),
  );
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({required this.title, required this.child, super.key});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: child);
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}
