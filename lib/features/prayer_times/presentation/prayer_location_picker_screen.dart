import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../data/location/city_search_provider.dart';
import '../data/location/prayer_location_service.dart';
import '../domain/prayer_times_models.dart';
import '../prayer_times_providers.dart';
import 'prayer_times_controller.dart';
import 'prayer_times_localizations.dart';

class PrayerLocationPickerScreen extends ConsumerStatefulWidget {
  const PrayerLocationPickerScreen({super.key});

  @override
  ConsumerState<PrayerLocationPickerScreen> createState() =>
      _PrayerLocationPickerScreenState();
}

class _PrayerLocationPickerScreenState
    extends ConsumerState<PrayerLocationPickerScreen> {
  late final TextEditingController _searchController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  bool _advancedVisible = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prayerTimesControllerProvider);

    return AppScaffold(
      title: PrayerTimesStrings.location(context),
      onBack: () => Navigator.maybePop(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  PrayerTimesStrings.useMyLocation(context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  PrayerTimesStrings.privacyNote(context),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: state.status == PrayerTimesStatus.locating
                      ? PrayerTimesStrings.refreshing(context)
                      : PrayerTimesStrings.useMyLocation(context),
                  icon: Icons.my_location_rounded,
                  expand: true,
                  onPressed: state.status == PrayerTimesStatus.locating
                      ? null
                      : _useMyLocation,
                ),
                if (state.locationErrorKind != null &&
                    state.status == PrayerTimesStatus.locationError) ...[
                  const SizedBox(height: 12),
                  Text(
                    _locationErrorMessage(context, state.locationErrorKind!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.locationErrorKind ==
                      PrayerLocationErrorKind.permissionPermanentlyDenied)
                    AppButton(
                      label: PrayerTimesStrings.openSettings(context),
                      icon: Icons.settings_outlined,
                      secondary: true,
                      onPressed: () => ref
                          .read(prayerTimesControllerProvider.notifier)
                          .openRelevantSettings(),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  PrayerTimesStrings.searchCity(context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => ref
                      .read(prayerTimesControllerProvider.notifier)
                      .searchCities(value),
                  decoration: InputDecoration(
                    hintText: PrayerTimesStrings.searchCity(context),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(prayerTimesControllerProvider.notifier)
                                  .searchCities('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                ),
                if (state.citySearchLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (state.cityResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final result in state.cityResults)
                    _CitySearchResultTile(
                      result: result,
                      onTap: () => _selectCity(result),
                    ),
                ] else if (_searchController.text.trim().length >= 2 &&
                    !state.citySearchLoading &&
                    state.citySearchError == null) ...[
                  const SizedBox(height: 16),
                  Text(
                    PrayerTimesStrings.noResults(context),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  PrayerTimesStrings.attribution(context),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _advancedVisible,
                  onChanged: (value) =>
                      setState(() => _advancedVisible = value),
                  title: Text(PrayerTimesStrings.advanced(context)),
                  subtitle: Text(
                    PrayerTimesStrings.manualCoordinates(context),
                  ),
                ),
                if (_advancedVisible) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: PrayerTimesStrings.latitude(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: PrayerTimesStrings.longitude(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: PrayerTimesStrings.apply(context),
                    icon: Icons.pin_drop_outlined,
                    expand: true,
                    onPressed: _useCoordinates,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _useMyLocation() async {
    await ref.read(prayerTimesControllerProvider.notifier).useMyLocation();
    if (!mounted) return;
    final state = ref.read(prayerTimesControllerProvider);
    if (state.location?.source == LocationSource.device &&
        state.status != PrayerTimesStatus.locationError) {
      Navigator.pop(context);
    }
  }

  Future<void> _selectCity(CitySearchResult result) async {
    await ref.read(prayerTimesControllerProvider.notifier).selectCity(result);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _useCoordinates() async {
    try {
      await ref
          .read(prayerTimesControllerProvider.notifier)
          .useManualCoordinates(
            _latitudeController.text,
            _longitudeController.text,
          );
      if (mounted) Navigator.pop(context);
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PrayerTimesStrings.invalidCoordinates(context)),
        ),
      );
    }
  }

  String _locationErrorMessage(
    BuildContext context,
    PrayerLocationErrorKind kind,
  ) {
    return switch (kind) {
      PrayerLocationErrorKind.serviceDisabled =>
        PrayerTimesStrings.locationServiceDisabled(context),
      PrayerLocationErrorKind.permissionDenied =>
        PrayerTimesStrings.permissionDenied(context),
      PrayerLocationErrorKind.permissionPermanentlyDenied =>
        PrayerTimesStrings.permissionPermanentlyDenied(context),
      _ => PrayerTimesStrings.locationError(context),
    };
  }
}

class _CitySearchResultTile extends StatelessWidget {
  const _CitySearchResultTile({
    required this.result,
    required this.onTap,
  });

  final CitySearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (result.region != null && result.region!.isNotEmpty) result.region!,
      result.country,
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.location_city_outlined),
      title: Text(result.name),
      subtitle: Text(parts.join(', ')),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
