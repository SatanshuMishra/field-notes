import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:field_notes/data/updates/download_page_installer.dart';
import 'package:field_notes/data/updates/update_record_store.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/features/updates/update_controller.dart';
import 'package:field_notes/features/updates/update_providers.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/update_overrides.dart';

final DateTime _start = DateTime(2026, 10, 11, 9);
final DateTime _stale = _start.subtract(const Duration(hours: 25));
final DateTime _fresh = _start.subtract(const Duration(hours: 2));
final ReleaseInfo _r11 = _release('1.1.0');
final ReleaseInfo _r12 = _release('1.2.0');
final ReleaseInfo _r13 = _release('1.3.0');

ReleaseInfo _release(String version) => ReleaseInfo(
  version: AppVersion.tryParse(version)!,
  tag: 'v$version',
  publishedAt: DateTime.utc(2026, 10, 10, 12),
  notes: ReleaseNotes.empty,
  pageUrl: Uri.parse(
    'https://github.com/SatanshuMishra/field-notes/releases/tag/v$version',
  ),
  assets: const <ReleaseAsset>[],
);

DateTime _at(Duration offset) => _start.add(offset);

final class _Source implements ReleaseSource {
  _Source(this.answer);

  ReleaseLookup answer;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<ReleaseLookup> latest() async {
    calls++;
    final Completer<void>? waiting = gate;
    if (waiting != null) {
      await waiting.future;
    }
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return answer;
  }
}

final class _BrokenStore implements UpdateRecordStore {
  @override
  Future<UpdateRecord> read() async => throw Exception('the record is gone');

  @override
  Future<void> recordAttempt(DateTime at) async {}

  @override
  Future<void> recordCheck(DateTime at, ReleaseInfo? available) async {}

  @override
  Future<void> recordSeenVersion(String version) async {}
}

final class _Installer implements UpdateInstaller {
  _Installer(this.route, [this.events = const <InstallEvent>[]]);

  @override
  final InstallRoute route;
  List<InstallEvent> events;
  Object? error;
  StreamController<InstallEvent>? live;
  final List<ReleaseInfo> releases = <ReleaseInfo>[];

  @override
  Stream<InstallEvent> install(ReleaseInfo release) {
    releases.add(release);
    final StreamController<InstallEvent>? gated = live;
    if (gated != null) {
      return gated.stream;
    }
    return _replay();
  }

  Stream<InstallEvent> _replay() async* {
    for (final InstallEvent event in events) {
      yield event;
    }
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
  }
}

final class _Harness {
  _Harness(
    this.async, {
    required this.store,
    required this.source,
    bool automatic = true,
    String installed = '1.2.0',
    Object? installedError,
    Object? settingsError,
    Future<UpdateInstaller>? installer,
  }) {
    if (settingsError == null) {
      _settings.add(_settingsWith(automatic));
    }
    container = ProviderContainer(
      overrides: [
        installedAppProvider.overrideWith((Ref ref) async {
          final Object? failure = installedError;
          if (failure != null) {
            throw failure;
          }
          return InstalledApp(version: installed);
        }),
        updateRecordStoreProvider.overrideWithValue(store),
        releaseSourceProvider.overrideWithValue(source),
        updateClockProvider.overrideWithValue(() => _start.add(async.elapsed)),
        appSettingsProvider.overrideWith(
          (Ref ref) => settingsError == null
              ? _settings.stream
              : Stream<AppSettings>.error(settingsError),
        ),
        updateInstallerProvider.overrideWith(
          (Ref ref) =>
              installer ??
              Future<UpdateInstaller>.value(
                _Installer(InstallRoute.restartInPlace),
              ),
        ),
      ],
    );
  }

  final FakeAsync async;
  final UpdateRecordStore store;
  final _Source source;
  final StreamController<AppSettings> _settings =
      StreamController<AppSettings>();
  final List<UpdateStatus> states = <UpdateStatus>[];
  late final ProviderContainer container;

  static AppSettings _settingsWith(bool automatic) =>
      AppSettings.defaults.copyWith(checkForUpdatesAutomatically: automatic);

  UpdateStatus get state => container.read(updateControllerProvider);

  UpdateController get controller =>
      container.read(updateControllerProvider.notifier);

  String? get greeting => container.read(updateGreetingProvider);

  List<UpdateStatus> get changes => <UpdateStatus>[
    for (int index = 0; index < states.length; index++)
      if (index == 0 || states[index] != states[index - 1]) states[index],
  ];

  void start() {
    container.listen<UpdateStatus>(
      updateControllerProvider,
      (UpdateStatus? previous, UpdateStatus next) => states.add(next),
    );
    async.elapse(Duration.zero);
  }

  void setAutomatic(bool automatic) {
    _settings.add(_settingsWith(automatic));
    async.elapse(Duration.zero);
  }

  void check() {
    unawaited(controller.check());
    async.elapse(Duration.zero);
  }

  void install() {
    unawaited(controller.install());
    async.elapse(Duration.zero);
  }

  void dispose() {
    container.dispose();
    unawaited(_settings.close());
    async.elapse(Duration.zero);
  }
}

void main() {
  test('checks run on demand and once a day when automatic', () {
    fakeAsync((FakeAsync async) {
      final MemoryUpdateRecordStore store = MemoryUpdateRecordStore(
        UpdateRecord(lastCheckedAt: _stale),
      );
      final _Source source = _Source(const NoRelease());
      final _Harness launch = _Harness(async, store: store, source: source)
        ..start();
      expect(launch.state, UpdateCurrent(_stale));
      async.elapse(const Duration(seconds: 9));
      expect(source.calls, 0);
      async.elapse(const Duration(seconds: 1));
      expect(source.calls, 1);
      expect(launch.state, UpdateCurrent(_at(const Duration(seconds: 10))));
      expect(
        store.record.lastCheckedAt,
        _at(const Duration(seconds: 10)).toUtc(),
      );
      async.elapse(const Duration(hours: 24) - const Duration(seconds: 10));
      expect(source.calls, 1);
      async.elapse(const Duration(hours: 1));
      expect(source.calls, 2);
      expect(launch.state, UpdateCurrent(_at(const Duration(hours: 25))));
      launch.dispose();
    });

    fakeAsync((FakeAsync async) {
      final _Source source = _Source(const NoRelease());
      final _Harness fresh = _Harness(
        async,
        store: MemoryUpdateRecordStore(UpdateRecord(lastCheckedAt: _fresh)),
        source: source,
      )..start();
      expect(fresh.state, UpdateCurrent(_fresh));
      expect(async.nonPeriodicTimerCount, 0);
      expect(async.periodicTimerCount, 1);
      async.elapse(const Duration(hours: 21));
      expect(source.calls, 0);
      async.elapse(const Duration(hours: 1));
      expect(source.calls, 1);
      expect(fresh.state, UpdateCurrent(_at(const Duration(hours: 22))));
      fresh.dispose();
    });

    fakeAsync((FakeAsync async) {
      final _Source source = _Source(const NoRelease());
      final _Harness missing = _Harness(
        async,
        store: MemoryUpdateRecordStore(),
        source: source,
      )..start();
      expect(missing.state, const UpdateIdle(null));
      async.elapse(const Duration(seconds: 9));
      expect(source.calls, 0);
      async.elapse(const Duration(seconds: 1));
      expect(source.calls, 1);
      expect(missing.state, UpdateCurrent(_at(const Duration(seconds: 10))));
      missing.dispose();
    });

    fakeAsync((FakeAsync async) {
      final _Source source = _Source(const NoRelease());
      final _Harness off = _Harness(
        async,
        store: MemoryUpdateRecordStore(UpdateRecord(lastCheckedAt: _stale)),
        source: source,
        automatic: false,
      )..start();
      expect(async.periodicTimerCount, 0);
      expect(async.nonPeriodicTimerCount, 0);
      async.elapse(const Duration(days: 2));
      expect(source.calls, 0);
      expect(off.state, UpdateCurrent(_stale));
      off.setAutomatic(true);
      expect(source.calls, 1);
      expect(off.state, UpdateCurrent(_at(const Duration(days: 2))));
      expect(async.periodicTimerCount, 1);
      off.setAutomatic(false);
      expect(async.periodicTimerCount, 0);
      expect(async.nonPeriodicTimerCount, 0);
      async.elapse(const Duration(days: 3));
      expect(source.calls, 1);
      off.dispose();
    });

    fakeAsync((FakeAsync async) {
      final _Source source = _Source(const NoRelease());
      final _Harness recent = _Harness(
        async,
        store: MemoryUpdateRecordStore(UpdateRecord(lastCheckedAt: _fresh)),
        source: source,
        automatic: false,
      )..start();
      recent.setAutomatic(true);
      expect(source.calls, 0);
      expect(async.periodicTimerCount, 1);
      recent.dispose();
    });

    fakeAsync((FakeAsync async) {
      final MemoryUpdateRecordStore store = MemoryUpdateRecordStore(
        UpdateRecord(lastCheckedAt: _fresh),
      );
      final _Source source = _Source(const LookupFailed(LookupFailure.offline))
        ..gate = Completer<void>();
      final _Harness manual = _Harness(
        async,
        store: store,
        source: source,
        automatic: false,
      )..start();
      manual.check();
      expect(manual.state, UpdateChecking(_fresh));
      manual.check();
      manual.check();
      expect(source.calls, 1);
      source.gate!.complete();
      source.gate = null;
      async.elapse(Duration.zero);
      expect(
        manual.state,
        UpdateCheckFailed(_fresh, LookupFailure.offline, null),
      );
      expect(store.record.lastCheckedAt, _start.toUtc());
      expect(store.record.lastAvailable, isNull);

      final List<(ReleaseLookup, UpdateStatus Function(DateTime now))> answers =
          <(ReleaseLookup, UpdateStatus Function(DateTime now))>[
            (const NoRelease(), (DateTime now) => UpdateCurrent(now)),
            (ReleaseFound(_r12), (DateTime now) => UpdateCurrent(now)),
            (ReleaseFound(_r11), (DateTime now) => UpdateCurrent(now)),
            (
              const LookupFailed(LookupFailure.badResponse),
              (DateTime now) => UpdateCheckFailed(
                now.subtract(const Duration(minutes: 1)),
                LookupFailure.badResponse,
                null,
              ),
            ),
            (ReleaseFound(_r13), (DateTime now) => UpdateAvailable(_r13, now)),
          ];
      for (final (
            ReleaseLookup answer,
            UpdateStatus Function(DateTime) expected,
          )
          in answers) {
        async.elapse(const Duration(minutes: 1));
        source.answer = answer;
        manual.check();
        final DateTime now = _start.add(async.elapsed);
        expect(manual.state, expected(now), reason: '$answer');
        expect(store.record.lastCheckedAt, now.toUtc(), reason: '$answer');
      }
      expect(store.record.lastAvailable, _r13);
      expect(source.calls, 6);
      expect(
        manual.changes,
        containsAllInOrder(<UpdateStatus>[
          UpdateChecking(_fresh),
          UpdateCheckFailed(_fresh, LookupFailure.offline, null),
        ]),
      );

      async.elapse(const Duration(minutes: 1));
      source.error = Exception('the network vanished');
      manual.check();
      expect(
        manual.state,
        UpdateAvailable(_r13, _at(const Duration(minutes: 5))),
      );
      expect(store.record.lastAvailable, _r13);
      manual.dispose();
    });
  });

  test('an available update survives a restart', () {
    fakeAsync((FakeAsync async) {
      final DateTime checked = _fresh;
      for (final (ReleaseInfo known, UpdateStatus expected)
          in <(ReleaseInfo, UpdateStatus)>[
            (_r13, UpdateAvailable(_r13, checked)),
            (_r12, UpdateCurrent(checked)),
            (_r11, UpdateCurrent(checked)),
          ]) {
        final _Source source = _Source(const NoRelease());
        final _Harness restarted = _Harness(
          async,
          store: MemoryUpdateRecordStore(
            UpdateRecord(lastCheckedAt: checked, lastAvailable: known),
          ),
          source: source,
        )..start();
        expect(restarted.state, expected, reason: '${known.version}');
        async.elapse(const Duration(minutes: 1));
        expect(source.calls, 0);
        restarted.dispose();
      }
    });

    fakeAsync((FakeAsync async) {
      final MemoryUpdateRecordStore store = MemoryUpdateRecordStore(
        UpdateRecord(lastCheckedAt: _fresh),
      );
      final _Source source = _Source(ReleaseFound(_r13));
      final _Harness first = _Harness(
        async,
        store: store,
        source: source,
        automatic: false,
      )..start();
      first.check();
      expect(first.state, UpdateAvailable(_r13, _start));
      first.dispose();

      final _Harness second = _Harness(
        async,
        store: store,
        source: source,
        automatic: false,
      )..start();
      expect(second.state, UpdateAvailable(_r13, _start.toUtc()));
      second.dispose();

      final _Harness updated = _Harness(
        async,
        store: store,
        source: source,
        automatic: false,
        installed: '1.3.0',
      )..start();
      expect(updated.state, UpdateCurrent(_start.toUtc()));
      expect(source.calls, 1);
      updated.dispose();
    });
  });

  test('a rate-limited check waits for the reset', () {
    fakeAsync((FakeAsync async) {
      final DateTime reset = _at(const Duration(minutes: 90));
      final _Source source = _Source(LookupRateLimited(reset));
      final _Harness limited = _Harness(
        async,
        store: MemoryUpdateRecordStore(UpdateRecord(lastCheckedAt: _stale)),
        source: source,
      )..start();
      async.elapse(const Duration(seconds: 10));
      expect(source.calls, 1);
      expect(limited.state, UpdateCheckFailed(_stale, null, reset));
      async.elapse(const Duration(minutes: 80));
      expect(source.calls, 1);
      limited.check();
      expect(source.calls, 1);
      expect(limited.state, UpdateCheckFailed(_stale, null, reset));
      source.answer = const NoRelease();
      async.elapse(const Duration(minutes: 39, seconds: 50));
      expect(source.calls, 2);
      expect(limited.state, UpdateCurrent(_at(const Duration(hours: 2))));
      limited.dispose();
    });

    fakeAsync((FakeAsync async) {
      final DateTime reset = _at(const Duration(minutes: 90));
      final MemoryUpdateRecordStore store = MemoryUpdateRecordStore(
        UpdateRecord(lastCheckedAt: _stale, lastAvailable: _r13),
      );
      final _Source source = _Source(LookupRateLimited(reset));
      final _Harness known = _Harness(async, store: store, source: source)
        ..start();
      expect(known.state, UpdateAvailable(_r13, _stale));
      async.elapse(const Duration(seconds: 10));
      expect(source.calls, 1);
      expect(known.state, UpdateAvailable(_r13, _stale));
      async.elapse(const Duration(minutes: 30));
      known.check();
      expect(source.calls, 1);
      expect(known.state, UpdateAvailable(_r13, _stale));
      source.answer = const LookupFailed(LookupFailure.offline);
      async.elapse(const Duration(minutes: 89, seconds: 50));
      expect(source.calls, 2);
      expect(known.state, UpdateAvailable(_r13, _stale));
      expect(store.record.lastAvailable, _r13);
      expect(store.record.lastCheckedAt, _at(const Duration(hours: 2)).toUtc());
      async.elapse(const Duration(hours: 23));
      expect(source.calls, 2);
      async.elapse(const Duration(hours: 1));
      expect(source.calls, 3);
      expect(known.state, UpdateAvailable(_r13, _stale));
      known.dispose();
    });
  });

  test('a failed check keeps a known update across a restart', () {
    fakeAsync((FakeAsync async) {
      final MemoryUpdateRecordStore store = MemoryUpdateRecordStore(
        UpdateRecord(lastCheckedAt: _fresh),
      );
      final _Source source = _Source(ReleaseFound(_r13));
      final _Harness first = _Harness(
        async,
        store: store,
        source: source,
        automatic: false,
      )..start();
      first.check();
      expect(first.state, UpdateAvailable(_r13, _start));
      async.elapse(const Duration(minutes: 5));
      source.answer = const LookupFailed(LookupFailure.offline);
      first.check();
      expect(first.state, UpdateAvailable(_r13, _start));
      expect(store.record.lastAvailable, _r13);
      expect(
        store.record.lastCheckedAt,
        _at(const Duration(minutes: 5)).toUtc(),
      );
      first.dispose();

      final _Harness second = _Harness(async, store: store, source: source)
        ..start();
      final DateTime failedAt = _at(const Duration(minutes: 5)).toUtc();
      expect(second.state, UpdateAvailable(_r13, failedAt));
      async.elapse(const Duration(minutes: 1));
      expect(source.calls, 2);
      second.check();
      expect(source.calls, 3);
      expect(second.state, UpdateAvailable(_r13, failedAt));
      expect(store.record.lastAvailable, _r13);
      second.dispose();
    });
  });

  test('the updater stays quiet when it cannot start and leaves no timer', () {
    for (final Object failure in <Object>[
      Exception('no package information'),
      MissingPluginException('no package_info_plus'),
    ]) {
      fakeAsync((FakeAsync async) {
        final _Source source = _Source(const NoRelease());
        final _Harness broken = _Harness(
          async,
          store: MemoryUpdateRecordStore(),
          source: source,
          installedError: failure,
        );
        expect(broken.start, returnsNormally);
        expect(broken.state, const UpdateIdle(null));
        async.elapse(const Duration(days: 2));
        broken.check();
        expect(source.calls, 0);
        expect(broken.state, const UpdateIdle(null));
        broken.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    }

    fakeAsync((FakeAsync async) {
      final _Source source = _Source(const NoRelease());
      final _Harness unparsed = _Harness(
        async,
        store: MemoryUpdateRecordStore(),
        source: source,
        installed: 'unknown',
      )..start();
      async.elapse(const Duration(days: 2));
      expect(source.calls, 0);
      expect(unparsed.state, const UpdateIdle(null));
      unparsed.dispose();
      expect(async.pendingTimers, isEmpty);
    });

    fakeAsync((FakeAsync async) {
      final _Source source = _Source(const NoRelease());
      final _Harness noRecord = _Harness(
        async,
        store: _BrokenStore(),
        source: source,
      )..start();
      async.elapse(const Duration(days: 2));
      expect(source.calls, 0);
      expect(noRecord.state, const UpdateIdle(null));
      noRecord.dispose();
      expect(async.pendingTimers, isEmpty);
    });

    fakeAsync((FakeAsync async) {
      final _Source source = _Source(const NoRelease());
      final _Harness noSettings = _Harness(
        async,
        store: MemoryUpdateRecordStore(),
        source: source,
        settingsError: Exception('the settings table is locked'),
      )..start();
      async.elapse(const Duration(days: 2));
      expect(source.calls, 0);
      expect(noSettings.state, const UpdateIdle(null));
      noSettings.dispose();
      expect(async.pendingTimers, isEmpty);
    });

    fakeAsync((FakeAsync async) {
      final _Source source = _Source(const NoRelease());
      final _Harness pending = _Harness(
        async,
        store: MemoryUpdateRecordStore(UpdateRecord(lastCheckedAt: _stale)),
        source: source,
      )..start();
      expect(async.periodicTimerCount, 1);
      expect(async.nonPeriodicTimerCount, 1);
      pending.dispose();
      expect(async.pendingTimers, isEmpty);
      async.elapse(const Duration(days: 2));
      expect(source.calls, 0);
    });
  });

  test('installing reports progress and failures', () {
    final DateTime checked = _fresh;
    UpdateRecord knownRecord() =>
        UpdateRecord(lastCheckedAt: checked, lastAvailable: _r13);

    fakeAsync((FakeAsync async) {
      final _Installer installer = _Installer(
        InstallRoute.restartInPlace,
        const <InstallEvent>[
          InstallDownloading(0, 1000),
          InstallDownloading(500, 1000),
          InstallVerifying(),
          InstallRestarting(),
        ],
      );
      final _Harness inPlace = _Harness(
        async,
        store: MemoryUpdateRecordStore(knownRecord()),
        source: _Source(const NoRelease()),
        automatic: false,
        installer: Future<UpdateInstaller>.value(installer),
      )..start();
      expect(inPlace.state, UpdateAvailable(_r13, checked));
      inPlace.states.clear();
      inPlace.install();
      expect(installer.releases, <ReleaseInfo>[_r13]);
      expect(inPlace.changes, <UpdateStatus>[
        UpdateDownloading(_r13, 0),
        UpdateDownloading(_r13, 0.5),
        UpdateRestarting(_r13),
      ]);
      inPlace.install();
      expect(installer.releases, hasLength(1));
      inPlace.dispose();
    });

    fakeAsync((FakeAsync async) {
      final _Installer installer = _Installer(
        InstallRoute.restartInPlace,
        const <InstallEvent>[
          InstallDownloading(100, null),
          InstallDownloading(300, null),
          InstallVerifying(),
          InstallRestarting(),
        ],
      );
      final _Harness unknownSize = _Harness(
        async,
        store: MemoryUpdateRecordStore(knownRecord()),
        source: _Source(const NoRelease()),
        automatic: false,
        installer: Future<UpdateInstaller>.value(installer),
      )..start();
      unknownSize.states.clear();
      unknownSize.install();
      expect(unknownSize.changes, <UpdateStatus>[
        UpdateDownloading(_r13, null),
        UpdateRestarting(_r13),
      ]);
      unknownSize.dispose();
    });

    for (final InstallRoute route in <InstallRoute>[
      InstallRoute.systemInstaller,
      InstallRoute.googlePlay,
      InstallRoute.downloadPage,
    ]) {
      fakeAsync((FakeAsync async) {
        final List<InstallEvent> events = route == InstallRoute.systemInstaller
            ? const <InstallEvent>[
                InstallDownloading(400, 800),
                InstallVerifying(),
                InstallHandedOff(),
              ]
            : const <InstallEvent>[InstallHandedOff()];
        final _Installer installer = _Installer(route, events);
        final _Harness handOff = _Harness(
          async,
          store: MemoryUpdateRecordStore(knownRecord()),
          source: _Source(const NoRelease()),
          automatic: false,
          installer: Future<UpdateInstaller>.value(installer),
        )..start();
        handOff.states.clear();
        handOff.install();
        expect(installer.releases, <ReleaseInfo>[_r13], reason: '$route');
        expect(handOff.state, UpdateAvailable(_r13, checked), reason: '$route');
        if (route == InstallRoute.systemInstaller) {
          expect(handOff.changes, <UpdateStatus>[
            UpdateDownloading(_r13, 0.5),
            UpdateAvailable(_r13, checked),
          ]);
        }
        handOff.dispose();
      });
    }

    fakeAsync((FakeAsync async) {
      final _Installer installer = _Installer(
        InstallRoute.restartInPlace,
        const <InstallEvent>[
          InstallDownloading(10, 100),
          InstallFailed(InstallFailure.network),
        ],
      );
      final _Harness failing = _Harness(
        async,
        store: MemoryUpdateRecordStore(knownRecord()),
        source: _Source(const NoRelease()),
        automatic: false,
        installer: Future<UpdateInstaller>.value(installer),
      )..start();
      failing.states.clear();
      failing.install();
      expect(failing.changes, <UpdateStatus>[
        UpdateDownloading(_r13, 0.1),
        UpdateAvailable(_r13, checked, lastFailure: InstallFailure.network),
      ]);

      for (final InstallFailure failure in InstallFailure.values) {
        installer.events = <InstallEvent>[InstallFailed(failure)];
        failing.install();
        expect(
          failing.state,
          UpdateAvailable(_r13, checked, lastFailure: failure),
        );
      }

      installer
        ..events = const <InstallEvent>[InstallDownloading(0, 10)]
        ..error = Exception('the installer crashed');
      failing.install();
      expect(
        failing.state,
        UpdateAvailable(_r13, checked, lastFailure: InstallFailure.installer),
      );

      installer
        ..events = const <InstallEvent>[InstallDownloading(1, 10)]
        ..error = null;
      failing.install();
      expect(
        failing.state,
        UpdateAvailable(_r13, checked, lastFailure: InstallFailure.installer),
      );

      installer.events = const <InstallEvent>[InstallHandedOff()];
      failing.install();
      expect(failing.state, UpdateAvailable(_r13, checked));
      failing.dispose();
    });

    fakeAsync((FakeAsync async) {
      final _Installer installer = _Installer(InstallRoute.restartInPlace);
      final _Harness current = _Harness(
        async,
        store: MemoryUpdateRecordStore(UpdateRecord(lastCheckedAt: checked)),
        source: _Source(const NoRelease()),
        automatic: false,
        installer: Future<UpdateInstaller>.value(installer),
      )..start();
      expect(current.state, UpdateCurrent(checked));
      current.install();
      expect(installer.releases, isEmpty);
      expect(current.state, UpdateCurrent(checked));
      current.dispose();
    });
  });

  test('a newer version greets the user once', () {
    fakeAsync((FakeAsync async) {
      final MemoryUpdateRecordStore store = MemoryUpdateRecordStore(
        UpdateRecord(lastCheckedAt: _fresh, lastSeenVersion: '1.1.0'),
      );
      final _Harness upgraded = _Harness(
        async,
        store: store,
        source: _Source(const NoRelease()),
      )..start();
      expect(upgraded.greeting, '1.2.0');
      expect(store.record.lastSeenVersion, '1.2.0');
      upgraded.container.read(updateGreetingProvider.notifier).consume();
      expect(upgraded.greeting, isNull);
      upgraded.dispose();

      final _Harness again = _Harness(
        async,
        store: store,
        source: _Source(const NoRelease()),
      )..start();
      expect(again.greeting, isNull);
      expect(store.record.lastSeenVersion, '1.2.0');
      again.dispose();
    });

    for (final String? seen in <String?>[null, '1.2.0', '1.3.0']) {
      fakeAsync((FakeAsync async) {
        final MemoryUpdateRecordStore store = MemoryUpdateRecordStore(
          UpdateRecord(lastCheckedAt: _fresh, lastSeenVersion: seen),
        );
        final _Harness launch = _Harness(
          async,
          store: store,
          source: _Source(const NoRelease()),
        )..start();
        expect(launch.greeting, isNull, reason: '$seen');
        expect(store.record.lastSeenVersion, '1.2.0', reason: '$seen');
        launch.dispose();
      });
    }
  });

  test('the update notice leaves Google Play copies to Google Play', () {
    for (final InstallRoute route in InstallRoute.values) {
      fakeAsync((FakeAsync async) {
        final _Installer installer = _Installer(route)
          ..live = StreamController<InstallEvent>();
        final _Harness available = _Harness(
          async,
          store: MemoryUpdateRecordStore(
            UpdateRecord(lastCheckedAt: _fresh, lastAvailable: _r13),
          ),
          source: _Source(const NoRelease()),
          automatic: false,
          installer: Future<UpdateInstaller>.value(installer),
        )..start();
        available.container.listen<ReleaseInfo?>(
          updateNoticeProvider,
          (ReleaseInfo? previous, ReleaseInfo? next) {},
        );
        async.elapse(Duration.zero);
        expect(
          available.container.read(updateNoticeProvider),
          route == InstallRoute.googlePlay ? isNull : _r13,
          reason: '$route',
        );
        available.install();
        installer.live!.add(const InstallDownloading(1, 4));
        async.elapse(Duration.zero);
        expect(available.state, UpdateDownloading(_r13, 0.25));
        expect(available.container.read(updateNoticeProvider), isNull);
        unawaited(installer.live!.close());
        available.dispose();
      });
    }

    fakeAsync((FakeAsync async) {
      final _Harness unknownRoute = _Harness(
        async,
        store: MemoryUpdateRecordStore(
          UpdateRecord(lastCheckedAt: _fresh, lastAvailable: _r13),
        ),
        source: _Source(const NoRelease()),
        automatic: false,
        installer: Completer<UpdateInstaller>().future,
      )..start();
      unknownRoute.container.listen<ReleaseInfo?>(
        updateNoticeProvider,
        (ReleaseInfo? previous, ReleaseInfo? next) {},
      );
      async.elapse(Duration.zero);
      expect(unknownRoute.state, UpdateAvailable(_r13, _fresh));
      expect(unknownRoute.container.read(updateNoticeProvider), isNull);
      unknownRoute.dispose();
    });

    fakeAsync((FakeAsync async) {
      final _Harness current = _Harness(
        async,
        store: MemoryUpdateRecordStore(UpdateRecord(lastCheckedAt: _fresh)),
        source: _Source(const NoRelease()),
        automatic: false,
      )..start();
      expect(current.container.read(updateNoticeProvider), isNull);
      current.dispose();
    });
  });

  test('the download page installer opens the release page', () async {
    final List<Uri> opened = <Uri>[];
    final DownloadPageInstaller page = DownloadPageInstaller(
      openLink: (Uri link) async {
        opened.add(link);
        return true;
      },
    );
    expect(page.route, InstallRoute.downloadPage);
    expect(await page.install(_r13).toList(), const <InstallEvent>[
      InstallHandedOff(),
    ]);
    expect(opened, <Uri>[_r13.pageUrl]);
    expect(
      await DownloadPageInstaller(openLink: (Uri link) async => false)
          .install(_r13)
          .toList(),
      const <InstallEvent>[InstallFailed(InstallFailure.installer)],
    );
    expect(
      await DownloadPageInstaller(
        openLink: (Uri link) async =>
            throw PlatformException(code: 'no_browser'),
      ).install(_r13).toList(),
      const <InstallEvent>[InstallFailed(InstallFailure.installer)],
    );
  });

  test('the quiet overrides settle on up to date without a check', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          ...updateQuietOverrides(),
          installedAppProvider.overrideWith(
            (Ref ref) async => const InstalledApp(version: '1.2.0'),
          ),
          appSettingsProvider.overrideWith(
            (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
          ),
        ],
      );
      container.listen<ReleaseInfo?>(
        updateNoticeProvider,
        (ReleaseInfo? previous, ReleaseInfo? next) {},
      );
      async.elapse(Duration.zero);
      expect(
        container.read(updateControllerProvider),
        UpdateCurrent(updateQuietNow),
      );
      expect(container.read(updateNoticeProvider), isNull);
      expect(container.read(updateGreetingProvider), isNull);
      expect(async.nonPeriodicTimerCount, 0);
      container.dispose();
      expect(async.pendingTimers, isEmpty);
    });
  });
}
