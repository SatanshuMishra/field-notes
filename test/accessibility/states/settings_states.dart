import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/features/settings/sections/reminders_sound_section.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/delete_all_dialog.dart';
import 'package:field_notes/features/settings/widgets/settings_notice.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/settings/support/fake_settings_repository.dart';
import '../../features/settings/support/recording_reminder_scheduler.dart';
import '../../features/settings/support/settings_harness.dart';
import '../../support/sync_overrides.dart';
import '../support/a11y_state.dart';

const Size _tallNoteSurface = Size(1080, 6840);
const double _noteDevicePixelRatio = 2.625;
const Size _tallDesktopSurface = Size(1280, 2600);
const String _deleteAll = 'Delete all…';
const String _deleteNotice = 'Deleted 3 days and 5 entries.';

final List<A11yStatefulControl> _tabStateful = <A11yStatefulControl>[
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

final List<A11yStatefulControl> _remindersStateful = <A11yStatefulControl>[
  ..._tabStateful,
  _toggles,
];

final List<A11yStatefulControl> _journalStateful = <A11yStatefulControl>[
  ..._tabStateful,
  _toggles,
  _segments,
];

bool get _onPhone =>
    resolveShellLayout(defaultTargetPlatform) == ShellLayout.bottomBar;

final Finder _weekStartChoices = find.byWidgetPredicate(
  (Widget widget) =>
      _onPhone ? widget is PhoneSheet : widget is PopupMenuItem<WeekStart>,
  description: 'the week start sheet on the phone, its menu on macOS',
);

final Finder _deleteAllConfirm = find.byWidgetPredicate(
  (Widget widget) =>
      _onPhone ? widget is PhoneSheet : widget is DeleteAllConfirmDialog,
  description: 'the delete-all confirm sheet on the phone, dialog on macOS',
);

void _useTallSurface(WidgetTester tester) {
  final bool sidebar =
      resolveShellLayout(defaultTargetPlatform) == ShellLayout.sidebar;
  tester.view.physicalSize = sidebar ? _tallDesktopSurface : _tallNoteSurface;
  tester.view.devicePixelRatio = sidebar ? 1 : _noteDevicePixelRatio;
  addTearDown(tester.view.reset);
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  SpellCheckAvailability spellCheck = SpellCheckAvailability.available,
  SettingsTab tab = SettingsTab.syncStorage,
}) async {
  _useTallSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      const SettingsScreen(),
      scrollable: false,
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
        ),
        reminderClockProvider.overrideWithValue(
          () => DateTime(2026, 9, 18, 9, 30),
        ),
        reminderSchedulerProvider.overrideWithValue(
          RecordingReminderScheduler(),
        ),
        spellCheckAvailabilityProvider.overrideWithValue(
          AsyncValue<SpellCheckAvailability>.data(spellCheck),
        ),
        settingsDataControllerProvider.overrideWith(
          (Ref ref) async => FakeSettingsDataController(
            deleteResult: const DataActionSucceeded(_deleteNotice),
          ),
        ),
        ...syncOffOverrides(),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(settingsTabKey(tab)));
  await tester.pumpAndSettle();
}

Future<void> _openDeleteAll(WidgetTester tester) async {
  await _pumpSettings(tester, tab: SettingsTab.data);
  await tester.tap(find.text(_deleteAll));
  await tester.pumpAndSettle();
}

final List<A11yState> settingsStates = <A11yState>[
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
    pump: (WidgetTester tester) => _pumpSettings(
      tester,
      spellCheck: SpellCheckAvailability.unavailable,
      tab: SettingsTab.journal,
    ),
    proof: <A11yProof>[A11yProof(find.text(spellCheckUnavailableDescription))],
    stateful: _journalStateful,
  ),
  A11yState(
    id: 'b3-settings-notice',
    pump: (WidgetTester tester) async {
      await _openDeleteAll(tester);
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
    },
    proof: <A11yProof>[A11yProof(find.byType(SettingsNotice))],
    stateful: _tabStateful,
  ),
  A11yState(
    id: 'b4-select-open',
    pump: (WidgetTester tester) async {
      await _pumpSettings(tester, tab: SettingsTab.journal);
      await tester.tap(find.byType(SettingsSelect<WeekStart>));
      await tester.pumpAndSettle();
    },
    proof: <A11yProof>[
      A11yProof(_weekStartChoices),
      A11yProof(
        find.descendant(of: _weekStartChoices, matching: find.text('Monday')),
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
    pump: (WidgetTester tester) =>
        _pumpSettings(tester, tab: SettingsTab.remindersSound),
    proof: <A11yProof>[A11yProof(find.byType(RemindersSoundSection))],
    stateful: _remindersStateful,
  ),
  A11yState(
    id: 'b7-settings-journal',
    pump: (WidgetTester tester) =>
        _pumpSettings(tester, tab: SettingsTab.journal),
    proof: <A11yProof>[A11yProof(find.byType(JournalSection))],
    stateful: _journalStateful,
  ),
  A11yState(
    id: 'b8-settings-data',
    pump: (WidgetTester tester) => _pumpSettings(tester, tab: SettingsTab.data),
    proof: <A11yProof>[
      A11yProof(find.widgetWithText(StickerButton, _deleteAll)),
    ],
    stateful: _tabStateful,
  ),
];
