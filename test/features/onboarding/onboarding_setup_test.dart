import 'dart:async';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/setup/onboarding_setup.dart';
import 'package:field_notes/features/onboarding/setup/setup_reminder_step.dart';
import 'package:field_notes/features/onboarding/setup/setup_storage_step.dart';
import 'package:field_notes/features/onboarding/setup/setup_summary.dart';
import 'package:field_notes/features/onboarding/setup/setup_week_step.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../settings/support/fake_settings_repository.dart';
import '../settings/support/recording_reminder_scheduler.dart';

const Size _desktop = Size(1280, 800);
const Size _phone = Size(360, 740);

const String _reminderTitle = 'A gentle daily nudge?';
const String _weekTitle = 'Your week starts on';
const String _storageTitle = 'Where should entries live?';
const String _summaryTitle = 'You’re all set';
const String _notificationBody = 'You haven’t written today’s field note yet.';
const String _saveError = 'Couldn’t save your choices. Try again.';
const String _sidebarSkip = 'Skip · use defaults';
const String _bottomBarSkip = 'Use defaults';

const Color _progressDone = Color(0xFFDBA493);

const ReminderTime _evening = ReminderTime(hour: 20, minute: 30);
const ReminderTime _morning = ReminderTime(hour: 8, minute: 0);

class _Run {
  _Run({required this.repository, required this.scheduler});

  final FakeSettingsRepository repository;
  final RecordingReminderScheduler scheduler;
  final List<SetupOutcome> outcomes = <SetupOutcome>[];
  final List<String> backOuts = <String>[];
}

class _OrderedSettingsRepository extends FakeSettingsRepository {
  _OrderedSettingsRepository({this.gate});

  final Completer<void>? gate;
  final List<String> order = <String>[];

  @override
  Future<void> setReminderEnabled(bool value) async {
    order.add('reminderEnabled');
    await gate?.future;
    await super.setReminderEnabled(value);
  }

  @override
  Future<void> setReminderTime(ReminderTime value) async {
    order.add('reminderTime');
    await super.setReminderTime(value);
  }

  @override
  Future<void> setWeekStart(WeekStart value) async {
    order.add('weekStart');
    await super.setWeekStart(value);
  }
}

Future<void> _onLayout(ShellLayout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = layout == ShellLayout.sidebar
      ? TargetPlatform.macOS
      : TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<_Run> _pumpSetup(
  WidgetTester tester, {
  required ShellLayout layout,
  FakeSettingsRepository? repository,
  ReminderPermission permission = ReminderPermission.granted,
  String countryCode = 'DE',
}) async {
  final bool sidebar = layout == ShellLayout.sidebar;
  tester.view.physicalSize = sidebar ? _desktop : _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Run run = _Run(
    repository: repository ?? FakeSettingsRepository(),
    scheduler: RecordingReminderScheduler(permission: permission),
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(run.repository),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
        ),
        reminderClockProvider.overrideWithValue(() => DateTime(2026, 9, 28, 9)),
        reminderSchedulerProvider.overrideWithValue(run.scheduler),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(
          platform: sidebar ? TargetPlatform.macOS : TargetPlatform.android,
        ),
        home: Scaffold(
          backgroundColor: FieldNotesColors.light.page,
          body: OnboardingSetup(
            layout: layout,
            countryCode: countryCode,
            onBackOut: () => run.backOuts.add('back'),
            onDone: run.outcomes.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return run;
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _primary(WidgetTester tester) => _tapKey(tester, setupPrimaryKey);

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _toSummary(WidgetTester tester) async {
  await _primary(tester);
  await _primary(tester);
  await _primary(tester);
  expect(find.text(_summaryTitle), findsOneWidget);
}

Finder _within(Key key, String text) =>
    find.descendant(of: find.byKey(key), matching: find.text(text));

double _previewOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byKey(setupNotificationPreviewKey)).opacity;

Color? _fillOf(WidgetTester tester, Key key) =>
    (tester.widget<DecoratedBox>(find.byKey(key)).decoration as BoxDecoration)
        .color;

Color? _presetFill(WidgetTester tester, ReminderPreset preset) =>
    (tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byKey(setupReminderPresetKey(preset)),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .color;

List<String> _lettersOf(WidgetTester tester, WeekStart start) {
  final List<Text> texts = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(setupWeekOptionKey(start)),
          matching: find.byType(Text),
        ),
      )
      .toList();
  return <String>[
    for (final Text text in texts.sublist(texts.length - 7)) text.data!,
  ];
}

void _focusTimeField(WidgetTester tester) {
  Focus.of(
    tester.element(
      find
          .descendant(
            of: find.byType(SettingsTimeField),
            matching: find.byType(DecoratedBox),
          )
          .first,
    ),
  ).requestFocus();
}

String _focusedLabel() {
  String label = '';
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
    Element element,
  ) {
    final Widget widget = element.widget;
    if (widget is Semantics && (widget.properties.label ?? '').isNotEmpty) {
      label = widget.properties.label!;
      return false;
    }
    return true;
  });
  return label;
}

void main() {
  testWidgets(
    'the reminder step shows the live notification preview and four presets '
    'with evening selected',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          await _pumpSetup(tester, layout: layout);

          expect(find.text('basic setup'), findsOneWidget);
          expect(find.text(_reminderTitle), findsOneWidget);
          expect(
            _within(setupNotificationPreviewKey, 'Field Notes'),
            findsOneWidget,
          );
          expect(
            _within(setupNotificationPreviewKey, _notificationBody),
            findsOneWidget,
          );
          expect(_within(setupNotificationPreviewKey, '20:30'), findsOneWidget);
          expect(_previewOpacity(tester), 1);

          expect(find.text('Daily reminder'), findsOneWidget);
          expect(
            tester.widget<SettingsToggle>(find.byType(SettingsToggle)).value,
            isTrue,
          );

          const Map<ReminderPreset, (String, String)> labels =
              <ReminderPreset, (String, String)>{
                ReminderPreset.morning: ('08:00', 'morning'),
                ReminderPreset.midday: ('12:30', 'midday'),
                ReminderPreset.evening: ('20:30', 'evening'),
                ReminderPreset.other: ('Other', 'pick a time'),
              };
          for (final ReminderPreset preset in ReminderPreset.values) {
            final (String value, String caption) = labels[preset]!;
            final Key key = setupReminderPresetKey(preset);
            expect(_within(key, value), findsOneWidget, reason: preset.name);
            expect(_within(key, caption), findsOneWidget, reason: preset.name);
            expect(
              tester.getSemantics(find.byKey(key)),
              isSemantics(
                label: '$value, $caption',
                isButton: true,
                hasSelectedState: true,
                isSelected: preset == ReminderPreset.evening,
                isInMutuallyExclusiveGroup: true,
              ),
              reason: preset.name,
            );
            expect(
              _presetFill(tester, preset),
              preset == ReminderPreset.evening
                  ? Palette.coral
                  : FieldNotesColors.light.cardWarm,
              reason: preset.name,
            );
          }

          double top(ReminderPreset preset) =>
              tester.getTopLeft(find.byKey(setupReminderPresetKey(preset))).dy;
          if (layout == ShellLayout.sidebar) {
            expect(top(ReminderPreset.midday), top(ReminderPreset.morning));
            expect(top(ReminderPreset.evening), top(ReminderPreset.morning));
            expect(top(ReminderPreset.other), top(ReminderPreset.morning));
          } else {
            expect(top(ReminderPreset.midday), top(ReminderPreset.morning));
            expect(
              top(ReminderPreset.evening),
              greaterThan(top(ReminderPreset.morning)),
            );
            expect(top(ReminderPreset.other), top(ReminderPreset.evening));
          }
          expect(find.byType(SettingsTimeField), findsNothing);

          expect(_fillOf(tester, setupProgressKey(0)), Palette.coral);
          expect(
            _fillOf(tester, setupProgressKey(1)),
            FieldNotesColors.light.ink18,
          );
          expect(
            _fillOf(tester, setupProgressKey(2)),
            FieldNotesColors.light.ink18,
          );
          expect(find.text('Continue'), findsOneWidget);
        });
      }
    },
  );

  testWidgets(
    'Other reveals a time field and turning the reminder off greys the '
    'preview and hides the presets',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          await _pumpSetup(tester, layout: layout);
          final Key other = setupReminderPresetKey(ReminderPreset.other);

          await _tapKey(tester, other);
          expect(find.byType(SettingsTimeField), findsOneWidget);
          expect(
            tester
                .widget<SettingsTimeField>(find.byType(SettingsTimeField))
                .value,
            const TimeOfDay(hour: 20, minute: 30),
          );
          expect(_within(other, '20:30'), findsOneWidget);
          expect(_within(other, 'Other'), findsNothing);
          expect(
            tester.getSemantics(find.byKey(other)),
            isSemantics(
              label: '20:30, pick a time',
              isButton: true,
              hasSelectedState: true,
              isSelected: true,
              isInMutuallyExclusiveGroup: true,
            ),
          );

          await tester.tap(find.byType(SettingsTimeField));
          await tester.pumpAndSettle();
          expect(find.byType(TimePickerDialog), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(find.byType(TimePickerDialog), findsNothing);
          expect(_within(other, '20:30'), findsOneWidget);

          await tester.tap(find.byType(SettingsToggle));
          await tester.pumpAndSettle();
          expect(_previewOpacity(tester), 0.38);
          expect(
            find.descendant(
              of: find.byKey(setupNotificationPreviewKey),
              matching: find.byType(ColorFiltered),
            ),
            findsOneWidget,
          );
          expect(_within(setupNotificationPreviewKey, 'off'), findsOneWidget);
          for (final ReminderPreset preset in ReminderPreset.values) {
            expect(
              find.byKey(setupReminderPresetKey(preset)),
              findsNothing,
              reason: preset.name,
            );
          }
          expect(find.byType(SettingsTimeField), findsNothing);

          await tester.tap(find.byType(SettingsToggle));
          await tester.pumpAndSettle();
          expect(_previewOpacity(tester), 1);
          expect(find.byType(SettingsTimeField), findsOneWidget);
        });
      }
    },
  );

  testWidgets(
    'Continue with the reminder on requests permission once and a denial '
    'turns the reminder off',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          final _Run run = await _pumpSetup(
            tester,
            layout: layout,
            permission: ReminderPermission.denied,
          );

          await _primary(tester);
          expect(run.scheduler.permissionRequests, 1);
          expect(find.text(_weekTitle), findsOneWidget);
          expect(run.repository.reminderEnabledWrites, isEmpty);
          expect(run.repository.reminderTimeWrites, isEmpty);
          expect(run.repository.weekStartWrites, isEmpty);

          await _tapKey(tester, setupBackKey);
          expect(find.text(_reminderTitle), findsOneWidget);
          expect(
            tester.widget<SettingsToggle>(find.byType(SettingsToggle)).value,
            isFalse,
          );
          expect(_previewOpacity(tester), 0.38);

          await _toSummary(tester);
          expect(find.text('Off'), findsOneWidget);
          expect(run.scheduler.permissionRequests, 1);

          await _tapKey(tester, setupSummaryChangeReminderKey);
          await tester.tap(find.byType(SettingsToggle));
          await tester.pumpAndSettle();
          await _primary(tester);
          expect(find.text(_weekTitle), findsOneWidget);
          expect(run.scheduler.permissionRequests, 1);
          expect(run.outcomes, isEmpty);
        });
      }
    },
  );

  testWidgets(
    'the week step lists the suggestion first, marked and selected, with '
    'Saturday offered',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          final bool sidebar = layout == ShellLayout.sidebar;
          final _Run run = await _pumpSetup(
            tester,
            layout: layout,
            countryCode: 'SA',
          );
          await _primary(tester);
          expect(run.scheduler.permissionRequests, 0);

          expect(find.text(_weekTitle), findsOneWidget);
          expect(
            find.text('Used by Calendar and your weekly garden.'),
            findsOneWidget,
          );
          double top(WeekStart start) =>
              tester.getTopLeft(find.byKey(setupWeekOptionKey(start))).dy;
          expect(top(WeekStart.saturday), lessThan(top(WeekStart.monday)));
          expect(top(WeekStart.monday), lessThan(top(WeekStart.sunday)));

          final String marker = sidebar
              ? 'suggested for your region'
              : 'suggested';
          expect(find.text(marker), findsOneWidget);
          expect(
            _within(setupWeekOptionKey(WeekStart.saturday), marker),
            findsOneWidget,
          );
          expect(
            find.text(sidebar ? 'suggested' : 'suggested for your region'),
            findsNothing,
          );

          const Map<WeekStart, List<String>> letters =
              <WeekStart, List<String>>{
                WeekStart.monday: <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'],
                WeekStart.sunday: <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'],
                WeekStart.saturday: <String>['S', 'S', 'M', 'T', 'W', 'T', 'F'],
              };
          void expectSelected(WeekStart selected) {
            for (final WeekStart start in WeekStart.values) {
              expect(
                _within(setupWeekOptionKey(start), start.label),
                findsOneWidget,
              );
              expect(_lettersOf(tester, start), letters[start]);
              expect(
                tester.getSemantics(find.byKey(setupWeekOptionKey(start))),
                isSemantics(
                  label: start == WeekStart.saturday
                      ? '${start.label}, $marker'
                      : start.label,
                  hasCheckedState: true,
                  isChecked: start == selected,
                  isInMutuallyExclusiveGroup: true,
                ),
                reason: start.name,
              );
              expect(
                _fillOf(tester, setupWeekLetterKey(start, 0)),
                start == selected ? Palette.coral : FieldNotesColors.light.pill,
                reason: start.name,
              );
              for (int index = 1; index < 7; index++) {
                expect(
                  _fillOf(tester, setupWeekLetterKey(start, index)),
                  isNull,
                  reason: '${start.name} $index',
                );
              }
            }
          }

          expectSelected(WeekStart.saturday);

          await _tapKey(tester, setupWeekOptionKey(WeekStart.monday));
          expectSelected(WeekStart.monday);
        });
      }
    },
  );

  testWidgets(
    'the storage step keeps My own server disabled and Finish enabled',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          await _pumpSetup(tester, layout: layout);
          await _primary(tester);
          await _primary(tester);

          expect(find.text(_storageTitle), findsOneWidget);
          expect(
            find.text('Everything stays on this device for now.'),
            findsOneWidget,
          );
          expect(_within(setupStorageDeviceKey, 'This device'), findsOneWidget);
          expect(
            _within(setupStorageDeviceKey, 'Private · no account needed'),
            findsOneWidget,
          );
          expect(
            _within(setupStorageServerKey, 'My own server'),
            findsOneWidget,
          );
          expect(
            _within(setupStorageServerKey, 'Arrives in a future update'),
            findsOneWidget,
          );

          void expectChoices() {
            expect(
              tester.getSemantics(find.byKey(setupStorageDeviceKey)),
              isSemantics(
                label: 'This device, Private · no account needed',
                hasCheckedState: true,
                isChecked: true,
                hasEnabledState: true,
                isEnabled: true,
                isInMutuallyExclusiveGroup: true,
              ),
            );
            expect(
              tester.getSemantics(find.byKey(setupStorageServerKey)),
              isSemantics(
                label: 'My own server, Arrives in a future update',
                hasCheckedState: true,
                isChecked: false,
                hasEnabledState: true,
                isEnabled: false,
                isInMutuallyExclusiveGroup: true,
              ),
            );
          }

          expectChoices();
          expect(
            tester
                .widget<Opacity>(
                  find
                      .descendant(
                        of: find.byKey(setupStorageServerKey),
                        matching: find.byType(Opacity),
                      )
                      .first,
                )
                .opacity,
            0.5,
          );

          await tester.tap(find.byKey(setupStorageServerKey));
          await tester.pumpAndSettle();
          expectChoices();
          expect(find.text(_storageTitle), findsOneWidget);

          expect(find.text('Finish'), findsOneWidget);
          expect(
            tester.getSemantics(find.byKey(setupPrimaryKey)),
            isSemantics(
              label: 'Finish',
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
            ),
          );
          await _primary(tester);
          expect(find.text(_summaryTitle), findsOneWidget);
        });
      }
    },
  );

  testWidgets('the summary rows show the choices and Change returns to each '
      'step', (WidgetTester tester) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        await _pumpSetup(tester, layout: layout);
        await _toSummary(tester);

        expect(find.text('all done'), findsOneWidget);
        expect(
          find.text('Change any of this later in Settings.'),
          findsOneWidget,
        );
        expect(find.text('Start journaling'), findsOneWidget);
        for (final String text in <String>[
          'REMINDER',
          'Daily at 20:30',
          'WEEK STARTS ON',
          'Monday',
          'ENTRIES LIVE',
          'On this device',
        ]) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        expect(find.text('Change'), findsNWidgets(3));
        for (int index = 0; index < 3; index++) {
          expect(_fillOf(tester, setupProgressKey(index)), _progressDone);
        }

        await _tapKey(tester, setupSummaryChangeReminderKey);
        expect(find.text(_reminderTitle), findsOneWidget);
        await _tapKey(tester, setupReminderPresetKey(ReminderPreset.morning));
        await _primary(tester);
        await _tapKey(tester, setupWeekOptionKey(WeekStart.saturday));
        await _primary(tester);
        await _primary(tester);
        expect(find.text('Daily at 08:00'), findsOneWidget);
        expect(find.text('Saturday'), findsOneWidget);

        await _tapKey(tester, setupSummaryChangeWeekKey);
        expect(find.text(_weekTitle), findsOneWidget);
        await _primary(tester);
        await _primary(tester);
        expect(find.text(_summaryTitle), findsOneWidget);

        await _tapKey(tester, setupSummaryChangeStorageKey);
        expect(find.text(_storageTitle), findsOneWidget);
        await _primary(tester);
        expect(find.text(_summaryTitle), findsOneWidget);
      });
    }
  });

  testWidgets(
    'Start journaling writes the reminder, time and week start then reports '
    'finished',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          final Completer<void> gate = Completer<void>();
          final _OrderedSettingsRepository repository =
              _OrderedSettingsRepository(gate: gate);
          final _Run run = await _pumpSetup(
            tester,
            layout: layout,
            repository: repository,
          );
          await _tapKey(tester, setupReminderPresetKey(ReminderPreset.morning));
          await _primary(tester);
          await _tapKey(tester, setupWeekOptionKey(WeekStart.sunday));
          await _primary(tester);
          await _primary(tester);
          expect(find.text('Daily at 08:00'), findsOneWidget);
          expect(find.text('Sunday'), findsOneWidget);
          expect(repository.order, isEmpty);

          await tester.tap(find.byKey(setupPrimaryKey));
          await tester.pump();
          expect(
            tester.getSemantics(find.byKey(setupPrimaryKey)),
            isSemantics(
              label: 'Start journaling',
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
            ),
          );
          expect(run.outcomes, isEmpty);

          gate.complete();
          await tester.pumpAndSettle();
          expect(repository.order, <String>[
            'reminderEnabled',
            'reminderTime',
            'weekStart',
          ]);
          expect(repository.reminderEnabledWrites, <bool>[true]);
          expect(repository.reminderTimeWrites, <ReminderTime>[_morning]);
          expect(repository.weekStartWrites, <WeekStart>[WeekStart.sunday]);
          expect(run.outcomes, <SetupOutcome>[SetupOutcome.finished]);
          expect(find.text(_saveError), findsNothing);
        });
      }
    },
  );

  testWidgets('a failed write keeps the summary and shows the save error', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final _Run run = await _pumpSetup(
          tester,
          layout: layout,
          repository: FakeSettingsRepository(
            writeError: StateError('disk full'),
          ),
        );
        await _toSummary(tester);
        expect(find.text(_saveError), findsNothing);

        await _primary(tester);
        expect(find.text(_saveError), findsOneWidget);
        expect(find.text(_summaryTitle), findsOneWidget);
        expect(run.outcomes, isEmpty);
        expect(
          tester.getSemantics(find.byKey(setupPrimaryKey)),
          isSemantics(
            label: 'Start journaling',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            isFocused: true,
          ),
        );
        expect(_focusedLabel(), 'Start journaling');

        await _primary(tester);
        expect(find.text(_saveError), findsOneWidget);
        expect(run.outcomes, isEmpty);
      });
    }
  });

  testWidgets(
    'skipping writes reminder on, 20:30 and Monday and reports skipped',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          final bool sidebar = layout == ShellLayout.sidebar;
          final _Run run = await _pumpSetup(
            tester,
            layout: layout,
            countryCode: 'SA',
            permission: ReminderPermission.denied,
          );
          await tester.tap(find.byType(SettingsToggle));
          await tester.pumpAndSettle();
          await _primary(tester);
          expect(find.text(_weekTitle), findsOneWidget);

          await tester.tap(find.text(sidebar ? _sidebarSkip : _bottomBarSkip));
          await tester.pumpAndSettle();
          expect(run.repository.reminderEnabledWrites, <bool>[true]);
          expect(run.repository.reminderTimeWrites, <ReminderTime>[_evening]);
          expect(run.repository.weekStartWrites, <WeekStart>[WeekStart.monday]);
          expect(run.outcomes, <SetupOutcome>[SetupOutcome.skipped]);
          expect(run.scheduler.permissionRequests, 0);

          final _Run escaped = await _pumpSetup(
            tester,
            layout: layout,
            countryCode: 'US',
          );
          await _press(tester, LogicalKeyboardKey.escape);
          expect(escaped.repository.reminderEnabledWrites, <bool>[true]);
          expect(escaped.repository.reminderTimeWrites, <ReminderTime>[
            _evening,
          ]);
          expect(escaped.repository.weekStartWrites, <WeekStart>[
            WeekStart.monday,
          ]);
          expect(escaped.outcomes, <SetupOutcome>[SetupOutcome.skipped]);
          expect(escaped.scheduler.permissionRequests, 0);
        });
      }
    },
  );

  testWidgets('a failed skip write stays on the step with the save error', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final _Run run = await _pumpSetup(
          tester,
          layout: layout,
          repository: FakeSettingsRepository(
            writeError: StateError('disk full'),
          ),
        );
        await _primary(tester);
        expect(find.text(_weekTitle), findsOneWidget);

        await _tapKey(tester, setupSkipKey);
        expect(find.text(_saveError), findsOneWidget);
        expect(find.text(_weekTitle), findsOneWidget);
        expect(run.outcomes, isEmpty);

        await _primary(tester);
        expect(find.text(_storageTitle), findsOneWidget);
        expect(find.text(_saveError), findsNothing);
      });
    }
  });

  testWidgets(
    'the skip action shows on the three steps and not on the summary with '
    'layout labels',
    (WidgetTester tester) async {
      for (final ShellLayout layout in ShellLayout.values) {
        await _onLayout(layout, () async {
          final bool sidebar = layout == ShellLayout.sidebar;
          final String shown = sidebar ? _sidebarSkip : _bottomBarSkip;
          final String hidden = sidebar ? _bottomBarSkip : _sidebarSkip;
          await _pumpSetup(tester, layout: layout);

          for (final String title in <String>[
            _reminderTitle,
            _weekTitle,
            _storageTitle,
          ]) {
            expect(find.text(title), findsOneWidget);
            expect(find.text(shown), findsOneWidget, reason: title);
            expect(find.text(hidden), findsNothing, reason: title);
            expect(
              find.text('↵ to continue'),
              sidebar ? findsOneWidget : findsNothing,
              reason: title,
            );
            await _primary(tester);
          }

          expect(find.text(_summaryTitle), findsOneWidget);
          expect(find.text(_sidebarSkip), findsNothing);
          expect(find.text(_bottomBarSkip), findsNothing);
          expect(find.byKey(setupSkipKey), findsNothing);
        });
      }
    },
  );

  testWidgets('Back on the first step backs out and the arrow keys move '
      'between steps', (WidgetTester tester) async {
    for (final ShellLayout layout in ShellLayout.values) {
      await _onLayout(layout, () async {
        final _Run run = await _pumpSetup(tester, layout: layout);
        expect(_focusedLabel(), 'Continue');

        await _press(tester, LogicalKeyboardKey.arrowLeft);
        expect(run.backOuts, <String>['back']);
        await _tapKey(tester, setupBackKey);
        expect(run.backOuts, <String>['back', 'back']);
        expect(find.text(_reminderTitle), findsOneWidget);

        await _tapKey(tester, setupReminderPresetKey(ReminderPreset.other));
        for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowLeft,
        ]) {
          _focusTimeField(tester);
          await tester.pump();
          await _press(tester, key);
          expect(find.text(_reminderTitle), findsOneWidget);
          expect(run.backOuts, <String>['back', 'back']);
        }

        await _tapKey(tester, setupReminderPresetKey(ReminderPreset.evening));
        await _press(tester, LogicalKeyboardKey.arrowRight);
        expect(find.text(_weekTitle), findsOneWidget);
        await _press(tester, LogicalKeyboardKey.enter);
        expect(find.text(_storageTitle), findsOneWidget);
        await _press(tester, LogicalKeyboardKey.arrowLeft);
        expect(find.text(_weekTitle), findsOneWidget);
        await _press(tester, LogicalKeyboardKey.arrowRight);
        await _press(tester, LogicalKeyboardKey.arrowRight);
        expect(find.text(_summaryTitle), findsOneWidget);
        expect(run.outcomes, isEmpty);
        expect(run.repository.reminderEnabledWrites, isEmpty);
      });
    }
  });
}
