import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/device_keys.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/device_storage.dart';
import 'package:field_notes/data/sync/background/background_uploads.dart';
import 'package:field_notes/data/sync/background/upload_result_applier.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/device_name.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/live_connection.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/engine/push_cycle.dart';
import 'package:field_notes/data/sync/engine/relay_rebase.dart';
import 'package:field_notes/data/sync/engine/server_address.dart';
import 'package:field_notes/data/sync/engine/stale_records.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/erase/journal_erase_service.dart';
import 'package:field_notes/data/sync/join/join_merge.dart';
import 'package:field_notes/data/sync/media/download_service.dart';
import 'package:field_notes/data/sync/media/media_cache.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/media/poster_maker.dart';
import 'package:field_notes/data/sync/media/unused_blobs.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/merge/state_applier.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/domain/platform/desktop_platform.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart'
    show
        AppLifecycleListener,
        AppLifecycleState,
        TargetPlatform,
        WidgetsBinding;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

const Duration localWriteDelay = Duration(seconds: 1);
const Duration localWriteMaxDelay = Duration(seconds: 10);
const Duration inactiveLeaveDelay = Duration(seconds: 1);
const Duration offlinePollInterval = Duration(minutes: 5);
const Duration firstBackoff = Duration(seconds: 2);
const Duration maxBackoff = Duration(seconds: 64);
const Duration maxBackoffJitter = Duration(seconds: 1);
const int unreachableAfterFailures = 3;

abstract final class EngineStateKeys {
  static const String paused = 'paused';
  static const String pausedValue = 'true';
}

typedef SyncClientFactory = RelayClient Function(
  Uri baseUrl,
  DeviceKeys device,
  void Function(SessionResponse session) onSession,
);

RelayClient defaultSyncClient(
  Uri baseUrl,
  DeviceKeys device,
  void Function(SessionResponse session) onSession,
) => RelayClient(baseUrl: baseUrl, device: device, onSession: onSession);

typedef UploadSenderFactory = UploadSender Function(RelayClient client);

UploadSender relayUploadSender(RelayClient client) => RelayUploadSender(client);

final class SyncMedia {
  const SyncMedia({
    required this.uploads,
    required this.downloads,
    required this.posters,
    required this.cache,
    required this.unusedBlobs,
    required this.settings,
    this.senderFor = relayUploadSender,
  });

  final UploadQueue uploads;
  final DownloadService downloads;
  final PosterMaker posters;
  final MediaCache cache;
  final UnusedBlobReporter unusedBlobs;
  final Future<AppSettings> Function() settings;
  final UploadSenderFactory senderFor;
}

typedef SyncMediaSource = Future<SyncMedia?> Function();

typedef JournalWiper = Future<void> Function();

final class BackgroundTransfer {
  const BackgroundTransfer({
    required this.uploads,
    required this.results,
    this.mobileDataChanges,
  });

  final BackgroundUploads uploads;
  final UploadResultApplier results;
  final Stream<bool>? mobileDataChanges;
}

typedef BackgroundTransferSource = Future<BackgroundTransfer?> Function();

Duration backoffAfter(int failures) {
  if (failures <= 0) {
    return Duration.zero;
  }
  final int shift = min(failures - 1, 20);
  final int millis = firstBackoff.inMilliseconds * (1 << shift);
  return Duration(milliseconds: min(millis, maxBackoff.inMilliseconds));
}

Duration jitteredBackoff(int failures, Random random) {
  if (failures <= 0) {
    return Duration.zero;
  }
  final int millis =
      backoffAfter(failures).inMilliseconds +
      random.nextInt(maxBackoffJitter.inMilliseconds + 1);
  return Duration(milliseconds: min(millis, maxBackoff.inMilliseconds));
}

enum LeaveRule { inactive, hidden, quit }

LeaveRule leaveRuleFor(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => LeaveRule.inactive,
  _ when isDesktopPlatform(platform) => LeaveRule.quit,
  _ => LeaveRule.hidden,
};

bool leavesOn(LeaveRule rule, AppLifecycleState state) => switch (state) {
  AppLifecycleState.detached => true,
  AppLifecycleState.hidden ||
  AppLifecycleState.paused => rule != LeaveRule.quit,
  AppLifecycleState.resumed || AppLifecycleState.inactive => false,
};

abstract interface class LifecycleSource {
  AppLifecycleState? get current;

  Stream<AppLifecycleState> get changes;

  void dispose();
}

final class AppLifecycleSource implements LifecycleSource {
  AppLifecycleSource() {
    _listener = AppLifecycleListener(onStateChange: _changes.add);
  }

  final StreamController<AppLifecycleState> _changes =
      StreamController<AppLifecycleState>.broadcast();
  late final AppLifecycleListener _listener;

  @override
  AppLifecycleState? get current => WidgetsBinding.instance.lifecycleState;

  @override
  Stream<AppLifecycleState> get changes => _changes.stream;

  @override
  void dispose() {
    _listener.dispose();
    unawaited(_changes.close());
  }
}

final class FirstPullProgress {
  const FirstPullProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is FirstPullProgress && other.done == done && other.total == total;

  @override
  int get hashCode => Object.hash(done, total);

  @override
  String toString() => 'FirstPullProgress($done of $total)';
}

class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required this._keyStore,
    required this._recorder,
    required this._network,
    required this._lifecycle,
    this._deviceName = defaultDeviceName,
    this._clock = const SystemSyncClock(),
    this._clientFor = defaultSyncClient,
    this._media,
    this._join,
    this._wipe,
    this._backgroundSource,
    this.pullPageSize,
    this.leaveRule = LeaveRule.hidden,
    Random? random,
  }) : _db = database,
       _random = random ?? Random();

  final AppDatabase _db;
  final KeyStore _keyStore;
  final ChangeRecorder _recorder;
  final NetworkMonitor _network;
  final LifecycleSource _lifecycle;
  final DeviceNameReader _deviceName;
  final SyncClock _clock;
  final SyncClientFactory _clientFor;
  final SyncMediaSource? _media;
  final JoinMerge? _join;
  final JournalWiper? _wipe;
  final BackgroundTransferSource? _backgroundSource;
  BackgroundTransfer? _background;
  final int? pullPageSize;
  final LeaveRule leaveRule;
  final Random _random;
  Future<SyncMedia?>? _loadedMedia;
  Future<void>? _preparing;

  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<FirstPullProgress?> _progress =
      StreamController<FirstPullProgress?>.broadcast();
  final StreamController<String?> _notices =
      StreamController<String?>.broadcast();
  String? _notice;
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  bool _started = false;
  bool _disposed = false;
  bool _enabled = false;
  bool _paused = false;
  bool _visible = true;
  NetworkKind _networkKind = NetworkKind.unmetered;
  AttentionReason? _stopReason;
  bool _storageFull = false;
  bool _deviceFull = false;
  bool _noteTooLong = false;
  bool _keysLocked = false;
  bool _troubled = false;
  bool _pulling = false;
  DateTime? _writesWaitingSince;
  StaleRecords _stale = const StaleRecords();
  int _failures = 0;
  int _liveFailures = 0;
  DateTime? _blockedUntil;
  DateTime? _lastSyncedAt;
  bool _keysRefreshed = false;
  FirstPullProgress? _currentProgress;
  RelayTag _tag = const RelayTag(address: null, generation: null, counter: 0);
  bool _rebasing = false;
  bool _newServerUnreachable = false;

  RelayClient? _client;
  String? _clientAddress;
  StateApplier? _applier;
  LiveConnection? _live;
  bool _liveOpening = false;

  Timer? _writeTimer;
  Timer? _inactiveTimer;
  Timer? _retryTimer;
  Timer? _reconnectTimer;
  Timer? _pollTimer;

  Future<void>? _loop;
  bool _wanted = false;

  bool get isEnabled => _enabled;

  bool get isPaused => _paused;

  bool get isLive => _live?.isOpen ?? false;

  int get consecutiveFailures => _failures;

  RelayTag get relayTag => _tag;

  bool get isRebasing => _rebasing;

  bool get keysLocked => _keysLocked;

  FirstPullProgress? get firstPullProgress => _currentProgress;

  Stream<FirstPullProgress?> get progress => _progress.stream;

  String? get notice => _notice;

  Stream<String?> get notices => _notices.stream;

  Stream<void> get changes => _changes.stream;

  bool get _blocked {
    final DateTime? until = _blockedUntil;
    return until != null && _clock.now().isBefore(until);
  }

  bool get _mayTalk =>
      _started &&
      !_disposed &&
      _enabled &&
      !_paused &&
      _visible &&
      _networkKind != NetworkKind.offline &&
      _stopReason == null &&
      !_keysLocked &&
      !_blocked;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _tag = await readRelayTag(_db);
    _background = await _loadBackground();
    final AppLifecycleState? lifecycle = _lifecycle.current;
    _visible = lifecycle == null || !leavesOn(leaveRule, lifecycle);
    _networkKind = await _network.current();
    _paused =
        await readSyncState(_db, EngineStateKeys.paused) ==
        EngineStateKeys.pausedValue;
    _enabled =
        await readSyncState(_db, SyncStateKeys.syncEnabled) == syncEnabledValue;
    _subscriptions
      ..add(_lifecycle.changes.listen(_lifecycleChanged))
      ..add(_network.changes.listen(_networkChanged))
      ..add(
        (_db.select(_db.syncStates)
              ..where((t) => t.key.equals(SyncStateKeys.syncEnabled)))
            .watchSingleOrNull()
            .listen(_enabledChanged),
      )
      ..add(
        _db
            .tableUpdates(
              TableUpdateQuery.onTableName(
                _db.syncOutbox.actualTableName,
                limitUpdateKind: UpdateKind.insert,
              ),
            )
            .listen((_) => _localWrite()),
      )
      ..add(
        _db
            .tableUpdates(
              TableUpdateQuery.onTableName(
                _db.mediaBlobs.actualTableName,
                limitUpdateKind: UpdateKind.insert,
              ),
            )
            .listen((_) {
              if (!_pulling) {
                unawaited(_prepareMedia());
              }
            }),
      )
      ..add(
        _db
            .tableUpdates(
              TableUpdateQuery.allOf(<TableUpdateQuery>[
                TableUpdateQuery.onTable(_db.syncOutbox),
                TableUpdateQuery.onTable(_db.syncUploads),
                TableUpdateQuery.onTable(_db.syncHeldStates),
              ]),
            )
            .listen((_) => _changed()),
      );
    final BackgroundTransfer? background = _background;
    if (background != null) {
      _subscriptions.add(
        background.results.arrivals.listen((_) => _localWrite()),
      );
      final Stream<bool>? mobileData = background.mobileDataChanges;
      if (mobileData != null) {
        _subscriptions.add(
          mobileData.listen(
            (_) => unawaited(background.uploads.rescheduleForNetworkRule()),
          ),
        );
      }
    }
    _changed();
    if (_enabled) {
      unawaited(_activate());
    }
  }

  Future<void> syncNow() async {
    _unlockKeys();
    if (!_mayTalk) {
      return;
    }
    await _requestCycle();
  }

  Future<void> pause(bool paused) async {
    await writeSyncState(
      _db,
      EngineStateKeys.paused,
      paused ? EngineStateKeys.pausedValue : 'false',
    );
    if (_paused == paused) {
      return;
    }
    _paused = paused;
    _changed();
    if (paused) {
      await _quiet();
      await _background?.uploads.pause();
    } else {
      _background?.uploads.resume();
      await _resume();
    }
  }

  Future<SyncStatus?> status() async {
    if (!_enabled) {
      return null;
    }
    final int held = await _count(_db.syncHeldStates);
    return syncStatusFor(
      SyncStatusInputs(
        outboxCount: await _count(_db.syncOutbox),
        online: _networkKind != NetworkKind.offline,
        uploadCount: await _pendingUploads(),
        paused: _paused,
        attention: _attention(held),
        lastSyncedAt: _lastSyncedAt ?? _clock.now(),
      ),
    );
  }

  Stream<SyncStatus?> watchStatus() async* {
    yield await status();
    await for (final void _ in _changes.stream) {
      yield await status();
    }
  }

  Stream<bool> watchKeysLocked() =>
      Stream<bool>.multi((MultiStreamController<bool> controller) {
        controller.add(_keysLocked);
        final StreamSubscription<void> changes = _changes.stream.listen(
          (void _) => controller.add(_keysLocked),
          onDone: controller.close,
        );
        controller.onCancel = changes.cancel;
      });

  void keysRefused() => _keyAccessFailed();

  Future<bool> fetchMedia(String blobId) async {
    await _waitOutRateLimit();
    if (!_mayTalk) {
      return false;
    }
    final SyncMedia? media = await _mediaServices();
    final RelayClient? client;
    try {
      client = await _readyClient();
    } on KeyAccessException {
      _keyAccessFailed();
      return false;
    }
    if (media == null || client == null) {
      return false;
    }
    final TransferKind kind = (await posterMediaIds(_db)).contains(blobId)
        ? TransferKind.poster
        : TransferKind.fullMedia;
    if (!await _mayTransfer(media, kind)) {
      return false;
    }
    try {
      return await media.downloads.download(client, blobId);
    } on RelayRateLimited catch (error) {
      _rateLimited(error.retryAfter);
      return fetchMedia(blobId);
    } on RelayException {
      return false;
    } on MediaDownloadException {
      return false;
    } on CryptoException {
      return false;
    } on NotEnoughSpaceException {
      _setDeviceFull(true);
      return false;
    } on KeyAccessException {
      _keyAccessFailed();
      return false;
    }
  }

  Future<bool> observeRelay({
    required String generation,
    int? latestSeq,
    int? cursor,
  }) async {
    if (_rebasing) {
      return false;
    }
    final String? stored = _tag.generation;
    if (stored == null) {
      _tag = _tag.withGeneration(generation);
      await writeSyncState(_db, relayGenerationKey, generation);
      return true;
    }
    final bool behind =
        latestSeq != null && cursor != null && latestSeq < cursor;
    if (stored != generation || behind) {
      _requestRebase();
      return false;
    }
    return true;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _cancelTimers();
    _inactiveTimer?.cancel();
    _inactiveTimer = null;
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _live?.close();
    _live = null;
    await _loop;
    _client?.close();
    _client = null;
    await _changes.close();
    await _progress.close();
    await _notices.close();
  }

  Future<BackgroundTransfer?> _loadBackground() async {
    try {
      return await _backgroundSource?.call();
    } on Exception {
      return null;
    }
  }

  Future<SyncMedia?> _mediaServices() async {
    final SyncMediaSource? source = _media;
    if (source == null) {
      return null;
    }
    final Future<SyncMedia?> loading = _loadedMedia ??= source();
    try {
      return await loading;
    } on Exception {
      _loadedMedia = null;
      return null;
    }
  }

  Future<bool> _mayTransfer(SyncMedia media, TransferKind kind) async {
    final AppSettings settings = await media.settings();
    return NetworkPolicy(
      allowMobileDataForMedia: settings.allowMobileDataForMedia,
    ).allows(kind, _networkKind);
  }

  Future<void> _prepareMedia() {
    if (!_enabled || _paused || _disposed || _keysLocked) {
      return Future<void>.value();
    }
    return _preparing ??= _safely(_prepareOnce)
        .whenComplete(() => _preparing = null);
  }

  Future<void> _prepareOnce() async {
    final SyncMedia? media = await _mediaServices();
    if (media == null) {
      return;
    }
    try {
      await media.posters.makeMissing();
    } on Exception catch (error) {
      debugPrint('Posters were not made this time: $error');
    }
    try {
      await media.uploads.prepareAll();
      _noteDeviceSpace(media);
      await _handOverPrepared(media);
    } on RelayException {
      return;
    } on CryptoException {
      return;
    } on StateError {
      return;
    } on FileSystemException {
      return;
    }
  }

  Future<void> _handOverPrepared(SyncMedia media) async {
    final BackgroundTransfer? background = _background;
    if (background == null) {
      return;
    }
    final RelayClient? client = _mayTalk ? await _readyClient() : null;
    if (client == null) {
      await _applyCollectedResults(background);
      await background.uploads.handOverPrepared();
      return;
    }
    await media.uploads.send(
      client,
      background.uploads,
      mayContinue: () => _mayTalk,
    );
  }

  Future<void> _transferMedia(
    RelayClient client,
    PullResult pulled,
    FenceCheck current,
  ) async {
    final SyncMedia? media = await _mediaServices();
    if (media == null || !_mayTalk) {
      return;
    }
    await _prepareMedia();
    final AppSettings settings = await media.settings();
    final NetworkPolicy policy = NetworkPolicy(
      allowMobileDataForMedia: settings.allowMobileDataForMedia,
    );
    final BackgroundTransfer? background = _background;
    await media.uploads.send(
      client,
      background?.uploads ?? media.senderFor(client),
      allowed: background != null
          ? null
          : (PendingUpload upload) => policy.allows(
              upload.isPoster ? TransferKind.poster : TransferKind.fullMedia,
              _networkKind,
            ),
      mayContinue: () => _mayTalk,
      isCurrent: current,
    );
    if (!_mayTalk || !current()) {
      return;
    }
    await media.downloads.downloadEager(
      client,
      keepAll: settings.keepAllMediaOnDevice,
      allowed: (TransferKind kind) => policy.allows(kind, _networkKind),
      mayContinue: () => _mayTalk,
    );
    _noteDeviceSpace(media);
    if (!pulled.complete || !_mayTalk || !current()) {
      return;
    }
    await media.unusedBlobs.report(client, isCurrent: current);
    await media.cache.trim(keepAll: settings.keepAllMediaOnDevice);
  }

  AttentionReason? _attention(int held) {
    final AttentionReason? stop = _stopReason;
    if (stop != null) {
      return stop;
    }
    if (_keysLocked) {
      return AttentionReason.keysLocked;
    }
    if (_newServerUnreachable) {
      return AttentionReason.newServerUnreachable;
    }
    if (held > 0) {
      return AttentionReason.clock;
    }
    if (_storageFull) {
      return AttentionReason.storageFull;
    }
    if (_deviceFull) {
      return AttentionReason.deviceFull;
    }
    if (_noteTooLong) {
      return AttentionReason.noteTooLong;
    }
    if (_failures >= unreachableAfterFailures &&
        _networkKind != NetworkKind.offline) {
      return _troubled ? AttentionReason.problem : AttentionReason.unreachable;
    }
    return null;
  }

  void _noteDeviceSpace(SyncMedia media) => _setDeviceFull(
    media.uploads.waitingForSpace || media.downloads.waitingForSpace,
  );

  void _setDeviceFull(bool full) {
    if (_deviceFull == full) {
      return;
    }
    _deviceFull = full;
    _changed();
  }

  Future<int> _count(TableInfo<Table, Object?> table) async {
    final Expression<int> count = countAll();
    final TypedResult row = await (_db.selectOnly(
      table,
    )..addColumns(<Expression<Object>>[count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> _pendingUploads() async {
    final Expression<int> count = _db.syncUploads.blobId.count();
    final TypedResult row =
        await (_db.selectOnly(_db.syncUploads)
              ..addColumns(<Expression<Object>>[count])
              ..where(
                _db.syncUploads.status.equals(assembledUploadStatus).not(),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  void _changed() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  void _setProgress(FirstPullProgress? progress) {
    if (_currentProgress == progress) {
      return;
    }
    _currentProgress = progress;
    if (!_progress.isClosed) {
      _progress.add(progress);
    }
  }

  void _lifecycleChanged(AppLifecycleState state) {
    _inactiveTimer?.cancel();
    _inactiveTimer = null;
    if (state == AppLifecycleState.inactive) {
      if (leaveRule == LeaveRule.inactive && _visible) {
        _inactiveTimer = _clock.timer(inactiveLeaveDelay, () {
          _inactiveTimer = null;
          _setVisible(false);
        });
      }
      return;
    }
    _setVisible(!leavesOn(leaveRule, state));
  }

  void _setVisible(bool visible) {
    if (visible == _visible) {
      return;
    }
    _visible = visible;
    if (visible) {
      _unlockKeys();
      unawaited(_resume());
    } else {
      unawaited(_quiet().then((_) => _handOverOnLeave()));
    }
  }

  Future<void> _applyCollectedResults(BackgroundTransfer background) async {
    if (!background.results.hasPending) {
      return;
    }
    final int counter = _tag.counter;
    await background.results.applyPending(
      push: await _pushCycle(null),
      isCurrent: () => _tag.counter == counter && !_disposed,
    );
  }

  Future<void> _handOverOnLeave() async {
    final BackgroundTransfer? background = _background;
    if (background == null ||
        !_enabled ||
        _paused ||
        _disposed ||
        _keysLocked) {
      return;
    }
    await _safely(() => _handOver(background));
  }

  Future<void> _handOver(BackgroundTransfer background) async {
    try {
      await _applyCollectedResults(background);
      final JoinMerge? join = _join;
      if (join == null || await join.stage() == JoinStage.done) {
        await background.uploads.handOverPushes(
          await _pushCycle(null),
          excluding: _stale.unpulled,
        );
      }
      await background.uploads.handOverPrepared();
    } on CryptoException {
      return;
    } on StateError {
      return;
    } on FileSystemException {
      return;
    }
  }

  Future<PushCycle> _pushCycle(DeviceService? devices) async => PushCycle(
    database: _db,
    applier: await _stateApplier(),
    keys: _journalKeys,
    refreshKeys: devices?.refreshKeys ?? _journalKeys,
    wallClock: () => _clock.now().millisecondsSinceEpoch,
  );

  void _networkChanged(NetworkKind kind) {
    final NetworkKind previous = _networkKind;
    final bool wasOnline = previous != NetworkKind.offline;
    _networkKind = kind;
    final bool online = kind != NetworkKind.offline;
    _changed();
    if (online && !wasOnline) {
      _failures = 0;
      _liveFailures = 0;
      unawaited(_resume());
    } else if (!online && wasOnline) {
      unawaited(_quiet());
    } else if (kind == NetworkKind.unmetered &&
        previous == NetworkKind.metered) {
      unawaited(_resume());
    }
  }

  void _enabledChanged(SyncState? row) {
    final bool enabled = row?.value == syncEnabledValue;
    if (enabled == _enabled) {
      return;
    }
    _enabled = enabled;
    _changed();
    if (enabled) {
      unawaited(_activate());
    } else {
      unawaited(_deactivate());
    }
  }

  void _localWrite() {
    if (!_mayTalk) {
      return;
    }
    final DateTime now = _clock.now();
    final Duration waited = now.difference(_writesWaitingSince ??= now);
    final Duration left = localWriteMaxDelay - waited;
    _writeTimer?.cancel();
    _writeTimer = _clock.timer(
      left < localWriteDelay
          ? (left.isNegative ? Duration.zero : left)
          : localWriteDelay,
      () {
        _writeTimer = null;
        _writesWaitingSince = null;
        unawaited(_requestCycle());
      },
    );
  }

  Future<void> _activate() async {
    _keysRefreshed = false;
    _keysLocked = false;
    _troubled = false;
    _stopReason = null;
    _failures = 0;
    _liveFailures = 0;
    _stale = const StaleRecords();
    _changed();
    await _background?.results.start();
    unawaited(_prepareMedia());
    await _resume();
  }

  Future<void> _deactivate() async {
    await _quiet();
    _client?.close();
    _client = null;
    _clientAddress = null;
    _setProgress(null);
  }

  Future<void> _resume() async {
    if (!_mayTalk) {
      return;
    }
    await _requestCycle();
  }

  Future<void> _quiet() async {
    _cancelTimers();
    final LiveConnection? live = _live;
    _live = null;
    await live?.close();
    _changed();
  }

  void _cancelTimers() {
    _writeTimer?.cancel();
    _writeTimer = null;
    _writesWaitingSince = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _requestCycle() {
    _wanted = true;
    return _loop ??= _drain().whenComplete(() => _loop = null);
  }

  Future<void> _drain() async {
    while (_wanted) {
      _wanted = false;
      await _safely(_cycleOnce, onUnexpected: _failedUnexpectedly);
    }
  }

  Future<void> _safely(
    Future<void> Function() work, {
    void Function()? onUnexpected,
  }) async {
    try {
      await work();
    } on KeyAccessException {
      _keyAccessFailed();
    } catch (error, stack) {
      debugPrint('Sync stopped a step that failed: $error\n$stack');
      onUnexpected?.call();
    }
  }

  void _keyAccessFailed() {
    if (_keysLocked) {
      return;
    }
    _keysLocked = true;
    _setProgress(null);
    unawaited(_quiet());
  }

  void _unlockKeys() {
    if (!_keysLocked) {
      return;
    }
    _keysLocked = false;
    _changed();
  }

  void _failedUnexpectedly() {
    _troubled = true;
    _failed();
  }

  Future<RelayClient?> _readyClient() async {
    final String? address = await readSyncState(_db, SyncStateKeys.relayUrl);
    final DeviceKeys? device = await _keyStore.readDeviceKeys();
    if (address == null || device == null) {
      return null;
    }
    if (_tag.address != address) {
      _tag = await readRelayTag(_db);
    }
    final RelayClient? existing = _client;
    if (existing != null && _clientAddress == address) {
      return existing;
    }
    existing?.close();
    final RelayClient client = _newClient(Uri.parse(address), device);
    _client = client;
    _clientAddress = address;
    return client;
  }

  RelayClient _newClient(Uri address, DeviceKeys device) {
    late final RelayClient client;
    client = _clientFor(address, device, (SessionResponse session) {
      if (identical(_client, client)) {
        _sessionStarted(session);
      }
    });
    return client;
  }

  void _sessionStarted(SessionResponse session) {
    unawaited(_storeUploadPass(session).catchError((Object _) {}));
    unawaited(
      observeRelay(generation: session.generation)
          .then((bool _) {}, onError: (Object _) {}),
    );
  }

  Future<void> _storeUploadPass(SessionResponse session) =>
      _keyStore.writeUploadPass(
        UploadPass(
          token: session.uploadPass,
          expiresAt: session.uploadPassExpiresAt,
        ),
      );

  Future<StateApplier> _stateApplier() async => _applier ??= StateApplier(
    database: _db,
    recorder: _recorder,
    localDeviceName: await _deviceName(),
  );

  Future<JournalKeys> _journalKeys() async {
    final JournalKeys? keys = await _keyStore.readJournalKeys();
    if (keys == null) {
      throw StateError('This device holds no journal keys');
    }
    return keys;
  }

  DeviceService _devices(RelayClient client) =>
      DeviceService(database: _db, keyStore: _keyStore, client: client);

  Future<void> _cycleOnce() async {
    if (!_mayTalk || _rebasing) {
      return;
    }
    final RelayClient? client = await _readyClient();
    if (client == null || !_mayTalk) {
      return;
    }
    final RelayTag made = _tag;
    bool current() => !_rebasing && _tag.admits(made);
    try {
      await _runCycle(client, current);
      if (current()) {
        _succeeded();
      }
    } on RelayRateLimited catch (error) {
      _rateLimited(error.retryAfter);
    } on RelayRejected catch (error) {
      _rejected(error);
    } on RelayException {
      _failed();
    } on CryptoException {
      _failed();
    } on FormatException {
      _failed();
    } on FileSystemException {
      _failed();
    } on MediaDownloadException {
      _failed();
    } on StateError {
      _failed();
    }
  }

  Future<void> _runCycle(RelayClient client, FenceCheck current) async {
    final StateApplier applier = await _stateApplier();
    final DeviceService devices = _devices(client);
    if (!_keysRefreshed) {
      await devices.refreshKeys();
      _keysRefreshed = true;
    }
    await _background?.results.applyPending(
      push: await _pushCycle(devices),
      client: client,
      isCurrent: current,
    );
    final PullCycle pull = PullCycle(
      database: _db,
      applier: applier,
      keys: _journalKeys,
      refreshKeys: devices.refreshKeys,
      pageSize: pullPageSize,
      wallClock: () => _clock.now().millisecondsSinceEpoch,
    );
    final JoinMerge? join = _join;
    final bool joining =
        join != null && await _joinStage(join) != JoinStage.done;
    final bool firstPull = !await firstPullHasCompleted(_db);
    await pull.retryHeld(isCurrent: current);
    final PullResult pulled;
    _pulling = true;
    try {
      pulled = await pull.run(
        client,
        onResponse: (PullResponse response, int cursor) => observeRelay(
          generation: response.generation,
          latestSeq: response.latestSeq,
          cursor: cursor,
        ),
        onPage: firstPull ? _firstPullPage : null,
        mayContinue: () => _mayTalk,
        isCurrent: current,
      );
    } finally {
      _pulling = false;
    }
    if (pulled.complete) {
      _setProgress(null);
      _stale = _stale.afterCompletePull();
    }
    if (!_mayTalk || !current()) {
      return;
    }
    if (join != null && joining) {
      if (!pulled.complete) {
        return;
      }
      await join.finish();
    }
    await _pushAll(client, await _pushCycle(devices), devices, current);
    if (!_mayTalk || !current()) {
      return;
    }
    await _transferMedia(client, pulled, current);
    if (!_mayTalk || !current()) {
      return;
    }
    await _followAddress(current);
  }

  Future<void> _followAddress(FenceCheck current) async {
    final Uri? target = await addressToFollow(_db);
    if (target == null) {
      if (_newServerUnreachable) {
        _newServerUnreachable = false;
        _changed();
      }
      return;
    }
    final DeviceKeys? device = await _keyStore.readDeviceKeys();
    if (device == null) {
      return;
    }
    final RelayClient candidate = _newClient(target, device);
    final SessionResponse session;
    try {
      session = await candidate.signIn();
    } on RelayRateLimited catch (error) {
      candidate.close();
      _newServerUnreachable = false;
      _rateLimited(error.retryAfter);
      return;
    } on RelayException {
      candidate.close();
      _newServerUnreachable = true;
      _changed();
      return;
    }
    if (!current()) {
      candidate.close();
      return;
    }
    _newServerUnreachable = false;
    _requestRebase(to: target, client: candidate, session: session);
  }

  void _requestRebase({
    Uri? to,
    RelayClient? client,
    SessionResponse? session,
  }) {
    if (_rebasing) {
      client?.close();
      return;
    }
    _rebasing = true;
    _tag = RelayTag(
      address: _tag.address,
      generation: _tag.generation,
      counter: _tag.counter + 1,
    );
    _changed();
    bool rebased = false;
    unawaited(
      _safely(() async {
        rebased = await _rebase(to: to, candidate: client, session: session);
      }, onUnexpected: _failedUnexpectedly).whenComplete(() {
        _rebasing = false;
        _changed();
        if (!rebased) {
          if (_retryTimer == null) {
            _failed();
          }
          return;
        }
        if (_mayTalk) {
          unawaited(_requestCycle());
        }
      }),
    );
  }

  Future<bool> _rebase({
    Uri? to,
    RelayClient? candidate,
    SessionResponse? session,
  }) async {
    final int counter = _tag.counter;
    await writeSyncState(_db, rebaseCounterKey, '$counter');
    final LiveConnection? live = _live;
    _live = null;
    await live?.close();
    final String? inUse = await readSyncState(_db, SyncStateKeys.relayUrl);
    final DeviceKeys? device = await _keyStore.readDeviceKeys();
    if (device == null || (to == null && inUse == null)) {
      candidate?.close();
      return true;
    }
    final Uri address = to ?? Uri.parse(inUse!);
    final RelayClient client =
        candidate ?? _client ?? _newClient(address, device);
    try {
      final SessionResponse signedIn = session ?? await client.signIn();
      await _storeUploadPass(signedIn);
      final RelayRebase rebase = RelayRebase(
        database: _db,
        keyStore: _keyStore,
        wallClock: () => _clock.now().millisecondsSinceEpoch,
      );
      await rebase.putKeysRight(client);
      final String addressText = normalizedAddress('$address');
      await rebase.reset(
        address: addressText,
        generation: signedIn.generation,
        counter: counter,
      );
      _tag = RelayTag(
        address: addressText,
        generation: signedIn.generation,
        counter: counter,
      );
      if (!identical(_client, client)) {
        _client?.close();
        _client = client;
      }
      _clientAddress = addressText;
      _keysRefreshed = true;
      _stale = const StaleRecords();
      _setProgress(null);
    } on RelayRateLimited catch (error) {
      if (!identical(_client, client)) {
        client.close();
      }
      _rateLimited(error.retryAfter);
      return false;
    } on RelayException {
      if (!identical(_client, client)) {
        client.close();
      }
      return false;
    } on CryptoException {
      return false;
    }
    _rebasing = false;
    await _ensureLive();
    final BackgroundTransfer? background = _background;
    if (background != null) {
      await background.uploads.cancelAll();
      await background.uploads.handOverPrepared();
    }
    final SyncMedia? media = await _mediaServices();
    if (media != null && _mayTalk) {
      try {
        await media.unusedBlobs.reportReferenced(
          client,
          isCurrent: () => _tag.counter == counter,
        );
      } on RelayException {
        return true;
      }
    }
    return true;
  }

  Future<JoinStage> _joinStage(JoinMerge join) async {
    final JoinStage stage = await join.stage();
    if (stage == JoinStage.notStarted) {
      await join.prepare();
      return JoinStage.pending;
    }
    return stage;
  }

  void _firstPullPage(PullPage page) {
    _setProgress(
      page.hasMore
          ? FirstPullProgress(done: page.received, total: page.total)
          : null,
    );
  }

  Future<void> _pushAll(
    RelayClient client,
    PushCycle push,
    DeviceService devices,
    FenceCheck current,
  ) async {
    _stale = _stale.within(await _outboxIds());
    final Set<int> held = _stale.heldAt(_clock.now());
    final Set<int> skipped = <int>{...held};
    final Set<int> again = <int>{};
    bool epochRefreshed = false;
    while (_mayTalk && current()) {
      final PushBatch? batch = await push.buildBatch(excluding: skipped);
      if (batch == null) {
        break;
      }
      final PushResponse response = await client.push(batch.request);
      if (!current()) {
        return;
      }
      final PushApplied applied = await push.applyResponse(
        batch.request,
        response,
        isCurrent: current,
      );
      skipped.addAll(applied.stale);
      final Set<int> repeated = _stale.answeredAgain(applied.stale);
      again.addAll(repeated);
      _stale = _stale.afterAnswer(
        sent: batch.outboxIds.toSet(),
        stale: applied.stale,
      );
      if (applied.stale.difference(repeated).isNotEmpty) {
        _wanted = true;
      }
      if (applied.staleEpoch.isNotEmpty) {
        final int relayEpoch = (await client.keys()).currentEpoch;
        if (relayEpoch < (await _journalKeys()).currentEpoch) {
          _requestRebase();
          return;
        }
        if (epochRefreshed) {
          skipped.addAll(applied.staleEpoch);
        } else {
          epochRefreshed = true;
          await devices.refreshKeys();
        }
      }
      if (applied.acknowledged == 0 &&
          applied.stale.isEmpty &&
          applied.staleEpoch.isEmpty) {
        skipped.addAll(batch.outboxIds);
      }
    }
    _holdStale(again: again, held: held);
    if (_noteTooLong != push.oversized.isNotEmpty) {
      _noteTooLong = push.oversized.isNotEmpty;
      _changed();
    }
  }

  void _holdStale({required Set<int> again, required Set<int> held}) {
    final DateTime now = _clock.now();
    final DateTime? until = _stale.heldUntil;
    if (again.isNotEmpty) {
      final Duration wait = jitteredBackoff(_stale.rounds + 1, _random);
      _stale = _stale.heldTill(now.add(wait));
      _scheduleRetry(wait);
    } else if (held.isNotEmpty && until != null && _retryTimer == null) {
      _scheduleRetry(until.difference(now));
    }
    _stale = _stale.releasedWhenRepaired();
  }

  Future<Set<int>> _outboxIds() async {
    final List<TypedResult> rows = await (_db.selectOnly(
      _db.syncOutbox,
    )..addColumns(<Expression<Object>>[_db.syncOutbox.id])).get();
    return rows
        .map((TypedResult row) => row.read(_db.syncOutbox.id))
        .whereType<int>()
        .toSet();
  }

  void _succeeded() {
    _failures = 0;
    _troubled = false;
    _storageFull = false;
    _lastSyncedAt = _clock.now();
    _changed();
    unawaited(_ensureLive());
  }

  void _failed() {
    _failures += 1;
    _changed();
    _scheduleRetry(jitteredBackoff(_failures, _random));
    _startPolling();
  }

  void _rateLimited(Duration retryAfter) {
    _blockedUntil = _clock.now().add(retryAfter);
    _changed();
    _scheduleRetry(retryAfter);
  }

  Future<void> _waitOutRateLimit() async {
    DateTime? until = _blockedUntil;
    while (!_disposed && until != null && _clock.now().isBefore(until)) {
      final Completer<void> waited = Completer<void>();
      _clock.timer(until.difference(_clock.now()), waited.complete);
      await waited.future;
      until = _blockedUntil;
    }
  }

  void _rejected(RelayRejected error) {
    switch (error.code) {
      case SyncErrorCode.unsupportedProtocol:
        _stop(AttentionReason.updateApp);
      case SyncErrorCode.deviceRemoved:
        _setNotice(deviceRemovedNotice);
        _stop(AttentionReason.removed);
      case SyncErrorCode.journalErased:
        unawaited(_journalErased());
      case SyncErrorCode.storageFull:
        _storageFull = true;
        _failed();
      case SyncErrorCode.tooManyRequests:
        _rateLimited(defaultRetryAfter);
      default:
        _failed();
    }
  }

  Future<void> _journalErased() async {
    _setNotice(journalErasedNotice);
    _stop(AttentionReason.removed);
    await _wipe?.call();
  }

  void _setNotice(String notice) {
    _notice = notice;
    if (!_notices.isClosed) {
      _notices.add(notice);
    }
  }

  void _stop(AttentionReason reason) {
    _stopReason = reason;
    _setProgress(null);
    unawaited(_quiet());
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = _clock.timer(delay, () {
      _retryTimer = null;
      unawaited(_resume());
    });
  }

  void _startPolling() {
    if (_pollTimer != null) {
      return;
    }
    _pollTimer = _clock.periodic(offlinePollInterval, () {
      if (!isLive) {
        unawaited(_resume());
      }
    });
  }

  Future<void> _ensureLive() async {
    final RelayClient? client = _client;
    if (!_mayTalk || client == null || isLive || _liveOpening) {
      return;
    }
    if (_reconnectTimer != null) {
      return;
    }
    _liveOpening = true;
    final LiveConnection live = LiveConnection(
      connect: client.connectLive,
      clock: _clock,
      onNudge: (int _) => unawaited(_resume()),
      onClosed: _liveClosed,
    );
    try {
      await live.open();
      if (!_mayTalk) {
        await live.close();
        return;
      }
      _live = live;
      _liveFailures = 0;
      _pollTimer?.cancel();
      _pollTimer = null;
      _changed();
      unawaited(_requestCycle());
    } on RelayRateLimited catch (error) {
      _rateLimited(error.retryAfter);
    } on RelayException {
      _liveFailures += 1;
      _scheduleReconnect();
    } catch (error) {
      debugPrint('Sync could not open its live connection: $error');
      _liveFailures += 1;
      _scheduleReconnect();
    } finally {
      _liveOpening = false;
    }
  }

  void _liveClosed() {
    _live = null;
    _changed();
    if (!_mayTalk) {
      return;
    }
    _liveFailures += 1;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _startPolling();
    _reconnectTimer?.cancel();
    _reconnectTimer = _clock.timer(jitteredBackoff(_liveFailures, _random), () {
      _reconnectTimer = null;
      unawaited(_resume());
    });
  }
}
