import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/relay_fixture.dart';
import '../support/simulated_device.dart';

const int _seed = 4207;
const int _operationsPerDevice = 200;
const int _rounds = 4;
const int _prefixBytes = 4;
const int _shortestNeedle = 7;

typedef _Needle = ({String label, Uint8List bytes});

int _prefixAt(Uint8List bytes, int at) =>
    bytes[at] |
    (bytes[at + 1] << 8) |
    (bytes[at + 2] << 16) |
    (bytes[at + 3] << 24);

final class _ByteScanner {
  _ByteScanner(Map<String, Uint8List> needles)
    : _byPrefix = _index(needles),
      count = needles.length;

  final Map<int, List<_Needle>> _byPrefix;
  final int count;

  static Map<int, List<_Needle>> _index(Map<String, Uint8List> needles) {
    final Map<int, List<_Needle>> index = <int, List<_Needle>>{};
    for (final MapEntry<String, Uint8List> needle in needles.entries) {
      if (needle.value.length < _shortestNeedle) {
        throw ArgumentError.value(
          needle.key,
          'needles',
          'Shorter than $_shortestNeedle bytes, so chance matches in '
              'ciphertext would hide real ones',
        );
      }
      (index[_prefixAt(needle.value, 0)] ??= <_Needle>[]).add((
        label: needle.key,
        bytes: needle.value,
      ));
    }
    return index;
  }

  Set<String> foundIn(Uint8List haystack) {
    final Set<String> found = <String>{};
    for (int at = 0; at + _prefixBytes <= haystack.length; at++) {
      final List<_Needle>? candidates = _byPrefix[_prefixAt(haystack, at)];
      if (candidates == null) {
        continue;
      }
      for (final _Needle needle in candidates) {
        if (_matchesAt(haystack, at, needle.bytes)) {
          found.add(needle.label);
        }
      }
    }
    return found;
  }

  static bool _matchesAt(Uint8List haystack, int at, Uint8List needle) {
    if (at + needle.length > haystack.length) {
      return false;
    }
    for (int index = 0; index < needle.length; index++) {
      if (haystack[at + index] != needle[index]) {
        return false;
      }
    }
    return true;
  }
}

Uint8List _utf8(String text) => Uint8List.fromList(utf8.encode(text));

Uint8List _hexBytes(String hex) => Uint8List.fromList(<int>[
  for (int at = 0; at < hex.length; at += 2)
    int.parse(hex.substring(at, at + 2), radix: 16),
]);

Future<Map<String, Map<String, Uint8List>>> _needlesOf(
  OfflineEditRun run,
) async {
  final SyncedRows journal = await run.devices.first.syncedRows();
  final List<Map<String, Object?>> entries = journal[SyncedTables.entries]!;
  final Map<String, Uint8List> texts = <String, Uint8List>{
    for (final TextWrite write in run.ledger.textWrites)
      'note line "${write.line}"': _utf8(write.line),
    for (final Map<String, Object?> entry in entries)
      if (entry['textContent'] case final String text)
        'note text of ${entry['id']}': _utf8(text),
  };
  final Map<String, Uint8List> dates = <String, Uint8List>{
    for (final String date in <String>{
      ...run.ledger.dates,
      for (final Map<String, Object?> day in journal[SyncedTables.days]!)
        day['date']! as String,
    })
      'date $date': _utf8(date),
  };
  final Map<String, Uint8List> moods = <String, Uint8List>{
    for (final String mood in run.ledger.moodIds) 'mood id $mood': _utf8(mood),
  };
  final Map<String, Uint8List> ulids = <String, Uint8List>{
    for (final Map<String, Object?> entry in entries)
      'entry id ${entry['id']}': _utf8(entry['id']! as String),
    for (final Map<String, Object?> photo in journal[SyncedTables.entryPhotos]!)
      'photo link id ${photo['id']}': _utf8(photo['id']! as String),
  };
  final Map<String, Uint8List> names = <String, Uint8List>{
    for (final String name in <String>{
      for (final SimulatedDevice device in run.devices) device.name,
      for (final Map<String, Object?> entry in entries)
        if (entry['conflictSourceDevice'] case final String label) label,
    })
      'device name $name': _utf8(name),
  };
  final Map<String, Uint8List> files = <String, Uint8List>{
    for (final SimulatedDevice device in run.devices)
      for (final File file in await device.mediaFiles())
        'media file ${p.basename(file.path)}': await file.readAsBytes(),
  };
  final Map<String, Uint8List> hashes = <String, Uint8List>{
    for (final Map<String, Object?> blob
        in journal[SyncedTables.mediaBlobs]!) ...<String, Uint8List>{
      'SHA-256 text ${blob['id']}': _utf8(blob['id']! as String),
      'SHA-256 bytes ${blob['id']}': _hexBytes(blob['id']! as String),
    },
  };
  return <String, Map<String, Uint8List>>{
    'note texts': texts,
    'dates': dates,
    'mood ids': moods,
    'ULIDs': ulids,
    'device names': names,
    'media files': files,
    'SHA-256 values': hashes,
  };
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('the relay stores and logs nothing readable', () async {
    final RelayFixture relay = await RelayFixture.start(rateBurst: 1000);
    addTearDown(relay.dispose);
    final OfflineEditRun run = await OfflineEditRun.play(
      relay,
      seed: _seed,
      operationsPerDevice: _operationsPerDevice,
      rounds: _rounds,
    );
    addTearDown(run.dispose);

    final Map<String, Map<String, Uint8List>> kinds = await _needlesOf(run);
    expect(kinds['note texts']!.length, greaterThan(300));
    expect(kinds['dates'], isNotEmpty);
    expect(kinds['mood ids'], isNotEmpty);
    expect(kinds['ULIDs']!.length, greaterThan(150));
    expect(kinds['device names']!.length, greaterThanOrEqualTo(3));
    expect(kinds['media files']!.length, greaterThan(20));
    expect(kinds['SHA-256 values']!.length, greaterThan(40));
    final _ByteScanner scanner = _ByteScanner(<String, Uint8List>{
      for (final Map<String, Uint8List> kind in kinds.values) ...kind,
    });

    final String accountId = await run.devices.first.accountId();
    expect(relay.recordSeqs(accountId).length, greaterThan(150));
    final List<File> stored = relay.storedFiles();
    expect(
      stored.where((File file) => p.isWithin(relay.mediaDirectory, file.path)),
      isNotEmpty,
    );
    expect(relay.logLines, isNotEmpty);

    final Map<String, Set<String>> readable = <String, Set<String>>{};
    for (final File file in stored) {
      final Set<String> found = scanner.foundIn(await file.readAsBytes());
      if (found.isNotEmpty) {
        readable[p.relative(file.path, from: relay.root.path)] = found;
      }
    }
    final Set<String> logged = scanner.foundIn(
      _utf8(relay.logLines.join('\n')),
    );
    if (logged.isNotEmpty) {
      readable['relay log output'] = logged;
    }
    expect(
      readable,
      isEmpty,
      reason: 'the relay holds plaintext from the journal',
    );
  }, timeout: const Timeout(Duration(minutes: 8)));
}
