import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:field_notes/data/settings/settings_keys.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/data/sync/merge/record_reader.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/relay_fixture.dart';
import '../support/simulated_device.dart';

const int _seed = 4207;
const int _operationsPerDevice = 200;
const int _rounds = 4;

const List<String> _operationKinds = <String>[
  'create text',
  'create voice',
  'create photo',
  'edit text',
  'set mood',
  'clear mood',
  'change week start',
  'delete entry',
  'delete day',
];

String _newest(Iterable<String> clocks) =>
    clocks.reduce((String a, String b) => Hlc.parse(b) > Hlc.parse(a) ? b : a);

Map<String, String> _clocksOf(Map<String, Object?> row) =>
    decodeFieldClocks(row['fieldClocks']! as String);

List<String> _lines(Map<String, Object?> entry) =>
    ((entry['textContent'] as String?) ?? '').split('\n');

bool _deleted(Map<String, Object?> row) => row['deletedAt'] != null;

bool _isCopy(Map<String, Object?> entry) =>
    entry['conflictSourceDevice'] != null;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('three devices converge after random offline edits', () async {
    final RelayFixture relay = await RelayFixture.start(rateBurst: 1000);
    addTearDown(relay.dispose);
    final OfflineEditRun run = await OfflineEditRun.play(
      relay,
      seed: _seed,
      operationsPerDevice: _operationsPerDevice,
      rounds: _rounds,
    );
    addTearDown(run.dispose);
    final JournalLedger ledger = run.ledger;

    expect(
      ledger.operations.values.fold<int>(0, (int sum, int n) => sum + n),
      run.devices.length * _operationsPerDevice,
    );
    for (final String kind in _operationKinds) {
      expect(ledger.operations[kind], greaterThan(0), reason: kind);
    }

    final SyncedRows journal = await run.devices.first.syncedRows();
    for (final SimulatedDevice device in run.devices.skip(1)) {
      final SyncedRows rows = await device.syncedRows();
      for (final String table in SyncedTables.fields.keys) {
        expect(
          rows[table],
          journal[table],
          reason: '${device.name} holds a different $table table',
        );
      }
    }

    final Map<String, Map<String, Object?>> entries =
        <String, Map<String, Object?>>{
          for (final Map<String, Object?> row in journal[SyncedTables.entries]!)
            row['id']! as String: row,
        };
    final List<Map<String, Object?>> copies = <Map<String, Object?>>[
      for (final Map<String, Object?> row in entries.values)
        if (_isCopy(row)) row,
    ];
    final List<Map<String, Object?>> originals = <Map<String, Object?>>[
      for (final Map<String, Object?> row in entries.values)
        if (!_isCopy(row)) row,
    ];
    expect(ledger.createdEntries.length, greaterThan(150));
    expect(
      entries.keys,
      containsAll(ledger.createdEntries.keys),
      reason: 'an entry a device made was lost',
    );
    expect(
      <String>{
        for (final Map<String, Object?> row in originals) row['id']! as String,
      },
      ledger.createdEntries.keys.toSet(),
      reason: 'an entry exists that no device made and is no conflict copy',
    );
    expect(copies.length, lessThanOrEqualTo(ledger.textWrites.length));
    expect(
      <String>{
        for (final Map<String, Object?> row in entries.values)
          if (_deleted(row)) row['id']! as String,
      },
      ledger.deletedEntries,
      reason: 'the deleted entries are not exactly those a device deleted',
    );

    final List<Map<String, Object?>> days = journal[SyncedTables.days]!;
    expect(<String>{
      for (final Map<String, Object?> day in days) day['date']! as String,
    }, hasLength(days.length));
    expect(<String>{
      for (final Map<String, Object?> day in days) day['id']! as String,
    }, ledger.dayDeletions.keys.toSet());
    for (final Map<String, Object?> day in days) {
      final String id = day['id']! as String;
      final Map<String, String> clocks = _clocksOf(day);
      final String deletion = _newest(ledger.dayDeletions[id]!.keys);
      expect(clocks['deletedAt'], deletion, reason: '$id deletion clock');
      expect(
        _deleted(day),
        ledger.dayDeletions[id]![deletion],
        reason: 'the newest delete or revive of $id did not decide it',
      );
      final String mood = _newest(ledger.dayMoods[id]!.keys);
      expect(clocks['moodId'], mood, reason: '$id mood clock');
      expect(
        day['moodId'],
        ledger.dayMoods[id]![mood],
        reason: 'the newest mood of $id did not win',
      );
    }

    final Map<String, Object?> weekStart =
        journal[SyncedTables.journalSettings]!.singleWhere(
          (Map<String, Object?> row) => row['key'] == SettingsKeys.weekStart,
        );
    final String newestWeekStart = _newest(ledger.weekStarts.keys);
    expect(_clocksOf(weekStart)['value'], newestWeekStart);
    expect(weekStart['value'], ledger.weekStarts[newestWeekStart]);

    expect(ledger.textWrites.length, greaterThan(300));
    for (final TextWrite write in ledger.textWrites) {
      final Map<String, Object?> entry = entries[write.entryId]!;
      if (_deleted(entry)) {
        continue;
      }
      expect(
        _lines(entry).contains(write.line) ||
            copies.any(
              (Map<String, Object?> copy) => _lines(copy).contains(write.line),
            ),
        isTrue,
        reason: '"${write.line}" written to ${write.entryId} was lost',
      );
      expect(
        <String>{
          for (final Map<String, Object?> row in originals)
            if (row['id'] != write.entryId && _lines(row).contains(write.line))
              row['id']! as String,
        },
        isEmpty,
        reason: '"${write.line}" was duplicated into another entry',
      );
    }

    final Set<String> blobs = <String>{
      for (final Map<String, Object?> row in journal[SyncedTables.mediaBlobs]!)
        row['id']! as String,
    };
    final Set<String> references = <String>{
      for (final Map<String, Object?> row in entries.values) ...<String>[
        if (row['mediaId'] case final String media) media,
        if (row['thumbnailMediaId'] case final String thumbnail) thumbnail,
      ],
      for (final Map<String, Object?> row in journal[SyncedTables.entryPhotos]!)
        row['mediaId']! as String,
      for (final Map<String, Object?> row in journal[SyncedTables.mediaBlobs]!)
        if (row['posterId'] case final String poster) poster,
    };
    expect(references, isNotEmpty);
    expect(
      references.difference(blobs),
      isEmpty,
      reason: 'an entry or photo refers to media whose metadata was lost',
    );
  }, timeout: const Timeout(Duration(minutes: 8)));
}
