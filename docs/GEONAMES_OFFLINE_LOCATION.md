# Offline GeoNames Location Data

Prayer Time uses two offline GeoNames-derived datasets for different jobs:

- `geonames_offline` provides reverse lookup from one-time GPS coordinates to the nearest supported populated place.
- `assets/data/geonames_cities15000.tsv` provides the forward city catalog used by manual offline search.

The bundled forward catalog is derived from the GeoNames `cities15000` export and GeoNames administrative-division/country metadata. Each row contains:

`geonameId, city, region, country, countryCode, latitude, longitude, timezoneId`

The application keeps the actual GPS latitude/longitude for `source=current`; the reverse-matched GeoNames coordinates are never substituted for those calculation coordinates. For `source=city`, the selected catalog coordinates are the calculation coordinates.

## Attribution

GeoNames data is licensed under CC BY 4.0. The application displays the attribution exposed by `geonames_offline` in Settings > About > Licenses. The complete Noto Nastaliq Urdu OFL notice is bundled as an asset and registered in Flutter's licence registry at startup. Dart/Flutter package notices are shown with Flutter's built-in licence page, and Android native dependency notices are collected through `flutter_native_oss_licenses` for both supported Android hosts.

The `geonames_offline` package documentation requires downstream applications that ship its data to display its attribution.
