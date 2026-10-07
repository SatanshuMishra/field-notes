import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/crypto/record_cipher.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/merge/record_reader.dart';
import 'package:field_notes/data/sync/merge/record_state.dart';
import 'package:field_notes/data/sync/merge/state_applier.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:sync_protocol/sync_protocol.dart' as protocol show RecordState;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

const String _textField = 'textContent';
const String _versionField = 'textVersion';

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

int _jsonLength(Map<String, Object?> json) =>
    utf8.encode(jsonEncode(json)).length;

final class PushBatch {
  PushBatch({required this.request, required List<int> outboxIds})
    : outboxIds = List<int>.unmodifiable(outboxIds);

  final PushRequest request;
  final List<int> outboxIds;
}

final class PushApplied {
  PushApplied({
    required this.acknowledged,
    required Set<int> stale,
    required Set<int> staleEpoch,
  }) : stale = Set<int>.unmodifiable(stale),
       staleEpoch = Set<int>.unmodifiable(staleEpoch);

  final int acknowledged;
  final Set<int> stale;
  final Set<int> staleEpoch;
}

const int outboxPageRows = 1000;

final class PushCycle {
  PushCycle({
    required AppDatabase database,
    required this._applier,
    required this._keys,
    required this._refreshKeys,
    this.maxChanges = maxPushChanges,
    this.maxBodyBytes = maxPushBodyBytes,
    this.maxEnvelope = maxEnvelopeBytes,
    Random? random,
    int Function()? wallClock,
  }) : _db = database,
       _reader = RecordReader(database),
       _random = random ?? Random.secure(),
       _wallClock = wallClock ?? _systemMillis;

  final AppDatabase _db;
  final StateApplier _applier;
  final RecordReader _reader;
  final JournalKeysSource _keys;
  final JournalKeysSource _refreshKeys;
  final int maxChanges;
  final int maxBodyBytes;
  final int maxEnvelope;
  final Random _random;
  final int Function() _wallClock;
  final Set<int> _oversized = <int>{};

  Set<int> get oversized => Set<int>.unmodifiable(_oversized);

  Future<int> pendingCount() async {
    final Expression<int> count = _db.syncOutbox.id.count();
    final TypedResult row = await (_db.selectOnly(
      _db.syncOutbox,
    )..addColumns(<Expression<Object>>[count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<PushBatch?> buildBatch({Set<int> excluding = const <int>{}}) async {
    final JournalKeys keys = await _keys();
    final KeyedNames names = KeyedNames(keys);
    final List<RecordPush> changes = <RecordPush>[];
    final List<int> outboxIds = <int>[];
    int bodyBytes = _jsonLength(
      PushRequest(changes: const <RecordPush>[]).toJson(),
    );
    int? after;
    bool full = false;
    while (!full) {
      final List<int> page = await _outboxPage(after);
      if (page.isEmpty) {
        break;
      }
      after = page.last;
      for (final int id in page) {
        if (changes.length >= maxChanges) {
          full = true;
          break;
        }
        if (excluding.contains(id) || _oversized.contains(id)) {
          continue;
        }
        final RecordPush? change = await _prepare(id, keys, names);
        if (change == null) {
          continue;
        }
        if (change.envelope.length > maxEnvelope) {
          _oversized.add(id);
          continue;
        }
        final int changeBytes =
            _jsonLength(change.toJson()) + (changes.isEmpty ? 0 : 1);
        if (bodyBytes + changeBytes > maxBodyBytes) {
          if (changes.isEmpty) {
            continue;
          }
          full = true;
          break;
        }
        changes.add(change);
        outboxIds.add(id);
        bodyBytes += changeBytes;
      }
    }
    return changes.isEmpty
        ? null
        : PushBatch(
            request: PushRequest(changes: changes),
            outboxIds: outboxIds,
          );
  }

  Future<PushRequest?> buildRequest({
    Set<int> excluding = const <int>{},
  }) async => (await buildBatch(excluding: excluding))?.request;

  Future<PushApplied> applyResponse(
    PushRequest request,
    PushResponse response, {
    FenceCheck isCurrent = alwaysCurrent,
  }) async {
    final Map<String, RecordPush> sent = <String, RecordPush>{
      for (final RecordPush change in request.changes) change.changeId: change,
    };
    JournalKeys keys = await _keys();
    bool refreshed = false;
    int acknowledged = 0;
    final Set<int> stale = <int>{};
    final Set<int> staleEpoch = <int>{};
    for (final RecordPushResult result in response.results) {
      if (!isCurrent()) {
        break;
      }
      final RecordPush? change = sent[result.changeId];
      if (change == null) {
        continue;
      }
      final RecordState pushed;
      try {
        pushed = await _openPushed(keys, change);
      } on CryptoException {
        continue;
      }
      switch (result.status) {
        case PushStatus.accepted:
        case PushStatus.duplicate:
          final int? seq = result.seq;
          if (seq == null) {
            continue;
          }
          await _acknowledge(change, pushed, seq);
          acknowledged += 1;
        case PushStatus.stale:
          final int? outboxId = await _outboxIdOf(pushed);
          if (outboxId != null) {
            stale.add(outboxId);
          }
          final protocol.RecordState? current = result.current;
          if (current == null) {
            continue;
          }
          if (!refreshed && !keys.hasEpoch(current.epoch)) {
            refreshed = true;
            keys = await _refreshKeys();
          }
          await _mergeCurrent(keys, current, isCurrent);
        case PushStatus.staleEpoch:
          final int? outboxId = await _outboxIdOf(pushed);
          if (outboxId != null) {
            staleEpoch.add(outboxId);
          }
      }
    }
    return PushApplied(
      acknowledged: acknowledged,
      stale: stale,
      staleEpoch: staleEpoch,
    );
  }

  Future<List<int>> _outboxPage(int? after) async {
    final Expression<int> id = _db.syncOutbox.id;
    final List<TypedResult> rows =
        await (_db.selectOnly(_db.syncOutbox)
              ..addColumns(<Expression<Object>>[id])
              ..where(
                after == null
                    ? const Constant<bool>(true)
                    : id.isBiggerThanValue(after),
              )
              ..orderBy(<OrderingTerm>[OrderingTerm.asc(id)])
              ..limit(outboxPageRows))
            .get();
    return <int>[for (final TypedResult row in rows) ?row.read(id)];
  }

  Future<RecordPush?> _prepare(
    int outboxId,
    JournalKeys keys,
    KeyedNames names,
  ) => _db.transaction(() async {
    final SyncOutboxData? row = await (_db.select(
      _db.syncOutbox,
    )..where((t) => t.id.equals(outboxId))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    final RecordState? state = await _reader.read(row.recordTable, row.rowId);
    if (state == null) {
      await (_db.delete(
        _db.syncOutbox,
      )..where((t) => t.id.equals(outboxId))).go();
      return null;
    }
    final Uint8List plain = utf8.encode(jsonEncode(state.toJson()));
    if (plain.length > maxEnvelope) {
      _oversized.add(outboxId);
      return null;
    }
    final String changeId = row.changeId ?? newSyncId(_random);
    if (row.changeId == null) {
      await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(outboxId)))
          .write(SyncOutboxCompanion(changeId: Value(changeId)));
    }
    final String recordKey = names.recordKey(row.recordTable, row.rowId);
    final SyncRecordSeq? base = await (_db.select(
      _db.syncRecordSeqs,
    )..where((t) => t.recordKey.equals(recordKey))).getSingleOrNull();
    return RecordPush(
      recordKey: recordKey,
      baseSeq: base?.seq ?? 0,
      changeId: changeId,
      epoch: keys.currentEpoch,
      envelope: RecordCipher(keys).seal(plain, recordKey, keys.currentEpoch),
    );
  });

  Future<RecordState> _openPushed(JournalKeys keys, RecordPush change) async {
    final protocol.RecordState state = protocol.RecordState(
      recordKey: change.recordKey,
      seq: 0,
      epoch: change.epoch,
      envelope: change.envelope,
    );
    if (keys.hasEpoch(change.epoch)) {
      return openRecordState(keys, state);
    }
    return openRecordState(await _refreshKeys(), state);
  }

  Future<void> _acknowledge(RecordPush change, RecordState pushed, int seq) =>
      _db.transaction(() async {
        await (_db.delete(_db.syncOutbox)..where(
              (t) =>
                  t.recordTable.equals(pushed.table) &
                  t.rowId.equals(pushed.rowId) &
                  t.changeId.equals(change.changeId),
            ))
            .go();
        await storeRecordSeq(
          _db,
          recordKey: change.recordKey,
          table: pushed.table,
          rowId: pushed.rowId,
          seq: seq,
        );
        final Object? text = pushed.fields[_textField];
        final Object? version = pushed.fields[_versionField];
        final String? clock = pushed.clocks[_textField];
        if (pushed.table == SyncedTables.entries &&
            text is String &&
            version is String &&
            clock != null) {
          await _db
              .into(_db.syncTextBases)
              .insertOnConflictUpdate(
                SyncTextBasesCompanion.insert(
                  entryId: pushed.rowId,
                  textContent: text,
                  clock: clock,
                  version: version,
                ),
              );
        }
      });

  Future<void> _mergeCurrent(
    JournalKeys keys,
    protocol.RecordState current,
    FenceCheck isCurrent,
  ) async {
    final RecordState opened;
    try {
      opened = openRecordState(keys, current);
    } on CryptoException {
      return;
    }
    if (!isCurrent()) {
      return;
    }
    try {
      await applyRemoteState(
        _db,
        _applier,
        recordKey: current.recordKey,
        seq: current.seq,
        state: opened,
        now: _wallClock(),
        isCurrent: isCurrent,
      );
    } on FormatException {
      return;
    }
  }

  Future<int?> _outboxIdOf(RecordState pushed) async {
    final SyncOutboxData? row =
        await (_db.select(_db.syncOutbox)..where(
              (t) =>
                  t.recordTable.equals(pushed.table) &
                  t.rowId.equals(pushed.rowId),
            ))
            .getSingleOrNull();
    return row?.id;
  }
}
