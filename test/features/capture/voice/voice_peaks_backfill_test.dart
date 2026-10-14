import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/media/audio_peaks_decoder.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/features/capture/voice/voice_peaks_backfill.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const String _dayId = 'day-1';
const MethodChannel _decoderChannel = MethodChannel('field_notes/audio_peaks');

Entry _voice(
  String id, {
  String? mediaId,
  List<double>? peaks,
  int? deletedAt,
}) => Entry(
  id: id,
  dayId: _dayId,
  type: EntryType.voice,
  createdAt: 1,
  updatedAt: 1,
  mediaId: mediaId,
  durationMs: 1000,
  peaks: peaks,
  deletedAt: deletedAt,
);

List<int> _audio(int seed) =>
    List<int>.generate(64, (int index) => (index * 31 + seed) % 251);

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (int attempt = 0; attempt < 100 && !done(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _idle(WidgetTester tester) async {
  for (int round = 0; round < 10; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

final class _Media {
  _Media._(this.database, this.root, this.store);

  final db.AppDatabase database;
  final Directory root;
  final FilesystemMediaStore store;

  static Future<_Media> open(WidgetTester tester) async {
    final _Media? media = await tester.runAsync(() async {
      final db.AppDatabase database = db.AppDatabase(NativeDatabase.memory());
      final Directory root = await Directory.systemTemp.createTemp(
        'fn_voice_peaks',
      );
      return _Media._(
        database,
        root,
        FilesystemMediaStore(
          database: database,
          recorder: ChangeRecorder(database),
          root: root,
        ),
      );
    });
    addTearDown(
      () => tester.runAsync(() async {
        await media!.database.close();
        await media.root.delete(recursive: true);
      }),
    );
    return media!;
  }

  Future<MediaBlob> put(WidgetTester tester, List<int> bytes) async {
    final MediaBlob? blob = await tester.runAsync(
      () => store.putBytes(
        bytes: bytes,
        mime: 'audio/mp4',
        kind: MediaKind.audio,
        durationMs: 1000,
      ),
    );
    return blob!;
  }

  String pathOf(MediaBlob blob) => p.join(root.path, blob.relPath);

  Future<void> removeFile(WidgetTester tester, MediaBlob blob) async {
    await tester.runAsync(() => File(pathOf(blob)).delete());
  }

  Future<void> restore(
    WidgetTester tester,
    MediaBlob blob,
    List<int> bytes,
  ) async {
    await tester.runAsync(() async {
      final File source = File(p.join(root.path, 'incoming.m4a'));
      await source.writeAsBytes(bytes, flush: true);
      await store.restoreFile(blob, source);
    });
  }
}

final class _Journal implements JournalRepository {
  _Journal(this._entries);

  final List<Entry> _entries;
  final StreamController<List<Entry>> _relisted =
      StreamController<List<Entry>>.broadcast();
  final List<({String entryId, List<double> peaks})> saved =
      <({String entryId, List<double> peaks})>[];

  void relist() => _relisted.add(_entries);

  @override
  Stream<List<Entry>> watchVoiceEntriesWithoutPeaks() async* {
    yield _entries;
    yield* _relisted.stream;
  }

  @override
  Future<void> setVoicePeaks(String entryId, List<double> peaks) async {
    saved.add((entryId: entryId, peaks: peaks));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SavingJournal extends DriftJournalRepository {
  _SavingJournal(super.database) : super(recorder: ChangeRecorder(database));

  final List<String> saved = <String>[];

  @override
  Future<void> setVoicePeaks(String entryId, List<double> peaks) async {
    await super.setVoicePeaks(entryId, peaks);
    saved.add(entryId);
  }
}

final class _Decoder implements AudioPeaksDecoder {
  _Decoder(this._answer);

  _Decoder.answering(List<double> rms)
    : this(() => Future<List<double>>.value(rms));

  final Future<List<double>> Function() _answer;
  final List<String> paths = <String>[];

  @override
  Future<List<double>> windowRms(String path) {
    paths.add(path);
    return _answer();
  }
}

final class _RecordingResolver implements MediaResolver {
  final List<String?> calls = <String?>[];

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async {
    calls.add(mediaId);
    return const ResolvedMedia.missing();
  }

  @override
  ResolvedMedia? resolved(String? mediaId) {
    calls.add(mediaId);
    return null;
  }
}

List<Override> _overrides({
  required JournalRepository journal,
  required _Media media,
  AudioPeaksDecoder? decoder,
}) => <Override>[
  journalRepositoryProvider.overrideWithValue(journal),
  mediaStoreProvider.overrideWith((Ref ref) async => media.store),
  if (decoder != null) audioPeaksDecoderProvider.overrideWithValue(decoder),
];

Future<void> _mount(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: const VoicePeaksBackfill(child: SizedBox.shrink()),
    ),
  );
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _idle(tester);
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('an older voice entry gets peaks from its audio', (
    WidgetTester tester,
  ) async {
    final _Media media = await _Media.open(tester);
    final MediaBlob blob = await media.put(tester, _audio(1));
    final _Decoder decoder = _Decoder.answering(<double>[0.01, 0.1]);
    final _Journal journal = _Journal(<Entry>[
      _voice('voice-1', mediaId: blob.id),
    ]);

    await _mount(
      tester,
      _overrides(journal: journal, media: media, decoder: decoder),
    );
    await _until(tester, () => journal.saved.isNotEmpty);
    await _idle(tester);

    expect(decoder.paths, <String>[media.pathOf(blob)]);
    expect(journal.saved, hasLength(1));
    expect(journal.saved.single.entryId, 'voice-1');
    expect(journal.saved.single.peaks, <double>[0.25, 0.75]);
    await _unmount(tester);
  });

  testWidgets(
    'entries with peaks, deleted entries and other kinds are left alone',
    (WidgetTester tester) async {
      final _Media media = await _Media.open(tester);
      final MediaBlob blob = await media.put(tester, _audio(1));
      final _Decoder decoder = _Decoder.answering(<double>[0.1]);
      final _Journal journal = _Journal(<Entry>[
        _voice('voice-with-peaks', mediaId: blob.id, peaks: <double>[0.5]),
        _voice('voice-deleted', mediaId: blob.id, deletedAt: 2),
        Entry(
          id: 'text-1',
          dayId: _dayId,
          type: EntryType.text,
          createdAt: 1,
          updatedAt: 1,
          textContent: 'A walk by the river',
          mediaId: blob.id,
        ),
      ]);

      await _mount(
        tester,
        _overrides(journal: journal, media: media, decoder: decoder),
      );
      await _idle(tester);

      expect(decoder.paths, isEmpty);
      expect(journal.saved, isEmpty);
      await _unmount(tester);
    },
  );

  testWidgets('a voice entry waits for its audio', (WidgetTester tester) async {
    final _Media media = await _Media.open(tester);
    final List<int> audio = _audio(1);
    final MediaBlob blob = await media.put(tester, audio);
    await media.removeFile(tester, blob);
    final _Decoder decoder = _Decoder.answering(<double>[0.01, 0.1]);
    final _Journal journal = _Journal(<Entry>[
      _voice('voice-1', mediaId: blob.id),
    ]);

    await _mount(
      tester,
      _overrides(journal: journal, media: media, decoder: decoder),
    );
    await _idle(tester);

    expect(decoder.paths, isEmpty);
    expect(journal.saved, isEmpty);

    await media.restore(tester, blob, audio);
    await _until(tester, () => journal.saved.isNotEmpty);
    await _idle(tester);

    expect(decoder.paths, <String>[media.pathOf(blob)]);
    expect(journal.saved, hasLength(1));
    expect(journal.saved.single.entryId, 'voice-1');
    expect(journal.saved.single.peaks, <double>[0.25, 0.75]);
    await _unmount(tester);
  });

  testWidgets('a voice entry whose media record has not arrived waits', (
    WidgetTester tester,
  ) async {
    final _Media media = await _Media.open(tester);
    final List<int> audio = _audio(2);
    final String mediaId = sha256Hex(audio);
    final _Decoder decoder = _Decoder.answering(<double>[0.01, 0.1]);
    final _Journal journal = _Journal(<Entry>[
      _voice('voice-1', mediaId: mediaId),
    ]);

    await _mount(
      tester,
      _overrides(journal: journal, media: media, decoder: decoder),
    );
    await _idle(tester);

    expect(decoder.paths, isEmpty);
    expect(journal.saved, isEmpty);

    final MediaBlob blob = await media.put(tester, audio);
    expect(blob.id, mediaId);
    await _until(tester, () => journal.saved.isNotEmpty);
    await _idle(tester);

    expect(decoder.paths, <String>[media.pathOf(blob)]);
    expect(journal.saved, hasLength(1));
    expect(journal.saved.single.entryId, 'voice-1');
    expect(journal.saved.single.peaks, <double>[0.25, 0.75]);
    await _unmount(tester);
  });

  testWidgets('the backfill never downloads audio or marks it opened', (
    WidgetTester tester,
  ) async {
    final _Media media = await _Media.open(tester);
    final MediaBlob here = await media.put(tester, _audio(1));
    final MediaBlob away = await media.put(tester, _audio(2));
    await media.removeFile(tester, away);
    final _RecordingResolver resolver = _RecordingResolver();
    final _Decoder decoder = _Decoder.answering(<double>[0.01, 0.1]);
    final _Journal journal = _Journal(<Entry>[
      _voice('voice-here', mediaId: here.id),
      _voice('voice-away', mediaId: away.id),
    ]);

    await _mount(tester, <Override>[
      ..._overrides(journal: journal, media: media, decoder: decoder),
      mediaResolverProvider.overrideWith((Ref ref) async => resolver),
    ]);
    await _until(tester, () => journal.saved.isNotEmpty);
    await _idle(tester);

    expect(decoder.paths, <String>[media.pathOf(here)]);
    expect(
      journal.saved.map(
        (({String entryId, List<double> peaks}) save) => save.entryId,
      ),
      <String>['voice-here'],
    );
    expect(resolver.calls, isEmpty);
    expect(File(media.pathOf(away)).existsSync(), isFalse);
    await _unmount(tester);
  });

  testWidgets('a failed decode is not retried in the same run', (
    WidgetTester tester,
  ) async {
    final _Media media = await _Media.open(tester);
    final MediaBlob blob = await media.put(tester, _audio(1));
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    addTearDown(
      () => messenger.setMockMethodCallHandler(_decoderChannel, null),
    );
    final Map<String, Object? Function()> answers =
        <String, Object? Function()>{
          'a platform failure': () =>
              throw PlatformException(code: 'decode-failed'),
          'not a list': () => <String, Object?>{
            'rms': <double>[0.1],
          },
          'a negative value': () => <Object?>[0.1, -1],
          'a value that is not a number': () => <Object?>[double.nan],
        };
    final List<String> logged = <String>[];
    final DebugPrintCallback original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      logged.add(message ?? '');
    };
    try {
      int scenario = 0;
      for (final MapEntry<String, Object? Function()> answer
          in answers.entries) {
        scenario += 1;
        final List<MethodCall> calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(_decoderChannel, (
          MethodCall call,
        ) async {
          calls.add(call);
          return answer.value();
        });
        logged.clear();
        final _Journal journal = _Journal(<Entry>[
          _voice('voice-$scenario', mediaId: blob.id),
        ]);

        await _mount(tester, _overrides(journal: journal, media: media));
        await _until(tester, () => calls.isNotEmpty);
        await _idle(tester);
        journal.relist();
        await _idle(tester);

        expect(calls, hasLength(1), reason: answer.key);
        expect(journal.saved, isEmpty, reason: answer.key);
        expect(logged, hasLength(1), reason: answer.key);
      }
      await _unmount(tester);
    } finally {
      debugPrint = original;
    }
  });

  testWidgets('entries are decoded one at a time', (WidgetTester tester) async {
    final _Media media = await _Media.open(tester);
    final MediaBlob first = await media.put(tester, _audio(1));
    final MediaBlob second = await media.put(tester, _audio(2));
    final List<Completer<List<double>>> pending = <Completer<List<double>>>[];
    final _Decoder decoder = _Decoder(() {
      final Completer<List<double>> decode = Completer<List<double>>();
      pending.add(decode);
      return decode.future;
    });
    final _Journal journal = _Journal(<Entry>[
      _voice('voice-1', mediaId: first.id),
      _voice('voice-2', mediaId: second.id),
    ]);

    await _mount(
      tester,
      _overrides(journal: journal, media: media, decoder: decoder),
    );
    await _until(tester, () => decoder.paths.isNotEmpty);
    await _idle(tester);

    expect(decoder.paths, <String>[media.pathOf(first)]);
    expect(journal.saved, isEmpty);

    pending.first.complete(<double>[0.01]);
    await _until(tester, () => decoder.paths.length == 2);
    await _idle(tester);

    expect(decoder.paths, <String>[media.pathOf(first), media.pathOf(second)]);
    expect(
      journal.saved.map(
        (({String entryId, List<double> peaks}) save) => save.entryId,
      ),
      <String>['voice-1'],
    );

    pending.last.complete(<double>[0.1]);
    await _until(tester, () => journal.saved.length == 2);
    await _idle(tester);

    expect(
      journal.saved.map(
        (({String entryId, List<double> peaks}) save) => save.entryId,
      ),
      <String>['voice-1', 'voice-2'],
    );
    expect(pending, hasLength(2));
    await _unmount(tester);
  });

  testWidgets('empty audio saves an empty list', (WidgetTester tester) async {
    final _Media media = await _Media.open(tester);
    final MediaBlob blob = await media.put(tester, _audio(1));
    final _Decoder decoder = _Decoder.answering(const <double>[]);
    final _Journal journal = _Journal(<Entry>[
      _voice('voice-1', mediaId: blob.id),
    ]);

    await _mount(
      tester,
      _overrides(journal: journal, media: media, decoder: decoder),
    );
    await _until(tester, () => journal.saved.isNotEmpty);
    await _idle(tester);

    expect(journal.saved, hasLength(1));
    expect(journal.saved.single.entryId, 'voice-1');
    expect(journal.saved.single.peaks, <double>[]);

    journal.relist();
    await _idle(tester);

    expect(decoder.paths, hasLength(1));
    expect(journal.saved, hasLength(1));
    await _unmount(tester);
  });

  testWidgets("a long recording's levels merge within 36,000 peaks", (
    WidgetTester tester,
  ) async {
    final _Media media = await _Media.open(tester);
    final MediaBlob blob = await media.put(tester, _audio(1));
    final _Decoder decoder = _Decoder.answering(<double>[
      ...List<double>.filled(36000, 0.01),
      ...List<double>.filled(36000, 0.1),
    ]);
    final _Journal journal = _Journal(<Entry>[
      _voice('voice-1', mediaId: blob.id),
    ]);

    await _mount(
      tester,
      _overrides(journal: journal, media: media, decoder: decoder),
    );
    await _until(tester, () => journal.saved.isNotEmpty);
    await _idle(tester);

    expect(decoder.paths, hasLength(1));
    expect(journal.saved, hasLength(1));
    expect(journal.saved.single.peaks, hasLength(36000));
    expect(journal.saved.single.peaks, <double>[
      ...List<double>.filled(18000, 0.25),
      ...List<double>.filled(18000, 0.75),
    ]);
    await _unmount(tester);
  });

  testWidgets('a damaged stored value is decoded again', (
    WidgetTester tester,
  ) async {
    final _Media media = await _Media.open(tester);
    final MediaBlob blob = await media.put(tester, _audio(1));
    await tester.runAsync(
      () => media.database
          .into(media.database.entries)
          .insert(
            db.EntriesCompanion.insert(
              id: 'voice-1',
              dayId: _dayId,
              type: 'voice',
              mediaId: Value<String?>(blob.id),
              durationMs: const Value<int?>(1000),
              createdAt: 1,
              updatedAt: 1,
              peaks: const Value<String?>('oops'),
            ),
          ),
    );
    final _SavingJournal journal = _SavingJournal(media.database);
    final _Decoder decoder = _Decoder.answering(<double>[0.01, 0.1]);

    await _mount(
      tester,
      _overrides(journal: journal, media: media, decoder: decoder),
    );
    await _until(tester, () => journal.saved.isNotEmpty);
    await _idle(tester);

    expect(decoder.paths, <String>[media.pathOf(blob)]);
    expect(journal.saved, <String>['voice-1']);
    final Entry? stored = await tester.runAsync<Entry?>(
      () => journal.entryById('voice-1'),
    );
    expect(stored?.peaks, <double>[0.25, 0.75]);
    await _unmount(tester);
  });

  testWidgets('a voice entry with no media is skipped', (
    WidgetTester tester,
  ) async {
    final _Media media = await _Media.open(tester);
    final _Decoder decoder = _Decoder.answering(<double>[0.01, 0.1]);
    final _Journal journal = _Journal(<Entry>[_voice('voice-1')]);

    await _mount(
      tester,
      _overrides(journal: journal, media: media, decoder: decoder),
    );
    await _idle(tester);

    expect(decoder.paths, isEmpty);
    expect(journal.saved, isEmpty);
    await _unmount(tester);
  });
}
