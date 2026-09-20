import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLockTimeout {
  immediate,
  oneMinute,
  fiveMinutes,
  never;

  Duration? get duration => switch (this) {
        AppLockTimeout.immediate => Duration.zero,
        AppLockTimeout.oneMinute => const Duration(minutes: 1),
        AppLockTimeout.fiveMinutes => const Duration(minutes: 5),
        AppLockTimeout.never => null,
      };

  static AppLockTimeout fromName(String? value) {
    return AppLockTimeout.values.firstWhere(
      (candidate) => candidate.name == value,
      orElse: () => AppLockTimeout.immediate,
    );
  }
}

enum AppLockError {
  unavailable,
  canceled,
  temporarilyLocked,
  failed,
}

class AppLockState {
  const AppLockState({
    required this.initialized,
    required this.enabled,
    required this.locked,
    required this.authenticating,
    required this.timeout,
    this.error,
  });

  const AppLockState.initial()
      : initialized = false,
        enabled = false,
        locked = false,
        authenticating = false,
        timeout = AppLockTimeout.immediate,
        error = null;

  final bool initialized;
  final bool enabled;
  final bool locked;
  final bool authenticating;
  final AppLockTimeout timeout;
  final AppLockError? error;

  AppLockState copyWith({
    bool? initialized,
    bool? enabled,
    bool? locked,
    bool? authenticating,
    AppLockTimeout? timeout,
    AppLockError? error,
    bool clearError = false,
  }) {
    return AppLockState(
      initialized: initialized ?? this.initialized,
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      authenticating: authenticating ?? this.authenticating,
      timeout: timeout ?? this.timeout,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

enum DeviceAuthFailure {
  unavailable,
  canceled,
  temporarilyLocked,
  failed,
}

class DeviceAuthenticationException implements Exception {
  const DeviceAuthenticationException(this.failure);

  final DeviceAuthFailure failure;
}

abstract class DeviceAuthenticationService {
  Future<bool> isSupported();

  Future<bool> authenticate({
    required String localizedReason,
  });
}

class LocalAuthDeviceAuthenticationService
    implements DeviceAuthenticationService {
  LocalAuthDeviceAuthenticationService({LocalAuthentication? authentication})
      : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isSupported() => _authentication.isDeviceSupported();

  @override
  Future<bool> authenticate({
    required String localizedReason,
  }) async {
    try {
      return await _authentication.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (error) {
      throw DeviceAuthenticationException(
        switch (error.code) {
          LocalAuthExceptionCode.noCredentialsSet ||
          LocalAuthExceptionCode.noBiometricsEnrolled ||
          LocalAuthExceptionCode.noBiometricHardware ||
          LocalAuthExceptionCode.uiUnavailable =>
            DeviceAuthFailure.unavailable,
          LocalAuthExceptionCode.temporaryLockout ||
          LocalAuthExceptionCode.biometricLockout =>
            DeviceAuthFailure.temporarilyLocked,
          LocalAuthExceptionCode.userCanceled ||
          LocalAuthExceptionCode.systemCanceled =>
            DeviceAuthFailure.canceled,
          _ => DeviceAuthFailure.failed,
        },
      );
    } catch (_) {
      throw const DeviceAuthenticationException(DeviceAuthFailure.failed);
    }
  }
}

final deviceAuthenticationServiceProvider =
    Provider<DeviceAuthenticationService>(
  (ref) => LocalAuthDeviceAuthenticationService(),
);

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);

class AppLockController extends Notifier<AppLockState> {
  static const String enabledStorageKey = 'qaza_app_lock_enabled';
  static const String timeoutStorageKey = 'qaza_app_lock_timeout';

  DateTime? _backgroundedAt;

  @override
  AppLockState build() {
    Future.microtask(restore);
    ref.onDispose(() {
      _backgroundedAt = null;
    });
    return const AppLockState.initial();
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(enabledStorageKey) ?? false;
    final timeout = AppLockTimeout.fromName(
      prefs.getString(timeoutStorageKey),
    );

    state = AppLockState(
      initialized: true,
      enabled: enabled,
      locked: enabled,
      authenticating: false,
      timeout: timeout,
    );
  }

  Future<bool> setEnabled({
    required bool enabled,
    required String localizedReason,
  }) async {
    if (!state.initialized || state.authenticating) return false;

    if (!enabled) {
      final authenticated = await _authenticate(localizedReason);
      if (!authenticated) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(enabledStorageKey, false);
      state = state.copyWith(
        enabled: false,
        locked: false,
        clearError: true,
      );
      return true;
    }

    final supported = await _isSupported();
    if (!supported) {
      state = state.copyWith(error: AppLockError.unavailable);
      return false;
    }

    final authenticated = await _authenticate(localizedReason);
    if (!authenticated) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledStorageKey, true);
    await prefs.setString(timeoutStorageKey, state.timeout.name);
    state = state.copyWith(
      enabled: true,
      locked: false,
      clearError: true,
    );
    return true;
  }

  Future<void> setTimeout(AppLockTimeout timeout) async {
    if (!state.initialized || !state.enabled || state.authenticating) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(timeoutStorageKey, timeout.name);

    state = state.copyWith(
      timeout: timeout,
      clearError: true,
    );
  }

  Future<bool> unlock({
    required String localizedReason,
  }) async {
    if (!state.initialized || !state.enabled || !state.locked) return true;

    final authenticated = await _authenticate(localizedReason);
    if (!authenticated) return false;

    state = state.copyWith(
      locked: false,
      clearError: true,
    );
    _backgroundedAt = null;
    return true;
  }

  Future<bool> _isSupported() async {
    try {
      return await ref.read(deviceAuthenticationServiceProvider).isSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _authenticate(String localizedReason) async {
    if (state.authenticating) return false;

    state = state.copyWith(
      authenticating: true,
      clearError: true,
    );

    try {
      final supported = await _isSupported();
      if (!supported) {
        state = state.copyWith(
          authenticating: false,
          error: AppLockError.unavailable,
        );
        return false;
      }

      final result = await ref
          .read(deviceAuthenticationServiceProvider)
          .authenticate(localizedReason: localizedReason);

      if (!result) {
        state = state.copyWith(
          authenticating: false,
          error: AppLockError.canceled,
        );
        return false;
      }

      state = state.copyWith(
        authenticating: false,
        clearError: true,
      );
      return true;
    } on DeviceAuthenticationException catch (error) {
      final mappedError = switch (error.failure) {
        DeviceAuthFailure.unavailable => AppLockError.unavailable,
        DeviceAuthFailure.canceled => AppLockError.canceled,
        DeviceAuthFailure.temporarilyLocked => AppLockError.temporarilyLocked,
        DeviceAuthFailure.failed => AppLockError.failed,
      };
      state = state.copyWith(
        authenticating: false,
        error: mappedError,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        authenticating: false,
        error: AppLockError.failed,
      );
      return false;
    }
  }

  void onLifecycleState(AppLifecycleState lifecycleState) {
    if (!state.initialized || !state.enabled) return;

    switch (lifecycleState) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (!state.authenticating) {
          _backgroundedAt ??= DateTime.now();
          if (state.timeout == AppLockTimeout.immediate) {
            state = state.copyWith(locked: true);
          }
        }
        break;
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt == null ||
            state.authenticating ||
            state.timeout == AppLockTimeout.never ||
            state.timeout == AppLockTimeout.immediate) {
          return;
        }

        final elapsed = DateTime.now().difference(backgroundedAt);
        final threshold = state.timeout.duration;
        if (threshold != null && elapsed >= threshold) {
          state = state.copyWith(locked: true);
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
