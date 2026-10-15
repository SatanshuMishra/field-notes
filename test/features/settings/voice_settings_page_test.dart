import 'dart:typed_data';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/icons/settings_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_level.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/voice_section.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/settings_phone_pages.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_section_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../../support/sync_overrides.dart';
import '../../support/update_overrides.dart';
import 'support/fake_settings_repository.dart';
import 'support/recording_reminder_scheduler.dart';

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

List<Override> _overrides(FakeSettingsRepository repository) => <Override>[
  settingsRepositoryProvider.overrideWithValue(repository),
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
  audioInputListerProvider.overrideWithValue(
    () async => const <InputDevice>[_macBook, _corsair],
  ),
  inputLevelRecorderProvider.overrideWithValue(_FakeRecorder.new),
  ...syncOffOverrides(),
  ...updateQuietOverrides(),
];

Widget _settingsApp(TargetPlatform platform, {required bool showSettings}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: platform),
    home: Scaffold(
      backgroundColor: FieldNotesColors.light.page,
      body: showSettings ? const SettingsScreen() : const SizedBox.expand(),
    ),
  );
}

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

Future<void> _pumpSettings(
  WidgetTester tester, {
  required TargetPlatform platform,
  required FakeSettingsRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(repository),
      child: _settingsApp(platform, showSettings: true),
    ),
  );
  await tester.pumpAndSettle();
}

String? _contentTitle(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(settingsContentTitleKey)).data;

Finder _choice(InputProfile profile) =>
    find.byKey(voiceProfileChoiceKey(profile));

void main() {
  testWidgets('the Voice tab shows the input profile choices', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    _desktopView(tester);
    final FakeSettingsRepository repository = FakeSettingsRepository(
      initial: AppSettings.defaults.copyWith(inputProfile: InputProfile.studio),
    );
    await _pumpSettings(
      tester,
      platform: TargetPlatform.macOS,
      repository: repository,
    );

    expect(SettingsTab.voice.label, 'Voice');
    expect(SettingsTab.voice.sublabel, 'microphone, noise');
    expect(SettingsTab.voice.glyph, SettingsGlyph.microphone);
    final Finder rail = find.byKey(settingsTabRailKey);
    final Finder reminders = find.descendant(
      of: rail,
      matching: find.byKey(settingsTabKey(SettingsTab.remindersSound)),
    );
    final Finder voice = find.descendant(
      of: rail,
      matching: find.byKey(settingsTabKey(SettingsTab.voice)),
    );
    final Finder data = find.descendant(
      of: rail,
      matching: find.byKey(settingsTabKey(SettingsTab.data)),
    );
    expect(voice, findsOneWidget);
    expect(
      find.descendant(of: voice, matching: find.text('Voice')),
      findsOneWidget,
    );
    expect(
      tester.getRect(voice).top,
      greaterThanOrEqualTo(tester.getRect(reminders).bottom),
    );
    expect(
      tester.getRect(voice).bottom,
      lessThanOrEqualTo(tester.getRect(data).top),
    );
    final SettingsIcon icon = tester.widget<SettingsIcon>(
      find.descendant(of: voice, matching: find.byType(SettingsIcon)),
    );
    expect(icon.glyph, SettingsGlyph.microphone);

    await tester.tap(voice);
    await tester.pumpAndSettle();

    expect(_contentTitle(tester), 'Voice');
    final Finder isolation = _choice(InputProfile.voiceIsolation);
    final Finder studio = _choice(InputProfile.studio);
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
      tester.getSemantics(studio),
      isSemantics(
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect(
      tester.getSemantics(isolation),
      isSemantics(
        hasCheckedState: true,
        isChecked: false,
        isInMutuallyExclusiveGroup: true,
      ),
    );

    final List<Finder> order = <Finder>[
      isolation,
      studio,
      find.text('Input device'),
      find.text('Input volume'),
      find.byType(InputLevelMeter),
    ];
    double previous = double.negativeInfinity;
    for (final Finder finder in order) {
      expect(finder, findsOneWidget);
      final double top = tester.getRect(finder).top;
      expect(top, greaterThan(previous));
      previous = top;
    }

    await tester.tap(isolation);
    await tester.pumpAndSettle();

    expect(repository.inputProfileWrites, <InputProfile>[
      InputProfile.voiceIsolation,
    ]);
    expect(
      tester.getSemantics(_choice(InputProfile.voiceIsolation)),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    expect(
      tester.getSemantics(_choice(InputProfile.studio)),
      isSemantics(hasCheckedState: true, isChecked: false),
    );
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the phone settings list has a Voice page', (
    WidgetTester tester,
  ) async {
    _phoneView(tester);
    await _pumpSettings(
      tester,
      platform: TargetPlatform.android,
      repository: FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(
          inputProfile: InputProfile.voiceIsolation,
        ),
      ),
    );
    final Finder row = find.byKey(settingsTabKey(SettingsTab.voice));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('Voice')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Voice Isolation')),
      findsOneWidget,
    );

    await _pumpSettings(
      tester,
      platform: TargetPlatform.android,
      repository: FakeSettingsRepository(
        initial: AppSettings.defaults.copyWith(
          inputProfile: InputProfile.fromId('noiseGate'),
        ),
      ),
    );
    expect(
      find.descendant(of: row, matching: find.text('Studio')),
      findsOneWidget,
    );
    expect(_choice(InputProfile.studio), findsNothing);

    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SettingsPageHeading),
        matching: find.text('Voice'),
      ),
      findsOneWidget,
    );
    expect(row, findsNothing);
    expect(_choice(InputProfile.voiceIsolation), findsOneWidget);
    expect(_choice(InputProfile.studio), findsOneWidget);
    expect(find.text('Input device'), findsOneWidget);
    expect(find.text('Input volume'), findsOneWidget);
    expect(find.byType(InputLevelMeter), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a Voice request opens the Voice section once', (
    WidgetTester tester,
  ) async {
    _desktopView(tester);
    final ProviderContainer container = ProviderContainer(
      overrides: _overrides(FakeSettingsRepository()),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _settingsApp(TargetPlatform.macOS, showSettings: false),
      ),
    );
    container
        .read(settingsSectionRequestProvider.notifier)
        .request(SettingsTab.voice);
    expect(container.read(settingsSectionRequestProvider), SettingsTab.voice);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _settingsApp(TargetPlatform.macOS, showSettings: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(_contentTitle(tester), 'Voice');
    expect(_choice(InputProfile.studio), findsOneWidget);
    expect(container.read(settingsSectionRequestProvider), isNull);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _settingsApp(TargetPlatform.macOS, showSettings: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _settingsApp(TargetPlatform.macOS, showSettings: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(_contentTitle(tester), 'Journal');
    expect(container.read(settingsSectionRequestProvider), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
