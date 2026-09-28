import 'dart:async';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_settings_repository.dart';
import 'support/recording_reminder_scheduler.dart';
import 'support/settings_harness.dart';

const Size _desktop = Size(1280, 800);
const Size _phone = Size(360, 740);
const double _largeTextScale = 1.5;

const Key _railKey = ValueKey<String>('settings-tab-rail');
const Key _chipsKey = ValueKey<String>('settings-tab-chips');
const Key _contentKey = ValueKey<String>('settings-tab-content');

const String _syncStorage = 'syncStorage';
const String _remindersSound = 'remindersSound';
const String _journal = 'journal';
const String _data = 'data';

const List<String> _tabNames = <String>[
  _syncStorage,
  _remindersSound,
  _journal,
  _data,
];

const Map<String, String> _tabLabels = <String, String>{
  _syncStorage: 'Sync & storage',
  _remindersSound: 'Reminders & sound',
  _journal: 'Journal',
  _data: 'Data',
};

const List<String> _sublabels = <String>[
  'where entries live',
  'nudges, prompts',
  'calendar, text size',
  'export, delete',
];

const List<String> _chipLabels = <String>[
  'Sync',
  'Reminders',
  'Journal',
  'Data',
];

const Map<String, List<String>> _rowsByTab = <String, List<String>>{
  _syncStorage: <String>[
    'Storage mode',
    'Server URL',
    'Access token',
    'Sync frequency',
    'Recovery passphrase',
    'Pair a device',
    'Connection',
  ],
  _remindersSound: <String>['Daily reminder', 'Reminder time', 'Sound effects'],
  _journal: <String>['Text size', 'Week starts on', 'Spell check'],
  _data: <String>['Export', 'Reclaim space', 'Delete all'],
};

const String _deleteNotice = 'Deleted 1 day and 2 entries.';

Finder _tab(String name) => find.byKey(ValueKey<String>('settings-tab-$name'));

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
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          backgroundColor: Palette.page,
          body: SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String name) async {
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

void main() {
  testWidgets(
    'sidebar settings shows the header and a four-tab rail with sublabels, opening on Sync & storage',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        final SemanticsHandle semantics = tester.ensureSemantics();
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
        expect(rail, findsOneWidget);
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
        _expectSelected(tester, _syncStorage);
        expect(find.text('Storage mode').hitTestable(), findsOneWidget);
        expect(find.text('Daily reminder'), findsNothing);
        expect(find.text('Delete all…'), findsNothing);
        semantics.dispose();
      });
    },
  );

  testWidgets(
    'sidebar settings keeps the rail 176 wide and the content at most 600 wide while the content scrolls',
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
        expect(tester.getSize(rail).width, 176);
        expect(tester.getSize(content).width, lessThanOrEqualTo(600));
        expect(tester.getTopLeft(content).dx - tester.getTopRight(rail).dx, 24);

        final ScrollableState scrollable = tester.state<ScrollableState>(
          find.ancestor(of: content, matching: find.byType(Scrollable)).first,
        );
        expect(scrollable.position.maxScrollExtent, greaterThanOrEqualTo(200));
        final double railTop = tester.getTopLeft(rail).dy;
        final double contentTop = tester.getTopLeft(content).dy;

        scrollable.position.jumpTo(200);
        await tester.pumpAndSettle();

        expect(scrollable.position.pixels, 200);
        expect(tester.getTopLeft(content).dy, contentTop - 200);
        expect(tester.getTopLeft(rail).dy, railTop);
        expect(tester.getSize(rail).width, 176);
        expect(tester.getSize(content).width, lessThanOrEqualTo(600));
      });
    },
  );

  testWidgets(
    'bottom-bar settings shows four scrolling chips Sync, Reminders, Journal, Data',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        await _pumpSettings(
          tester,
          platform: TargetPlatform.android,
          size: _phone,
        );

        final Finder chips = find.byKey(_chipsKey);
        expect(chips, findsOneWidget);
        expect(find.byKey(_railKey), findsNothing);
        final List<Scrollable> rows = tester
            .widgetList<Scrollable>(
              find.descendant(of: chips, matching: find.byType(Scrollable)),
            )
            .toList();
        expect(rows, hasLength(1));
        expect(rows.single.axisDirection, AxisDirection.right);
        double previousRight = double.negativeInfinity;
        double? row;
        for (final String label in _chipLabels) {
          final Finder chip = find.descendant(
            of: chips,
            matching: find.text(label),
          );
          expect(chip, findsOneWidget, reason: label);
          final Rect rect = tester.getRect(chip);
          expect(rect.left, greaterThan(previousRight), reason: label);
          row ??= rect.center.dy;
          expect(rect.center.dy, row, reason: label);
          previousRight = rect.right;
        }
        expect(find.text('Storage mode'), findsOneWidget);

        await tester.tap(
          find.descendant(of: chips, matching: find.text('Data')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Delete all'), findsOneWidget);
        expect(find.text('Storage mode'), findsNothing);
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
      expect(_focusedLabel(), _tabLabels[_syncStorage]);
      await _press(tester, LogicalKeyboardKey.tab);
      expect(_focusedLabel(), _tabLabels[_remindersSound]);

      await _press(tester, LogicalKeyboardKey.space);

      _expectSelected(tester, _remindersSound);
      expect(find.text('Daily reminder'), findsOneWidget);
      expect(find.text('Storage mode'), findsNothing);
      expect(_focusedLabel(), _tabLabels[_remindersSound]);

      await _press(tester, LogicalKeyboardKey.tab);
      expect(_focusedLabel(), _tabLabels[_journal]);
      await _press(tester, LogicalKeyboardKey.enter);

      _expectSelected(tester, _journal);
      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Daily reminder'), findsNothing);
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
          'Sync & storage',
          'Reminders & sound',
          'Journal',
          'Data',
          'Export…',
          'Reclaim space',
          'Delete all…',
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

  testWidgets('a platform other than macOS shows the chip layout', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.linux, () async {
      await _pumpSettings(
        tester,
        platform: TargetPlatform.linux,
        size: _desktop,
      );

      final Finder chips = find.byKey(_chipsKey);
      expect(chips, findsOneWidget);
      expect(find.byKey(_railKey), findsNothing);
      for (final String label in _chipLabels) {
        expect(
          find.descendant(of: chips, matching: find.text(label)),
          findsOneWidget,
        );
      }

      await tester.tap(
        find.descendant(of: chips, matching: find.text('Journal')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Storage mode'), findsNothing);
    });
  });
}
