import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

class _StreamingAudioRecorder extends Fake implements AudioRecorder {
  StreamController<Uint8List>? _chunks;
  RecordConfig? streamedWith;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    streamedWith = config;
    final StreamController<Uint8List> chunks = StreamController<Uint8List>();
    _chunks = chunks;
    return chunks.stream;
  }

  @override
  Future<String?> stop() async {
    await _chunks?.close();
    return null;
  }

  @override
  Future<void> cancel() async {
    await _chunks?.close();
  }

  @override
  Future<void> dispose() async {}
}

class _FileWritingEncoder extends Fake implements LiveEncoder {
  final List<String> openedPaths = <String>[];
  final List<int> bitRates = <int>[];

  @override
  Future<int> open({
    required String path,
    required int sampleRate,
    required int channels,
    required int bitRate,
  }) async {
    openedPaths.add(path);
    bitRates.add(bitRate);
    return openedPaths.length;
  }

  @override
  Future<void> append(int id, Uint8List pcm) async {}

  @override
  Future<String> close(int id) async {
    final String path = openedPaths[id - 1];
    await File(path).writeAsBytes(<int>[1, 2, 3], flush: true);
    return path;
  }

  @override
  Future<void> cancel(int id) async {}
}

class _NotedChain implements RunningVoiceChain {
  @override
  int get delaySamples => 0;

  @override
  Future<Uint8List> process(Uint8List pcm16) async => pcm16;

  @override
  Future<Uint8List> flush() async => Uint8List(0);

  @override
  Future<void> close() async {}
}

File _capturedFile(VoiceRecording recording) =>
    (recording.media as CaptureFile).file;

void main() {
  group('voice recording format', () {
    test('records into an m4a container with the mp4 audio mime', () {
      expect(voiceRecordingExtension, 'm4a');
      expect(voiceRecordingMime, 'audio/mp4');
    });
  });

  group('voice recording configuration', () {
    test('streams the microphone into a 96 kbps live encoder', () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'voice_config_test_',
      );
      addTearDown(() => temp.delete(recursive: true));
      final _StreamingAudioRecorder fake = _StreamingAudioRecorder();
      final _FileWritingEncoder encoder = _FileWritingEncoder();
      final RecordVoiceRecorder recorder = RecordVoiceRecorder(
        recorder: fake,
        encoder: encoder,
        chainRunner: runVoiceChainInline,
        temporaryDirectory: () async => temp,
      );
      addTearDown(recorder.dispose);

      await recorder.start();

      final RecordConfig? config = fake.streamedWith;
      expect(config, isNotNull);
      expect(config!.encoder, AudioEncoder.pcm16bits);
      expect(config.numChannels, 1);
      expect(config.sampleRate, 48000);
      expect(encoder.bitRates, <int>[96000]);
      expect(p.dirname(encoder.openedPaths.single), temp.path);
      expect(p.basename(encoder.openedPaths.single), startsWith('voice_'));
      expect(p.extension(encoder.openedPaths.single), '.m4a');

      await recorder.cancel();
    });

    test('a failing settings read records Studio at volume 100', () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'voice_processing_test_',
      );
      addTearDown(() => temp.delete(recursive: true));
      final List<({InputProfile profile, int volume})> chains =
          <({InputProfile profile, int volume})>[];
      final RecordVoiceRecorder recorder = RecordVoiceRecorder(
        recorder: _StreamingAudioRecorder(),
        encoder: _FileWritingEncoder(),
        chainRunner:
            ({required InputProfile profile, required int volume}) async {
              chains.add((profile: profile, volume: volume));
              return _NotedChain();
            },
        temporaryDirectory: () async => temp,
        resolveProcessing: () async => throw StateError('no settings'),
      );
      addTearDown(recorder.dispose);

      await recorder.start();

      expect(chains, <({InputProfile profile, int volume})>[
        (profile: InputProfile.studio, volume: 100),
      ]);

      await recorder.cancel();
    });
  });

  group('voiceRecordingFileName', () {
    test('builds a timestamped file name with the recording extension', () {
      expect(voiceRecordingFileName(1720000000000), 'voice_1720000000000.m4a');
    });

    test('produces distinct names for distinct timestamps', () {
      expect(voiceRecordingFileName(1) == voiceRecordingFileName(2), isFalse);
    });
  });

  group('resolveVoiceRecordingPath', () {
    test('creates the target directory when it does not exist', () async {
      final Directory base = await Directory.systemTemp.createTemp(
        'voice_recorder_test_',
      );
      addTearDown(() => base.delete(recursive: true));
      final Directory missing = Directory(
        p.join(base.path, 'nested', 'caches', 'bundle'),
      );
      expect(missing.existsSync(), isFalse);

      final String path = await resolveVoiceRecordingPath(
        missing,
        1720000000000,
      );

      expect(missing.existsSync(), isTrue);
      expect(path, p.join(missing.path, 'voice_1720000000000.m4a'));
    });

    test('returns a path inside an already-existing directory', () async {
      final Directory base = await Directory.systemTemp.createTemp(
        'voice_recorder_test_',
      );
      addTearDown(() => base.delete(recursive: true));

      final String path = await resolveVoiceRecordingPath(base, 42);

      expect(base.existsSync(), isTrue);
      expect(path, p.join(base.path, 'voice_42.m4a'));
    });
  });

  group('releasing saved memos', () {
    late Directory temp;
    late RecordVoiceRecorder recorder;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('voice_release_test_');
      recorder = RecordVoiceRecorder(
        recorder: _StreamingAudioRecorder(),
        encoder: _FileWritingEncoder(),
        chainRunner: runVoiceChainInline,
        temporaryDirectory: () async => temp,
      );
    });

    tearDown(() async {
      await recorder.dispose();
      await temp.delete(recursive: true);
    });

    test(
      'releasing a saved memo deletes the file the recorder created',
      () async {
        final File picked = File(p.join(temp.path, 'picked.m4a'))
          ..writeAsBytesSync(<int>[9, 9]);

        await recorder.start();
        final VoiceRecording recording = await recorder.stop();
        final File captured = _capturedFile(recording);

        expect(p.isWithin(temp.path, captured.path), isTrue);
        expect(captured.existsSync(), isTrue);

        await recorder.releaseSaved(
          VoiceRecording(
            media: CaptureFile(file: picked, mime: voiceRecordingMime),
            durationMs: 1,
          ),
        );

        expect(picked.existsSync(), isTrue);
        expect(captured.existsSync(), isTrue);

        await recorder.releaseSaved(recording);

        expect(captured.existsSync(), isFalse);
        expect(picked.existsSync(), isTrue);
      },
    );

    test(
      'releasing an earlier stop keeps the file a later stop still holds',
      () async {
        await recorder.start();
        final VoiceRecording first = await recorder.stop();
        final VoiceRecording retry = await recorder.stop();
        final File captured = _capturedFile(retry);

        expect(_capturedFile(first).path, captured.path);

        await recorder.releaseSaved(first);

        expect(captured.existsSync(), isTrue);

        await recorder.releaseSaved(retry);

        expect(captured.existsSync(), isFalse);
      },
    );
  });
}
