# Platform Setup

Qaza Namaz is an offline-only Flutter Android application. The production app does not require cloud authentication, cloud databases, cloud backup, or an internet connection.

## Android requirements

- Flutter stable 3.47.4
- Java 17
- Android target SDK 36
- NDK 28.2.13676358
- Release signing configured through `android/key.properties`
- Google Play Services Location remains available because the location-settings bridge uses it.

## Offline location

Location uses geolocator for device location and Google Play Services Location for Android location-settings resolution. Reverse geocoding uses bundled GeoNames data. Prayer-time and Qibla calculations run locally.

## Release verification

Before release:

1. Run Flutter analysis and tests.
2. Build the release APK/AAB.
3. Verify the merged release manifest does not request `android.permission.INTERNET`.
4. Verify the offline architecture check passes.
5. Test the installed release with network access disabled.
