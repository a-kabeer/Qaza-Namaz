import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../../domain/services/qaza_service.dart';

class FinalAuthPage extends StatefulWidget {
  const FinalAuthPage({required this.onGoogleSignIn, super.key});
  final Future<void> Function() onGoogleSignIn;
  @override State<FinalAuthPage> createState() => _FinalAuthPageState();
}

class _FinalAuthPageState extends State<FinalAuthPage> {
  bool loading = false;
  Future<void> _google() async {
    setState(() => loading = true);
    try { await widget.onGoogleSignIn(); } finally { if (mounted) setState(() => loading = false); }
  }
  void _notConfigured(String label) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label authentication is not connected yet.')));
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.mosque_rounded, size: 58, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('Qaza Namaz', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4), const Text('قضاء نماز', textAlign: TextAlign.center),
                const SizedBox(height: 26), Text('Welcome back', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6), const Text('Sign in to continue your Qaza Namaz tracker.'),
                const SizedBox(height: 20),
                OutlinedButton.icon(onPressed: loading ? null : _google, icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold)), label: const Text('Continue with Google')),
                const SizedBox(height: 10), OutlinedButton.icon(onPressed: loading ? null : () => _notConfigured('Phone'), icon: const Icon(Icons.phone_iphone_rounded), label: const Text('Continue with Phone')),
                const SizedBox(height: 10), OutlinedButton.icon(onPressed: loading ? null : () => _notConfigured('WhatsApp'), icon: const Icon(Icons.chat_rounded), label: const Text('Continue with WhatsApp')),
                const SizedBox(height: 20), TextField(keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 12), TextField(obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
                const SizedBox(height: 14), FilledButton(onPressed: loading ? null : () => _notConfigured('Email'), child: const Text('Sign in')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class FinalAppShell extends StatefulWidget {
  const FinalAppShell({required this.repository, required this.userId, super.key});
  final QazaRepository repository;
  final String userId;
  @override State<FinalAppShell> createState() => _FinalAppShellState();
}

class _FinalAppShellState extends State<FinalAppShell> {
  int index = 0;
  late final QazaService service = QazaService(widget.repository);
  @override Widget build(BuildContext context) {
    final pages = [DashboardScreen(service: service, userId: widget.userId), const CalculatorScreen(), HistoryScreen(service: service, userId: widget.userId), const SettingsScreen()];
    return Scaffold(body: pages[index], bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (value) => setState(() => index = value), destinations: const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'Calculator'),
      NavigationDestination(icon: Icon(Icons.history), label: 'Logs'), NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
    ]));
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.service, required this.userId, super.key});
  final QazaService service; final String userId;
  @override Widget build(BuildContext context) => PageScaffold(title: 'Qaza Namaz', child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Your spiritual ledger', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 8), const Text('Track each missed prayer as an individual record.'), const SizedBox(height: 18),
    FutureBuilder<List<QazaRecord>>(future: service.getPendingForUser(userId: userId), builder: (context, snapshot) {
      final records = snapshot.data ?? <QazaRecord>[];
      return Column(children: [Card(child: ListTile(leading: const Icon(Icons.pending_actions), title: const Text('Pending Qaza'), trailing: Text('${records.length}', style: Theme.of(context).textTheme.headlineSmall))), const SizedBox(height: 12), for (final prayer in PrayerType.values) PrayerCard(prayer: prayer, count: records.where((r) => r.prayerType == prayer).length)]);
    }),
    const SizedBox(height: 16), FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddQazaScreen(service: service, userId: userId))), icon: const Icon(Icons.add), label: const Text('Add Qaza')),
    const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompleteQazaScreen(service: service, userId: userId))), icon: const Icon(Icons.check_circle_outline), label: const Text('Complete Qaza')),
    const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NamazWiseScreen(service: service, userId: userId))), icon: const Icon(Icons.format_list_bulleted), label: const Text('Namaz-wise')),
  ]));
}

class PrayerCard extends StatelessWidget { const PrayerCard({required this.prayer, required this.count, super.key}); final PrayerType prayer; final int count; @override Widget build(BuildContext context) => Card(child: ListTile(title: Text(prayer.label), trailing: Text('$count'))); }

class AddQazaScreen extends StatefulWidget {
  const AddQazaScreen({required this.service, required this.userId, super.key});
  final QazaService service; final String userId;
  @override State<AddQazaScreen> createState() => _AddQazaScreenState();
}
class _AddQazaScreenState extends State<AddQazaScreen> {
  DateTime selectedDate = DateTime.now(); final Set<PrayerType> selectedPrayers = {};
  Future<void> _pickDate() async { final picked = await showDatePicker(context: context, firstDate: DateTime(1950), lastDate: DateTime.now(), initialDate: selectedDate); if (picked != null) setState(() => selectedDate = picked); }
  Future<void> _save() async {
    if (selectedPrayers.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one prayer.'))); return; }
    final now = DateTime.now();
    final records = selectedPrayers.map((p) => QazaRecord(id: '${widget.userId}_${p.name}_${_dateKey(selectedDate)}', userId: widget.userId, prayerType: p, originalDate: DateTime(selectedDate.year, selectedDate.month, selectedDate.day), status: QazaStatus.pending, completedAt: null, createdAt: now, updatedAt: now)).toList();
    await widget.service.addRecords(records); if (mounted) Navigator.pop(context);
  }
  @override Widget build(BuildContext context) => PageScaffold(title: 'Add Qaza', child: ListView(padding: const EdgeInsets.all(16), children: [
    Card(child: ListTile(title: const Text('Gregorian date'), subtitle: Text(_formatDate(selectedDate)), trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate))), const SizedBox(height: 12), const Text('Missed prayers'),
    for (final p in PrayerType.values) CheckboxListTile(value: selectedPrayers.contains(p), onChanged: (value) => setState(() => value == true ? selectedPrayers.add(p) : selectedPrayers.remove(p)), title: Text(p.label)),
    const SizedBox(height: 12), FilledButton(onPressed: _save, child: const Text('Save')),
  ]));
}

class CompleteQazaScreen extends StatefulWidget { const CompleteQazaScreen({required this.service, required this.userId, super.key}); final QazaService service; final String userId; @override State<CompleteQazaScreen> createState() => _CompleteQazaScreenState(); }
class _CompleteQazaScreenState extends State<CompleteQazaScreen> {
  PrayerType prayer = PrayerType.fajr;
  Future<void> _completeOldest() async {
    final records = await widget.service.getPendingForPrayer(userId: widget.userId, prayerType: prayer);
    if (records.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pending Qaza for this prayer.'))); return; }
    records.sort((a, b) => a.originalDate.compareTo(b.originalDate)); await widget.service.completeRecord(userId: widget.userId, recordId: records.first.id, completedAt: DateTime.now()); if (mounted) setState(() {});
  }
  @override Widget build(BuildContext context) => PageScaffold(title: 'Complete Qaza', child: ListView(padding: const EdgeInsets.all(16), children: [DropdownButtonFormField<PrayerType>(value: prayer, items: [for (final p in PrayerType.values) DropdownMenuItem(value: p, child: Text(p.label))], onChanged: (v) { if (v != null) setState(() => prayer = v); }, decoration: const InputDecoration(labelText: 'Prayer')), const SizedBox(height: 16), FilledButton.icon(onPressed: _completeOldest, icon: const Icon(Icons.check), label: const Text('Complete oldest pending'))]));
}

class NamazWiseScreen extends StatelessWidget { const NamazWiseScreen({required this.service, required this.userId, super.key}); final QazaService service; final String userId; @override Widget build(BuildContext context) => PageScaffold(title: 'Namaz-wise', child: ListView(padding: const EdgeInsets.all(16), children: [for (final prayer in PrayerType.values) Card(child: ListTile(title: Text(prayer.label), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PendingDatesScreen(service: service, userId: userId, prayer: prayer))))])); }
class PendingDatesScreen extends StatefulWidget { const PendingDatesScreen({required this.service, required this.userId, required this.prayer, super.key}); final QazaService service; final String userId; final PrayerType prayer; @override State<PendingDatesScreen> createState() => _PendingDatesScreenState(); }
class _PendingDatesScreenState extends State<PendingDatesScreen> {
  final Set<String> selected = {};
  Future<void> _completeSelected() async { if (selected.isEmpty) return; await widget.service.completeRecords(userId: widget.userId, recordIds: selected.toList(), completedAt: DateTime.now()); if (mounted) setState(() => selected.clear()); }
  @override Widget build(BuildContext context) => PageScaffold(title: '${widget.prayer.label} Qaza', child: FutureBuilder<List<QazaRecord>>(future: widget.service.getPendingForPrayer(userId: widget.userId, prayerType: widget.prayer), builder: (context, snapshot) { final records = snapshot.data ?? <QazaRecord>[]; return ListView(padding: const EdgeInsets.all(16), children: [for (final record in records) CheckboxListTile(value: selected.contains(record.id), onChanged: (v) => setState(() => v == true ? selected.add(record.id) : selected.remove(record.id)), title: Text(_formatDate(record.originalDate))), const SizedBox(height: 12), FilledButton(onPressed: selected.isEmpty ? null : _completeSelected, child: Text('Mark ${selected.length} as completed'))]; }));
}

class CalculatorScreen extends StatelessWidget { const CalculatorScreen({super.key}); @override Widget build(BuildContext context) => PageScaffold(title: 'Calculator', child: ListView(padding: const EdgeInsets.all(16), children: [Text('Qaza estimate calculator', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12), const Text('Use this screen for planning and estimation. It does not replace individual Qaza records.'), const SizedBox(height: 20), const TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Years of missed prayers')), const SizedBox(height: 12), const FilledButton(onPressed: null, child: Text('Calculate'))])); }
class HistoryScreen extends StatelessWidget { const HistoryScreen({required this.service, required this.userId, super.key}); final QazaService service; final String userId; @override Widget build(BuildContext context) => PageScaffold(title: 'History', child: FutureBuilder<List<QazaRecord>>(future: service.getRecords(userId: userId), builder: (context, snapshot) { final records = snapshot.data ?? <QazaRecord>[]; return ListView(padding: const EdgeInsets.all(16), children: [for (final r in records) Card(child: ListTile(title: Text(r.prayerType.label), subtitle: Text('Original: ${_formatDate(r.originalDate)}\nStatus: ${r.status.name}'), trailing: r.completedAt == null ? null : Text(_formatDate(r.completedAt))) )]; })); }
class SettingsScreen extends StatelessWidget { const SettingsScreen({super.key}); @override Widget build(BuildContext context) => PageScaffold(title: 'Settings', child: ListView(children: [ListTile(title: const Text('Account'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()))), ListTile(title: const Text('Prayer & Fiqh Rules'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FiqhScreen()))), ListTile(title: const Text('Notifications'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))), ListTile(title: const Text('Data & Cloud'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataCloudScreen()))), ListTile(title: const Text('Progress'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProgressScreen()))), ListTile(title: const Text('About'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()))])); }
class PageScaffold extends StatelessWidget { const PageScaffold({required this.title, required this.child, super.key}); final String title; final Widget child; @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: child); }
class AccountScreen extends StatelessWidget { const AccountScreen({super.key}); @override Widget build(BuildContext context) => const PageScaffold(title: 'Account', child: ListView(padding: EdgeInsets.all(16), children: [CircleAvatar(radius: 36, child: Icon(Icons.person, size: 38)), SizedBox(height: 16), ListTile(title: Text('Signed-in account'), subtitle: Text('Google authentication')), ListTile(title: Text('Account security'), subtitle: Text('Managed by the authentication provider'))])); }
class FiqhScreen extends StatelessWidget { const FiqhScreen({super.key}); @override Widget build(BuildContext context) => const PageScaffold(title: 'Prayer & Fiqh Rules', child: ListView(padding: EdgeInsets.all(16), children: [ListTile(title: Text('Calculation Method'), subtitle: Text('Choose the method applicable to your circumstances.')), ListTile(title: Text('Baligh / Puberty'), subtitle: Text('Used by the planning calculator.')), ListTile(title: Text('Witr'), subtitle: Text('Witr remains an independent prayer category.'))])); }
class NotificationsScreen extends StatelessWidget { const NotificationsScreen({super.key}); @override Widget build(BuildContext context) => const PageScaffold(title: 'Notifications', child: ListView(padding: EdgeInsets.all(16), children: [SwitchListTile(value: false, onChanged: null, title: Text('Daily reminder'), subtitle: Text('Notification support will be implemented in the notifications task.'))])); }
class DataCloudScreen extends StatelessWidget { const DataCloudScreen({super.key}); @override Widget build(BuildContext context) => const PageScaffold(title: 'Data & Cloud', child: ListView(padding: EdgeInsets.all(16), children: [Card(child: ListTile(leading: Icon(Icons.cloud_done_outlined), title: Text('Cloud Sync'), subtitle: Text('Sync status will be provided by the sync task.'))), SizedBox(height: 10), Card(child: ListTile(title: Text('Export / Import'), subtitle: Text('JSON and CSV controls will be connected by the data task.')))])); }
class ProgressScreen extends StatelessWidget { const ProgressScreen({super.key}); @override Widget build(BuildContext context) => const PageScaffold(title: 'Progress', child: Center(child: Text('Detailed progress will use live Qaza records.'))); }
class AboutScreen extends StatelessWidget { const AboutScreen({super.key}); @override Widget build(BuildContext context) => const PageScaffold(title: 'About', child: ListView(padding: EdgeInsets.all(16), children: [ListTile(title: Text('Qaza Namaz'), subtitle: Text('Islamic Prayer Qaza Tracker')), ListTile(title: Text('Version'), subtitle: Text('0.2.0'))])); }
String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _formatDate(DateTime? date) { if (date == null) return '—'; const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']; return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}'; }
