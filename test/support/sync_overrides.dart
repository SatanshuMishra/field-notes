import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/media/media_gc.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/background/battery_settings.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/live_connection.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/enrolment/restore_service.dart';
import 'package:field_notes/data/sync/join/join_merge.dart';
import 'package:field_notes/data/sync/media/download_service.dart';
import 'package:field_notes/data/sync/media/media_cache.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/media/poster_maker.dart';
import 'package:field_notes/data/sync/media/unused_blobs.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../sync/support/relay_fixture.dart';

final class FakeBatterySettings implements BatterySettings {
  FakeBatterySettings({this.exempt = false});

  bool exempt;
  int checks = 0;
  int opens = 0;

  @override
  Future<bool> isExempt() async {
    checks += 1;
    return exempt;
  }

  @override
  Future<BatterySettingsScreen> open() async {
    opens += 1;
    return BatterySettingsScreen.ignoreOptimizationsRequest;
  }
}

Never _noSyncSetup(Ref ref) =>
    throw StateError('No sync set-up runs in this test');

List<Override> syncOffOverrides({BatterySettings? battery}) => <Override>[
  syncEnabledProvider.overrideWith((Ref ref) => Stream<bool>.value(false)),
  relayAddressProvider.overrideWith((Ref ref) => Stream<String?>.value(null)),
  syncStatusProvider.overrideWith((Ref ref) => Stream<SyncStatus?>.value(null)),
  firstPullProgressProvider.overrideWith(
    (Ref ref) => Stream<FirstPullProgress?>.value(null),
  ),
  syncNoticeProvider.overrideWith((Ref ref) => Stream<String?>.value(null)),
  enrolmentServiceProvider.overrideWith(_noSyncSetup),
  restoreServiceProvider.overrideWith(_noSyncSetup),
  pairingServiceProvider.overrideWith(_noSyncSetup),
  deviceServiceProvider.overrideWith((Ref ref) async => null),
  journalDevicesProvider.overrideWith(
    (Ref ref) async => const <JournalDevice>[],
  ),
  batterySettingsProvider.overrideWithValue(battery ?? FakeBatterySettings()),
];

List<Override> syncOnOverrides({
  required SyncStatus status,
  String address = 'https://sync.example.com',
  List<JournalDevice> devices = const <JournalDevice>[],
  Object? devicesError,
  Object? deviceServiceError,
  BatterySettings? battery,
  Stream<FirstPullProgress?>? progress,
}) => <Override>[
  syncEnabledProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  relayAddressProvider.overrideWith(
    (Ref ref) => Stream<String?>.value(address),
  ),
  syncStatusProvider.overrideWith(
    (Ref ref) => Stream<SyncStatus?>.value(status),
  ),
  firstPullProgressProvider.overrideWith(
    (Ref ref) => progress ?? Stream<FirstPullProgress?>.value(null),
  ),
  syncNoticeProvider.overrideWith((Ref ref) => Stream<String?>.value(null)),
  enrolmentServiceProvider.overrideWith(_noSyncSetup),
  restoreServiceProvider.overrideWith(_noSyncSetup),
  pairingServiceProvider.overrideWith(_noSyncSetup),
  deviceServiceProvider.overrideWith(
    (Ref ref) async =>
        deviceServiceError == null ? null : throw deviceServiceError,
  ),
  journalDevicesProvider.overrideWith(
    (Ref ref) async => devicesError == null ? devices : throw devicesError,
  ),
  batterySettingsProvider.overrideWithValue(battery ?? FakeBatterySettings()),
];

EnrolmentService stubRelayEnrolment(
  AppDatabase database, {
  String accountId = 'account-stub',
  Random? random,
}) => EnrolmentService(
  database: database,
  keyStore: KeyStore(MemorySecureValues()),
  clientFor: (Uri baseUrl, DeviceKeys? device) => RelayClient(
    baseUrl: baseUrl,
    device: device,
    client: MockClient(
      (http.Request request) async => http.Response(
        jsonEncode(InviteRedeemResponse(accountId: accountId).toJson()),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      ),
    ),
  ),
  deviceName: () async => 'Test device',
  random: random,
);

Future<void> eventually(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  String reason = 'The condition was not met in time',
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(reason);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

final class SentRequest {
  const SentRequest({
    required this.method,
    required this.url,
    required this.bodyBytes,
    required this.body,
  });

  final String method;
  final Uri url;
  final int bodyBytes;
  final String body;

  String get path => url.path;
}

typedef RequestInterceptor = Future<http.StreamedResponse?> Function(
  http.BaseRequest request,
);

final class RecordingClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final List<SentRequest> sent = <SentRequest>[];
  RequestInterceptor? intercept;

  int countOf(String method, String path) => sent
      .where(
        (SentRequest request) =>
            request.method == method && request.path == path,
      )
      .length;

  List<SentRequest> to(String method, String path) => <SentRequest>[
    for (final SentRequest request in sent)
      if (request.method == method && request.path == path) request,
  ];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bool plain = request is http.Request;
    sent.add(
      SentRequest(
        method: request.method,
        url: request.url,
        bodyBytes: plain ? request.bodyBytes.length : 0,
        body: plain ? utf8.decode(request.bodyBytes, allowMalformed: true) : '',
      ),
    );
    final RequestInterceptor? hook = intercept;
    if (hook != null) {
      final http.StreamedResponse? answer = await hook(request);
      if (answer != null) {
        return answer;
      }
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

http.StreamedResponse jsonAnswer(
  int statusCode,
  Map<String, Object?> body, {
  Map<String, String> headers = const <String, String>{},
}) => http.StreamedResponse(
  Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
  statusCode,
  headers: <String, String>{'content-type': 'application/json', ...headers},
);

final class NoJitter implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}

final class SyncTestDevice {
  SyncTestDevice(String name, {Duration ahead = Duration.zero})
    : this._withValues(name, MemorySecureValues(), ahead);

  SyncTestDevice._withValues(this.name, this.secureValues, Duration ahead)
    : database = AppDatabase(NativeDatabase.memory()),
      keyStore = KeyStore(secureValues),
      wallOffset = ahead {
    recorder = ChangeRecorder(database, wallClock: wallMillis);
    journal = DriftJournalRepository(
      database,
      recorder: recorder,
      clock: wallMillis,
    );
    journalSettings = JournalSettingsStore(database, recorder);
    settings = DriftSettingsRepository(database, journalSettings);
  }

  final String name;
  final AppDatabase database;
  final MemorySecureValues secureValues;
  final KeyStore keyStore;
  final ManualSyncClock clock = ManualSyncClock();
  final FakeNetworkMonitor network = FakeNetworkMonitor();
  final FakeLifecycleSource lifecycle = FakeLifecycleSource();
  final RecordingClient http = RecordingClient();
  final List<Uri> socketAddresses = <Uri>[];
  late final ChangeRecorder recorder;
  late final DriftJournalRepository journal;
  late final JournalSettingsStore journalSettings;
  late final DriftSettingsRepository settings;
  Duration wallOffset;
  List<String> words = const <String>[];
  final List<SyncEngine> _engines = <SyncEngine>[];
  final List<RelayClient> _clients = <RelayClient>[];

  int get sockets => socketAddresses.length;

  int wallMillis() => clock.nowMillis() + wallOffset.inMilliseconds;

  Future<JournalKeys> journalKeys() async =>
      (await keyStore.readJournalKeys())!;

  Future<DeviceKeys> deviceKeys() async => (await keyStore.readDeviceKeys())!;

  Future<String> deviceId() async => (await deviceKeys()).deviceId;

  Future<String?> syncState(String key) => readSyncState(database, key);

  Future<WebSocketChannel> _socket(Uri uri, Map<String, String> headers) {
    socketAddresses.add(uri);
    return connectWebSocket(uri, headers);
  }

  RelayClient relayClient(
    Uri baseUrl,
    DeviceKeys device,
    void Function(SessionResponse session) onSession,
  ) {
    final RelayClient client = RelayClient(
      baseUrl: baseUrl,
      device: device,
      onSession: onSession,
      client: http,
      connectSocket: _socket,
    );
    return client;
  }

  Future<RelayClient> plainClient(Uri baseUrl) async {
    final RelayClient client = RelayClient(
      baseUrl: baseUrl,
      device: await keyStore.readDeviceKeys(),
    );
    _clients.add(client);
    return client;
  }

  JoinMerge joinMerge() => JoinMerge(
    database: database,
    recorder: recorder,
    readMeadowKey: settings.meadowKey,
    wallClock: wallMillis,
  );

  SyncEngine engine({
    int? pullPageSize,
    SyncMediaSource? media,
    bool joining = false,
    JournalWiper? wipe,
    BackgroundTransferSource? background,
    LeaveRule leaveRule = LeaveRule.hidden,
    Random? random,
  }) {
    final SyncEngine created = SyncEngine(
      database: database,
      keyStore: keyStore,
      recorder: recorder,
      network: network,
      lifecycle: lifecycle,
      deviceName: () async => name,
      clock: clock,
      clientFor: relayClient,
      media: media,
      join: joining ? joinMerge() : null,
      wipe: wipe,
      backgroundSource: background,
      pullPageSize: pullPageSize,
      leaveRule: leaveRule,
      random: random ?? NoJitter(),
    );
    _engines.add(created);
    return created;
  }

  Future<void> disposeEngines() async {
    for (final SyncEngine engine in _engines) {
      await engine.dispose();
    }
    _engines.clear();
  }

  Future<void> dispose() async {
    await disposeEngines();
    for (final RelayClient client in _clients) {
      client.close();
    }
    http.close();
    await database.close();
  }
}

Future<void> _pairingPause(Duration _) =>
    Future<void>.delayed(const Duration(milliseconds: 10));

Future<SyncTestDevice> enrolDevice(
  RelayFixture relay,
  SyncTestDevice device, {
  bool switchOn = true,
}) async {
  final PendingEnrolment pending = await EnrolmentService(
    database: device.database,
    keyStore: device.keyStore,
    deviceName: () async => device.name,
  ).start(relayUrl: relay.baseUrl, inviteCode: relay.createInvite(device.name));
  device.words = pending.words;
  if (switchOn) {
    await pending.confirm(<String>[
      for (final int position in pending.positions) pending.words[position - 1],
    ]);
  }
  return device;
}

Future<SyncTestDevice> pairDevice(
  RelayFixture relay,
  SyncTestDevice host,
  SyncTestDevice joiner,
) async {
  final HostedPairing hosted = await PairingService(
    database: host.database,
    keyStore: host.keyStore,
    deviceName: () async => host.name,
    wait: _pairingPause,
  ).open();
  try {
    final Future<void> joining = PairingService(
      database: joiner.database,
      keyStore: joiner.keyStore,
      deviceName: () async => joiner.name,
      wait: _pairingPause,
    ).join(hosted.code.phrase, relayUrl: relay.baseUrl);
    await hosted.confirm(await hosted.waitForJoin());
    await joining;
  } finally {
    hosted.close();
  }
  return joiner;
}

Future<SyncTestDevice> restoreDevice(
  RelayFixture relay,
  List<String> words,
  SyncTestDevice device,
) async {
  await RestoreService(
    database: device.database,
    keyStore: device.keyStore,
    deviceName: () async => device.name,
  ).restore(relayUrl: relay.baseUrl, phrase: words.join(' '));
  return device;
}

final class FakeNetworkMonitor implements NetworkMonitor {
  FakeNetworkMonitor([this._kind = NetworkKind.unmetered]);

  final StreamController<NetworkKind> _changes =
      StreamController<NetworkKind>.broadcast(sync: true);
  NetworkKind _kind;

  NetworkKind get kind => _kind;

  set kind(NetworkKind value) {
    _kind = value;
    _changes.add(value);
  }

  @override
  Future<NetworkKind> current() async => _kind;

  @override
  Stream<NetworkKind> get changes => _changes.stream;
}

final class FakeLifecycleSource implements LifecycleSource {
  FakeLifecycleSource([this._current = AppLifecycleState.resumed]);

  final StreamController<AppLifecycleState> _changes =
      StreamController<AppLifecycleState>.broadcast(sync: true);
  AppLifecycleState? _current;

  set state(AppLifecycleState value) {
    _current = value;
    _changes.add(value);
  }

  @override
  AppLifecycleState? get current => _current;

  @override
  Stream<AppLifecycleState> get changes => _changes.stream;

  @override
  void dispose() {}
}

final class _ManualTimer implements Timer {
  _ManualTimer(this._clock, this.dueAt, this.period, this.callback);

  final ManualSyncClock _clock;
  DateTime dueAt;
  final Duration? period;
  final void Function() callback;
  bool _active = true;
  int _tick = 0;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _active = false;
    _clock._timers.remove(this);
  }

  void fire() {
    _tick += 1;
    final Duration? every = period;
    if (every == null) {
      cancel();
    } else {
      dueAt = dueAt.add(every);
    }
    callback();
  }
}

final class ManualSyncClock implements SyncClock {
  ManualSyncClock([DateTime? start]) : _now = (start ?? DateTime.now()).toUtc();

  final List<_ManualTimer> _timers = <_ManualTimer>[];
  DateTime _now;

  int get pendingTimers => _timers.length;

  @override
  DateTime now() => _now;

  int nowMillis() => _now.millisecondsSinceEpoch;

  @override
  Timer timer(Duration delay, void Function() callback) =>
      _add(delay, null, callback);

  @override
  Timer periodic(Duration period, void Function() callback) =>
      _add(period, period, callback);

  Future<void> advance(Duration by) async {
    final DateTime end = _now.add(by);
    while (true) {
      final List<_ManualTimer> due = <_ManualTimer>[
        for (final _ManualTimer timer in _timers)
          if (!timer.dueAt.isAfter(end)) timer,
      ]..sort((_ManualTimer a, _ManualTimer b) => a.dueAt.compareTo(b.dueAt));
      if (due.isEmpty) {
        break;
      }
      final _ManualTimer next = due.first;
      if (next.dueAt.isAfter(_now)) {
        _now = next.dueAt;
      }
      next.fire();
      await Future<void>.delayed(Duration.zero);
    }
    _now = end;
  }

  _ManualTimer _add(Duration delay, Duration? period, void Function() fire) {
    final _ManualTimer created = _ManualTimer(
      this,
      _now.add(delay),
      period,
      fire,
    );
    _timers.add(created);
    return created;
  }
}

final class SyncTestMedia {
  SyncTestMedia(
    this.device,
    this.root, {
    this.partBytes = 1024,
    this.settings = AppSettings.defaults,
  }) {
    store = FilesystemMediaStore(
      database: device.database,
      recorder: device.recorder,
      root: root,
      clock: device.wallMillis,
    );
    collector = MediaGarbageCollector(database: device.database, root: root);
    uploads = UploadQueue(
      database: device.database,
      store: store,
      keys: journalKeysFrom(device.keyStore),
      workRoot: uploadWorkRoot(root),
      partBytes: partBytes,
    );
    downloads = DownloadService(
      database: device.database,
      store: store,
      keyStore: device.keyStore,
      workRoot: downloadWorkRoot(root),
      clock: device.wallMillis,
    );
    posters = PosterMaker(
      database: device.database,
      store: store,
      recorder: device.recorder,
    );
    cache = MediaCache(
      database: device.database,
      store: store,
      reachable: collector.reachableMediaIds,
      clock: device.wallMillis,
    );
    unusedBlobs = UnusedBlobReporter(
      database: device.database,
      reachable: collector.reachableMediaIds,
      keys: journalKeysFrom(device.keyStore),
      uploads: uploads,
      clock: device.wallMillis,
    );
  }

  static Future<SyncTestMedia> create(
    SyncTestDevice device, {
    int partBytes = 1024,
    AppSettings settings = AppSettings.defaults,
  }) async {
    final Directory temporary = await Directory.systemTemp.createTemp(
      'fn_sync_media',
    );
    addTearDown(() async {
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    });
    return SyncTestMedia(
      device,
      Directory('${temporary.path}/media'),
      partBytes: partBytes,
      settings: settings,
    );
  }

  final SyncTestDevice device;
  final Directory root;
  final int partBytes;
  AppSettings settings;
  late final FilesystemMediaStore store;
  late final MediaGarbageCollector collector;
  late final UploadQueue uploads;
  late final DownloadService downloads;
  late final PosterMaker posters;
  late final MediaCache cache;
  late final UnusedBlobReporter unusedBlobs;

  SyncMedia bundle({UploadSenderFactory senderFor = relayUploadSender}) =>
      SyncMedia(
        uploads: uploads,
        downloads: downloads,
        posters: posters,
        cache: cache,
        unusedBlobs: unusedBlobs,
        settings: () async => settings,
        senderFor: senderFor,
      );

  SyncMediaSource source({UploadSenderFactory senderFor = relayUploadSender}) {
    final SyncMedia media = bundle(senderFor: senderFor);
    return () async => media;
  }
}

const String relayCopyDatabase = 'relay.sqlite3';
const String relayCopyMedia = 'media';
const List<String> _sqliteSuffixes = <String>['', '-wal', '-shm'];

Future<void> _copyDirectory(Directory from, Directory to) async {
  if (!await from.exists()) {
    return;
  }
  await to.create(recursive: true);
  await for (final FileSystemEntity entity in from.list(followLinks: false)) {
    final String target = p.join(to.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(target));
    } else if (entity is File) {
      await entity.copy(target);
    }
  }
}

Future<Directory> copyStoppedRelay(RelayFixture relay) async {
  expect(relay.running, isFalse);
  final Directory copy = await Directory.systemTemp.createTemp('fn_relay_copy');
  addTearDown(() async {
    if (await copy.exists()) {
      await copy.delete(recursive: true);
    }
  });
  for (final String suffix in _sqliteSuffixes) {
    final File file = File('${relay.databasePath}$suffix');
    if (await file.exists()) {
      await file.copy(p.join(copy.path, '$relayCopyDatabase$suffix'));
    }
  }
  await _copyDirectory(
    Directory(relay.mediaDirectory),
    Directory(p.join(copy.path, relayCopyMedia)),
  );
  return copy;
}

Future<void> restoreStoppedRelay(RelayFixture relay, Directory copy) async {
  expect(relay.running, isFalse);
  for (final String suffix in _sqliteSuffixes) {
    final File current = File('${relay.databasePath}$suffix');
    if (await current.exists()) {
      await current.delete();
    }
    final File saved = File(p.join(copy.path, '$relayCopyDatabase$suffix'));
    if (await saved.exists()) {
      await saved.copy('${relay.databasePath}$suffix');
    }
  }
  final Directory media = Directory(relay.mediaDirectory);
  if (await media.exists()) {
    await media.delete(recursive: true);
  }
  await _copyDirectory(Directory(p.join(copy.path, relayCopyMedia)), media);
}

Future<RelayFixture> startRelayOnCopy(Directory copy) => RelayFixture.start(
  databasePath: p.join(copy.path, relayCopyDatabase),
  mediaDirectory: p.join(copy.path, relayCopyMedia),
  rateBurst: 1000,
);

Future<void> pointAt(SyncTestDevice device, RelayFixture relay) =>
    writeSyncState(device.database, SyncStateKeys.relayUrl, '${relay.baseUrl}');
