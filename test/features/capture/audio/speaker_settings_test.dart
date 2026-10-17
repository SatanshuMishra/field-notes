import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
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

  int opened = 0;

  @override
  Future<String?> defaultOutputName() async => 'MacBook Pro Speakers';

  @override
  Future<List<AudioOutputDevice>> listOutputs() async =>
      const <AudioOutputDevice>[
        AudioOutputDevice(id: null, name: 'System output'),
        AudioOutputDevice(id: 'a', name: 'MacBook Pro Speakers'),
        AudioOutputDevice(id: 'b', name: 'WH-1000XM5'),
      ];

  @override
  Future<void> openSoundSettings() async {
    opened++;
  }
}

List<Override> _audioOverrides(
  FakeSettingsRepository repository,
  _FakeOutput output,
) => <Override>[
  settingsRepositoryProvider.overrideWithValue(repository),
  audioInputListerProvider.overrideWithValue(
    () async => const <InputDevice>[_macBook],
  ),
  inputLevelRecorderProvider.overrideWithValue(_FakeRecorder.new),
  audioOutputProvider.overrideWithValue(output),
];

List<Override> _settingsOverrides(
  FakeSettingsRepository repository,
  _FakeOutput output,
) => <Override>[
  ..._audioOverrides(repository, output),
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

void _view(WidgetTester tester, {required bool phone}) {
  tester.view.physicalSize = phone
      ? const Size(384, 832)
      : const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  if (phone) {
    tester.view.padding = const FakeViewPadding(top: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24);
  }
  addTearDown(tester.view.reset);
}

Future<void> _showVoiceSettings(
  WidgetTester tester, {
  required TargetPlatform platform,
  required FakeSettingsRepository repository,
  required _FakeOutput output,
}) async {
  final bool phone = platform == TargetPlatform.android;
  _view(tester, phone: phone);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _settingsOverrides(repository, output),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(
          backgroundColor: FieldNotesColors.light.page,
          body: const SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final Finder voice = phone
      ? find.byKey(settingsTabKey(SettingsTab.voice))
      : find.descendant(
          of: find.byKey(settingsTabRailKey),
          matching: find.byKey(settingsTabKey(SettingsTab.voice)),
        );
  await tester.ensureVisible(voice);
  await tester.pumpAndSettle();
  await tester.tap(voice);
  await tester.pumpAndSettle();
}

Finder _inRow(Key row, String text) =>
    find.descendant(of: find.byKey(row), matching: find.text(text));

void main() {
  testWidgets('settings shows the speaker group', (WidgetTester tester) async {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      await _showVoiceSettings(
        tester,
        platform: platform,
        repository: FakeSettingsRepository(),
        output: _FakeOutput(),
      );

      final Finder device = find.byKey(outputDeviceRowKey);
      final Finder volume = find.byKey(outputVolumeRowKey);
      await tester.ensureVisible(volume);
      await tester.pumpAndSettle();
      expect(
        _inRow(outputDeviceRowKey, 'Output device'),
        findsOneWidget,
        reason: platform.name,
      );
      expect(
        _inRow(outputDeviceRowKey, 'System output'),
        findsOneWidget,
        reason: platform.name,
      );
      expect(
        _inRow(outputVolumeRowKey, 'Output volume'),
        findsOneWidget,
        reason: platform.name,
      );
      expect(
        _inRow(outputVolumeRowKey, '100%'),
        findsOneWidget,
        reason: platform.name,
      );
      final Slider slider = tester.widget<Slider>(
        find.descendant(of: volume, matching: find.byType(Slider)),
      );
      expect(slider.min, 0, reason: platform.name);
      expect(slider.max, 100, reason: platform.name);
      expect(slider.value, 100, reason: platform.name);
      final double meterBottom = tester
          .getRect(find.byType(InputLevelMeter))
          .bottom;
      expect(
        tester.getRect(device).top,
        greaterThan(meterBottom),
        reason: platform.name,
      );
      expect(
        tester.getRect(volume).top,
        greaterThan(tester.getRect(device).top),
        reason: platform.name,
      );
      if (platform == TargetPlatform.macOS) {
        final Rect label = tester.getRect(find.text('speaker'));
        expect(label.top, greaterThan(meterBottom));
        expect(label.bottom, lessThanOrEqualTo(tester.getRect(device).top));
      }
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('choosing an output stores it', (WidgetTester tester) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await _showVoiceSettings(
      tester,
      platform: TargetPlatform.macOS,
      repository: repository,
      output: _FakeOutput(),
    );
    await tester.ensureVisible(find.byKey(outputDeviceRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(outputDeviceRowKey));
    await tester.pumpAndSettle();
    final Finder choice = find.descendant(
      of: find.byKey(outputDeviceMenuKey),
      matching: find.text('WH-1000XM5'),
    );
    expect(choice, findsOneWidget);

    await tester.tap(choice);
    await tester.pumpAndSettle();

    expect(repository.audioOutputIdWrites, <String?>['b']);
    expect(find.byKey(outputDeviceMenuKey), findsNothing);
    expect(_inRow(outputDeviceRowKey, 'WH-1000XM5'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets("the panel's output row opens the dropdown", (
    WidgetTester tester,
  ) async {
    _view(tester, phone: false);
    final _FakeOutput output = _FakeOutput();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: _audioOverrides(FakeSettingsRepository(), output),
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

    await tester.tap(find.byKey(outputDeviceRowKey));
    await tester.pumpAndSettle();

    final Finder menu = find.byKey(outputDeviceMenuKey);
    expect(menu, findsOneWidget);
    expect(
      find.descendant(of: menu, matching: find.text('WH-1000XM5')),
      findsOneWidget,
    );
    expect(find.byType(InputPanel), findsOneWidget);
    expect(output.opened, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
