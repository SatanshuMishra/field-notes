import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:field_notes/data/media/audio_clean_channel.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_cleanup.dart';
import 'package:field_notes/features/capture/audio/take_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

typedef _Step = Future<void> Function(String output);

const List<int> _takeBytes = <int>[1, 2, 3, 4, 5, 6, 7, 8];
const List<int> _rewrittenBytes = <int>[9, 9, 9];

Uint8List _wav(int frames) {
  final ByteData data = ByteData(44 + frames * 2);
  void ascii(int offset, String text) {
    for (int index = 0; index < text.length; index += 1) {
      data.setUint8(offset + index, text.codeUnitAt(index));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + frames * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, 48000, Endian.little)
    ..setUint32(28, 96000, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frames * 2, Endian.little);
  for (int frame = 0; frame < frames; frame += 1) {
    data.setInt16(
      44 + frame * 2,
      (sin(2 * pi * 220 * frame / 48000) * 3000).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

Future<void> _writeWav(String output) => File(output).writeAsBytes(_wav(12000));

Future<void> _writeTake(String output) =>
    File(output).writeAsBytes(_rewrittenBytes);

Future<void> _copyCleaner({
  required String input,
  required String output,
  required InputProfile profile,
  required int volume,
  IsolateRunner? run,
}) async {
  await File(input).copy(output);
}

Future<void> _failingCleaner({
  required String input,
  required String output,
  required InputProfile profile,
  required int volume,
  IsolateRunner? run,
}) async {
  throw const FileSystemException('the cleaner broke');
}

class _FakeChannel extends AudioCleanChannel {
  _FakeChannel({List<_Step>? decodes, _Step? replace})
    : _decodes = decodes ?? const <_Step>[],
      _replace = replace ?? _writeTake;

  final List<_Step> _decodes;
  final _Step _replace;
  final List<String> calls = <String>[];
  final List<String> decodeOutputs = <String>[];
  final List<String> replaceOutputs = <String>[];
  final List<int> bitRates = <int>[];

  @override
  Future<DecodedAudio> decodeAudio(String input, String output) async {
    final int index = decodeOutputs.length;
    calls.add('decodeAudio');
    decodeOutputs.add(output);
    await (index < _decodes.length ? _decodes[index] : _writeWav)(output);
    return const DecodedAudio(sampleRate: 48000, channels: 1, frames: 12000);
  }

  @override
  Future<File> replaceAudio(
    String input,
    String audio,
    String output,
    int bitRate,
  ) async {
    calls.add('replaceAudio');
    replaceOutputs.add(output);
    bitRates.add(bitRate);
    await _replace(output);
    return File(output);
  }
}

List<FileSystemEntity> _cleanupEntries(Directory temporary) => temporary
    .listSync(followLinks: false)
    .where(
      (FileSystemEntity entity) =>
          p.basename(entity.path).startsWith('take-cleanup-'),
    )
    .toList();

File _take(Directory temporary, String name) =>
    File(p.join(temporary.path, name))..writeAsBytesSync(_takeBytes);

Future<void> _until(bool Function() condition) async {
  for (int index = 0; index < 4000 && !condition(); index += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue, reason: 'the cleanup never got there');
}

class _Outcome<T> {
  _Outcome(Future<T> future) {
    future.then(
      (T value) {
        _value = value;
        done = true;
      },
      onError: (Object failure) {
        error = failure;
        done = true;
      },
    );
  }

  bool done = false;
  T? _value;
  Object? error;

  T get value {
    expect(error, isNull);
    expect(done, isTrue);
    return _value as T;
  }
}

class _Time {
  final FakeAsync fake = FakeAsync();
  final List<Object> escaped = <Object>[];
  late final Zone _zone = runZonedGuarded<Zone>(
    () => Zone.current,
    (Object error, StackTrace stackTrace) => escaped.add(error),
  )!;

  T run<T>(T Function() body) =>
      _zone.run(() => fake.run((FakeAsync _) => body()));

  Future<void> turn() async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    fake.flushMicrotasks();
  }

  Future<void> settle() async {
    for (int index = 0; index < 40; index += 1) {
      await turn();
    }
  }

  Future<void> until(bool Function() condition) async {
    for (int index = 0; index < 4000 && !condition(); index += 1) {
      await turn();
    }
    expect(condition(), isTrue, reason: 'the cleanup never got there');
  }

  Future<void> elapse(Duration duration) async {
    fake.elapse(duration);
    await settle();
  }

  _Outcome<T> begin<T>(Future<T> Function() action) =>
      run(() => _Outcome<T>(action()));
}

void main() {
  late Directory temporary;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('take_cleanup_test_');
  });

  tearDown(() {
    if (temporary.existsSync()) {
      temporary.deleteSync(recursive: true);
    }
  });

  TakeCleanup cleanupWith(
    AudioCleanChannel channel, {
    AudioCleaner cleaner = _copyCleaner,
  }) => TakeCleanup(
    channel: channel,
    cleaner: cleaner,
    temporaryDirectory: () async => temporary,
  );

  test('studio at 100 percent saves the take as recorded', () async {
    final _FakeChannel channel = _FakeChannel();
    final TakeCleanup cleanup = cleanupWith(channel);
    final File take = _take(temporary, 'voice_1.m4a');

    final File result = await cleanup.clean(
      take,
      kind: TakeKind.voice,
      profile: InputProfile.studio,
      volume: 100,
      duration: const Duration(seconds: 30),
    );

    expect(result, same(take));
    expect(channel.calls, isEmpty);
    expect(cleanup.needsCleanup(InputProfile.studio, 100), isFalse);
  });

  test('voice isolation cleans a voice take at 48 kbps', () async {
    final _FakeChannel channel = _FakeChannel();
    final TakeCleanup cleanup = TakeCleanup(
      channel: channel,
      temporaryDirectory: () async => temporary,
    );
    final File take = _take(temporary, 'voice_2.m4a');

    final File result = await cleanup.clean(
      take,
      kind: TakeKind.voice,
      profile: InputProfile.voiceIsolation,
      volume: 100,
      duration: const Duration(seconds: 30),
    );

    expect(channel.calls, <String>['decodeAudio', 'replaceAudio']);
    expect(channel.bitRates, <int>[48000]);
    expect(result.path, channel.replaceOutputs.single);
    expect(result.readAsBytesSync(), _rewrittenBytes);
    final Directory folder = result.parent;
    expect(p.basename(folder.path), startsWith('take-cleanup-'));
    expect(p.equals(folder.parent.path, temporary.path), isTrue);
    expect(
      folder.listSync().where(
        (FileSystemEntity entity) => p.extension(entity.path) == '.wav',
      ),
      isEmpty,
    );
    expect(take.readAsBytesSync(), _takeBytes);

    await cleanup.release(result);

    expect(_cleanupEntries(temporary), isEmpty);
  });

  test('a volume change rewrites a video take at 96 kbps', () async {
    final _FakeChannel channel = _FakeChannel();
    final TakeCleanup cleanup = cleanupWith(channel);
    final File take = _take(temporary, 'video_3.mp4');

    final File result = await cleanup.clean(
      take,
      kind: TakeKind.video,
      profile: InputProfile.studio,
      volume: 150,
      duration: const Duration(seconds: 30),
    );

    expect(channel.calls, <String>['decodeAudio', 'replaceAudio']);
    expect(channel.bitRates, <int>[96000]);
    expect(result.path, channel.replaceOutputs.single);
    expect(p.extension(result.path), '.mp4');
    await cleanup.release(result);
  });

  test('a ten-minute take gets the full 120 s', () async {
    final _Time time = _Time();
    final _FakeChannel channel = _FakeChannel(
      replace: (String output) async {
        await Future<void>.delayed(const Duration(seconds: 110));
        await _writeTake(output);
      },
    );
    final TakeCleanup cleanup = cleanupWith(channel);
    final File take = _take(temporary, 'voice_4.m4a');

    final _Outcome<File> outcome = time.begin(
      () => cleanup.clean(
        take,
        kind: TakeKind.voice,
        profile: InputProfile.voiceIsolation,
        volume: 100,
        duration: const Duration(seconds: 600),
      ),
    );
    await time.until(() => channel.replaceOutputs.isNotEmpty);
    await time.elapse(const Duration(seconds: 110));
    await time.until(() => outcome.done);

    expect(outcome.value.path, channel.replaceOutputs.single);
    expect(outcome.value.readAsBytesSync(), _rewrittenBytes);
    expect(time.escaped, isEmpty);
    await cleanup.release(outcome.value);
  });

  test('a take longer than 30 minutes is saved as recorded', () async {
    final _FakeChannel channel = _FakeChannel();
    final TakeCleanup cleanup = cleanupWith(channel);
    final File take = _take(temporary, 'voice_5.m4a');

    final File result = await cleanup.clean(
      take,
      kind: TakeKind.voice,
      profile: InputProfile.voiceIsolation,
      volume: 100,
      duration: const Duration(minutes: 31),
    );

    expect(result, same(take));
    expect(channel.calls, isEmpty);
  });

  test('a failed cleanup saves the take as recorded', () async {
    final File take = _take(temporary, 'voice_6.m4a');
    final List<TakeCleanup> cleanups = <TakeCleanup>[
      cleanupWith(
        _FakeChannel(
          decodes: <_Step>[
            (String output) async =>
                throw const AudioCleanException('decode broke'),
          ],
        ),
      ),
      cleanupWith(_FakeChannel(), cleaner: _failingCleaner),
      cleanupWith(
        _FakeChannel(
          replace: (String output) async =>
              throw const AudioCleanException('replace broke'),
        ),
      ),
    ];

    for (final TakeCleanup cleanup in cleanups) {
      final File result = await cleanup.clean(
        take,
        kind: TakeKind.voice,
        profile: InputProfile.voiceIsolation,
        volume: 100,
        duration: const Duration(seconds: 30),
      );

      expect(result, same(take));
      expect(result.readAsBytesSync(), _takeBytes);
      expect(_cleanupEntries(temporary), isEmpty);
    }
  });

  test(
    'a cleanup past its budget is abandoned and the take saved whole',
    () async {
      final _Time time = _Time();
      final _FakeChannel channel = _FakeChannel(
        replace: (String output) => Completer<void>().future,
      );
      final TakeCleanup cleanup = cleanupWith(channel);
      final File take = _take(temporary, 'voice_7.m4a');

      final _Outcome<File> outcome = time.begin(
        () => cleanup.clean(
          take,
          kind: TakeKind.voice,
          profile: InputProfile.voiceIsolation,
          volume: 100,
          duration: const Duration(seconds: 60),
        ),
      );
      await time.until(() => channel.replaceOutputs.isNotEmpty);
      await time.elapse(const Duration(seconds: 24));
      expect(outcome.done, isFalse);
      await time.elapse(const Duration(seconds: 1));
      await time.until(() => outcome.done);

      expect(outcome.value, same(take));
      expect(outcome.value.readAsBytesSync(), _takeBytes);
      expect(time.escaped, isEmpty);
    },
  );

  test("an abandoned step's late output is deleted when it settles", () async {
    final _Time time = _Time();
    bool settled = false;
    final _FakeChannel channel = _FakeChannel(
      replace: (String output) async {
        await Future<void>.delayed(const Duration(seconds: 40));
        await File(output).parent.create(recursive: true);
        await _writeTake(output);
        settled = true;
      },
    );
    final TakeCleanup cleanup = cleanupWith(channel);
    final File take = _take(temporary, 'voice_8.m4a');

    final _Outcome<File> outcome = time.begin(
      () => cleanup.clean(
        take,
        kind: TakeKind.voice,
        profile: InputProfile.voiceIsolation,
        volume: 100,
        duration: const Duration(seconds: 60),
      ),
    );
    await time.until(() => channel.replaceOutputs.isNotEmpty);
    await time.elapse(const Duration(seconds: 25));
    await time.until(() => outcome.done);

    expect(outcome.value, same(take));
    expect(outcome.value.readAsBytesSync(), _takeBytes);

    await time.elapse(const Duration(seconds: 15));
    await time.until(() => settled);
    await time.until(() => _cleanupEntries(temporary).isEmpty);

    expect(_cleanupEntries(temporary), isEmpty);
    expect(time.escaped, isEmpty);
  });

  test('leftover cleanup folders are swept when a cleanup starts', () async {
    final Completer<void> heldStarted = Completer<void>();
    final Completer<void> heldGate = Completer<void>();
    final Completer<void> lastStarted = Completer<void>();
    final Completer<void> lastGate = Completer<void>();
    final _FakeChannel channel = _FakeChannel(
      decodes: <_Step>[
        _writeWav,
        (String output) async {
          heldStarted.complete();
          await heldGate.future;
          await _writeWav(output);
        },
        (String output) async {
          lastStarted.complete();
          await lastGate.future;
          await _writeWav(output);
        },
      ],
    );
    final TakeCleanup cleanup = cleanupWith(channel);
    Future<File> start(String name) => cleanup.clean(
      _take(temporary, name),
      kind: TakeKind.voice,
      profile: InputProfile.voiceIsolation,
      volume: 100,
      duration: const Duration(seconds: 30),
    );

    final File unreleased = await start('voice_9a.m4a');
    final Future<File> held = start('voice_9b.m4a');
    await heldStarted.future;
    final Directory heldFolder = File(channel.decodeOutputs[1]).parent;
    final Directory old = Directory(p.join(temporary.path, 'take-cleanup-old'))
      ..createSync();
    File(p.join(old.path, 'decoded.wav')).writeAsBytesSync(_wav(480));
    final File note = File(p.join(temporary.path, 'take-cleanup-note'))
      ..writeAsStringSync('keep me');

    final Future<File> last = start('voice_9c.m4a');
    await lastStarted.future;

    expect(old.existsSync(), isFalse);
    expect(note.existsSync(), isTrue);
    expect(note.readAsStringSync(), 'keep me');
    expect(unreleased.existsSync(), isTrue);
    expect(unreleased.parent.existsSync(), isTrue);
    expect(heldFolder.existsSync(), isTrue);

    heldGate.complete();
    lastGate.complete();
    final List<File> finished = await Future.wait(<Future<File>>[held, last]);
    for (final File result in <File>[unreleased, ...finished]) {
      await cleanup.release(result);
    }
    await _until(
      () =>
          _cleanupEntries(temporary)
              .every((FileSystemEntity entity) => entity is File),
    );
  });
}
