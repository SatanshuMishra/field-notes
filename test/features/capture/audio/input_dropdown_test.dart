import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../../../support/sync_overrides.dart';
import '../../../support/update_overrides.dart';
import '../../settings/support/fake_settings_repository.dart';
import '../../settings/support/recording_reminder_scheduler.dart';

const InputDevice _macBook = InputDevice(
  id: 'a',
  label: 'MacBook Pro Microphone',
);
const InputDevice _headphones = InputDevice(id: 'b', label: 'WH-1000XM5');

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
  Future<List<AudioOutputDevice>> listOutputs() async =>
      const <AudioOutputDevice>[
        AudioOutputDevice(id: null, name: 'System output'),
      ];

  @override
  Future<void> openSoundSettings() async {}
}

List<Override> _audioOverrides(FakeSettingsRepository repository) => <Override>[
  settingsRepositoryProvider.overrideWithValue(repository),
  audioInputListerProvider.overrideWithValue(
    () async => const <InputDevice>[_macBook, _headphones],
  ),
  inputLevelRecorderProvider.overrideWithValue(_FakeRecorder.new),
  audioOutputProvider.overrideWithValue(_FakeOutput()),
];

List<Override> _settingsOverrides(FakeSettingsRepository repository) =>
    <Override>[
      ..._audioOverrides(repository),
      entriesForDateProvider.overrideWith(
        (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
      ),
      reminderClockProvider.overrideWithValue(() => DateTime(2026, 10, 14, 9)),
      reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
      spellCheckAvailabilityProvider.overrideWithValue(
        const AsyncValue<SpellCheckAvailability>.data(
          SpellCheckAvailability.available,
        ),
      ),
      ...syncOffOverrides(),
      ...updateQuietOverrides(),
    ];

void _desktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _showVoiceSettings(
  WidgetTester tester,
  FakeSettingsRepository repository,
) async {
  _desktopView(tester);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _settingsOverrides(repository),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          backgroundColor: FieldNotesColors.light.page,
          body: const SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byKey(settingsTabRailKey),
      matching: find.byKey(settingsTabKey(SettingsTab.voice)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _showRecorderPanel(
  WidgetTester tester,
  FakeSettingsRepository repository,
) async {
  _desktopView(tester);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _audioOverrides(repository),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const Scaffold(
          backgroundColor: Palette.mediaGround,
          body: SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: RecorderInputButton(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(recorderInputKey));
  await tester.pumpAndSettle();
  expect(find.byType(InputPanel), findsOneWidget);
}

Finder _inMenu(Key menu, Finder finder) =>
    find.descendant(of: find.byKey(menu), matching: finder);

Future<void> _showPhoneVoiceSettings(
  WidgetTester tester,
  FakeSettingsRepository repository,
) async {
  tester.view.physicalSize = const Size(384, 832);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _settingsOverrides(repository),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: Scaffold(
          backgroundColor: FieldNotesColors.light.page,
          body: const SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final Finder voice = find.byKey(settingsTabKey(SettingsTab.voice));
  await tester.ensureVisible(voice);
  await tester.pumpAndSettle();
  await tester.tap(voice);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings opens the device menu under the row', (
    WidgetTester tester,
  ) async {
    await _showVoiceSettings(tester, FakeSettingsRepository());

    final Finder row = find.byKey(inputDeviceRowKey);
    expect(row, findsOneWidget);
    final double volumeTop = tester.getRect(find.byKey(inputVolumeRowKey)).top;
    expect(find.byKey(inputDeviceMenuKey), findsNothing);

    await tester.tap(row);
    await tester.pumpAndSettle();

    final Finder menu = find.byKey(inputDeviceMenuKey);
    expect(menu, findsOneWidget);
    expect(
      (tester.getRect(menu).top - tester.getRect(row).bottom).abs(),
      lessThanOrEqualTo(8),
    );
    expect(_inMenu(inputDeviceMenuKey, find.byType(InkWell)), findsNWidgets(3));
    expect(
      _inMenu(inputDeviceMenuKey, find.text('System default')),
      findsOneWidget,
    );
    expect(
      _inMenu(inputDeviceMenuKey, find.text('MacBook Pro Microphone')),
      findsOneWidget,
    );
    expect(
      _inMenu(inputDeviceMenuKey, find.text('WH-1000XM5')),
      findsOneWidget,
    );
    expect(tester.getRect(find.byKey(inputVolumeRowKey)).top, volumeTop);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('choosing stores and closes', (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _showVoiceSettings(tester, repository);
    await tester.tap(find.byKey(inputDeviceRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(inputDeviceMenuKey), findsOneWidget);

    await tester.tap(_inMenu(inputDeviceMenuKey, find.text('WH-1000XM5')));
    await tester.pumpAndSettle();

    expect(repository.audioInputIdWrites, <String?>['b']);
    expect(find.byKey(inputDeviceMenuKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('settings opens the profile menu', (WidgetTester tester) async {
    await _showVoiceSettings(
      tester,
      FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(
          inputProfile: InputProfile.voiceIsolation,
        ),
      ),
    );
    expect(find.byKey(inputProfileMenuKey), findsNothing);

    await tester.tap(find.byKey(inputProfileRowKey));
    await tester.pumpAndSettle();

    final Finder isolation = _inMenu(
      inputProfileMenuKey,
      find.byKey(inputProfileChoiceKey(InputProfile.voiceIsolation)),
    );
    final Finder studio = _inMenu(
      inputProfileMenuKey,
      find.byKey(inputProfileChoiceKey(InputProfile.studio)),
    );
    expect(
      find.descendant(of: isolation, matching: find.text('Voice Isolation')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: isolation,
        matching: find.text(
          'Clears background noise like fans, traffic and typing from your voice.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: isolation, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: studio, matching: find.text('Studio')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: studio,
        matching: find.text('Your microphone as it is, with no processing.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: studio, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate((Widget widget) => widget is Radio),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget.runtimeType.toString().contains('Radio'),
      ),
      findsNothing,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a pick inside the recorder panel sticks', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _showRecorderPanel(tester, repository);
    await tester.tap(find.byKey(inputDeviceRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(inputDeviceMenuKey), findsOneWidget);

    await tester.tap(_inMenu(inputDeviceMenuKey, find.text('WH-1000XM5')));
    await tester.pumpAndSettle();

    expect(repository.audioInputIdWrites, <String?>['b']);
    expect(find.byType(InputPanel), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('escape leaves the choice alone', (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository(
      initial: AppSettings.defaults.copyWith(inputProfile: InputProfile.studio),
    );
    await _showRecorderPanel(tester, repository);
    await tester.tap(find.byKey(inputProfileRowKey));
    await tester.pumpAndSettle();
    expect(find.byKey(inputProfileMenuKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(inputProfileMenuKey), findsNothing);
    expect(repository.inputProfileWrites, isEmpty);
    expect(find.byType(InputLevelMeter), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('escape closes a menu that lost focus', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _showPhoneVoiceSettings(tester, repository);
    final Finder row = find.byKey(inputDeviceRowKey);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final TestGesture touch = await tester.startGesture(
      tester.getCenter(row),
      kind: PointerDeviceKind.touch,
    );
    await touch.up();
    await tester.pumpAndSettle();
    expect(find.byKey(inputDeviceMenuKey), findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(inputDeviceMenuKey), findsNothing);
    expect(repository.audioInputIdWrites, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
