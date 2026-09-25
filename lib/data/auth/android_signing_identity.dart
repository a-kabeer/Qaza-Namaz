import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'google_auth_config.dart';

/// The package name and signing certificate fingerprints of the running build.
///
/// Read from the installed package at runtime, not from build configuration,
/// because the question is what Google Play services actually sees when it
/// matches this caller against a registered OAuth client.
@immutable
class AndroidSigningIdentity {
  const AndroidSigningIdentity({
    required this.packageName,
    required this.sha1Fingerprints,
    required this.sha256Fingerprints,
  });

  factory AndroidSigningIdentity.fromPlatform(Map<Object?, Object?> value) =>
      AndroidSigningIdentity(
        packageName: (value['packageName'] as String?) ?? '',
        sha1Fingerprints: _normalizeAll(value['sha1']),
        sha256Fingerprints: _normalizeAll(value['sha256']),
      );

  final String packageName;
  final List<String> sha1Fingerprints;
  final List<String> sha256Fingerprints;

  /// True when the platform gave us nothing to judge.
  bool get isUnknown => packageName.isEmpty || sha1Fingerprints.isEmpty;

  static List<String> _normalizeAll(Object? value) => <String>[
        if (value is List)
          for (final entry in value)
            if (entry is String && entry.trim().isNotEmpty)
              normalizeFingerprint(entry),
      ];

  /// Lowercase, with any `:` separators removed, as google-services.json
  /// stores certificate hashes.
  static String normalizeFingerprint(String value) =>
      value.replaceAll(':', '').replaceAll(' ', '').toLowerCase();
}

/// The outcome of checking this build against the registered OAuth clients.
enum AndroidSigningRegistration {
  /// The package and one of its certificates are registered.
  registered,

  /// The build is signed with a certificate no registered OAuth client knows.
  unregisteredCertificate,

  /// The build reports a different package name than the registered one.
  unexpectedPackage,

  /// The platform could not tell us; nothing is enforced.
  unknown,
}

/// Compares a build's own identity with what Firebase has registered.
///
/// Pure, so the decision is testable without a device.
AndroidSigningRegistration checkAndroidSigningRegistration(
  AndroidSigningIdentity identity, {
  String expectedPackage = googleAndroidApplicationId,
  List<String> registeredSha1s = googleAndroidCertificateSha1s,
}) {
  if (identity.isUnknown || registeredSha1s.isEmpty) {
    return AndroidSigningRegistration.unknown;
  }
  if (identity.packageName != expectedPackage) {
    return AndroidSigningRegistration.unexpectedPackage;
  }

  final registered = {
    for (final value in registeredSha1s)
      AndroidSigningIdentity.normalizeFingerprint(value),
  };
  final matches =
      identity.sha1Fingerprints.any((value) => registered.contains(value));
  return matches
      ? AndroidSigningRegistration.registered
      : AndroidSigningRegistration.unregisteredCertificate;
}

/// Reads the running build's signing identity from the Android host.
class AndroidSigningIdentityService {
  const AndroidSigningIdentityService({MethodChannel? channel})
      : _channel = channel ?? _defaultChannel;

  static const MethodChannel _defaultChannel =
      MethodChannel('qaza_namaz/signing_identity');

  final MethodChannel _channel;

  /// Returns null on any platform or failure that cannot answer.
  ///
  /// Null always means "cannot tell", never "not registered", so a failure to
  /// introspect can never block a sign-in that would otherwise work.
  Future<AndroidSigningIdentity?> read() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final value = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getSigningIdentity',
      );
      if (value == null) return null;
      final identity = AndroidSigningIdentity.fromPlatform(value);
      return identity.isUnknown ? null : identity;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
