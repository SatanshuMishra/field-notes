import 'dart:async';

import 'package:field_notes/data/updates/update_record_store.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderSubscription;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_controller.g.dart';

const Duration automaticCheckDelay = Duration(seconds: 10);
const Duration automaticCheckInterval = Duration(hours: 24);
const Duration automaticCheckEvaluation = Duration(hours: 1);

@Riverpod(keepAlive: true)
class UpdateGreeting extends _$UpdateGreeting {
  @override
  String? build() => null;

  void greet(String version) => state = version;

  void consume() => state = null;
}

@Riverpod(keepAlive: true)
class UpdateController extends _$UpdateController {
  Timer? _launchTimer;
  Timer? _evaluationTimer;
  AppVersion? _installed;
  ReleaseInfo? _known;
  DateTime? _lastChecked;
  DateTime? _lastAttempt;
  DateTime? _retryAfter;
  bool _ready = false;
  bool _automatic = false;
  bool _installing = false;

  @override
  UpdateStatus build() {
    ref.onDispose(_cancelTimers);
    ref.listen<AsyncValue<AppSettings>>(appSettingsProvider, _onSettings);
    unawaited(_start());
    return const UpdateIdle(null);
  }

  DateTime _now() => ref.read(updateClockProvider)();

  UpdateRecordStore get _store => ref.read(updateRecordStoreProvider);

  Future<void> _start() async {
    final InstalledApp app;
    final AppVersion installed;
    final UpdateRecord record;
    final AppSettings settings;
    try {
      app = await _firstOutcome(installedAppProvider);
      final AppVersion? parsed = AppVersion.tryParse(app.version);
      if (parsed == null) {
        throw FormatException(
          'The installed version does not parse',
          app.version,
        );
      }
      installed = parsed;
      record = await _store.read();
      settings = await _firstOutcome(appSettingsProvider);
    } catch (error) {
      debugPrint('Update checks are unavailable: $error');
      _cancelTimers();
      return;
    }
    if (!ref.mounted) {
      return;
    }
    _installed = installed;
    _lastChecked = record.lastCheckedAt;
    _lastAttempt = record.lastCheckedAt;
    final ReleaseInfo? available = record.lastAvailable;
    if (available != null && available.version.isNewerThan(installed)) {
      _known = available;
      state = UpdateAvailable(available, record.lastCheckedAt ?? _now());
    } else if (record.lastCheckedAt != null) {
      state = UpdateCurrent(record.lastCheckedAt!);
    }
    final AppVersion? seen = record.lastSeenVersion == null
        ? null
        : AppVersion.tryParse(record.lastSeenVersion!);
    if (seen != null && installed.isNewerThan(seen)) {
      ref.read(updateGreetingProvider.notifier).greet(app.version);
    }
    _ready = true;
    final bool automatic =
        ref.read(appSettingsProvider).value?.checkForUpdatesAutomatically ??
        settings.checkForUpdatesAutomatically;
    if (automatic) {
      _turnOnAutomatic(atLaunch: true);
    }
    await _record(() => _store.recordSeenVersion(app.version));
  }

  Future<T> _firstOutcome<T>(ProviderListenable<AsyncValue<T>> provider) {
    final Completer<T> outcome = Completer<T>();
    final ProviderSubscription<AsyncValue<T>> subscription = ref.listen(
      provider,
      (AsyncValue<T>? previous, AsyncValue<T> next) {
        if (outcome.isCompleted) {
          return;
        }
        if (next.hasError) {
          outcome.completeError(next.error!, next.stackTrace);
        } else if (next.hasValue) {
          outcome.complete(next.requireValue);
        }
      },
      fireImmediately: true,
    );
    return outcome.future.whenComplete(subscription.close);
  }

  void _onSettings(
    AsyncValue<AppSettings>? previous,
    AsyncValue<AppSettings> next,
  ) {
    if (!_ready) {
      return;
    }
    if (next is AsyncError<AppSettings>) {
      debugPrint('Update settings could not be read: ${next.error}');
      _turnOffAutomatic();
      return;
    }
    final AppSettings? settings = next.value;
    if (settings == null) {
      return;
    }
    if (settings.checkForUpdatesAutomatically && !_automatic) {
      _turnOnAutomatic(atLaunch: false);
    } else if (!settings.checkForUpdatesAutomatically && _automatic) {
      _turnOffAutomatic();
    }
  }

  void _turnOnAutomatic({required bool atLaunch}) {
    _automatic = true;
    _evaluationTimer ??= Timer.periodic(
      automaticCheckEvaluation,
      (Timer timer) => _evaluate(),
    );
    if (!atLaunch) {
      _evaluate();
    } else if (_isDue(_now())) {
      _launchTimer?.cancel();
      _launchTimer = Timer(automaticCheckDelay, _evaluate);
    }
  }

  void _turnOffAutomatic() {
    _automatic = false;
    _cancelTimers();
  }

  void _cancelTimers() {
    _launchTimer?.cancel();
    _launchTimer = null;
    _evaluationTimer?.cancel();
    _evaluationTimer = null;
  }

  bool _isDue(DateTime now) {
    final DateTime? retryAfter = _retryAfter;
    if (retryAfter != null && now.isBefore(retryAfter)) {
      return false;
    }
    final DateTime? lastAttempt = _lastAttempt;
    return lastAttempt == null ||
        lastAttempt.isAfter(now) ||
        now.difference(lastAttempt) >= automaticCheckInterval;
  }

  void _evaluate() {
    if (!ref.mounted || !_ready || !_automatic) {
      return;
    }
    if (_isDue(_now())) {
      unawaited(check());
    }
  }

  Future<void> check() async {
    final AppVersion? installed = _installed;
    final UpdateStatus current = state;
    if (installed == null ||
        _installing ||
        current is UpdateChecking ||
        current is UpdateDownloading ||
        current is UpdateRestarting) {
      return;
    }
    final DateTime? retryAfter = _retryAfter;
    if (retryAfter != null && _now().isBefore(retryAfter)) {
      state = _knownOr(UpdateCheckFailed(_lastChecked, null, retryAfter));
      return;
    }
    state = UpdateChecking(_lastChecked);
    ReleaseLookup lookup;
    try {
      lookup = await ref.read(releaseSourceProvider).latest();
    } catch (error) {
      debugPrint('The update check failed: $error');
      lookup = const LookupFailed(LookupFailure.badResponse);
    }
    if (!ref.mounted) {
      return;
    }
    final DateTime now = _now();
    switch (lookup) {
      case ReleaseFound(:final ReleaseInfo release)
          when release.version.isNewerThan(installed):
        _settled(now, release);
        state = UpdateAvailable(release, now);
        await _record(() => _store.recordCheck(now, release));
      case ReleaseFound() || NoRelease():
        _settled(now, null);
        state = UpdateCurrent(now);
        await _record(() => _store.recordCheck(now, null));
      case LookupRateLimited(:final DateTime retryAfter):
        _retryAfter = retryAfter;
        state = _knownOr(UpdateCheckFailed(_lastChecked, null, retryAfter));
      case LookupFailed(:final LookupFailure reason):
        _retryAfter = null;
        _lastAttempt = now;
        state = _knownOr(UpdateCheckFailed(_lastChecked, reason, null));
        await _record(() => _store.recordAttempt(now));
    }
  }

  void _settled(DateTime now, ReleaseInfo? known) {
    _known = known;
    _lastChecked = now;
    _lastAttempt = now;
    _retryAfter = null;
  }

  UpdateStatus _knownOr(UpdateCheckFailed failed) {
    final ReleaseInfo? known = _known;
    if (known == null) {
      return failed;
    }
    return UpdateAvailable(known, _lastChecked ?? _now());
  }

  Future<void> install() async {
    final UpdateStatus current = state;
    if (current is! UpdateAvailable || _installing) {
      return;
    }
    final ReleaseInfo release = current.release;
    final DateTime checkedAt = current.checkedAt;
    _installing = true;
    try {
      final UpdateInstaller installer = await ref.read(
        updateInstallerProvider.future,
      );
      double? fraction;
      await for (final InstallEvent event in installer.install(release)) {
        if (!ref.mounted) {
          return;
        }
        switch (event) {
          case InstallDownloading(:final int received, :final int? total):
            fraction = total != null && total > 0
                ? (received / total).clamp(0.0, 1.0)
                : null;
            state = UpdateDownloading(release, fraction);
          case InstallVerifying():
            state = UpdateDownloading(release, fraction);
          case InstallRestarting():
            state = UpdateRestarting(release);
          case InstallHandedOff():
            state = UpdateAvailable(release, checkedAt);
          case InstallFailed(:final InstallFailure failure):
            state = UpdateAvailable(release, checkedAt, lastFailure: failure);
        }
      }
      if (ref.mounted && state is UpdateDownloading) {
        state = UpdateAvailable(
          release,
          checkedAt,
          lastFailure: InstallFailure.installer,
        );
      }
    } catch (error) {
      debugPrint('The update could not be installed: $error');
      if (ref.mounted) {
        state = UpdateAvailable(
          release,
          checkedAt,
          lastFailure: InstallFailure.installer,
        );
      }
    } finally {
      _installing = false;
    }
  }

  Future<void> _record(Future<void> Function() write) async {
    try {
      await write();
    } catch (error) {
      debugPrint('The update record could not be saved: $error');
    }
  }
}
