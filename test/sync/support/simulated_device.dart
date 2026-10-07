import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/drafts/draft_paths.dart';
import 'package:field_notes/data/journal/day_ids.dart';
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/media/media_duration.dart';
import 'package:field_notes/data/settings/settings_keys.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/enrolment/restore_service.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/merge/record_reader.dart';
import 'package:field_notes/data/sync/pairing/pairing_service.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../support/sync_overrides.dart';
import 'relay_fixture.dart';

typedef WallClock = int Function();

typedef SyncedRows = Map<String, List<Map<String, Object?>>>;

typedef TextWrite = ({String entryId, String line});

int systemWallClock() => DateTime.now().millisecondsSinceEpoch;

WallClock skewedWallClock(Duration skew) =>
    () => systemWallClock() + skew.inMilliseconds;

const String simulatedInviteNote = 'Simulated journal';
const Duration settleTimeout = Duration(minutes: 3);
const Duration _settlePoll = Duration(milliseconds: 100);
const int _settledPolls = 3;
const Duration _pairingPoll = Duration(milliseconds: 20);
const Duration _pushTimeout = Duration(minutes: 1);
const String _clocksColumn = 'fieldClocks';
const String _deletedField = 'deletedAt';
const String _moodField = 'moodId';
const String _valueField = 'value';
const String _voiceMime = 'audio/mp4';
const String _photoMime = 'image/png';

const List<domain.Mood> scenarioMoods = <domain.Mood>[
  domain.Mood.grateful,
  domain.Mood.hopeful,
  domain.Mood.anxious,
];

final List<String> scenarioDates = List<String>.unmodifiable(<String>[
  for (int day = 1; day <= 12; day++)
    '2025-03-${day.toString().padLeft(2, '0')}',
]);

const List<String> _vocabulary = <String>[
  'heron',
  'lantern',
  'harbour',
  'ember',
  'quarry',
  'saffron',
  'orchard',
  'cobalt',
  'thistle',
  'granite',
  'marigold',
  'estuary',
];

final class SilentDurationProbe implements MediaDurationProbe {
  const SilentDurationProbe();

  @override
  Future<Duration?> duration({
    required File file,
    required domain.MediaKind kind,
  }) => Future<Duration?>.value();
}

final class SimulatedPhoto {
  const SimulatedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });

  factory SimulatedPhoto.random(Random random) {
    final int width = 12 + random.nextInt(13);
    final int height = 8 + random.nextInt(9);
    final img.Image image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        image.setPixelRgb(
          x,
          y,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
    }
    return SimulatedPhoto(
      bytes: img.encodePng(image),
      width: width,
      height: height,
    );
  }

  final Uint8List bytes;
  final int width;
  final int height;
}

final List<SimulatedPhoto> sharedPhotos = List<SimulatedPhoto>.unmodifiable(
  <SimulatedPhoto>[
    for (int index = 0; index < 3; index++)
      SimulatedPhoto.random(Random(7100 + index)),
  ],
);

final class SimulatedDevice {
  SimulatedDevice._({
    required this.name,
    required this.root,
    required this.database,
    required this.keyStore,
    required this.network,
    required this.container,
  });

  static Future<SimulatedDevice> create(
    String name, {
    WallClock wallClock = systemWallClock,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    final Directory root = await Directory.systemTemp.createTemp(
      'fn_simulated_device_',
    );
    final AppDatabase database = AppDatabase(NativeDatabase.memory());
    final KeyStore keyStore = KeyStore(MemorySecureValues());
    final FakeNetworkMonitor network = FakeNetworkMonitor();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        changeRecorderProvider.overrideWith(
          (Ref ref) =>
              ChangeRecorder(ref.watch(databaseProvider), wallClock: wallClock),
        ),
        journalRepositoryProvider.overrideWith(
          (Ref ref) => DriftJournalRepository(
            ref.watch(databaseProvider),
            recorder: ref.watch(changeRecorderProvider),
            clock: wallClock,
          ),
        ),
        keyStoreProvider.overrideWithValue(keyStore),
        networkMonitorProvider.overrideWithValue(network),
        appLifecycleProvider.overrideWithValue(FakeLifecycleSource()),
        mediaRootProvider.overrideWith(
          (Ref ref) async => Directory(p.join(root.path, mediaSubdir)),
        ),
        draftRootProvider.overrideWith(
          (Ref ref) async => Directory(p.join(root.path, draftsSubdir)),
        ),
        backgroundTransferProvider.overrideWith((Ref ref) async => null),
        mediaDurationProbeProvider.overrideWithValue(
          const SilentDurationProbe(),
        ),
      ],
    );
    final SimulatedDevice device = SimulatedDevice._(
      name: name,
      root: root,
      database: database,
      keyStore: keyStore,
      network: network,
      container: container,
    );
    container.read(syncEngineProvider);
    return device;
  }

  final String name;
  final Directory root;
  final AppDatabase database;
  final KeyStore keyStore;
  final FakeNetworkMonitor network;
  final ProviderContainer container;
  bool _disposed = false;

  SyncEngine get engine => container.read(syncEngineProvider);

  JournalRepository get journal => container.read(journalRepositoryProvider);

  SettingsRepository get settings => container.read(settingsRepositoryProvider);

  Future<FilesystemMediaStore> mediaStore() =>
      container.read(filesystemMediaStoreProvider.future);

  Future<Directory> mediaRoot() => container.read(mediaRootProvider.future);

  Future<NoteWriter> noteWriter() => container.read(noteWriterProvider.future);

  Future<CaptureService> captureService() =>
      container.read(captureServiceProvider.future);

  bool get online => network.kind != NetworkKind.offline;

  void goOnline() => network.kind = NetworkKind.unmetered;

  void goOffline() => network.kind = NetworkKind.offline;

  Future<String> accountId() async => (await keyStore.readAccountId())!;

  Future<List<String>> enrol(RelayFixture relay) async {
    final PendingEnrolment pending =
        await EnrolmentService(
          database: database,
          keyStore: keyStore,
          deviceName: () async => name,
        ).start(
          relayUrl: relay.baseUrl,
          inviteCode: relay.createInvite(simulatedInviteNote),
        );
    await pending.confirm(<String>[
      for (final int position in pending.positions) pending.words[position - 1],
    ]);
    return pending.words;
  }

  Future<void> pairWith(SimulatedDevice host, RelayFixture relay) async {
    final HostedPairing hosted = await PairingService(
      database: host.database,
      keyStore: host.keyStore,
      deviceName: () async => host.name,
      pollInterval: _pairingPoll,
    ).open();
    try {
      final Future<void> joining =
          PairingService(
            database: database,
            keyStore: keyStore,
            deviceName: () async => name,
            pollInterval: _pairingPoll,
          ).join(
            hosted.code.phrase,
            relayUrl: relay.baseUrl,
            confirmJournal: joinAnyJournal,
          );
      await hosted.confirm(await hosted.waitForJoin());
      await joining;
    } finally {
      hosted.close();
    }
  }

  Future<RestoredJournal> restore(RelayFixture relay, List<String> words) =>
      RestoreService(
        database: database,
        keyStore: keyStore,
        deviceName: () async => name,
      ).restore(relayUrl: relay.baseUrl, phrase: words.join(' '));

  Future<SyncedRows> syncedRows() async => <String, List<Map<String, Object?>>>{
    SyncedTables.days: _syncedColumns(<Map<String, Object?>>[
      for (final Day row in await database.select(database.days).get())
        row.toJson(),
    ], SyncedTables.dayFields),
    SyncedTables.entries: _syncedColumns(<Map<String, Object?>>[
      for (final Entry row in await database.select(database.entries).get())
        row.toJson(),
    ], SyncedTables.entryFields),
    SyncedTables.entryPhotos: _syncedColumns(<Map<String, Object?>>[
      for (final EntryPhoto row
          in await database.select(database.entryPhotos).get())
        row.toJson(),
    ], SyncedTables.entryPhotoFields),
    SyncedTables.mediaBlobs: _syncedColumns(<Map<String, Object?>>[
      for (final MediaBlob row
          in await database.select(database.mediaBlobs).get())
        row.toJson(),
    ], SyncedTables.mediaBlobFields),
    SyncedTables.journalSettings: _syncedColumns(<Map<String, Object?>>[
      for (final JournalSetting row
          in await database.select(database.journalSettings).get())
        row.toJson(),
    ], SyncedTables.journalSettingFields),
  };

  Future<List<File>> mediaFiles() async {
    final Directory media = await mediaRoot();
    if (!await media.exists()) {
      return const <File>[];
    }
    return List<File>.unmodifiable(<File>[
      await for (final FileSystemEntity entity in media.list(
        recursive: true,
        followLinks: false,
      ))
        if (entity is File &&
            !p
                .split(p.relative(entity.path, from: media.path))
                .any((String part) => part.startsWith('.')))
          entity,
    ]);
  }

  Future<Map<String, int>> recordSeqs() async => <String, int>{
    for (final SyncRecordSeq row
        in await database.select(database.syncRecordSeqs).get())
      row.recordKey: row.seq,
  };

  Future<int> outboxCount() => _rowCount(database, database.syncOutbox);

  Future<List<String>> unsettledReasons(Map<String, int> relaySeqs) async {
    final SyncMedia media = await container.read(syncMediaProvider.future);
    final int outbox = await outboxCount();
    final int held = await _rowCount(database, database.syncHeldStates);
    final int uploading = (await database.select(database.syncUploads).get())
        .where((SyncUpload row) => row.status != assembledUploadStatus)
        .length;
    final int unprepared = (await media.uploads.unpreparedBlobIds()).length;
    final Map<String, int> seqs = await recordSeqs();
    final int behind = relaySeqs.entries
        .where((MapEntry<String, int> entry) => seqs[entry.key] != entry.value)
        .length;
    final SyncStatus? status = await engine.status();
    return List<String>.unmodifiable(<String>[
      if (!online) 'offline',
      if (engine.isRebasing) 'rebasing',
      if (outbox > 0) '$outbox changes waiting',
      if (held > 0) '$held states held back',
      if (uploading > 0) '$uploading uploads unfinished',
      if (unprepared > 0) '$unprepared files not yet queued',
      if (behind > 0) '$behind records behind the relay',
      if (!mapEquals(seqs, relaySeqs) && behind == 0)
        'records the relay does not hold',
      if (status is! SyncedStatus) 'status ${status?.runtimeType}',
    ]);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await engine.dispose();
    container.dispose();
    await database.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}

Future<int> _rowCount(
  AppDatabase database,
  TableInfo<Table, Object?> table,
) async {
  final Expression<int> count = countAll();
  final TypedResult row = await (database.selectOnly(
    table,
  )..addColumns(<Expression<Object>>[count])).getSingle();
  return row.read(count) ?? 0;
}

List<Map<String, Object?>> _syncedColumns(
  List<Map<String, Object?>> rows,
  List<String> fields,
) {
  final String key = fields.first;
  final List<Map<String, Object?>> kept =
      <Map<String, Object?>>[
        for (final Map<String, Object?> row in rows)
          Map<String, Object?>.unmodifiable(<String, Object?>{
            for (final String field in fields) field: row[field],
            _clocksColumn: row[_clocksColumn],
          }),
      ]..sort(
        (Map<String, Object?> a, Map<String, Object?> b) =>
            '${a[key]}'.compareTo('${b[key]}'),
      );
  return List<Map<String, Object?>>.unmodifiable(kept);
}

Future<void> settle(
  RelayFixture relay,
  List<SimulatedDevice> devices, {
  Duration timeout = settleTimeout,
}) async {
  final String accountId = await devices.first.accountId();
  final DateTime deadline = DateTime.now().add(timeout);
  Map<String, int>? previous;
  int stable = 0;
  while (stable < _settledPolls) {
    await Future<void>.delayed(_settlePoll);
    final Map<String, int> seqs = relay.recordSeqs(accountId);
    final List<String> reasons = <String>[
      if (previous == null || !mapEquals(previous, seqs)) 'relay still moving',
      for (final SimulatedDevice device in devices)
        for (final String reason in await device.unsettledReasons(seqs))
          '${device.name}: $reason',
    ];
    previous = seqs;
    stable = reasons.isEmpty ? stable + 1 : 0;
    if (reasons.isNotEmpty && DateTime.now().isAfter(deadline)) {
      fail('The devices did not settle: ${reasons.join('; ')}');
    }
  }
}

Future<void> _waitForPush(SimulatedDevice device) async {
  final DateTime deadline = DateTime.now().add(_pushTimeout);
  while (await device.outboxCount() > 0) {
    if (DateTime.now().isAfter(deadline)) {
      fail('${device.name} did not push its changes');
    }
    await Future<void>.delayed(_settlePoll);
  }
}

final class JournalLedger {
  final Map<String, String> _created = <String, String>{};
  final Set<String> _deleted = <String>{};
  final List<TextWrite> _writes = <TextWrite>[];
  final Map<String, Map<String, bool>> _dayDeletions =
      <String, Map<String, bool>>{};
  final Map<String, Map<String, String?>> _dayMoods =
      <String, Map<String, String?>>{};
  final Map<String, String> _weekStarts = <String, String>{};
  final Set<String> _dates = <String>{};
  final Set<String> _moodIds = <String>{};
  final Map<String, int> _operations = <String, int>{};

  Map<String, String> get createdEntries =>
      Map<String, String>.unmodifiable(_created);

  Set<String> get deletedEntries => Set<String>.unmodifiable(_deleted);

  List<TextWrite> get textWrites => List<TextWrite>.unmodifiable(_writes);

  Map<String, Map<String, bool>> get dayDeletions =>
      Map<String, Map<String, bool>>.unmodifiable(_dayDeletions);

  Map<String, Map<String, String?>> get dayMoods =>
      Map<String, Map<String, String?>>.unmodifiable(_dayMoods);

  Map<String, String> get weekStarts =>
      Map<String, String>.unmodifiable(_weekStarts);

  Set<String> get dates => Set<String>.unmodifiable(_dates);

  Set<String> get moodIds => Set<String>.unmodifiable(_moodIds);

  Map<String, int> get operations => Map<String, int>.unmodifiable(_operations);

  void _counted(String operation) {
    _operations[operation] = (_operations[operation] ?? 0) + 1;
  }

  void _createdEntry(String entryId, String date) {
    _created[entryId] = date;
    _dates.add(date);
  }

  void _wrote(String entryId, String line) {
    _writes.add((entryId: entryId, line: line));
  }

  void _observedDay(Day row) {
    final Map<String, String> clocks = decodeFieldClocks(row.fieldClocks);
    _dates.add(row.date);
    final String? deletedClock = clocks[_deletedField];
    if (deletedClock != null) {
      (_dayDeletions[row.id] ??= <String, bool>{})[deletedClock] =
          row.deletedAt != null;
    }
    final String? moodClock = clocks[_moodField];
    if (moodClock != null) {
      (_dayMoods[row.id] ??= <String, String?>{})[moodClock] = row.moodId;
    }
    if (row.moodId case final String mood) {
      _moodIds.add(mood);
    }
  }

  void _observedWeekStart(JournalSetting row) {
    final String? clock = decodeFieldClocks(row.fieldClocks)[_valueField];
    if (clock != null) {
      _weekStarts[clock] = row.value;
    }
  }
}

final class RandomActivity {
  RandomActivity(this.random, this.ledger);

  final Random random;
  final JournalLedger ledger;
  int _lines = 0;

  Future<void> step(SimulatedDevice device) async {
    final int roll = random.nextInt(100);
    if (roll < 18) {
      return _createText(device);
    }
    if (roll < 26) {
      return _createVoice(device);
    }
    if (roll < 34) {
      return _createPhoto(device);
    }
    if (roll < 59) {
      return _editText(device);
    }
    if (roll < 71) {
      return _setMood(device);
    }
    if (roll < 77) {
      return _clearMood(device);
    }
    if (roll < 81) {
      return _changeWeekStart(device);
    }
    if (roll < 93) {
      return _deleteEntry(device);
    }
    return _deleteDay(device);
  }

  String _date() => scenarioDates[random.nextInt(scenarioDates.length)];

  String _line() {
    _lines += 1;
    final List<String> words = <String>[
      for (int index = 0; index < 3; index++)
        _vocabulary[random.nextInt(_vocabulary.length)],
    ];
    return 'line ${_lines.toString().padLeft(4, '0')} ${words.join(' ')}';
  }

  Uint8List _bytes(int length) => Uint8List.fromList(
    List<int>.generate(length, (int _) => random.nextInt(256)),
  );

  Future<void> _createText(SimulatedDevice device) async {
    final String date = _date();
    final int count = 1 + random.nextInt(3);
    final List<String> lines = <String>[
      for (int index = 0; index < count; index++) _line(),
    ];
    final NoteSaveResult saved = await (await device.noteWriter()).save(
      date: date,
      source: lines.join('\n'),
    );
    ledger._counted('create text');
    _recordCreated(saved.entry.id, date, lines);
    await _observeDay(device, date);
  }

  Future<void> _createVoice(SimulatedDevice device) async {
    final String date = _date();
    final CaptureResult captured = await (await device.captureService())
        .capture(
          VoiceCaptureRequest(
            date: date,
            audio: CaptureBytes(
              bytes: _bytes(600 + random.nextInt(1800)),
              mime: _voiceMime,
            ),
            durationMs: 1000 + random.nextInt(9000),
          ),
        );
    ledger._counted('create voice');
    _recordCreated(captured.entry.id, date, const <String>[]);
    await _observeDay(device, date);
  }

  Future<void> _createPhoto(SimulatedDevice device) async {
    final String date = _date();
    final FilesystemMediaStore store = await device.mediaStore();
    final int count = 1 + random.nextInt(2);
    final List<String> photoIds = <String>[];
    for (int index = 0; index < count; index++) {
      final SimulatedPhoto photo = random.nextInt(4) == 0
          ? sharedPhotos[random.nextInt(sharedPhotos.length)]
          : SimulatedPhoto.random(random);
      final domain.MediaBlob blob = await store.putBytes(
        bytes: photo.bytes,
        mime: _photoMime,
        kind: domain.MediaKind.photo,
        width: photo.width,
        height: photo.height,
      );
      photoIds.add(blob.id);
    }
    final List<String> lines = <String>[_line()];
    final NoteSaveResult saved = await (await device.noteWriter()).save(
      date: date,
      source: lines.join('\n'),
      photoMediaIds: photoIds,
    );
    ledger._counted('create photo');
    _recordCreated(saved.entry.id, date, lines);
    await _observeDay(device, date);
  }

  Future<void> _editText(SimulatedDevice device) async {
    final List<Entry> candidates = await _visibleEntries(
      device,
      textOnly: true,
    );
    if (candidates.isEmpty) {
      return _createText(device);
    }
    final Entry entry = candidates[random.nextInt(candidates.length)];
    final List<String> lines = (entry.textContent ?? '').split('\n');
    final String line = _line();
    final int at = random.nextInt(lines.length + 1);
    final List<String> edited = <String>[
      ...lines.take(at),
      line,
      ...lines.skip(at),
    ];
    final domain.Day day = (await device.journal.dayById(entry.dayId))!;
    final List<String> photos = <String>[
      for (final domain.EntryPhoto photo in await device.journal.photosForEntry(
        entry.id,
      ))
        photo.mediaId,
    ];
    await (await device.noteWriter()).save(
      entryId: entry.id,
      date: day.date,
      source: edited.join('\n'),
      photoMediaIds: photos,
    );
    ledger
      .._counted('edit text')
      .._wrote(entry.id, line);
  }

  Future<void> _setMood(SimulatedDevice device) async {
    final String date = _date();
    final domain.Mood mood =
        scenarioMoods[random.nextInt(scenarioMoods.length)];
    await device.journal.setMoodForDate(date: date, mood: mood);
    ledger._counted('set mood');
    await _observeDay(device, date);
  }

  Future<void> _clearMood(SimulatedDevice device) async {
    final List<Day> live = await _liveDays(device);
    if (live.isEmpty) {
      return _setMood(device);
    }
    final List<Day> moody = <Day>[
      for (final Day day in live)
        if (day.moodId != null) day,
    ];
    final List<Day> candidates = moody.isEmpty ? live : moody;
    final Day day = candidates[random.nextInt(candidates.length)];
    await device.journal.setMoodForDate(date: day.date, mood: null);
    ledger._counted('clear mood');
    await _observeDay(device, day.date);
  }

  Future<void> _changeWeekStart(SimulatedDevice device) async {
    final WeekStart value =
        WeekStart.values[random.nextInt(WeekStart.values.length)];
    await device.settings.setWeekStart(value);
    ledger._counted('change week start');
    final JournalSetting row = await (device.database.select(
      device.database.journalSettings,
    )..where((t) => t.key.equals(SettingsKeys.weekStart))).getSingle();
    ledger._observedWeekStart(row);
  }

  Future<void> _deleteEntry(SimulatedDevice device) async {
    final List<Entry> candidates = await _visibleEntries(
      device,
      textOnly: false,
    );
    if (candidates.isEmpty) {
      return _createText(device);
    }
    final Entry entry = candidates[random.nextInt(candidates.length)];
    await device.journal.softDeleteEntry(entry.id);
    ledger
      .._counted('delete entry')
      .._deleted.add(entry.id);
  }

  Future<void> _deleteDay(SimulatedDevice device) async {
    final List<Day> live = await _liveDays(device);
    if (live.isEmpty) {
      return _setMood(device);
    }
    final Day day = live[random.nextInt(live.length)];
    await device.journal.softDeleteDay(day.id);
    ledger._counted('delete day');
    await _observeDay(device, day.date);
  }

  void _recordCreated(String entryId, String date, List<String> lines) {
    ledger._createdEntry(entryId, date);
    for (final String line in lines) {
      ledger._wrote(entryId, line);
    }
  }

  Future<void> _observeDay(SimulatedDevice device, String date) async {
    final Day row = await (device.database.select(
      device.database.days,
    )..where((t) => t.id.equals(dayIdForDate(date)))).getSingle();
    ledger._observedDay(row);
  }

  Future<List<Day>> _liveDays(SimulatedDevice device) =>
      (device.database.select(device.database.days)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy(<OrderClauseGenerator<$DaysTable>>[
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  Future<List<Entry>> _visibleEntries(
    SimulatedDevice device, {
    required bool textOnly,
  }) async {
    final Set<String> liveDays = <String>{
      for (final Day day in await _liveDays(device)) day.id,
    };
    final List<Entry> entries =
        await (device.database.select(device.database.entries)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy(<OrderClauseGenerator<$EntriesTable>>[
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return List<Entry>.unmodifiable(<Entry>[
      for (final Entry entry in entries)
        if (liveDays.contains(entry.dayId) &&
            (!textOnly || entry.type == domain.EntryType.text.id))
          entry,
    ]);
  }
}

final class OfflineEditRun {
  OfflineEditRun._({
    required this.relay,
    required this.devices,
    required this.ledger,
  });

  static const List<String> deviceNames = <String>[
    'Studio Mac of Ada',
    'Pocket Phone of Ada',
    'Kitchen Tablet of Ada',
  ];

  static const List<Duration> clockSkews = <Duration>[
    Duration.zero,
    Duration(seconds: 45),
    Duration(seconds: -45),
  ];

  static Future<OfflineEditRun> play(
    RelayFixture relay, {
    required int seed,
    required int operationsPerDevice,
    required int rounds,
  }) async {
    if (rounds <= 0 || operationsPerDevice % rounds != 0) {
      throw ArgumentError.value(
        rounds,
        'rounds',
        'Must divide the $operationsPerDevice operations per device evenly',
      );
    }
    final Random random = Random(seed);
    final List<SimulatedDevice> devices = <SimulatedDevice>[];
    final OfflineEditRun run = OfflineEditRun._(
      relay: relay,
      devices: devices,
      ledger: JournalLedger(),
    );
    try {
      for (int index = 0; index < deviceNames.length; index++) {
        devices.add(
          await SimulatedDevice.create(
            deviceNames[index],
            wallClock: skewedWallClock(clockSkews[index]),
          ),
        );
      }
      await devices.first.enrol(relay);
      for (final SimulatedDevice device in devices.skip(1)) {
        await device.pairWith(devices.first, relay);
      }
      await settle(relay, devices);
      final RandomActivity activity = RandomActivity(random, run.ledger);
      final int perRound = operationsPerDevice ~/ rounds;
      for (int round = 0; round < rounds; round++) {
        for (final SimulatedDevice device in devices) {
          device.goOffline();
        }
        final List<SimulatedDevice> turns = <SimulatedDevice>[
          for (final SimulatedDevice device in devices)
            for (int turn = 0; turn < perRound; turn++) device,
        ]..shuffle(random);
        for (final SimulatedDevice device in turns) {
          await activity.step(device);
        }
        final List<SimulatedDevice> order = <SimulatedDevice>[...devices]
          ..shuffle(random);
        for (final SimulatedDevice device in order) {
          device.goOnline();
          if (random.nextBool()) {
            await _waitForPush(device);
          }
        }
        await settle(relay, devices);
      }
      return run;
    } on Object {
      await run.dispose();
      rethrow;
    }
  }

  final RelayFixture relay;
  final List<SimulatedDevice> devices;
  final JournalLedger ledger;

  Future<void> dispose() async {
    for (final SimulatedDevice device in devices) {
      await device.dispose();
    }
  }
}
