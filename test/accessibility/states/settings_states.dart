import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/data/media/audio_output.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/anchored_dropdown.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/about_section.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/features/settings/sections/reminders_sound_section.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/delete_all_dialog.dart';
import 'package:field_notes/features/settings/widgets/settings_notice.dart';
import 'package:field_notes/features/settings/widgets/settings_phone_pages.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/state/installed_app_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

import '../../features/settings/support/fake_settings_repository.dart';
import '../../features/settings/support/recording_reminder_scheduler.dart';
import '../../features/settings/support/settings_harness.dart'
    show FakeSettingsDataController;
import '../../support/sync_overrides.dart';
import '../../support/update_overrides.dart';
import '../support/a11y_state.dart';

const Size _tallNoteSurface = Size(1080, 6840);
const double _noteDevicePixelRatio = 2.625;
const Size _tallDesktopSurface = Size(1280, 2600);
const String _deleteAll = 'Delete all…';
const String _deleteNotice = 'Deleted 3 days and 5 entries.';
const String _aboutVersion = '1.4.2';
const String _exportFailed = 'Export failed. Nothing was written.';
final SyncStatus _synced = SyncedStatus(DateTime.utc(2026, 9, 18, 15));

const List<InputDevice> _microphones = <InputDevice>[
  InputDevice(id: 'built-in', label: 'Built-in Microphone'),
  InputDevice(id: 'headset', label: 'Headset Microphone'),
];

const List<AudioOutputDevice> _speakers = <AudioOutputDevice>[
  AudioOutputDevice(id: null, name: 'System output'),
  AudioOutputDevice(id: 'built-in', name: 'Built-in Speakers'),
  AudioOutputDevice(id: 'headphones', name: 'Headphones'),
];

class _QuietRecorder extends Fake implements AudioRecorder {
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

class _ListedSpeakers extends AudioOutput {
  const _ListedSpeakers();

  @override
  Future<String?> defaultOutputName() async => _speakers[1].name;

  @override
  Future<List<AudioOutputDevice>> listOutputs() async => _speakers;

  @override
  Future<void> openSoundSettings() async {}
}

List<A11yStatefulControl> get _tabStateful => <A11yStatefulControl>[
  if (!_onPhone)
    for (final SettingsTab tab in SettingsTab.values)
      A11yStatefulControl.finder(
        find.byKey(settingsTabKey(tab)),
        A11yStateKind.selected,
      ),
];

final A11yStatefulControl _toggles = A11yStatefulControl.finder(
  find.byType(SettingsToggle),
  A11yStateKind.toggled,
);

final A11yStatefulControl _segments = A11yStatefulControl.finder(
  find.descendant(
    of: find.bySubtype<SettingsSegmented<Object?>>(),
    matching: find.byType(GestureDetector),
  ),
  A11yStateKind.selected,
);

List<A11yStatefulControl> get _remindersStateful => <A11yStatefulControl>[
  ..._tabStateful,
  _toggles,
];

List<A11yStatefulControl> get _journalStateful => <A11yStatefulControl>[
  ..._tabStateful,
  _toggles,
  _segments,
];

List<A11yStatefulControl> get _aboutDesktopStateful => <A11yStatefulControl>[
  for (final SettingsTab tab in SettingsTab.values)
    A11yStatefulControl.finder(
      find.byKey(settingsTabKey(tab)),
      A11yStateKind.selected,
    ),
  _toggles,
];

List<A11yStatefulControl> get _aboutPhoneStateful => <A11yStatefulControl>[
  _toggles,
];

bool get _onPhone =>
    resolveShellLayout(defaultTargetPlatform) == ShellLayout.bottomBar;

final Finder _weekStartChoices = find.byWidgetPredicate(
  (Widget widget) =>
      _onPhone ? widget is PhoneSheet : widget is AnchoredDropdown<WeekStart>,
  description: 'the week start sheet on the phone, its dropdown on desktop',
);

final Finder _deleteAllConfirm = find.byWidgetPredicate(
  (Widget widget) =>
      _onPhone ? widget is PhoneSheet : widget is DeleteAllConfirmDialog,
  description: 'the delete-all confirm sheet on the phone, dialog on desktop',
);

void _useTallSurface(WidgetTester tester, A11yVariant variant) =>
    variant.useWindow(
      tester,
      variant.desktop
          ? const A11yWindow(
              physicalSize: _tallDesktopSurface,
              devicePixelRatio: 1,
            )
          : const A11yWindow(
              physicalSize: _tallNoteSurface,
              devicePixelRatio: _noteDevicePixelRatio,
            ),
    );

Widget _settingsApp(
  A11yVariant variant, {
  required List<Override> overrides,
  required Widget child,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
}) => KeyedSubtree(
  key: UniqueKey(),
  child: ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: variant.theme,
      builder: variant.scaleText,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: context.colors.page,
          body: Padding(padding: padding, child: child),
        ),
      ),
    ),
  ),
);

List<Override> _settingsOverrides({
  SpellCheckAvailability spellCheck = SpellCheckAvailability.available,
  DataActionResult exportResult = const DataActionDismissed(),
  SyncStatus? sync,
}) => <Override>[
  settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
  appSettingsProvider.overrideWith(
    (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
  ),
  entriesForDateProvider.overrideWith(
    (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
  ),
  reminderClockProvider.overrideWithValue(() => DateTime(2026, 9, 18, 9, 30)),
  reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
  spellCheckAvailabilityProvider.overrideWithValue(
    AsyncValue<SpellCheckAvailability>.data(spellCheck),
  ),
  settingsDataControllerProvider.overrideWith(
    (Ref ref) async => FakeSettingsDataController(
      exportResult: exportResult,
      deleteResult: const DataActionSucceeded(_deleteNotice),
    ),
  ),
  audioInputListerProvider.overrideWithValue(() async => _microphones),
  inputLevelRecorderProvider.overrideWithValue(_QuietRecorder.new),
  audioOutputProvider.overrideWithValue(const _ListedSpeakers()),
  if (sync != null) ...syncOnOverrides(status: sync) else ...syncOffOverrides(),
  ...updateQuietOverrides(),
];

Future<void> _pumpSettings(
  WidgetTester tester,
  A11yVariant variant, {
  SpellCheckAvailability spellCheck = SpellCheckAvailability.available,
  SettingsTab tab = SettingsTab.syncStorage,
  DataActionResult exportResult = const DataActionDismissed(),
  SyncStatus? sync,
}) async {
  _useTallSurface(tester, variant);
  await tester.pumpWidget(
    _settingsApp(
      variant,
      overrides: _settingsOverrides(
        spellCheck: spellCheck,
        exportResult: exportResult,
        sync: sync,
      ),
      padding: const EdgeInsets.all(16),
      child: const SettingsScreen(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(settingsTabKey(tab)));
  await tester.pumpAndSettle();
}

Future<void> _pumpAbout(WidgetTester tester, A11yVariant variant) async {
  _useTallSurface(tester, variant);
  await tester.pumpWidget(
    _settingsApp(
      variant,
      overrides: <Override>[
        ..._settingsOverrides(),
        installedAppProvider.overrideWith(
          (Ref ref) async => const InstalledApp(version: _aboutVersion),
        ),
      ],
      child: const SettingsScreen(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(settingsTabKey(SettingsTab.about)));
  await tester.pumpAndSettle();
}

Future<void> _openDeleteAll(
  WidgetTester tester,
  A11yVariant variant, {
  SyncStatus? sync,
}) async {
  await _pumpSettings(tester, variant, tab: SettingsTab.data, sync: sync);
  await tester.tap(find.text(_deleteAll));
  await tester.pumpAndSettle();
}

Future<void> _openVoiceMenu(
  WidgetTester tester,
  A11yVariant variant,
  Key row,
) async {
  await _pumpSettings(tester, variant, tab: SettingsTab.voice);
  await tester.tap(find.byKey(row));
  await tester.pumpAndSettle();
}

List<A11yState> get settingsStates => <A11yState>[
  A11yState(
    id: 'b1-settings',
    pump: _pumpSettings,
    proof: <A11yProof>[
      A11yProof(find.byType(SettingsScreen)),
      A11yProof(find.byType(SyncStorageSection)),
      A11yProof(find.text(startSyncTitle)),
    ],
    stateful: _tabStateful,
  ),
  A11yState(
    id: 'b2-settings-spell-unavailable',
    pump: (WidgetTester tester, A11yVariant variant) => _pumpSettings(
      tester,
      variant,
      spellCheck: SpellCheckAvailability.unavailable,
      tab: SettingsTab.journal,
    ),
    proof: <A11yProof>[A11yProof(find.text(spellCheckUnavailableDescription))],
    stateful: _journalStateful,
  ),
  A11yState(
    id: 'b3-settings-notice',
    pump: (WidgetTester tester, A11yVariant variant) async {
      await _openDeleteAll(tester, variant);
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
    },
    proof: <A11yProof>[A11yProof(find.byType(SettingsNotice))],
    stateful: _tabStateful,
  ),
  A11yState(
    id: 'b4-select-open',
    pump: (WidgetTester tester, A11yVariant variant) async {
      await _pumpSettings(tester, variant, tab: SettingsTab.journal);
      await tester.tap(find.byType(SettingsSelect<WeekStart>));
      await tester.pumpAndSettle();
    },
    proof: <A11yProof>[
      A11yProof(_weekStartChoices),
      A11yProof(
        find.descendant(of: _weekStartChoices, matching: find.text('Saturday')),
      ),
    ],
    stateful: _journalStateful,
  ),
  A11yState(
    id: 'b5-delete-all-dialog',
    pump: _openDeleteAll,
    proof: <A11yProof>[
      A11yProof(_deleteAllConfirm),
      A11yProof(
        find.descendant(
          of: _deleteAllConfirm,
          matching: find.text('Delete everything'),
        ),
      ),
    ],
    stateful: _tabStateful,
  ),
  A11yState(
    id: 'b6-settings-reminders',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpSettings(tester, variant, tab: SettingsTab.remindersSound),
    proof: <A11yProof>[A11yProof(find.byType(RemindersSoundSection))],
    stateful: _remindersStateful,
  ),
  A11yState(
    id: 'b7-settings-journal',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpSettings(tester, variant, tab: SettingsTab.journal),
    proof: <A11yProof>[A11yProof(find.byType(JournalSection))],
    stateful: _journalStateful,
  ),
  A11yState(
    id: 'b8-settings-data',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpSettings(tester, variant, tab: SettingsTab.data),
    proof: <A11yProof>[
      A11yProof(find.widgetWithText(SettingsActionButton, _deleteAll)),
    ],
    stateful: _tabStateful,
  ),
  A11yState(
    id: 'b9-settings-about',
    pump: _pumpAbout,
    platforms: const <TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.windows,
    },
    proof: <A11yProof>[
      A11yProof(find.byKey(settingsTabRailKey)),
      A11yProof(find.byType(AboutSection)),
      A11yProof(find.byKey(settingsContentTitleKey)),
      A11yProof(find.text(aboutAuthorName)),
    ],
    stateful: _aboutDesktopStateful,
  ),
  A11yState(
    id: 'b10-settings-about-phone',
    pump: _pumpAbout,
    platforms: const <TargetPlatform>{TargetPlatform.android},
    proof: <A11yProof>[
      A11yProof(find.byType(AboutSection)),
      A11yProof(find.byType(SettingsBackPill)),
      A11yProof(find.text(aboutAuthorName)),
    ],
    stateful: _aboutPhoneStateful,
  ),
  A11yState(
    id: 'b11-select-dropdown-input-profile',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _openVoiceMenu(tester, variant, inputProfileRowKey),
    proof: <A11yProof>[
      A11yProof(find.byKey(inputProfileMenuKey)),
      A11yProof(
        find.descendant(
          of: find.byKey(inputProfileMenuKey),
          matching: find.text(InputProfile.studio.label),
        ),
      ),
    ],
    stateful: _tabStateful,
  ),
  A11yState(
    id: 'b12-select-dropdown-microphone',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _openVoiceMenu(tester, variant, inputDeviceRowKey),
    proof: <A11yProof>[
      A11yProof(find.byKey(inputDeviceMenuKey)),
      A11yProof(
        find.descendant(
          of: find.byKey(inputDeviceMenuKey),
          matching: find.text(_microphones.last.label),
        ),
      ),
    ],
    stateful: _tabStateful,
  ),
  A11yState(
    id: 'b13-select-dropdown-speaker',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _openVoiceMenu(tester, variant, outputDeviceRowKey),
    proof: <A11yProof>[
      A11yProof(find.byKey(outputDeviceMenuKey)),
      A11yProof(
        find.descendant(
          of: find.byKey(outputDeviceMenuKey),
          matching: find.text(_speakers.last.name),
        ),
      ),
    ],
    stateful: _tabStateful,
  ),
  A11yState(
    id: 'b14-sync-delete-all-dialog',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _openDeleteAll(tester, variant, sync: _synced),
    proof: <A11yProof>[
      A11yProof(find.byType(SyncDeleteAllDialog)),
      A11yProof(find.byKey(removeFromThisDeviceKey)),
      A11yProof(find.byKey(deleteEverywhereKey)),
    ],
    stateful: _tabStateful,
  ),
  A11yState(
    id: 'b15-settings-data-error',
    pump: (WidgetTester tester, A11yVariant variant) async {
      await _pumpSettings(
        tester,
        variant,
        tab: SettingsTab.data,
        exportResult: const DataActionFailed(_exportFailed),
      );
      await tester.tap(find.text('Export…'));
      await tester.pumpAndSettle();
    },
    proof: <A11yProof>[
      A11yProof(find.byType(SettingsNotice)),
      A11yProof(find.text(_exportFailed)),
    ],
    stateful: _tabStateful,
  ),
  A11yState(
    id: 'b16-settings-sync-paused',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpSettings(tester, variant, sync: const PausedStatus()),
    proof: <A11yProof>[
      A11yProof(find.byType(SyncStorageSection)),
      A11yProof(find.text(pauseSyncLabel)),
    ],
    stateful: <A11yStatefulControl>[..._tabStateful, _toggles],
  ),
];
