import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:field_notes/data/media/live_audio_channel.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

const List<int> fakeSoundBytes = <int>[1, 2, 3];
const List<int> fakeJoinedBytes = <int>[5, 6, 7, 8];
const int _firstEncoderId = 7;
const int _bytesPerSample = 2;
const double _fullScale = 32768;

Uint8List pcmAtDbfs(double dbfs, {int samples = 4800}) {
  final int value = (_fullScale * math.pow(10, dbfs / 20)).round().clamp(
    0,
    32767,
  );
  final ByteData data = ByteData(samples * _bytesPerSample);
  for (int index = 0; index < samples; index += 1) {
    data.setInt16(
      index * _bytesPerSample,
      index.isEven ? value : -value,
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

Uint8List silentPcm(int samples) => Uint8List(samples * _bytesPerSample);

class FakeMicrophone extends Fake implements AudioRecorder {
  FakeMicrophone({List<String>? events, this.granted = true})
    : events = events ?? <String>[];

  final List<String> events;
  final bool granted;
  final List<RecordConfig> startStreamConfigs = <RecordConfig>[];
  StreamController<Uint8List>? _chunks;

  void push(Uint8List chunk) => _chunks?.add(chunk);

  void fail(Object error) => _chunks?.addError(error);

  @override
  Future<bool> hasPermission({bool request = true}) async => granted;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    startStreamConfigs.add(config);
    events.add('mic.start');
    final StreamController<Uint8List> chunks = StreamController<Uint8List>();
    _chunks = chunks;
    return chunks.stream;
  }

  @override
  Future<void> pause() async => events.add('mic.pause');

  @override
  Future<void> resume() async => events.add('mic.resume');

  @override
  Future<String?> stop() async {
    events.add('mic.stop');
    _endStream();
    return null;
  }

  @override
  Future<void> cancel() async {
    events.add('mic.cancel');
    _endStream();
  }

  void _endStream() {
    final StreamController<Uint8List>? chunks = _chunks;
    if (chunks != null) {
      unawaited(chunks.close());
    }
  }

  @override
  Future<void> dispose() async {}
}

typedef FakeEncoderOpening = ({
  String path,
  int sampleRate,
  int channels,
  int bitRate,
});

typedef FakeSoundJoin = ({
  String video,
  String audio,
  String output,
  List<int> videoBytes,
  List<int> audioBytes,
});

class FakeLiveAudio extends Fake implements LiveEncoder, AudioJoiner {
  FakeLiveAudio({
    this.appendFails = false,
    this.closeFails = false,
    this.joinFails = false,
    this.writesFiles = true,
  });

  final bool writesFiles;
  bool appendFails;
  bool closeFails;
  bool joinFails;
  final List<FakeEncoderOpening> opened = <FakeEncoderOpening>[];
  final List<Uint8List> appended = <Uint8List>[];
  final List<FakeSoundJoin> joins = <FakeSoundJoin>[];
  final Map<int, String> _paths = <int, String>{};
  int closes = 0;
  int cancels = 0;

  String? get soundPath => opened.isEmpty ? null : opened.last.path;

  int get samplesAppended => appended.fold<int>(
    0,
    (int total, Uint8List pcm) => total + pcm.lengthInBytes ~/ _bytesPerSample,
  );

  @override
  Future<int> open({
    required String path,
    required int sampleRate,
    required int channels,
    required int bitRate,
  }) async {
    opened.add((
      path: path,
      sampleRate: sampleRate,
      channels: channels,
      bitRate: bitRate,
    ));
    if (writesFiles) {
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fakeSoundBytes);
    }
    final int id = _firstEncoderId + _paths.length;
    _paths[id] = path;
    return id;
  }

  @override
  Future<void> append(int id, Uint8List pcm) async {
    if (appendFails) {
      throw const LiveAudioException(appendPcmMethod, 'encode-failed');
    }
    appended.add(Uint8List.fromList(pcm));
  }

  @override
  Future<String> close(int id) async {
    closes += 1;
    if (closeFails) {
      throw const LiveAudioException(closeEncoderMethod, 'encode-failed');
    }
    return _paths[id]!;
  }

  @override
  Future<void> cancel(int id) async {
    cancels += 1;
    final String? path = _paths[id];
    if (writesFiles && path != null && File(path).existsSync()) {
      File(path).deleteSync();
    }
  }

  @override
  Future<String> join({
    required String video,
    required String audio,
    required String output,
  }) async {
    joins.add((
      video: video,
      audio: audio,
      output: output,
      videoBytes: File(video).readAsBytesSync(),
      audioBytes: File(audio).readAsBytesSync(),
    ));
    if (joinFails) {
      throw const LiveAudioException(joinAudioMethod, 'join-failed');
    }
    File(output).writeAsBytesSync(fakeJoinedBytes);
    return output;
  }
}

class PassThroughChain implements RunningVoiceChain {
  @override
  int get delaySamples => 0;

  @override
  Future<Uint8List> process(Uint8List pcm16) async => pcm16;

  @override
  Future<Uint8List> flush() async => Uint8List(0);

  @override
  Future<void> close() async {}
}

Future<RunningVoiceChain> passThroughChain({
  required InputProfile profile,
  required int volume,
}) async => PassThroughChain();
