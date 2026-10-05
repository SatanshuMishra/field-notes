import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/database/ids.dart';
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/data/sync/merge/record_reader.dart';
import 'package:field_notes/data/sync/merge/record_state.dart';
import 'package:field_notes/data/sync/merge/text_merge.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/entry_type.dart';
import 'package:field_notes/domain/models/media_kind.dart';

enum ApplyOutcome { applied, heldBack }

const String _textField = 'textContent';
const String _versionField = 'textVersion';
const String _updatedField = 'updatedAt';
const String _deletedField = 'deletedAt';
const String _dayField = 'dayId';
const String _clocksColumn = 'fieldClocks';
const String _relPathColumn = 'relPath';
const String _emptyClocks = '{}';
const List<String> _textFields = <String>[_textField, _versionField];
const List<String> _mergedTextFields = <String>[
  _textField,
  _versionField,
  _updatedField,
];

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

class StateApplier {
  StateApplier({
    required AppDatabase database,
    required this._recorder,
    required this._localDeviceName,
    int Function()? wallClock,
  }) : _db = database,
       _reader = RecordReader(database),
       _wallClock = wallClock ?? _systemMillis;

  final AppDatabase _db;
  final ChangeRecorder _recorder;
  final String _localDeviceName;
  final RecordReader _reader;
  final int Function() _wallClock;

  Future<ApplyOutcome> apply(RecordState remote) async {
    final List<String> names = _checkedFields(remote);
    final List<Hlc> remoteClocks = remote.clocks.values.map(Hlc.parse).toList();
    return _db.transaction(() async {
      if (remoteClocks.isNotEmpty &&
          await _recorder.receive(remoteClocks.reduce(_newer)) ==
              HlcReceipt.heldBack) {
        return ApplyOutcome.heldBack;
      }
      final RecordState? local = await _reader.read(remote.table, remote.rowId);
      final RecordState newest = _newestFields(local, remote, names);
      if (remote.table == SyncedTables.entries) {
        await _applyEntry(local, remote, newest);
      } else {
        await _store(local, newest);
      }
      return ApplyOutcome.applied;
    });
  }

  Future<void> _applyEntry(
    RecordState? local,
    RecordState remote,
    RecordState newest,
  ) async {
    if (local == null) {
      await _store(null, newest);
      await _storeBase(remote);
      return;
    }
    final _TextVersion localVersion = _TextVersion.decode(
      local.fields[_versionField],
    );
    final _TextVersion remoteVersion = _TextVersion.decode(
      remote.fields[_versionField],
    );
    if (localVersion.includes(remoteVersion)) {
      await _store(local, _textFrom(local, newest));
    } else if (remoteVersion.includes(localVersion)) {
      await _store(local, _textFrom(remote, newest));
    } else {
      await _applyConcurrentText(
        local: local,
        remote: remote,
        newest: newest,
        localVersion: localVersion,
        remoteVersion: remoteVersion,
      );
    }
    await _storeBase(remote);
  }

  Future<void> _applyConcurrentText({
    required RecordState local,
    required RecordState remote,
    required RecordState newest,
    required _TextVersion localVersion,
    required _TextVersion remoteVersion,
  }) async {
    final RecordState kept = _withText(
      newest,
      text: remote.fields[_textField],
      version: localVersion
          .union(remoteVersion)
          .raisedFor(_recorder.nodeId)
          .encode(),
      clocks: <String, String>{
        for (final String field in _textFields)
          if (_newerClock(local.clocks[field], remote.clocks[field])
              case final String clock)
            field: clock,
      },
    );
    if (newest.fields[_deletedField] != null) {
      await _store(local, kept);
      return;
    }
    final Object? localText = local.fields[_textField];
    final TextMergeResult result = await _mergedText(
      entryId: remote.rowId,
      local: localText,
      remote: remote.fields[_textField],
      versions: <_TextVersion>[localVersion, remoteVersion],
    );
    switch (result) {
      case MergedText(:final String text):
        final String clocks = await _recorder.stamp(
          table: SyncedTables.entries,
          rowId: remote.rowId,
          fields: _mergedTextFields,
          currentClocks: _encodeClocks(kept.clocks),
        );
        await _store(
          local,
          RecordState(
            table: kept.table,
            rowId: kept.rowId,
            fields: <String, Object?>{
              ...kept.fields,
              _textField: text,
              _updatedField: _wallClock(),
            },
            clocks: decodeFieldClocks(clocks),
          ),
        );
      case TextConflict():
        await _store(local, kept);
        if (localText is String) {
          await _insertConflictCopy(
            dayId: kept.fields[_dayField]! as String,
            text: localText,
          );
        }
    }
  }

  Future<TextMergeResult> _mergedText({
    required String entryId,
    required Object? local,
    required Object? remote,
    required List<_TextVersion> versions,
  }) async {
    final SyncTextBase? base = await (_db.select(
      _db.syncTextBases,
    )..where((t) => t.entryId.equals(entryId))).getSingleOrNull();
    if (base == null || local is! String || remote is! String) {
      return const TextMergeResult.conflict();
    }
    final _TextVersion baseVersion = _TextVersion.decode(base.version);
    if (!versions.every(
      (_TextVersion version) => version.includes(baseVersion),
    )) {
      return const TextMergeResult.conflict();
    }
    return merge(base: base.textContent, local: local, remote: remote);
  }

  Future<void> _insertConflictCopy({
    required String dayId,
    required String text,
  }) async {
    final String id = newId();
    final int now = _wallClock();
    final String clocks = await _recorder.stamp(
      table: SyncedTables.entries,
      rowId: id,
      fields: SyncedTables.entryFields,
      currentClocks: _emptyClocks,
    );
    await _db
        .into(_db.entries)
        .insert(
          EntriesCompanion.insert(
            id: id,
            dayId: dayId,
            type: EntryType.text.id,
            textContent: Value(text),
            createdAt: now,
            updatedAt: now,
            conflictSourceDevice: Value(_localDeviceName),
            textVersion: Value(
              _TextVersion.empty.raisedFor(_recorder.nodeId).encode(),
            ),
            fieldClocks: Value(clocks),
          ),
        );
  }

  Future<void> _storeBase(RecordState remote) async {
    final Object? text = remote.fields[_textField];
    final String? clock = remote.clocks[_textField];
    if (text is! String || clock == null) {
      return;
    }
    await _db
        .into(_db.syncTextBases)
        .insertOnConflictUpdate(
          SyncTextBasesCompanion.insert(
            entryId: remote.rowId,
            textContent: text,
            clock: clock,
            version: _TextVersion.decode(remote.fields[_versionField]).encode(),
          ),
        );
  }

  Future<void> _store(RecordState? local, RecordState merged) async {
    if (local != null && _same(local, merged)) {
      return;
    }
    final Map<String, Object?> row = <String, Object?>{
      ...merged.fields,
      _clocksColumn: _encodeClocks(merged.clocks),
    };
    switch (merged.table) {
      case SyncedTables.days:
        await _db
            .into(_db.days)
            .insertOnConflictUpdate(Day.fromJson(row).toCompanion(false));
      case SyncedTables.entries:
        await _db
            .into(_db.entries)
            .insertOnConflictUpdate(Entry.fromJson(row).toCompanion(false));
      case SyncedTables.entryPhotos:
        await _db
            .into(_db.entryPhotos)
            .insertOnConflictUpdate(
              EntryPhoto.fromJson(row).toCompanion(false),
            );
      case SyncedTables.mediaBlobs:
        final String relPath = await _relPathFor(merged);
        await _db
            .into(_db.mediaBlobs)
            .insertOnConflictUpdate(
              MediaBlob.fromJson(<String, Object?>{
                ...row,
                _relPathColumn: relPath,
              }).toCompanion(false),
            );
      case SyncedTables.journalSettings:
        await _db
            .into(_db.journalSettings)
            .insertOnConflictUpdate(
              JournalSetting.fromJson(row).toCompanion(false),
            );
    }
  }

  Future<String> _relPathFor(RecordState blob) async {
    final MediaBlob? existing = await (_db.select(
      _db.mediaBlobs,
    )..where((t) => t.id.equals(blob.rowId))).getSingleOrNull();
    if (existing != null) {
      return existing.relPath;
    }
    final Object? kindId = blob.fields['kind'];
    final MediaKind? kind = MediaKind.fromId(kindId is String ? kindId : null);
    if (kind == null) {
      throw FormatException('A media blob state names no known kind.', kindId);
    }
    return relPathForBlob(
      id: blob.rowId,
      mime: blob.fields['mime']! as String,
      kind: kind,
    );
  }
}

List<String> _checkedFields(RecordState remote) {
  final List<String>? names = SyncedTables.fields[remote.table];
  if (names == null) {
    throw ArgumentError.value(remote.table, 'remote', 'Not a synced table.');
  }
  final List<String> missing = names
      .where((String name) => !remote.fields.containsKey(name))
      .toList();
  if (missing.isNotEmpty) {
    throw FormatException(
      'A ${remote.table} state lacks ${missing.join(', ')}.',
      remote.rowId,
    );
  }
  final String keyField = remote.table == SyncedTables.journalSettings
      ? 'key'
      : 'id';
  if (remote.fields[keyField] != remote.rowId) {
    throw FormatException(
      'A ${remote.table} state names another row.',
      remote.rowId,
    );
  }
  return names;
}

RecordState _newestFields(
  RecordState? local,
  RecordState remote,
  List<String> names,
) {
  final Map<String, RecordState> sourceOf = <String, RecordState>{
    for (final String name in names)
      name: local == null || _isNewer(remote.clocks[name], local.clocks[name])
          ? remote
          : local,
  };
  return RecordState(
    table: remote.table,
    rowId: remote.rowId,
    fields: <String, Object?>{
      for (final MapEntry<String, RecordState> source in sourceOf.entries)
        source.key: source.value.fields[source.key],
    },
    clocks: <String, String>{
      for (final MapEntry<String, RecordState> source in sourceOf.entries)
        if (source.value.clocks[source.key] case final String clock)
          source.key: clock,
    },
  );
}

RecordState _textFrom(RecordState source, RecordState target) {
  return _withText(
    target,
    text: source.fields[_textField],
    version: source.fields[_versionField],
    clocks: <String, String>{
      for (final String field in _textFields)
        if (source.clocks[field] case final String clock) field: clock,
    },
  );
}

RecordState _withText(
  RecordState target, {
  required Object? text,
  required Object? version,
  required Map<String, String> clocks,
}) {
  return RecordState(
    table: target.table,
    rowId: target.rowId,
    fields: <String, Object?>{
      ...target.fields,
      _textField: text,
      _versionField: version,
    },
    clocks: <String, String>{
      for (final MapEntry<String, String> clock in target.clocks.entries)
        if (!_textFields.contains(clock.key)) clock.key: clock.value,
      ...clocks,
    },
  );
}

bool _isNewer(String? candidate, String? current) {
  if (candidate == null) {
    return false;
  }
  return current == null || Hlc.parse(candidate) > Hlc.parse(current);
}

String? _newerClock(String? a, String? b) => _isNewer(b, a) ? b : a;

Hlc _newer(Hlc a, Hlc b) => b > a ? b : a;

bool _same(RecordState a, RecordState b) {
  return _sameEntries(a.fields, b.fields) && _sameEntries(a.clocks, b.clocks);
}

bool _sameEntries<V>(Map<String, V> a, Map<String, V> b) {
  return a.length == b.length &&
      a.keys.every((String key) => b.containsKey(key) && a[key] == b[key]);
}

String _encodeClocks(Map<String, String> clocks) {
  return jsonEncode(SplayTreeMap<String, String>.of(clocks));
}

class _TextVersion {
  const _TextVersion(this._counts);

  factory _TextVersion.decode(Object? encoded) {
    final Object? decoded = encoded is String ? jsonDecode(encoded) : null;
    if (decoded is! Map<String, Object?> ||
        decoded.values.any((Object? count) => count is! int)) {
      throw FormatException(
        'A text version is not a JSON object of edit counts.',
        encoded,
      );
    }
    return _TextVersion(Map<String, int>.unmodifiable(decoded));
  }

  static const _TextVersion empty = _TextVersion(<String, int>{});

  final Map<String, int> _counts;

  int _count(String node) => _counts[node] ?? 0;

  bool includes(_TextVersion other) {
    return other._counts.entries.every(
      (MapEntry<String, int> count) => count.value <= _count(count.key),
    );
  }

  _TextVersion union(_TextVersion other) {
    return _TextVersion(<String, int>{
      for (final String node in <String>{
        ..._counts.keys,
        ...other._counts.keys,
      })
        node: max(_count(node), other._count(node)),
    });
  }

  _TextVersion raisedFor(String node) {
    return _TextVersion(<String, int>{..._counts, node: _count(node) + 1});
  }

  String encode() => jsonEncode(SplayTreeMap<String, int>.of(_counts));
}
