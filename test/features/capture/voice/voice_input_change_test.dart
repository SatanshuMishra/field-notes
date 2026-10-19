import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../../settings/support/fake_settings_repository.dart';
import 'voice_test_support.dart';

const List<InputDevice> _inputs = <InputDevice>[
  InputDevice(id: 'headset', label: 'Muted headset'),
  InputDevice(id: 'built-in', label: 'Built-in microphone'),
];

void main() {
  testWidgets(
    'choosing another input while the voice recorder cannot hear reopens '
    'the microphone',
    (WidgetTester tester) async {
      final FakeSettingsRepository settings = FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(audioInputId: 'headset'),
      );
      final FakeVoiceRecorder voice = FakeVoiceRecorder()
        ..hearingNow = MicrophoneHearing.cannotHear;
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            voiceRecorderProvider.overrideWith((Ref ref) => voice),
            settingsRepositoryProvider.overrideWithValue(settings),
            audioInputListerProvider.overrideWithValue(() async => _inputs),
            reflectionPromptsEnabledProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VoiceComposerConnector(date: '2026-10-19')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(voice.openCalls, 1);

      await settings.setAudioInputId('built-in');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(voice.openCalls, 2);
    },
  );
}
