import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/domain/settings/input_profile.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

const String _openLabel = 'open voice';
const String _clearingStatus = 'Clearing background noise…';
const String _adjustingStatus = 'Adjusting the volume…';
const int _takeMs = 2000;
const int _levelStepMs = 60;
const int _sampleRate = 48000;

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);
const MethodChannel _audioCleanChannel = MethodChannel(
  'field_notes/audio_clean',
);

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

class _Launcher extends ConsumerWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appSettingsProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showVoiceComposer(context, '2026-10-16'),
      child: const Text(_openLabel),
    );
  }
}

Uint8List _speechWav(int frames) {
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
    ..setUint32(24, _sampleRate, Endian.little)
    ..setUint32(28, _sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frames * 2, Endian.little);
  for (int frame = 0; frame < frames; frame += 1) {
    data.setInt16(
      44 + frame * 2,
      (sin(2 * pi * 220 * frame / _sampleRate) * 6000).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

File _platformThatCanCleanTakes(WidgetTester tester) {
  final Directory root = Directory.systemTemp.createTempSync('live-keep-');
  final Directory temporary = Directory('${root.path}/tmp')..createSync();
  final File take = File('${root.path}/take.m4a')
    ..writeAsBytesSync(<int>[1, 2, 3, 4]);
  final TestDefaultBinaryMessengerBinding binding = tester.binding;
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _pathProviderChannel,
    (MethodCall call) async => temporary.path,
  );
  binding.defaultBinaryMessenger.setMockMethodCallHandler(_audioCleanChannel, (
    MethodCall call,
  ) async {
    final Map<Object?, Object?> arguments =
        call.arguments as Map<Object?, Object?>;
    final String output = arguments['output']! as String;
    if (call.method == 'decodeAudio') {
      final int frames = _sampleRate * _takeMs ~/ 1000;
      File(output).writeAsBytesSync(_speechWav(frames));
      return <String, Object?>{
        'sampleRate': _sampleRate,
        'channels': 1,
        'frames': frames,
      };
    }
    File(output).writeAsBytesSync(<int>[9, 9, 9]);
    return output;
  });
  addTearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _audioCleanChannel,
      null,
    );
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });
  return take;
}

FakeVoiceRecorder _recorderWithTake(File take) => FakeVoiceRecorder(
  recording: VoiceRecording(
    media: CaptureFile(file: take, mime: 'audio/mp4', durationMs: _takeMs),
    durationMs: _takeMs,
  ),
);

Future<void> _pumpApp(
  WidgetTester tester, {
  required AppSettings settings,
  required FakeVoiceRecorder recorder,
  required FakeCaptureService service,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        voiceRecorderProvider.overrideWith((Ref ref) => recorder),
        captureServiceProvider.overrideWith((Ref ref) => service),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(settings),
        ),
        reflectionPromptsEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const Scaffold(body: Center(child: _Launcher())),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text(_openLabel));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _speakForTwoSeconds(
  WidgetTester tester,
  FakeVoiceRecorder recorder,
) async {
  await startVoiceTake(tester);
  for (int ms = 0; ms <= _takeMs; ms += _levelStepMs) {
    recorder.elapsed = Duration(milliseconds: ms);
    recorder.levels.add(0.6);
    await tester.pump(const Duration(milliseconds: _levelStepMs));
  }
  recorder.elapsed = const Duration(milliseconds: _takeMs);
}

Future<List<String>> _keepUntilToast(WidgetTester tester) async {
  final List<String> statusesSeen = <String>[];
  void lookForCleaningStatus() {
    for (final String status in <String>[_clearingStatus, _adjustingStatus]) {
      if (find.text(status).evaluate().isNotEmpty) {
        statusesSeen.add(status);
      }
    }
  }

  await tester.tap(find.byKey(voiceSavePillKey));
  for (int frame = 0; frame < 600; frame += 1) {
    await tester.pump(const Duration(milliseconds: 8));
    lookForCleaningStatus();
    if (find.text(voiceSavedToastMessage).evaluate().isNotEmpty) {
      return statusesSeen;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('the saved toast never appeared after Keep');
}

void main() {
  testWidgets('a voice isolation take keeps its peaks', (
    WidgetTester tester,
  ) async {
    final File take = _platformThatCanCleanTakes(tester);
    final FakeVoiceRecorder recorder = _recorderWithTake(take);
    final FakeCaptureService service = FakeCaptureService();
    await _pumpApp(
      tester,
      settings: AppSettings.defaults.copyWith(
        inputProfile: InputProfile.voiceIsolation,
      ),
      recorder: recorder,
      service: service,
    );

    await _speakForTwoSeconds(tester, recorder);
    await _keepUntilToast(tester);

    final VoiceCaptureRequest request =
        service.requests.single as VoiceCaptureRequest;
    expect(request.peaks, isNotEmpty);
    expect(request.peaks.reduce(max), greaterThanOrEqualTo(0.5));

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);

  testWidgets('keep never waits on cleaning', (WidgetTester tester) async {
    final File take = _platformThatCanCleanTakes(tester);
    final FakeVoiceRecorder recorder = _recorderWithTake(take);
    final FakeCaptureService service = FakeCaptureService();
    await _pumpApp(
      tester,
      settings: AppSettings.defaults.copyWith(
        inputProfile: InputProfile.voiceIsolation,
        inputVolume: 150,
      ),
      recorder: recorder,
      service: service,
    );

    await _speakForTwoSeconds(tester, recorder);
    final List<String> statusesSeen = await _keepUntilToast(tester);

    expect(statusesSeen, isEmpty);
    expect(service.requests, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);
}
