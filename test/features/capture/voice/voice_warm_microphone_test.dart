import 'dart:io';

import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/voice/record_voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../audio/live_audio_test_support.dart';

const Duration _chunkEvery = Duration(milliseconds: 100);
const Duration _poll = Duration(milliseconds: 10);
const Duration _rearmWait = Duration(seconds: 1);
const Duration _cannotHearWait = Duration(seconds: 4);
const int _samplesPerChunk = 4800;
const AudioInput _systemDefault = AudioInput(id: null, label: 'System default');
const AudioInput _usbMicrophone = AudioInput(
  id: 'usb-mic',
  label: 'USB microphone',
);

typedef _WarmVoice = ({
  RecordVoiceRecorder recorder,
  FakeMicrophone microphone,
  FakeLiveAudio sound,
});

Future<_WarmVoice> _warmVoice({
  Future<AudioInput> Function()? resolveInput,
}) async {
  final Directory temp = await Directory.systemTemp.createTemp(
    'voice_warm_microphone_',
  );
  addTearDown(() => temp.delete(recursive: true));
  final FakeMicrophone microphone = FakeMicrophone();
  final FakeLiveAudio sound = FakeLiveAudio();
  final RecordVoiceRecorder recorder = RecordVoiceRecorder(
    recorder: microphone,
    encoder: sound,
    chainRunner: passThroughChain,
    temporaryDirectory: () async => temp,
    resolveInput: resolveInput ?? () async => _systemDefault,
  );
  addTearDown(recorder.dispose);
  return (recorder: recorder, microphone: microphone, sound: sound);
}

Future<void> _speakFor(FakeMicrophone microphone, int chunks) async {
  for (int chunk = 0; chunk < chunks; chunk += 1) {
    await Future<void>.delayed(_chunkEvery);
    microphone.push(pcmAtDbfs(-20, samples: _samplesPerChunk));
  }
}

Future<void> _waitForStreams(FakeMicrophone microphone, int streams) async {
  final Stopwatch waited = Stopwatch()..start();
  while (microphone.streamsOpened < streams && waited.elapsed < _rearmWait) {
    await Future<void>.delayed(_poll);
  }
}

Future<void> _waitUntilCannotHear(RecordVoiceRecorder recorder) async {
  final Stopwatch waited = Stopwatch()..start();
  while (recorder.hearingNow != MicrophoneHearing.cannotHear &&
      waited.elapsed < _cannotHearWait) {
    await Future<void>.delayed(_poll);
  }
}

void main() {
  test('a voice take uses the microphone opened with the recorder', () async {
    final _WarmVoice voice = await _warmVoice();

    await voice.recorder.open();
    expect(voice.microphone.startStreamConfigs, hasLength(1));
    await _speakFor(voice.microphone, 2);

    await voice.recorder.start();
    await _speakFor(voice.microphone, 3);

    expect(voice.microphone.startStreamConfigs, hasLength(1));
    expect(voice.sound.opened, hasLength(1));
    expect(voice.sound.samplesAppended, greaterThan(0));

    final int eventsBeforeClose = voice.microphone.events.length;
    await voice.recorder.close();

    final List<String> afterClose = voice.microphone.events.sublist(
      eventsBeforeClose,
    );
    expect(afterClose, contains('mic.cancel'));
    expect(afterClose, isNot(contains('mic.start')));
    expect(voice.microphone.startStreamConfigs, hasLength(1));
  });

  test(
    'a kept voice take leaves the microphone open for the next take',
    () async {
      final _WarmVoice voice = await _warmVoice();

      await voice.recorder.open();
      await voice.recorder.start();
      await _speakFor(voice.microphone, 3);
      final VoiceRecording first = await voice.recorder.stop();
      expect(first.durationMs, greaterThan(0));

      await _waitForStreams(voice.microphone, 2);
      expect(voice.microphone.startStreamConfigs, hasLength(2));

      await voice.recorder.start();
      await _speakFor(voice.microphone, 3);
      final VoiceRecording second = await voice.recorder.stop();

      expect(second.durationMs, greaterThan(0));
      expect(second.media, isNot(first.media));
      await _waitForStreams(voice.microphone, 3);
      expect(voice.microphone.startStreamConfigs, hasLength(3));

      await voice.recorder.close();
      await Future<void>.delayed(_rearmWait);
      expect(voice.microphone.startStreamConfigs, hasLength(3));
    },
  );

  test(
    'a take on an input chosen after opening reopens on that input',
    () async {
      AudioInput chosen = _systemDefault;
      final _WarmVoice voice = await _warmVoice(
        resolveInput: () async => chosen,
      );

      await voice.recorder.open();
      expect(voice.microphone.startStreamConfigs.single.device, isNull);

      chosen = _usbMicrophone;
      await voice.recorder.start();

      expect(voice.microphone.startStreamConfigs, hasLength(2));
      expect(voice.microphone.startStreamConfigs.last.device?.id, 'usb-mic');

      await voice.recorder.cancel();
      await _waitForStreams(voice.microphone, 3);
      expect(voice.microphone.startStreamConfigs, hasLength(3));
      await voice.recorder.close();
    },
  );

  test('a take without opening first still opens the microphone', () async {
    final _WarmVoice voice = await _warmVoice();

    await voice.recorder.start();
    await _speakFor(voice.microphone, 2);
    await voice.recorder.stop();
    await Future<void>.delayed(_chunkEvery);

    expect(voice.microphone.startStreamConfigs, hasLength(1));
    expect(voice.sound.samplesAppended, greaterThan(0));
  });

  test(
    'a voice recorder closed while it cannot hear no longer reports it',
    () async {
      final _WarmVoice voice = await _warmVoice();

      await voice.recorder.open();
      await _waitUntilCannotHear(voice.recorder);
      expect(voice.recorder.hearingNow, MicrophoneHearing.cannotHear);

      await voice.recorder.close();

      expect(voice.recorder.hearingNow, isNot(MicrophoneHearing.cannotHear));
    },
  );

  test('an open voice recorder that cannot hear moves to an input chosen after '
      'opening', () async {
    AudioInput chosen = _systemDefault;
    final _WarmVoice voice = await _warmVoice(resolveInput: () async => chosen);

    await voice.recorder.open();
    await _waitUntilCannotHear(voice.recorder);
    expect(voice.recorder.hearingNow, MicrophoneHearing.cannotHear);

    chosen = _usbMicrophone;
    await voice.recorder.open();

    expect(voice.microphone.startStreamConfigs.last.device?.id, 'usb-mic');
    expect(voice.recorder.hearingNow, isNot(MicrophoneHearing.cannotHear));
    await voice.recorder.close();
  });

  test(
    'an open voice recorder follows a newly chosen input when told to',
    () async {
      AudioInput chosen = _systemDefault;
      final _WarmVoice voice = await _warmVoice(
        resolveInput: () async => chosen,
      );
      await voice.recorder.open();

      chosen = _usbMicrophone;
      await voice.recorder.followChosenInput();

      expect(voice.microphone.startStreamConfigs.last.device?.id, 'usb-mic');
      await voice.recorder.close();
    },
  );

  test('a closed voice recorder stays closed when told to follow', () async {
    AudioInput chosen = _systemDefault;
    final _WarmVoice voice = await _warmVoice(resolveInput: () async => chosen);
    await voice.recorder.open();
    await voice.recorder.close();
    final int opened = voice.microphone.streamsOpened;

    chosen = _usbMicrophone;
    await voice.recorder.followChosenInput();

    expect(voice.microphone.streamsOpened, opened);
  });
}
