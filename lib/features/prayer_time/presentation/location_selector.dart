import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/prayer_time_providers.dart';
import '../domain/prayer_location.dart';

enum LocationSelectorStyle {
  card,
  header,
}

class LocationSelector extends ConsumerWidget {
  const LocationSelector({
    super.key,
    required this.location,
    this.style = LocationSelectorStyle.card,
  });

  final PrayerLocation? location;
  final LocationSelectorStyle style;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final option = await showModalBottomSheet<CityOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _LocationPickerSheet(),
    );
    if (option == null || !context.mounted) return;
    await ref.read(prayerTimeControllerProvider.notifier).selectCity(option);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final refreshing = ref.watch(prayerTimeRefreshProvider);
    final scheme = Theme.of(context).colorScheme;

    final content = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: refreshing ? null : () => _pick(context, ref),
      child: Padding(
        padding: style == LocationSelectorStyle.header
            ? const EdgeInsets.symmetric(vertical: 4)
            : const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: location == null
                  ? Text(l10n.prayerTimeSelectLocation)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location!.primaryLabel,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (location!.secondaryLabel.isNotEmpty)
                          Text(
                            location!.secondaryLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
            ),
            if (refreshing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );

    if (style == LocationSelectorStyle.header) {
      return content;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: content,
    );
  }
}

class _LocationPickerSheet extends ConsumerStatefulWidget {
  const _LocationPickerSheet();

  @override
  ConsumerState<_LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<_LocationPickerSheet> {
  String? _countryCode;
  String _query = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalogAsync = ref.watch(offlineCityCatalogProvider);

    return catalogAsync.when(
      loading: () => SizedBox(
        height: MediaQuery.sizeOf(context).height * .35,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .35,
        child: Center(child: Text(l10n.prayerTimeNoCities)),
      ),
      data: (catalog) {
        if (_countryCode == null) {
          final query = _query.trim().toLowerCase();
          final codes = catalog.countryCodes();
          final countries = query.isEmpty
              ? codes
              : codes.where((code) {
                  return catalog.countryName(code)
                      .toLowerCase()
                      .contains(query);
                }).toList(growable: false);

          return _PickerScaffold(
            title: l10n.prayerTimeSelectCountry,
            searchLabel: l10n.prayerTimeSelectCountry,
            onQueryChanged: (value) => setState(() => _query = value),
            controller: _searchController,
            child: ListView.builder(
              itemCount: countries.length,
              itemBuilder: (_, index) {
                final code = countries[index];
                return ListTile(
                  leading: const Icon(Icons.public_rounded),
                  title: Text(catalog.countryName(code)),
                  subtitle: Text(code),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => setState(() {
                    _countryCode = code;
                    _query = '';
                    _searchController.clear();
                  }),
                );
              },
            ),
          );
        }

        final cities = catalog.citiesForCountry(
          _countryCode!,
          query: _query,
        );

        return _PickerScaffold(
          title: catalog.countryName(_countryCode!),
          searchLabel: l10n.prayerTimeSearchCity,
          onQueryChanged: (value) => setState(() => _query = value),
          controller: _searchController,
          leading: IconButton(
            tooltip: l10n.commonBack,
            onPressed: () => setState(() {
              _countryCode = null;
              _query = '';
              _searchController.clear();
            }),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          child: cities.isEmpty
              ? Center(child: Text(l10n.prayerTimeNoCities))
              : ListView.builder(
                  itemCount: cities.length,
                  itemBuilder: (_, index) {
                    final city = cities[index];
                    return ListTile(
                      title: Text(city.city),
                      subtitle: Text(
                        city.region.isEmpty
                            ? city.timezoneId
                            : '${city.region} • ${city.timezoneId}',
                      ),
                      onTap: () => Navigator.of(context).pop(city),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _PickerScaffold extends StatelessWidget {
  const _PickerScaffold({
    required this.title,
    required this.searchLabel,
    required this.onQueryChanged,
    required this.controller,
    required this.child,
    this.leading,
  });

  final String title;
  final String searchLabel;
  final ValueChanged<String> onQueryChanged;
  final TextEditingController controller;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                if (leading != null) leading!,
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SearchBar(
              hintText: searchLabel,
              leading: const Icon(Icons.search_rounded),
              controller: controller,
              onChanged: onQueryChanged,
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
