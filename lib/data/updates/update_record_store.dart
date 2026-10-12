import 'dart:convert';

import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/settings_keys.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_record_store.g.dart';

class UpdateRecord {
  const UpdateRecord({
    this.lastCheckedAt,
    this.lastAvailable,
    this.lastSeenVersion,
  });

  static const UpdateRecord empty = UpdateRecord();

  final DateTime? lastCheckedAt;
  final ReleaseInfo? lastAvailable;
  final String? lastSeenVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateRecord &&
          lastCheckedAt == other.lastCheckedAt &&
          lastAvailable == other.lastAvailable &&
          lastSeenVersion == other.lastSeenVersion;

  @override
  int get hashCode =>
      Object.hash(lastCheckedAt, lastAvailable, lastSeenVersion);

  @override
  String toString() =>
      'UpdateRecord(lastCheckedAt: ${lastCheckedAt?.toIso8601String()}, '
      'lastAvailable: $lastAvailable, lastSeenVersion: $lastSeenVersion)';
}

abstract interface class UpdateRecordStore {
  Future<UpdateRecord> read();

  Future<void> recordCheck(DateTime at, ReleaseInfo? available);

  Future<void> recordAttempt(DateTime at);

  Future<void> recordSeenVersion(String version);
}

class DriftUpdateRecordStore implements UpdateRecordStore {
  DriftUpdateRecordStore(this._db);

  final AppDatabase _db;

  static const List<String> _keys = <String>[
    SettingsKeys.updateLastCheckedAt,
    SettingsKeys.updateLastAvailable,
    SettingsKeys.updateLastSeenVersion,
  ];

  @override
  Future<UpdateRecord> read() async {
    final List<Setting> rows = await (_db.select(
      _db.settings,
    )..where(($SettingsTable t) => t.key.isIn(_keys))).get();
    final Map<String, String> values = <String, String>{
      for (final Setting row in rows) row.key: row.value,
    };
    return UpdateRecord(
      lastCheckedAt: _decodeTime(values[SettingsKeys.updateLastCheckedAt]),
      lastAvailable: _decodeRelease(values[SettingsKeys.updateLastAvailable]),
      lastSeenVersion: _decodeVersion(
        values[SettingsKeys.updateLastSeenVersion],
      ),
    );
  }

  @override
  Future<void> recordCheck(DateTime at, ReleaseInfo? available) {
    return _db.transaction(() async {
      await _put(SettingsKeys.updateLastCheckedAt, _encodeTime(at));
      if (available == null) {
        await (_db.delete(_db.settings)..where(
              ($SettingsTable t) =>
                  t.key.equals(SettingsKeys.updateLastAvailable),
            ))
            .go();
      } else {
        await _put(
          SettingsKeys.updateLastAvailable,
          jsonEncode(available.toJson()),
        );
      }
    });
  }

  @override
  Future<void> recordAttempt(DateTime at) =>
      _put(SettingsKeys.updateLastCheckedAt, _encodeTime(at));

  @override
  Future<void> recordSeenVersion(String version) =>
      _put(SettingsKeys.updateLastSeenVersion, version);

  Future<void> _put(String key, String value) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value),
        );
  }

  String _encodeTime(DateTime at) => at.toUtc().toIso8601String();

  DateTime? _decodeTime(String? raw) {
    if (raw == null) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != raw) {
      return null;
    }
    return parsed;
  }

  ReleaseInfo? _decodeRelease(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      return ReleaseInfo.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  String? _decodeVersion(String? raw) {
    if (raw == null || AppVersion.tryParse(raw) == null) {
      return null;
    }
    return raw;
  }
}

class MemoryUpdateRecordStore implements UpdateRecordStore {
  MemoryUpdateRecordStore([UpdateRecord initial = UpdateRecord.empty])
    : _record = initial;

  UpdateRecord _record;

  UpdateRecord get record => _record;

  @override
  Future<UpdateRecord> read() async => _record;

  @override
  Future<void> recordCheck(DateTime at, ReleaseInfo? available) async {
    _record = UpdateRecord(
      lastCheckedAt: at.toUtc(),
      lastAvailable: available,
      lastSeenVersion: _record.lastSeenVersion,
    );
  }

  @override
  Future<void> recordAttempt(DateTime at) async {
    _record = UpdateRecord(
      lastCheckedAt: at.toUtc(),
      lastAvailable: _record.lastAvailable,
      lastSeenVersion: _record.lastSeenVersion,
    );
  }

  @override
  Future<void> recordSeenVersion(String version) async {
    _record = UpdateRecord(
      lastCheckedAt: _record.lastCheckedAt,
      lastAvailable: _record.lastAvailable,
      lastSeenVersion: version,
    );
  }
}

@Riverpod(keepAlive: true)
UpdateRecordStore updateRecordStore(Ref ref) {
  return DriftUpdateRecordStore(ref.watch(databaseProvider));
}
