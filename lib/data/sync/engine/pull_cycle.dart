import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/crypto/record_cipher.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/merge/record_state.dart';
import 'package:field_notes/data/sync/merge/state_applier.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:sync_protocol/sync_protocol.dart' as protocol show RecordState;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

const String pullCursorKey = 'pull_cursor';
const String pullCompleteKey = 'pull_complete';
const String firstPullDoneKey = 'first_pull_done';
const String pullCompleteValue = 'true';
const String pullIncompleteValue = 'false';
const Duration pullApplyBudget = Duration(milliseconds: 100);

typedef JournalKeysSource = Future<JournalKeys> Function();

typedef FenceCheck = bool Function();

bool alwaysCurrent() => true;

JournalKeysSource journalKeysFrom(KeyStore keyStore) => () async {
  final JournalKeys? keys = await keyStore.readJournalKeys();
  if (keys == null) {
    throw StateError('This device holds no journal keys');
  }
  return keys;
};

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

Uint8List sealRecordState(
  JournalKeys keys,
  RecordState state,
  String recordKey,
  int epoch,
) =>
    RecordCipher(keys)
        .seal(utf8.encode(jsonEncode(state.toJson())), recordKey, epoch);

RecordState openRecordState(JournalKeys keys, protocol.RecordState state) {
  final Uint8List plain = RecordCipher(keys)
      .open(state.envelope, state.recordKey, state.epoch);
  final RecordState opened;
  try {
    opened = RecordState.fromJson(decodeJsonObject(utf8.decode(plain)));
  } on FormatException catch (error) {
    throw CryptoException('The record does not hold a record state', error);
  }
  if (KeyedNames(keys).recordKey(opened.table, opened.rowId) !=
      state.recordKey) {
    throw const CryptoException('The record belongs to another record key');
  }
  return opened;
}

Future<int> readPullCursor(AppDatabase database) async =>
    int.tryParse(await readSyncState(database, pullCursorKey) ?? '') ?? 0;

Future<bool> pullHasCompleted(AppDatabase database) async =>
    await readSyncState(database, pullCompleteKey) == pullCompleteValue;

Future<bool> firstPullHasCompleted(AppDatabase database) async =>
    await readSyncState(database, firstPullDoneKey) == pullCompleteValue;

Future<void> storeRecordSeq(
  AppDatabase database, {
  required String recordKey,
  required String table,
  required String rowId,
  required int seq,
}) async {
  final SyncRecordSeq? stored = await (database.select(
    database.syncRecordSeqs,
  )..where((t) => t.recordKey.equals(recordKey))).getSingleOrNull();
  if (stored != null && stored.seq >= seq) {
    return;
  }
  await database
      .into(database.syncRecordSeqs)
      .insertOnConflictUpdate(
        SyncRecordSeqsCompanion.insert(
          recordKey: recordKey,
          recordTable: table,
          rowId: rowId,
          seq: seq,
        ),
      );
}

Future<void> holdRecordState(
  AppDatabase database, {
  required String recordKey,
  required int seq,
  required RecordState state,
  required int heldAt,
}) => database
    .into(database.syncHeldStates)
    .insertOnConflictUpdate(
      SyncHeldStatesCompanion.insert(
        recordKey: recordKey,
        stateJson: jsonEncode(<String, Object?>{
          'seq': seq,
          'state': state.toJson(),
        }),
        heldAt: heldAt,
      ),
    );

Future<ApplyOutcome> applyRemoteState(
  AppDatabase database,
  StateApplier applier, {
  required String recordKey,
  required int seq,
  required RecordState state,
  required int now,
  FenceCheck isCurrent = alwaysCurrent,
}) async {
  final ApplyOutcome outcome = await applier.apply(state);
  if (!isCurrent()) {
    return outcome;
  }
  if (outcome == ApplyOutcome.heldBack) {
    await holdRecordState(
      database,
      recordKey: recordKey,
      seq: seq,
      state: state,
      heldAt: now,
    );
  } else {
    await storeRecordSeq(
      database,
      recordKey: recordKey,
      table: state.table,
      rowId: state.rowId,
      seq: seq,
    );
  }
  return outcome;
}

final class PullPage {
  const PullPage({
    required this.received,
    required this.remaining,
    required this.hasMore,
  });

  final int received;
  final int remaining;
  final bool hasMore;

  int get total => received + remaining;
}

final class PullResult {
  const PullResult({
    required this.complete,
    required this.received,
    required this.dropped,
  });

  final bool complete;
  final int received;
  final bool dropped;
}

final class PullCycle {
  PullCycle({
    required AppDatabase database,
    required this._applier,
    required this._keys,
    required this._refreshKeys,
    this.pageSize,
    int Function()? wallClock,
  }) : _db = database,
       _wallClock = wallClock ?? _systemMillis;

  final AppDatabase _db;
  final StateApplier _applier;
  final JournalKeysSource _keys;
  final JournalKeysSource _refreshKeys;
  final int? pageSize;
  final int Function() _wallClock;

  Future<int> retryHeld({FenceCheck isCurrent = alwaysCurrent}) async {
    final List<SyncHeldState> held = await _db.select(_db.syncHeldStates).get();
    int stillHeld = 0;
    for (final SyncHeldState row in held) {
      if (!isCurrent()) {
        return held.length;
      }
      final Map<String, Object?> json = decodeJsonObject(row.stateJson);
      final Object? seq = json['seq'];
      final Object? state = json['state'];
      if (seq is! int || state is! Map<String, Object?>) {
        await _dropHeld(row.recordKey);
        continue;
      }
      final RecordState remote = RecordState.fromJson(state);
      final ApplyOutcome outcome;
      try {
        outcome = await _applier.apply(remote);
      } on FormatException {
        await _dropHeld(row.recordKey);
        continue;
      }
      if (outcome == ApplyOutcome.heldBack) {
        stillHeld += 1;
        continue;
      }
      if (!isCurrent()) {
        return held.length;
      }
      await _db.transaction(() async {
        await _dropHeld(row.recordKey);
        await storeRecordSeq(
          _db,
          recordKey: row.recordKey,
          table: remote.table,
          rowId: remote.rowId,
          seq: seq,
        );
      });
    }
    return stillHeld;
  }

  Future<PullResult> run(
    RelayClient client, {
    Future<bool> Function(PullResponse response, int cursor)? onResponse,
    void Function(PullPage page)? onPage,
    FenceCheck mayContinue = alwaysCurrent,
    FenceCheck isCurrent = alwaysCurrent,
  }) async {
    bool refreshed = false;
    int received = 0;
    while (mayContinue() && isCurrent()) {
      final int cursor = await readPullCursor(_db);
      final PullResponse response = await client.pull(
        after: cursor,
        limit: pageSize,
      );
      if (!isCurrent() ||
          (onResponse != null && !await onResponse(response, cursor)) ||
          !isCurrent()) {
        return PullResult(complete: false, received: received, dropped: true);
      }
      JournalKeys keys = await _keys();
      if (!refreshed &&
          response.states.any(
            (protocol.RecordState state) => !keys.hasEpoch(state.epoch),
          )) {
        refreshed = true;
        keys = await _refreshKeys();
      }
      final List<protocol.RecordState> states = response.states;
      int applied = 0;
      while (applied < states.length) {
        final int from = applied;
        applied = await _db.transaction(() async {
          final Stopwatch spent = Stopwatch()..start();
          int next = from;
          while (next < states.length &&
              (next == from || spent.elapsed < pullApplyBudget)) {
            await _receive(keys, states[next], isCurrent);
            next += 1;
            if (!isCurrent()) {
              break;
            }
          }
          return next;
        });
        if (!isCurrent()) {
          return PullResult(complete: false, received: received, dropped: true);
        }
      }
      final int last = states.fold(
        cursor,
        (int highest, protocol.RecordState state) => max(highest, state.seq),
      );
      received += response.states.length;
      if (!isCurrent()) {
        return PullResult(complete: false, received: received, dropped: true);
      }
      await writeSyncState(_db, pullCursorKey, '$last');
      onPage?.call(
        PullPage(
          received: received,
          remaining: response.remaining,
          hasMore: response.hasMore,
        ),
      );
      if (!response.hasMore) {
        await writeSyncState(_db, pullCompleteKey, pullCompleteValue);
        await writeSyncState(_db, firstPullDoneKey, pullCompleteValue);
        return PullResult(complete: true, received: received, dropped: false);
      }
      await writeSyncState(_db, pullCompleteKey, pullIncompleteValue);
    }
    return PullResult(complete: false, received: received, dropped: false);
  }

  Future<void> _receive(
    JournalKeys keys,
    protocol.RecordState state,
    FenceCheck isCurrent,
  ) async {
    final RecordState opened;
    try {
      opened = openRecordState(keys, state);
    } on CryptoException {
      return;
    }
    try {
      await applyRemoteState(
        _db,
        _applier,
        recordKey: state.recordKey,
        seq: state.seq,
        state: opened,
        now: _wallClock(),
        isCurrent: isCurrent,
      );
    } on FormatException {
      return;
    } on ArgumentError {
      return;
    }
  }

  Future<void> _dropHeld(String recordKey) => (_db.delete(
    _db.syncHeldStates,
  )..where((t) => t.recordKey.equals(recordKey))).go();
}
