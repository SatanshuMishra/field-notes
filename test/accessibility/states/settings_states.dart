import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/delete_all_dialog.dart';
import 'package:field_notes/features/settings/widgets/settings_notice.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/settings/support/fake_settings_repository.dart';
import '../../features/settings/support/recording_reminder_scheduler.dart';
import '../../features/settings/support/settings_harness.dart';
import '../support/a11y_state.dart';

const Size _tallNoteSurface = Size(1080, 6840);
const double _noteDevicePixelRatio = 2.625;
const String _deleteAll = 'Delete all…';
const String _deleteNotice = 'Deleted 3 days and 5 entries.';

final List<A11yStatefulControl> _settingsStateful = <A11yStatefulControl>[
  A11yStatefulControl.finder(
    find.byType(SettingsToggle),
    A11yStateKind.toggled,
  ),
  A11yStatefulControl.finder(
    find.descendant(
      of: find.bySubtype<SettingsSegmented<Object?>>(),
      matching: find.byType(GestureDetector),
    ),
    A11yStateKind.selected,
  ),
];

void _useTallNoteSurface(WidgetTester tester) {
  tester.view.physicalSize = _tallNoteSurface;
  tester.view.devicePixelRatio = _noteDevicePixelRatio;
  addTearDown(tester.view.reset);
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  SpellCheckAvailability spellCheck = SpellCheckAvailability.available,
}) async {
  _useTallNoteSurface(tester);
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
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDeleteAll(WidgetTester tester) async {
  await _pumpSettings(tester);
  await tester.tap(find.text(_deleteAll));
  await tester.pumpAndSettle();
}

final List<A11yState> settingsStates = <A11yState>[
  A11yState(
    id: 'b1-settings',
    pump: _pumpSettings,
    proof: <A11yProof>[
      A11yProof(find.byType(SettingsScreen)),
      A11yProof(find.widgetWithText(StickerButton, _deleteAll)),
    ],
    stateful: _settingsStateful,
  ),
  A11yState(
    id: 'b2-settings-spell-unavailable',
    pump: (WidgetTester tester) =>
        _pumpSettings(tester, spellCheck: SpellCheckAvailability.unavailable),
    proof: <A11yProof>[A11yProof(find.text(spellCheckUnavailableDescription))],
    stateful: _settingsStateful,
  ),
  A11yState(
    id: 'b3-settings-notice',
    pump: (WidgetTester tester) async {
      await _openDeleteAll(tester);
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
    },
    proof: <A11yProof>[A11yProof(find.byType(SettingsNotice))],
    stateful: _settingsStateful,
  ),
  A11yState(
    id: 'b4-select-open',
    pump: (WidgetTester tester) async {
      await _pumpSettings(tester);
      await tester.tap(find.byType(PopupMenuButton<WeekStart>));
      await tester.pumpAndSettle();
    },
    proof: <A11yProof>[
      A11yProof(find.widgetWithText(PopupMenuItem<WeekStart>, 'Monday')),
    ],
    stateful: _settingsStateful,
  ),
  A11yState(
    id: 'b5-delete-all-dialog',
    pump: _openDeleteAll,
    proof: <A11yProof>[A11yProof(find.byType(DeleteAllConfirmDialog))],
    stateful: _settingsStateful,
  ),
];
