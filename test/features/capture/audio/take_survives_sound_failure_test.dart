import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/live_audio_capture.dart';
import 'package:field_notes/features/capture/platform/camera_video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'live_audio_test_support.dart';

const int _chunkSamples = 4800;
const int _chunksEachSide = 5;
const int _brokenChainDelay = 960;
const int _brokenChainVolume = 150;

class _Camera extends CameraPlatform {
  _Camera(this.root);

  final Directory root;
  final List<String> pictures = <String>[];
  int _written = 0;
  final StreamController<CameraInitializedEvent> _initialized =
      StreamController<CameraInitializedEvent>.broadcast();
  final StreamController<CameraErrorEvent> _errors =
      StreamController<CameraErrorEvent>.broadcast();

  String _write(String extension, List<int> bytes) {
    _written += 1;
    final Directory folder = Directory(p.join(root.path, 'camera'))
      ..createSync(recursive: true);
    final String path = p.join(folder.path, 'take_$_written.$extension');
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[
        CameraDescription(
          name: 'cam-0',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
      ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async => 1;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(
      () => _initialized.add(
        const CameraInitializedEvent(
          1,
          1280,
          720,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized.stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream<DeviceOrientationChangedEvent>.empty();

  @override
  Future<Iterable<VideoStabilizationMode>> getSupportedVideoStabilizationModes(
    int cameraId,
  ) async => const <VideoStabilizationMode>[];

  @override
  Future<void> startVideoCapturing(VideoCaptureOptions options) async {}

  @override
  Future<XFile> takePicture(int cameraId) async =>
      XFile(_write('jpg', const <int>[0xFF, 0xD8, 0xFF, 0xD9]));

  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    final String movie = _write('mp4', const <int>[0, 0, 0, 24]);
    pictures.add(movie);
    return XFile(movie);
  }

  @override
  Future<void> dispose(int cameraId) async {}

  @override
  Widget buildPreview(int cameraId) => const SizedBox();
}

class _ChainBreakingOnce implements RunningVoiceChain {
  _ChainBreakingOnce({required this.breaksOnChunk});

  final int breaksOnChunk;
  List<int> _held = List<int>.filled(_brokenChainDelay, 0);
  int _chunks = 0;
  int callsAfterBreak = 0;

  bool get _broken => _chunks >= breaksOnChunk;

  @override
  int get delaySamples => _brokenChainDelay;

  @override
  Future<Uint8List> process(Uint8List pcm16) async {
    if (_broken) {
      callsAfterBreak += 1;
    }
    _chunks += 1;
    if (_chunks == breaksOnChunk) {
      throw StateError('chain isolate died');
    }
    final List<int> joined = <int>[..._held, ..._samplesOf(pcm16)];
    final int count = pcm16.lengthInBytes ~/ 2;
    _held = joined.sublist(count);
    return _pcmOf(joined.sublist(0, count));
  }

  @override
  Future<Uint8List> flush() async {
    if (_broken) {
      callsAfterBreak += 1;
    }
    final List<int> rest = _held;
    _held = <int>[];
    return _pcmOf(rest);
  }

  @override
  Future<void> close() async {}
}

Uint8List _pcmOf(List<int> samples) {
  final ByteData data = ByteData(samples.length * 2);
  for (int index = 0; index < samples.length; index += 1) {
    data.setInt16(index * 2, samples[index], Endian.little);
  }
  return data.buffer.asUint8List();
}

List<int> _samplesOf(Uint8List pcm) {
  final ByteData data = ByteData.sublistView(pcm);
  return <int>[
    for (int index = 0; index < pcm.lengthInBytes ~/ 2; index += 1)
      data.getInt16(index * 2, Endian.little),
  ];
}

Uint8List _countingChunk(int first) => _pcmOf(<int>[
  for (int index = 0; index < _chunkSamples; index += 1) first + index % 100,
]);

Future<RunningVoiceChain> _studio({
  required InputProfile profile,
  required int volume,
}) => runVoiceChainInline(profile: InputProfile.studio, volume: 100);

Future<void> _settle() async {
  for (int turn = 0; turn < 20; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

typedef _Fault = Future<void> Function(
  FakeMicrophone mic,
  FakeLiveAudio liveAudio,
);

Future<void> _failOneAppend(FakeMicrophone mic, FakeLiveAudio liveAudio) async {
  liveAudio.appendFails = true;
  mic.push(silentPcm(_chunkSamples));
  await _settle();
  liveAudio.appendFails = false;
}

Future<void> _failTheMicStream(
  FakeMicrophone mic,
  FakeLiveAudio liveAudio,
) async => mic.fail(StateError('mic hiccup'));

Future<void> _sendAnOddLengthChunk(
  FakeMicrophone mic,
  FakeLiveAudio liveAudio,
) async => mic.push(Uint8List(3));

Future<void> _failTheClose(FakeMicrophone mic, FakeLiveAudio liveAudio) async {
  liveAudio.closeFails = true;
}

final Map<String, ({_Fault fault, bool voice})> _faults =
    <String, ({_Fault fault, bool voice})>{
      'one failed append': (fault: _failOneAppend, voice: true),
      'one mic stream error': (fault: _failTheMicStream, voice: true),
      'one odd-length chunk': (fault: _sendAnOddLengthChunk, voice: true),
      'a failed close': (fault: _failTheClose, voice: false),
    };

Future<void> _recordAround(
  FakeMicrophone mic,
  FakeLiveAudio liveAudio,
  _Fault fault,
) async {
  for (int index = 0; index < _chunksEachSide; index += 1) {
    mic.push(silentPcm(_chunkSamples));
  }
  await _settle();
  await fault(mic, liveAudio);
  await _settle();
  for (int index = 0; index < _chunksEachSide; index += 1) {
    mic.push(silentPcm(_chunkSamples));
  }
  await _settle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late CameraPlatform original;

  setUp(() {
    root = Directory.systemTemp.createTempSync('take_survives_sound_failure_');
    original = CameraPlatform.instance;
  });

  tearDown(() {
    CameraPlatform.instance = original;
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  RecordVoiceRecorder voiceRecorder(
    FakeMicrophone mic,
    FakeLiveAudio liveAudio,
    VoiceChainRunner chainRunner, {
    int volume = 100,
  }) {
    final RecordVoiceRecorder recorder = RecordVoiceRecorder(
      recorder: mic,
      encoder: liveAudio,
      chainRunner: chainRunner,
      temporaryDirectory: () async => root,
      resolveInput: () async =>
          const AudioInput(id: null, label: 'System default'),
      resolveProcessing: () async =>
          (profile: InputProfile.voiceIsolation, volume: volume),
    );
    addTearDown(recorder.dispose);
    return recorder;
  }

  for (final MapEntry<String, ({_Fault fault, bool voice})> entry
      in _faults.entries) {
    if (entry.value.voice) {
      test('voice: ${entry.key} still keeps the whole take', () async {
        final FakeMicrophone mic = FakeMicrophone();
        final FakeLiveAudio liveAudio = FakeLiveAudio();
        final RecordVoiceRecorder recorder = voiceRecorder(
          mic,
          liveAudio,
          _studio,
        );

        await recorder.start();
        await _recordAround(mic, liveAudio, entry.value.fault);
        final VoiceRecording take = await recorder.stop();

        final File kept = (take.media as CaptureFile).file;
        expect(kept.path, liveAudio.soundPath);
        expect(kept.existsSync(), isTrue);
        expect(liveAudio.closes, 1);
        expect(liveAudio.cancels, 0);
        expect(
          liveAudio.samplesAppended,
          greaterThanOrEqualTo(2 * _chunksEachSide * _chunkSamples),
          reason: 'chunks after the fault were dropped',
        );
      });
    }

    test('video: ${entry.key} still keeps the picture', () async {
      final _Camera camera = _Camera(root);
      CameraPlatform.instance = camera;
      final FakeMicrophone mic = FakeMicrophone();
      final FakeLiveAudio liveAudio = FakeLiveAudio();
      final CameraVideoRecorder recorder = CameraVideoRecorder(
        temporaryDirectory: () async => Directory(p.join(root.path, 'tmp')),
        encoder: liveAudio,
        audioJoiner: liveAudio,
        audioRecorderFactory: () => mic,
        chainRunner: _studio,
        resolveInput: () async =>
            const AudioInput(id: null, label: 'System default'),
      );
      addTearDown(recorder.dispose);
      final List<VideoCaptureDevice> devices = await recorder.listDevices();
      recorder.openSession(devices.single.id);

      await recorder.start();
      await _recordAround(mic, liveAudio, entry.value.fault);
      final VideoRecording take = await recorder.stop();

      final File kept = (take.media as CaptureFile).file;
      expect(kept.existsSync(), isTrue);
      expect(kept.readAsBytesSync(), isNotEmpty);
      expect(
        (take.thumbnail! as CaptureFile).file.existsSync(),
        isTrue,
        reason: 'the still was deleted on a sound-only failure',
      );
      if (liveAudio.closeFails) {
        expect(kept.path, camera.pictures.single);
        expect(liveAudio.joins, isEmpty);
      } else {
        expect(kept.path, liveAudio.joins.single.output);
      }
    });
  }

  test('a broken chain is never asked again and the input is written at its '
      'volume in line with the picture', () async {
    final FakeMicrophone mic = FakeMicrophone();
    final FakeLiveAudio liveAudio = FakeLiveAudio();
    final _ChainBreakingOnce chain = _ChainBreakingOnce(breaksOnChunk: 4);
    final RecordVoiceRecorder recorder = voiceRecorder(
      mic,
      liveAudio,
      ({required InputProfile profile, required int volume}) async => chain,
      volume: _brokenChainVolume,
    );

    await recorder.start();
    for (int index = 0; index < 2 * _chunksEachSide; index += 1) {
      mic.push(_countingChunk(index * 100));
    }
    await _settle();
    final VoiceRecording take = await recorder.stop();

    expect(chain.callsAfterBreak, 0);
    expect(liveAudio.cancels, 0);
    expect((take.media as CaptureFile).file.existsSync(), isTrue);
    expect(liveAudio.samplesAppended, 2 * _chunksEachSide * _chunkSamples);
    final List<int> written = _samplesOf(
      Uint8List.fromList(<int>[
        for (final Uint8List pcm in liveAudio.appended) ...pcm,
      ]),
    );
    final List<int> afterBreak = written.sublist(3 * _chunkSamples);
    final List<int> inputAfterBreak = <int>[
      for (int index = 3; index < 2 * _chunksEachSide; index += 1)
        ..._samplesOf(_countingChunk(index * 100)),
    ];
    expect(afterBreak, <int>[
      for (final int sample in inputAfterBreak)
        (sample * _brokenChainVolume / 100).round().clamp(-32768, 32767),
    ]);
  });
}
