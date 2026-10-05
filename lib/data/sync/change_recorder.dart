import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/hlc.dart';

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

class ChangeRecorder {
  ChangeRecorder(this._db, {int Function()? wallClock})
    : _wallClock = wallClock ?? _systemMillis;

  static const String nodeIdKey = 'node_id';
  static const String lastClockKey = 'hlc_last';
  static const int _nodeIdBytes = 8;

  final AppDatabase _db;
  final int Function() _wallClock;
  HlcClock? _clock;
  String? _nodeId;

  String get nodeId {
    final String? id = _nodeId;
    if (id == null) {
      throw StateError('The change recorder has not stamped or received yet.');
    }
    return id;
  }

  Future<String> stamp({
    required String table,
    required String rowId,
    required Iterable<String> fields,
    required String currentClocks,
  }) async {
    final HlcClock clock = await _loadedClock();
    final String stamped = clock.now().encode();
    final SplayTreeMap<String, String> clocks = SplayTreeMap<String, String>.of(
      <String, String>{
        ..._decodeFieldClocks(currentClocks),
        for (final String field in fields) field: stamped,
      },
    );
    await _storeLast(clock.last);
    await _enqueue(table: table, rowId: rowId);
    return jsonEncode(clocks);
  }

  Future<HlcReceipt> receive(Hlc remote) async {
    final HlcClock clock = await _loadedClock();
    final HlcReceipt receipt = clock.receive(remote);
    if (receipt == HlcReceipt.accepted) {
      await _storeLast(clock.last);
    }
    return receipt;
  }

  Future<HlcClock> _loadedClock() async {
    final HlcClock? loaded = _clock;
    if (loaded != null) {
      return loaded;
    }
    final String nodeId = await _readState(nodeIdKey) ?? _newNodeId();
    final String? last = await _readState(lastClockKey);
    final HlcClock clock = HlcClock(
      nodeId: nodeId,
      last: last == null ? null : Hlc.parse(last),
      wallClock: _wallClock,
    );
    _nodeId = nodeId;
    _clock = clock;
    return clock;
  }

  Future<String?> _readState(String key) async {
    final SyncState? row = await (_db.select(
      _db.syncStates,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _storeLast(Hlc last) async {
    await _db
        .into(_db.syncStates)
        .insert(
          SyncStatesCompanion.insert(key: nodeIdKey, value: nodeId),
          mode: InsertMode.insertOrIgnore,
        );
    await _db
        .into(_db.syncStates)
        .insertOnConflictUpdate(
          SyncStatesCompanion.insert(key: lastClockKey, value: last.encode()),
        );
  }

  Future<void> _enqueue({required String table, required String rowId}) async {
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            recordTable: table,
            rowId: rowId,
            enqueuedAt: _wallClock(),
          ),
          onConflict: DoUpdate(
            (_) => const SyncOutboxCompanion(changeId: Value(null)),
            target: <Column<Object>>[
              _db.syncOutbox.recordTable,
              _db.syncOutbox.rowId,
            ],
          ),
        );
  }

  String _newNodeId() {
    final Random random = Random.secure();
    return List<String>.generate(
      _nodeIdBytes,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

Map<String, String> _decodeFieldClocks(String encoded) {
  final Object? decoded = jsonDecode(encoded);
  if (decoded is! Map<String, Object?> ||
      decoded.values.any((Object? value) => value is! String)) {
    throw FormatException(
      'Field clocks are not a JSON object of encoded clocks.',
      encoded,
    );
  }
  return decoded.cast<String, String>();
}
