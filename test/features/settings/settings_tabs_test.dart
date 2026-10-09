import 'dart:async';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sync_overrides.dart';
import 'support/fake_settings_repository.dart';
import 'support/recording_reminder_scheduler.dart';
import 'support/settings_harness.dart';

const Size _desktop = Size(1280, 800);
const Size _phone = Size(360, 740);
const double _largeTextScale = 2;

const Key _railKey = ValueKey<String>('settings-tab-rail');
const Key _chipsKey = ValueKey<String>('settings-tab-chips');
const Key _contentKey = ValueKey<String>('settings-tab-content');

const String _journal = 'journal';
const String _syncStorage = 'syncStorage';
const String _remindersSound = 'remindersSound';
const String _data = 'data';

const List<String> _tabNames = <String>[
  _journal,
  _syncStorage,
  _remindersSound,
  _data,
];

const Map<String, String> _tabLabels = <String, String>{
  _journal: 'Journal',
  _syncStorage: 'Sync & storage',
  _remindersSound: 'Reminders & sound',
  _data: 'Data',
};

const List<String> _sublabels = <String>[
  'theme, calendar, text size',
  'where entries live',
  'nudges, prompts',
  'export, delete',
];

const String _firstSyncRow = 'Start syncing';
const String _backToSettings = 'Settings';

const Map<String, List<String>> _rowsByTab = <String, List<String>>{
  _journal: <String>[
    'Appearance',
    'Text size',
    'Week starts on',
    'Spell check',
  ],
  _syncStorage: <String>[
    _firstSyncRow,
    'Join my journal',
    'Restore with recovery phrase',
  ],
  _remindersSound: <String>['Daily reminder', 'Reminder time', 'Sound effects'],
  _data: <String>['Export', 'Reclaim space', 'Delete all', 'Privacy policy'],
};

const String _deleteNotice = 'Deleted 1 day and 2 entries.';

Finder _tab(String name) => find.byKey(ValueKey<String>('settings-tab-$name'));

final Finder _backPill = find.ancestor(
  of: find.text(_backToSettings),
  matching: find.byType(GlassSurface),
);

Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size size,
  SettingsDataController? dataController,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
        ),
        reminderClockProvider.overrideWithValue(() => DateTime(2026, 9, 28, 9)),
        reminderSchedulerProvider.overrideWithValue(
          RecordingReminderScheduler(),
        ),
        spellCheckAvailabilityProvider.overrideWithValue(
          const AsyncValue<SpellCheckAvailability>.data(
            SpellCheckAvailability.available,
          ),
        ),
        if (dataController != null)
          settingsDataControllerProvider.overrideWith(
            (Ref ref) async => dataController,
          ),
        ...syncOffOverrides(),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: FieldNotesColors.light.page,
          body: const SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String name) async {
  if (_backPill.evaluate().isNotEmpty) {
    await tester.tap(_backPill);
    await tester.pumpAndSettle();
  }
  await tester.tap(_tab(name));
  await tester.pumpAndSettle();
}

Future<void> _runDeleteAll(WidgetTester tester) async {
  await _select(tester, _data);
  await tester.tap(find.text('Delete all…'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete everything'));
  await tester.pump();
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

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void _expectSelected(WidgetTester tester, String selected) {
  for (final String name in _tabNames) {
    expect(
      tester.getSemantics(_tab(name)),
      isSemantics(
        label: _tabLabels[name],
        isButton: true,
        hasSelectedState: true,
        isSelected: name == selected,
      ),
      reason: name,
    );
  }
}

void _expectSectionList(WidgetTester tester) {
  expect(find.byKey(_railKey), findsNothing);
  expect(find.byKey(_chipsKey), findsNothing);
  double previousBottom = double.negativeInfinity;
  for (final String name in _tabNames) {
    final Finder row = _tab(name);
    expect(row, findsOneWidget, reason: name);
    expect(
      find.descendant(of: row, matching: find.text(_tabLabels[name]!)),
      findsOneWidget,
      reason: name,
    );
    final Rect rect = tester.getRect(row);
    expect(rect.top, greaterThan(previousBottom), reason: name);
    previousBottom = rect.bottom;
  }
}

void main() {
  testWidgets('the Journal tab reads theme, calendar, text size', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      await _pumpSettings(
        tester,
        platform: TargetPlatform.macOS,
        size: _desktop,
      );

      final Finder rail = find.byKey(_railKey);
      expect(
        find.descendant(
          of: rail,
          matching: find.text('theme, calendar, text size'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rail, matching: find.text('calendar, text size')),
        findsNothing,
      );
    });
  });

  testWidgets(
    'settings lists Journal, Sync & storage, Reminders & sound, Data and opens on Journal',
    (WidgetTester tester) async {
      expect(SettingsTab.values, <SettingsTab>[
        SettingsTab.journal,
        SettingsTab.syncStorage,
        SettingsTab.remindersSound,
        SettingsTab.data,
      ]);
      expect(
        <String>[for (final SettingsTab tab in SettingsTab.values) tab.label],
        <String>['Journal', 'Sync & storage', 'Reminders & sound', 'Data'],
      );

      await _onPlatform(TargetPlatform.macOS, () async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        await _pumpSettings(
          tester,
          platform: TargetPlatform.macOS,
          size: _desktop,
        );

        final Finder rail = find.byKey(_railKey);
        expect(rail, findsOneWidget);
        double previousTop = double.negativeInfinity;
        for (final String name in _tabNames) {
          final Finder label = find.descendant(
            of: rail,
            matching: find.text(_tabLabels[name]!),
          );
          expect(label, findsOneWidget, reason: name);
          final double top = tester.getRect(label).top;
          expect(top, greaterThan(previousTop), reason: name);
          previousTop = top;
        }
        _expectSelected(tester, _journal);
        expect(find.text('Text size').hitTestable(), findsOneWidget);
        expect(find.text(_firstSyncRow), findsNothing);
        expect(find.text('Daily reminder'), findsNothing);
        expect(find.text('Delete all…'), findsNothing);
        semantics.dispose();
      });
    },
  );

  testWidgets(
    'sidebar settings shows the header and a four-tab rail with sublabels',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        await _pumpSettings(
          tester,
          platform: TargetPlatform.macOS,
          size: _desktop,
        );

        expect(find.text('preferences'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(
          tester.getRect(find.text('preferences')).bottom,
          lessThanOrEqualTo(tester.getRect(find.text('Settings')).top),
        );
        final Finder rail = find.byKey(_railKey);
        double previousBottom = double.negativeInfinity;
        for (int index = 0; index < _tabNames.length; index++) {
          final Finder label = find.descendant(
            of: rail,
            matching: find.text(_tabLabels[_tabNames[index]]!),
          );
          final Finder sublabel = find.descendant(
            of: rail,
            matching: find.text(_sublabels[index]),
          );
          expect(label, findsOneWidget);
          expect(sublabel, findsOneWidget);
          final Rect labelRect = tester.getRect(label);
          final Rect sublabelRect = tester.getRect(sublabel);
          expect(labelRect.top, greaterThan(previousBottom));
          expect(sublabelRect.top, greaterThanOrEqualTo(labelRect.bottom));
          previousBottom = sublabelRect.bottom;
        }
      });
    },
  );

  testWidgets(
    'sidebar settings keeps the rail 196 wide beside a dashed rule and the rows fill the window while the content scrolls',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        await _pumpSettings(
          tester,
          platform: TargetPlatform.macOS,
          size: _desktop,
          textScale: _largeTextScale,
        );

        final Finder rail = find.byKey(_railKey);
        final Finder content = find.byKey(_contentKey);
        final Finder rule = find.byWidgetPredicate(
          (Widget widget) =>
              widget is DashedDivider && widget.axis == Axis.vertical,
          description: 'the vertical dashed rule',
        );
        expect(rule, findsOneWidget);
        final DashedDivider divider = tester.widget<DashedDivider>(rule);
        expect(divider.thickness, 1.5);
        expect(
          divider.color!.toARGB32(),
          FieldNotesColors.light.ink25.toARGB32(),
        );
        expect(tester.getSize(rail).width, 196);
        expect(
          tester.getRect(rule).left,
          greaterThan(tester.getRect(rail).right),
        );
        expect(
          tester.getRect(content).left,
          greaterThan(tester.getRect(rule).right),
        );
        expect(
          tester.getRect(content).right,
          moreOrLessEquals(_desktop.width - 28),
        );
        expect(
          tester.getSize(content).width,
          greaterThan(_desktop.width - 28 - tester.getRect(rule).right - 30),
        );

        final ScrollableState scrollable = tester.state<ScrollableState>(
          find.ancestor(of: content, matching: find.byType(Scrollable)).first,
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        final double offset = scrollable.position.maxScrollExtent;
        final double railTop = tester.getTopLeft(rail).dy;
        final double contentTop = tester.getTopLeft(content).dy;

        scrollable.position.jumpTo(offset);
        await tester.pumpAndSettle();

        expect(scrollable.position.pixels, offset);
        expect(tester.getTopLeft(content).dy, contentTop - offset);
        expect(tester.getTopLeft(rail).dy, railTop);
        expect(tester.getSize(rail).width, 196);
        expect(
          tester.getRect(content).right,
          moreOrLessEquals(_desktop.width - 28),
        );
      });
    },
  );

  testWidgets(
    'bottom-bar settings lists the four sections and opens each as its own page',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        await _pumpSettings(
          tester,
          platform: TargetPlatform.android,
          size: _phone,
        );

        _expectSectionList(tester);
        expect(_backPill, findsNothing);
        expect(find.text(_firstSyncRow), findsNothing);
        expect(find.text('Delete all'), findsNothing);

        await tester.tap(_tab(_data));
        await tester.pumpAndSettle();

        expect(find.text('Delete all'), findsOneWidget);
        expect(find.text(_firstSyncRow), findsNothing);
        expect(_tab(_journal), findsNothing);
        expect(_backPill, findsOneWidget);

        await tester.tap(_backPill);
        await tester.pumpAndSettle();

        _expectSectionList(tester);
        expect(find.text('Delete all'), findsNothing);
      });
    },
  );

  testWidgets('every live settings row is found on exactly one tab', (
    WidgetTester tester,
  ) async {
    for (final (TargetPlatform platform, Size size) in <(TargetPlatform, Size)>[
      (TargetPlatform.macOS, _desktop),
      (TargetPlatform.android, _phone),
    ]) {
      await _onPlatform(platform, () async {
        await _pumpSettings(tester, platform: platform, size: size);
        final Map<String, List<String>> foundOn = <String, List<String>>{
          for (final List<String> rows in _rowsByTab.values)
            for (final String row in rows) row: <String>[],
        };
        for (final String name in _tabNames) {
          await _select(tester, name);
          for (final String row in foundOn.keys) {
            if (find.text(row).evaluate().isNotEmpty) {
              foundOn[row] = <String>[...foundOn[row]!, name];
            }
          }
        }
        for (final MapEntry<String, List<String>> tab in _rowsByTab.entries) {
          for (final String row in tab.value) {
            expect(foundOn[row], <String>[
              tab.key,
            ], reason: '$row on ${platform.name}');
          }
        }
      });
    }
  });

  testWidgets('a notice raised on one tab stays visible after switching tabs', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      final FakeSettingsDataController controller = FakeSettingsDataController(
        deleteResult: const DataActionSucceeded(_deleteNotice),
      );
      await _pumpSettings(
        tester,
        platform: TargetPlatform.macOS,
        size: _desktop,
        dataController: controller,
      );

      await _runDeleteAll(tester);
      await tester.pumpAndSettle();

      expect(controller.deleteCalls, 1);
      expect(find.text(_deleteNotice).hitTestable(), findsOneWidget);

      await _select(tester, _journal);

      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Delete all'), findsNothing);
      expect(find.text(_deleteNotice).hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.text(_deleteNotice)).bottom,
        lessThan(tester.getRect(find.text('Text size')).top),
      );

      await _select(tester, _remindersSound);

      expect(find.text(_deleteNotice).hitTestable(), findsOneWidget);
    });
  });

  testWidgets('tabs are reachable by keyboard and expose selected state', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpSettings(
        tester,
        platform: TargetPlatform.macOS,
        size: _desktop,
      );

      await _press(tester, LogicalKeyboardKey.tab);
      expect(_focusedLabel(), _tabLabels[_journal]);
      await _press(tester, LogicalKeyboardKey.tab);
      expect(_focusedLabel(), _tabLabels[_syncStorage]);

      await _press(tester, LogicalKeyboardKey.space);

      _expectSelected(tester, _syncStorage);
      expect(find.text(_firstSyncRow), findsOneWidget);
      expect(find.text('Text size'), findsNothing);
      expect(_focusedLabel(), _tabLabels[_syncStorage]);

      await _press(tester, LogicalKeyboardKey.tab);
      expect(_focusedLabel(), _tabLabels[_remindersSound]);
      await _press(tester, LogicalKeyboardKey.enter);

      _expectSelected(tester, _remindersSound);
      expect(find.text('Daily reminder'), findsOneWidget);
      expect(find.text(_firstSyncRow), findsNothing);
      semantics.dispose();
    });
  });

  testWidgets(
    'one Tab lap reaches the tab buttons and every control of the selected tab',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        await _pumpSettings(
          tester,
          platform: TargetPlatform.macOS,
          size: _desktop,
        );
        await _select(tester, _data);

        await _press(tester, LogicalKeyboardKey.tab);
        final FocusNode anchor = FocusManager.instance.primaryFocus!;
        final List<String> lap = <String>[_focusedLabel()];
        for (int press = 0; press < 20; press++) {
          await _press(tester, LogicalKeyboardKey.tab);
          if (identical(FocusManager.instance.primaryFocus, anchor)) {
            break;
          }
          lap.add(_focusedLabel());
        }

        expect(identical(FocusManager.instance.primaryFocus, anchor), isTrue);
        expect(lap, <String>[
          'Journal',
          'Sync & storage',
          'Reminders & sound',
          'Data',
          'Export…',
          'Reclaim space',
          'Delete all…',
          'Open',
        ]);
      });
    },
  );

  testWidgets(
    'a notice from work that finishes after switching tabs still shows',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        final Completer<void> gate = Completer<void>();
        final FakeSettingsDataController controller =
            FakeSettingsDataController(
              deleteResult: const DataActionSucceeded(_deleteNotice),
              gate: gate,
            );
        await _pumpSettings(
          tester,
          platform: TargetPlatform.android,
          size: _phone,
          dataController: controller,
        );

        await _runDeleteAll(tester);
        await tester.pumpAndSettle();
        expect(controller.deleteCalls, 1);
        expect(find.text(_deleteNotice), findsNothing);

        await _select(tester, _journal);
        await _select(tester, _data);
        expect(
          tester
              .widget<StickerButton>(
                find.widgetWithText(StickerButton, 'Delete all…'),
              )
              .onPressed,
          isNull,
        );
        await _select(tester, _journal);
        expect(find.text('Text size'), findsOneWidget);

        gate.complete();
        await tester.pumpAndSettle();

        expect(controller.deleteCalls, 1);
        expect(find.text(_deleteNotice).hitTestable(), findsOneWidget);
        expect(find.text('Text size'), findsOneWidget);
      });
    },
  );

  testWidgets('a platform other than macOS shows the phone section list', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.linux, () async {
      await _pumpSettings(
        tester,
        platform: TargetPlatform.linux,
        size: _desktop,
      );

      _expectSectionList(tester);

      await tester.tap(_tab(_journal));
      await tester.pumpAndSettle();

      expect(find.text('Text size'), findsOneWidget);
      expect(find.text(_firstSyncRow), findsNothing);
      expect(_backPill, findsOneWidget);
    });
  });
}
