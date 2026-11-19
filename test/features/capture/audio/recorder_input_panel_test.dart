import 'dart:async';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../../settings/support/fake_settings_repository.dart';
import '../video/video_test_support.dart'
    show fakeVideoDevices, reflectionPromptsOff;

const double _tolerance = 0.5;

const InputDevice _macBook = InputDevice(
  id: 'a',
  label: 'MacBook Pro Microphone',
);
const InputDevice _corsair = InputDevice(id: 'b', label: 'CORSAIR HS80 MAX');

class _FakeRecorder extends Fake implements AudioRecorder {
  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async =>
      const Stream<Uint8List>.empty();

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> dispose() async {}
}

class _FakeOutput extends AudioOutput {
  _FakeOutput();

  @override
  Future<String?> defaultOutputName() async => 'MacBook Pro Speakers';

  @override
  Future<void> openSoundSettings() async {}
}

const Set<VideoRecorderPhase> _videoShowsInput = <VideoRecorderPhase>{
  VideoRecorderPhase.idle,
  VideoRecorderPhase.breathing,
  VideoRecorderPhase.arming,
  VideoRecorderPhase.recording,
  VideoRecorderPhase.paused,
};

List<Override> _audioOverrides({
  AudioRecorderFactory microphone = _FakeRecorder.new,
}) => <Override>[
  audioInputListerProvider.overrideWithValue(
    () async => const <InputDevice>[_macBook, _corsair],
  ),
  inputLevelRecorderProvider.overrideWithValue(microphone),
  audioOutputProvider.overrideWithValue(_FakeOutput()),
];

void _desktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _phoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(384, 832);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24);
  addTearDown(tester.view.reset);
}

int _litSegments(WidgetTester tester, Color ink) => <int>[
  for (int index = 0; index < inputLevelSegments; index++)
    if ((tester
                    .widget<DecoratedBox>(
                      find.byKey(inputLevelSegmentKey(index)),
                    )
                    .decoration
                as BoxDecoration)
            .color ==
        ink)
      index,
].length;

Future<void> _pumpSheet(
  WidgetTester tester,
  TargetPlatform platform,
  Widget sheet, {
  AudioRecorderFactory microphone = _FakeRecorder.new,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        reflectionPromptsOff(),
        ..._audioOverrides(microphone: microphone),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(body: sheet),
      ),
    ),
  );
  await tester.pump();
}

VoiceRecorderSheet _voiceSheet(
  VoiceRecorderPhase phase, {
  VoidCallback? onStart,
  VoidCallback? onCancel,
  Stream<double> levels = const Stream<double>.empty(),
}) => VoiceRecorderSheet(
  phase: phase,
  levels: levels,
  onStart: onStart ?? () {},
  onStop: () {},
  onCancel: onCancel ?? () {},
  onPause: () {},
  onResume: () {},
);

VideoRecorderSheet _videoSheet(
  VideoRecorderPhase phase, {
  Stream<double> levels = const Stream<double>.empty(),
}) => VideoRecorderSheet(
  phase: phase,
  levels: levels,
  onStart: () {},
  onStop: () {},
  onLeave: () {},
  onPause: () {},
  onResume: () {},
  supportsPause: true,
  devices: fakeVideoDevices,
  selectedDeviceId: fakeVideoDevices.first.id,
  onDeviceChanged: (String id) {},
  onCameraChanged: (bool on) {},
);

Color? _panelInkOf(WidgetTester tester, String text) => tester
    .renderObject<RenderParagraph>(
      find.descendant(of: find.byType(InputPanel), matching: find.text(text)),
    )
    .text
    .style
    ?.color;

GlassTone _panelTone(WidgetTester tester) => tester
    .widget<GlassSurface>(
      find
          .descendant(
            of: find.byType(InputPanel),
            matching: find.byType(GlassSurface),
          )
          .first,
    )
    .tone;

void main() {
  testWidgets(
    'the input panel takes paper inks in the light voice room and media inks in the video recorder',
    (WidgetTester tester) async {
      _desktopView(tester);
      const FieldNotesColors paper = FieldNotesColors.light;
      final List<(String, Widget, GlassTone, Color, Color)> rooms =
          <(String, Widget, GlassTone, Color, Color)>[
            (
              'voice',
              _voiceSheet(VoiceRecorderPhase.idle),
              GlassTone.paper,
              paper.ink,
              paper.mutedInkStrong,
            ),
            (
              'video',
              _videoSheet(VideoRecorderPhase.idle),
              GlassTone.media,
              Palette.mediaInk,
              Palette.mediaInk.withValues(alpha: 0.68),
            ),
          ];
      for (final (
            String room,
            Widget sheet,
            GlassTone tone,
            Color ink,
            Color mutedInk,
          )
          in rooms) {
        await _pumpSheet(tester, TargetPlatform.macOS, sheet);
        await tester.tap(find.byKey(recorderInputKey));
        await tester.pump();
        await tester.pump();

        expect(_panelTone(tester), tone, reason: room);
        for (final String title in const <String>[
          inputDeviceTitle,
          inputProfileTitle,
          inputVolumeTitle,
          outputDeviceTitle,
        ]) {
          expect(_panelInkOf(tester, title), ink, reason: '$room $title');
        }
        expect(_panelInkOf(tester, inputLevelLabel), mutedInk, reason: room);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the voice recorder opens the input panel from its trailing controls',
    (WidgetTester tester) async {
      _desktopView(tester);
      int left = 0;
      int started = 0;
      await _pumpSheet(
        tester,
        TargetPlatform.macOS,
        _voiceSheet(
          VoiceRecorderPhase.idle,
          onStart: () => started++,
          onCancel: () => left++,
        ),
      );

      final Finder input = find.byKey(recorderInputKey);
      expect(input, findsOneWidget);
      expect(
        tester.getSemantics(input),
        isSemantics(label: 'Input', isButton: true),
      );
      final Rect button = tester.getRect(input);
      final Rect hint = tester.getRect(find.byKey(voiceKeyHintKey));
      expect(button.left, greaterThanOrEqualTo(hint.right));
      expect(
        (button.center.dy - hint.center.dy).abs(),
        lessThanOrEqualTo(button.height / 2),
      );
      expect(find.byType(InputPanel), findsNothing);

      await tester.tap(input);
      await tester.pump();
      await tester.pump();

      final Finder panel = find.byType(InputPanel);
      expect(panel, findsOneWidget);
      final Rect panelRect = tester.getRect(panel);
      expect(panelRect.top, greaterThanOrEqualTo(button.bottom));
      expect(panelRect.right, moreOrLessEquals(button.right, epsilon: 1));

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(started, 0);
      expect(find.byType(InputPanel), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byType(InputPanel), findsNothing);
      expect(left, 0);
      expect(started, 0);
      expect(input, findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the video recorder opens the input panel from its trailing controls',
    (WidgetTester tester) async {
      _phoneView(tester);
      await _pumpSheet(
        tester,
        TargetPlatform.android,
        _videoSheet(VideoRecorderPhase.idle),
      );

      final Finder input = find.byKey(recorderInputKey);
      expect(input, findsOneWidget);
      final Rect button = tester.getRect(input);
      final Rect flip = tester.getRect(find.byKey(videoFlipCameraKey));
      final Rect camera = tester.getRect(find.byKey(videoCameraKey));
      expect(camera.left, greaterThanOrEqualTo(flip.right - _tolerance));
      expect(button.left, greaterThanOrEqualTo(camera.right - _tolerance));
      expect(
        (button.center.dy - camera.center.dy).abs(),
        lessThanOrEqualTo(_tolerance),
      );

      await tester.tap(input);
      await tester.pump();
      await tester.pump();

      final Finder panel = find.byType(InputPanel);
      expect(panel, findsOneWidget);
      expect(tester.getRect(panel).top, greaterThanOrEqualTo(button.bottom));
      expect(
        find.descendant(
          of: find.byKey(inputDeviceRowKey),
          matching: find.text('Chosen by Android'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(inputProfileRowKey));
      await tester.pump();
      await tester.pump();
      expect(find.byType(InputPanel), findsOneWidget);

      await tester.tapAt(const Offset(40, 600));
      await tester.pump();
      await tester.pump();
      expect(find.byType(InputPanel), findsNothing);
      expect(input, findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('the input button stays through a take and hides while saving', (
    WidgetTester tester,
  ) async {
    _desktopView(tester);
    for (final VoiceRecorderPhase phase in VoiceRecorderPhase.values) {
      await _pumpSheet(tester, TargetPlatform.macOS, _voiceSheet(phase));
      expect(
        find.byKey(recorderInputKey),
        phase == VoiceRecorderPhase.saving ? findsNothing : findsOneWidget,
        reason: 'voice ${phase.name}',
      );
    }
    for (final VideoRecorderPhase phase in VideoRecorderPhase.values) {
      await _pumpSheet(tester, TargetPlatform.macOS, _videoSheet(phase));
      expect(
        find.byKey(recorderInputKey),
        _videoShowsInput.contains(phase) ? findsOneWidget : findsNothing,
        reason: 'video ${phase.name}',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the input panel meter follows the take while recording', (
    WidgetTester tester,
  ) async {
    _desktopView(tester);
    final StreamController<double> take = StreamController<double>.broadcast();
    addTearDown(take.close);
    int microphonesOpened = 0;
    final List<(String, Widget, Color)> sheets = <(String, Widget, Color)>[
      for (final VoiceRecorderPhase phase in <VoiceRecorderPhase>[
        VoiceRecorderPhase.recording,
        VoiceRecorderPhase.paused,
      ])
        (
          'voice ${phase.name}',
          _voiceSheet(phase, levels: take.stream),
          FieldNotesColors.light.ink,
        ),
      for (final VideoRecorderPhase phase in <VideoRecorderPhase>[
        VideoRecorderPhase.recording,
        VideoRecorderPhase.paused,
      ])
        (
          'video ${phase.name}',
          _videoSheet(phase, levels: take.stream),
          Palette.mediaInk,
        ),
    ];
    for (final (String name, Widget sheet, Color ink) in sheets) {
      await _pumpSheet(
        tester,
        TargetPlatform.macOS,
        sheet,
        microphone: () {
          microphonesOpened++;
          return _FakeRecorder();
        },
      );
      final Finder input = find.byKey(recorderInputKey);
      expect(input, findsOneWidget, reason: name);
      await tester.tap(input);
      await tester.pump();
      await tester.pump();
      expect(find.byType(InputPanel), findsOneWidget, reason: name);

      take.add(0.6);
      await tester.pump();
      await tester.pump();

      expect(_litSegments(tester, ink), 12, reason: name);
    }
    expect(microphonesOpened, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
