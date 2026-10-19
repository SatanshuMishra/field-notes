import 'dart:typed_data';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../settings/support/fake_settings_repository.dart';
import 'video/video_test_support.dart' show reflectionPromptsOff;

const int _mousePointerId = 41;
const int _mouseDevice = 1;
const int _darkHover = 0x1FFFFFFF;

enum _Shape { circle, pill, row }

class _Row {
  const _Row(this.key, this.label, this.shape);

  final Key key;
  final String label;
  final _Shape shape;
}

const List<_Row> _videoRows = <_Row>[
  _Row(ValueKey<String>('video-shutter'), 'Pause recording', _Shape.circle),
  _Row(ValueKey<String>('video-discard-circle'), 'Let go', _Shape.circle),
  _Row(ValueKey<String>('video-save-circle'), 'Keep', _Shape.circle),
];

const List<_Row> _voiceRows = <_Row>[
  _Row(
    ValueKey<String>('voice-record-button'),
    'Pause recording',
    _Shape.circle,
  ),
  _Row(ValueKey<String>('voice-discard-pill'), 'Let it go', _Shape.pill),
  _Row(ValueKey<String>('voice-save-pill'), 'Keep this', _Shape.pill),
];

const List<_Row> _panelRows = <_Row>[
  _Row(ValueKey<String>('input-device-row'), 'Input device', _Shape.row),
  _Row(ValueKey<String>('input-profile-row'), 'Input profile', _Shape.row),
  _Row(ValueKey<String>('output-device-row'), 'Output device', _Shape.row),
  _Row(ValueKey<String>('voice-settings-row'), 'Voice settings', _Shape.row),
];

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

void _desktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        reflectionPromptsOff(),
        audioInputListerProvider.overrideWithValue(
          () async => const <InputDevice>[
            InputDevice(id: 'a', label: 'MacBook Pro Microphone'),
          ],
        ),
        inputLevelRecorderProvider.overrideWithValue(_FakeRecorder.new),
        audioOutputProvider.overrideWithValue(_FakeOutput()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(backgroundColor: Palette.mediaGround, body: body),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<TestGesture> _mousePointer(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: _mousePointerId,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

bool _hasShape(BoxDecoration decoration, _Shape shape) => switch (shape) {
  _Shape.circle => decoration.shape == BoxShape.circle,
  _Shape.pill =>
    decoration.borderRadius == const BorderRadius.all(Radius.circular(24)),
  _Shape.row =>
    decoration.borderRadius == const BorderRadius.all(Radius.circular(10)),
};

Finder _hoverFill(_Row row) => find.descendant(
  of: find.byKey(row.key),
  matching: find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    return decoration is BoxDecoration &&
        decoration.color?.toARGB32() == _darkHover &&
        _hasShape(decoration, row.shape);
  }),
);

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

Future<void> _expectRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_Row> rows,
) async {
  await mouse.moveTo(Offset.zero);
  await tester.pump();
  for (final _Row row in rows) {
    expect(find.byKey(row.key), findsOneWidget, reason: row.label);
    expect(_hoverFill(row), findsNothing, reason: row.label);

    await mouse.moveTo(tester.getCenter(find.byKey(row.key)));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.click, reason: row.label);
    expect(_hoverFill(row), findsOneWidget, reason: row.label);
    expect(
      tester.getSemantics(find.byKey(row.key)),
      isSemantics(label: row.label, isButton: true),
      reason: row.label,
    );
  }
}

void main() {
  testWidgets('every recorder sheet control shows the click cursor and hover', (
    WidgetTester tester,
  ) async {
    _desktopView(tester);
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TestGesture mouse = await _mousePointer(tester);

    await _pump(
      tester,
      VideoRecorderSheet(
        phase: VideoRecorderPhase.recording,
        onStart: () {},
        onStop: () {},
        onLeave: () {},
        onPause: () {},
        onResume: () {},
        supportsPause: true,
      ),
    );
    await _expectRows(tester, mouse, _videoRows);

    await _pump(
      tester,
      VoiceRecorderSheet(
        phase: VoiceRecorderPhase.recording,
        onStart: () {},
        onStop: () {},
        onCancel: () {},
        onPause: () {},
        onResume: () {},
        onDiscard: () {},
      ),
    );
    await _expectRows(tester, mouse, _voiceRows);

    await _pump(tester, Center(child: InputPanel(onVoiceSettings: () {})));
    await _expectRows(tester, mouse, _panelRows);

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
