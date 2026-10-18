import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../../settings/support/fake_settings_repository.dart';

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
  _FakeOutput(this.name);

  final String? name;
  int opened = 0;

  @override
  Future<String?> defaultOutputName() async => name;

  @override
  Future<List<AudioOutputDevice>> listOutputs() async => <AudioOutputDevice>[
    const AudioOutputDevice(id: null, name: 'System output'),
    if (name != null) AudioOutputDevice(id: 'speakers', name: name!),
  ];

  @override
  Future<void> openSoundSettings() async {
    opened++;
  }
}

class _Lister {
  _Lister(this.devices);

  List<InputDevice> devices;

  Future<List<InputDevice>> call() async => devices;
}

Future<void> _show(
  WidgetTester tester, {
  required TargetPlatform platform,
  required FakeSettingsRepository repository,
  required _Lister lister,
  required _FakeOutput output,
  bool phone = false,
  bool androidVideo = false,
}) async {
  tester.view.physicalSize = phone
      ? const Size(384, 832)
      : const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  if (phone) {
    tester.view.padding = const FakeViewPadding(top: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24);
  }
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
        audioInputListerProvider.overrideWithValue(lister.call),
        audioOutputProvider.overrideWithValue(output),
        inputLevelRecorderProvider.overrideWithValue(_FakeRecorder.new),
      ],
      child: MaterialApp(
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(
          backgroundColor: Palette.mediaGround,
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: InputPanel(androidVideo: androidVideo),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inRow(Key row, String text) =>
    find.descendant(of: find.byKey(row), matching: find.text(text));

void main() {
  testWidgets('the input panel shows its rows on a glass surface', (
    WidgetTester tester,
  ) async {
    await _show(
      tester,
      platform: TargetPlatform.macOS,
      repository: FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(
          inputProfile: InputProfile.studio,
          inputVolume: 100,
        ),
      ),
      lister: _Lister(<InputDevice>[_macBook, _corsair]),
      output: _FakeOutput('MacBook Pro Speakers'),
    );

    final Finder glass = find.byType(GlassSurface);
    expect(glass, findsOneWidget);
    Finder inGlass(Finder finder) =>
        find.descendant(of: glass, matching: finder);
    final List<(Finder, Finder?)> rows = <(Finder, Finder?)>[
      (
        inGlass(find.text('Input device')),
        inGlass(find.text('System default')),
      ),
      (inGlass(find.text('Input profile')), inGlass(find.text('Studio'))),
      (inGlass(find.text('Input volume')), inGlass(find.text('100%'))),
      (inGlass(find.byType(InputLevelMeter)), null),
      (
        inGlass(find.text('Output device')),
        inGlass(find.text('System output')),
      ),
      (inGlass(find.text('Voice settings')), null),
    ];
    double previous = double.negativeInfinity;
    for (final (Finder title, Finder? value) in rows) {
      expect(title, findsOneWidget);
      final double top = tester.getRect(title).top;
      expect(top, greaterThan(previous));
      previous = top;
      if (value != null) {
        expect(value, findsOneWidget);
        expect(
          tester.getCenter(value).dy,
          moreOrLessEquals(tester.getCenter(title).dy, epsilon: 1),
        );
        expect(
          tester.getRect(value).left,
          greaterThan(tester.getRect(title).left),
        );
      }
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('choosing an input and a profile stores them', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository(
      initial: AppSettings.defaults.copyWith(
        inputProfile: InputProfile.studio,
        inputVolume: 100,
      ),
    );
    await _show(
      tester,
      platform: TargetPlatform.macOS,
      repository: repository,
      lister: _Lister(<InputDevice>[_macBook, _corsair]),
      output: _FakeOutput('MacBook Pro Speakers'),
    );

    final double volumeTop = tester.getRect(find.byKey(inputVolumeRowKey)).top;
    await tester.tap(find.byKey(inputDeviceRowKey));
    await tester.pumpAndSettle();
    Finder inDeviceMenu(Key key) => find.descendant(
      of: find.byKey(inputDeviceMenuKey),
      matching: find.byKey(key),
    );
    expect(inDeviceMenu(inputChoiceKey(null)), findsOneWidget);
    expect(inDeviceMenu(inputChoiceKey('a')), findsOneWidget);
    expect(inDeviceMenu(inputChoiceKey('b')), findsOneWidget);
    expect(tester.getRect(find.byKey(inputVolumeRowKey)).top, volumeTop);
    await tester.tap(find.byKey(inputChoiceKey('b')));
    await tester.pumpAndSettle();
    expect(repository.audioInputIdWrites, <String?>['b']);
    expect(_inRow(inputDeviceRowKey, 'CORSAIR HS80 MAX'), findsOneWidget);
    expect(find.byKey(inputChoiceKey('b')), findsNothing);
    expect(find.byKey(inputDeviceMenuKey), findsNothing);

    await tester.tap(find.byKey(inputDeviceRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(inputChoiceKey(null)));
    await tester.pumpAndSettle();
    expect(repository.audioInputIdWrites, <String?>['b', null]);
    expect(_inRow(inputDeviceRowKey, 'System default'), findsOneWidget);

    await tester.tap(find.byKey(inputProfileRowKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(inputProfileChoiceKey(InputProfile.voiceIsolation)),
    );
    await tester.pumpAndSettle();
    expect(_inRow(inputProfileRowKey, 'Voice Isolation'), findsOneWidget);

    await tester.tap(find.byKey(inputProfileRowKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(inputProfileChoiceKey(InputProfile.voiceIsolation)),
    );
    await tester.pumpAndSettle();
    expect(repository.inputProfileWrites, <InputProfile>[
      InputProfile.voiceIsolation,
    ]);
    expect(_inRow(inputProfileRowKey, 'Voice Isolation'), findsOneWidget);
    expect(
      find.byKey(inputProfileChoiceKey(InputProfile.studio)),
      findsNothing,
    );
    expect(repository.audioInputIdWrites, <String?>['b', null]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the device menu follows the arrow keys and Enter', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _show(
      tester,
      platform: TargetPlatform.macOS,
      repository: repository,
      lister: _Lister(<InputDevice>[_macBook, _corsair]),
      output: _FakeOutput('MacBook Pro Speakers'),
    );

    await tester.tap(find.byKey(inputDeviceRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(inputDeviceMenuKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(repository.audioInputIdWrites, <String?>['b']);
    expect(find.byKey(inputDeviceMenuKey), findsNothing);
    expect(_inRow(inputDeviceRowKey, 'CORSAIR HS80 MAX'), findsOneWidget);

    await tester.tap(find.byKey(inputDeviceRowKey));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 790));
    await tester.pumpAndSettle();
    expect(find.byKey(inputDeviceMenuKey), findsNothing);
    expect(repository.audioInputIdWrites, <String?>['b']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the volume slider stores on release', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository(
      initial: AppSettings.defaults.copyWith(
        inputProfile: InputProfile.voiceIsolation,
        inputVolume: 100,
      ),
    );
    final _FakeOutput output = _FakeOutput(null);
    await _show(
      tester,
      platform: TargetPlatform.windows,
      repository: repository,
      lister: _Lister(<InputDevice>[_macBook, _corsair]),
      output: output,
    );
    expect(_inRow(inputVolumeRowKey, '100%'), findsOneWidget);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await tester.pump();
    for (
      int step = 0;
      step < 600 && _inRow(inputVolumeRowKey, '150%').evaluate().isEmpty;
      step++
    ) {
      await gesture.moveBy(const Offset(0.5, 0));
      await tester.pump();
    }
    expect(_inRow(inputVolumeRowKey, '150%'), findsOneWidget);
    expect(repository.inputVolumeWrites, isEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repository.inputVolumeWrites, <int>[150]);
    expect(_inRow(inputVolumeRowKey, '150%'), findsOneWidget);

    await tester.tap(find.byKey(inputProfileRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(inputProfileChoiceKey(InputProfile.studio)));
    await tester.pumpAndSettle();
    expect(repository.inputProfileWrites, <InputProfile>[InputProfile.studio]);
    expect(_inRow(inputProfileRowKey, 'Studio'), findsOneWidget);
    expect(repository.inputVolumeWrites, <int>[150]);

    expect(_inRow(outputDeviceRowKey, 'Output device'), findsOneWidget);
    expect(_inRow(outputDeviceRowKey, 'System output'), findsOneWidget);
    await tester.tap(find.byKey(outputDeviceRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(outputDeviceMenuKey), findsOneWidget);
    expect(output.opened, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'a device that vanishes while the list is open falls back to the default',
    (WidgetTester tester) async {
      final FakeSettingsRepository repository = FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(audioInputId: 'a'),
      );
      final _Lister lister = _Lister(<InputDevice>[_macBook, _corsair]);
      await _show(
        tester,
        platform: TargetPlatform.macOS,
        repository: repository,
        lister: lister,
        output: _FakeOutput('MacBook Pro Speakers'),
      );
      expect(
        _inRow(inputDeviceRowKey, 'MacBook Pro Microphone'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(inputDeviceRowKey));
      await tester.pumpAndSettle();
      expect(find.byKey(inputChoiceKey('b')), findsOneWidget);

      lister.devices = const <InputDevice>[];
      await tester.tap(find.byKey(inputChoiceKey('b')));
      await tester.pumpAndSettle();

      expect(repository.audioInputIdWrites, <String?>[null]);
      expect(_inRow(inputDeviceRowKey, 'System default'), findsOneWidget);
      expect(find.byKey(inputChoiceKey('b')), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('on Android the video panel leaves the microphone to Android', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository videoRepository = FakeSettingsRepository();
    await _show(
      tester,
      platform: TargetPlatform.android,
      repository: videoRepository,
      lister: _Lister(<InputDevice>[_macBook, _corsair]),
      output: _FakeOutput('Phone speaker'),
      phone: true,
      androidVideo: true,
    );
    expect(_inRow(inputDeviceRowKey, 'Chosen by Android'), findsOneWidget);
    await tester.tap(find.byKey(inputDeviceRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(inputChoiceKey(null)), findsNothing);
    expect(find.text('MacBook Pro Microphone'), findsNothing);
    expect(find.text('CORSAIR HS80 MAX'), findsNothing);
    expect(find.text('Output device'), findsNothing);
    expect(find.byKey(outputDeviceRowKey), findsNothing);
    expect(videoRepository.audioInputIdWrites, isEmpty);

    await _show(
      tester,
      platform: TargetPlatform.android,
      repository: FakeSettingsRepository(),
      lister: _Lister(<InputDevice>[_macBook, _corsair]),
      output: _FakeOutput('Phone speaker'),
      phone: true,
    );
    expect(_inRow(inputDeviceRowKey, 'System default'), findsOneWidget);
    await tester.tap(find.byKey(inputDeviceRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(inputChoiceKey(null)), findsOneWidget);
    expect(find.text('MacBook Pro Microphone'), findsOneWidget);
    expect(find.text('CORSAIR HS80 MAX'), findsOneWidget);
    expect(find.text('Output device'), findsNothing);
    expect(find.byKey(outputDeviceRowKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
