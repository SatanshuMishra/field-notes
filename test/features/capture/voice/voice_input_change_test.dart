import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/features/capture/voice/follows_chosen_input.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../settings/support/fake_settings_repository.dart';
import 'voice_test_support.dart';

class _FollowingVoiceRecorder extends FakeVoiceRecorder
    implements FollowsChosenInput {
  int follows = 0;

  @override
  Future<void> followChosenInput() async {
    follows++;
  }
}

Future<(_FollowingVoiceRecorder, FakeSettingsRepository)> _openVoiceSheet(
  WidgetTester tester,
) async {
  final FakeSettingsRepository settings = FakeSettingsRepository(
    initial: AppSettings.defaults.copyWith(audioInputId: 'headset'),
  );
  final _FollowingVoiceRecorder voice = _FollowingVoiceRecorder();
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        voiceRecorderProvider.overrideWith((Ref ref) => voice),
        settingsRepositoryProvider.overrideWithValue(settings),
        reflectionPromptsEnabledProvider.overrideWithValue(false),
      ],
      child: const MaterialApp(
        home: Scaffold(body: VoiceComposerConnector(date: '2026-10-19')),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return (voice, settings);
}

void main() {
  testWidgets(
    'choosing another input while the voice recorder is open makes it follow',
    (WidgetTester tester) async {
      final (_FollowingVoiceRecorder voice, FakeSettingsRepository settings) =
          await _openVoiceSheet(tester);
      expect(voice.follows, 0);

      settings.emit(settings.initial.copyWith(audioInputId: 'built-in'));
      await tester.pump();

      expect(voice.follows, 1);
    },
  );

  testWidgets('a settings change that keeps the input does not reopen it', (
    WidgetTester tester,
  ) async {
    final (_FollowingVoiceRecorder voice, FakeSettingsRepository settings) =
        await _openVoiceSheet(tester);

    settings.emit(settings.initial.copyWith(inputVolume: 60));
    await tester.pump();

    expect(voice.follows, 0);
  });
}
