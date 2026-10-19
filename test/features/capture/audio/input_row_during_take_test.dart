import 'dart:async';
import 'dart:typed_data';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../../settings/support/fake_settings_repository.dart';

const AudioInput _corsair = AudioInput(id: 'b', label: 'CORSAIR HS80 MAX');

class _FakeRecorder extends Fake implements AudioRecorder {
  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async =>
      StreamController<Uint8List>().stream;

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> dispose() async {}
}

class _FakeOutput extends AudioOutput {
  @override
  Future<String?> defaultOutputName() async => 'MacBook Pro Speakers';

  @override
  Future<List<AudioOutputDevice>> listOutputs() async =>
      const <AudioOutputDevice>[
        AudioOutputDevice(id: null, name: 'System output'),
      ];

  @override
  Future<void> openSoundSettings() async {}
}

void main() {
  testWidgets(
    "the input row shows the take's microphone while the device list is loading",
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final Completer<List<InputDevice>> listing =
          Completer<List<InputDevice>>();
      final StreamController<double> takeLevels =
          StreamController<double>.broadcast();
      addTearDown(takeLevels.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            settingsRepositoryProvider.overrideWithValue(
              FakeSettingsRepository(
                initial: AppSettings.defaults.copyWith(audioInputId: 'b'),
              ),
            ),
            audioInputListerProvider.overrideWithValue(() => listing.future),
            selectedAudioInputProvider.overrideWith(
              (Ref ref) async => _corsair,
            ),
            audioOutputProvider.overrideWithValue(_FakeOutput()),
            inputLevelRecorderProvider.overrideWithValue(_FakeRecorder.new),
          ],
          child: MaterialApp(
            theme: fieldNotesTheme(platform: TargetPlatform.macOS),
            home: Scaffold(
              backgroundColor: Palette.mediaGround,
              body: Align(
                alignment: Alignment.topCenter,
                child: InputPanel(takeLevels: takeLevels.stream),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(inputDeviceRowKey),
          matching: find.text(_corsair.label),
        ),
        findsOneWidget,
      );
      final SemanticsNode row = tester.getSemantics(
        find.byKey(inputDeviceRowKey),
      );
      expect(row.label, contains(_corsair.label));
      expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

      await tester.tap(find.byKey(inputDeviceRowKey), warnIfMissed: false);
      await tester.pump();
      expect(find.byKey(inputDeviceMenuKey), findsNothing);
      semantics.dispose();
    },
  );
}
