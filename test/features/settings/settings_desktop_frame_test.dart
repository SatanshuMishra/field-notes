import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/settings_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../../support/sync_overrides.dart';
import '../../support/update_overrides.dart';
import 'support/fake_settings_repository.dart';
import 'support/recording_reminder_scheduler.dart';
import 'support/settings_harness.dart';

const Size _window = Size(1440, 900);
const Size _shortWindow = Size(1140, 480);
const Size _smallestWindow = Size(872, 600);
const double _contentMaxWidth = 680;
const double _tolerance = 0.01;

const Key _settingsButton = ValueKey<String>('settings-button');

List<JournalDevice> _devices(DateTime now) => <JournalDevice>[
  JournalDevice(
    deviceId: 'this-mac',
    name: 'Studio Mac',
    createdAt: now.subtract(const Duration(days: 30)),
    lastSeenAt: now,
    isThisDevice: true,
  ),
  JournalDevice(
    deviceId: 'phone',
    name: 'Galaxy S24 Ultra',
    createdAt: now.subtract(const Duration(days: 20)),
    lastSeenAt: now.subtract(const Duration(hours: 3)),
    isThisDevice: false,
  ),
];

List<Override> _shellOverrides(DateTime now) {
  final List<Override> sync = syncOnOverrides(
    status: SyncedStatus(now),
    devices: _devices(now),
  );
  final Set<Object> replaced = <Object>{
    for (final Override override in sync) override.origin,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    ...sync,
    appSettingsProvider.overrideWith(
      (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
    ),
    settingsDataControllerProvider.overrideWith(
      (Ref ref) async => FakeSettingsDataController(),
    ),
  ];
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required TargetPlatform platform,
  Size window = _window,
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _shellOverrides(DateTime.now().toUtc()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_settingsButton));
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(WidgetTester tester) async {
  final DateTime now = DateTime.now().toUtc();
  tester.view.physicalSize = _shortWindow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
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
        settingsDataControllerProvider.overrideWith(
          (Ref ref) async => FakeSettingsDataController(),
        ),
        ...syncOnOverrides(status: SyncedStatus(now), devices: _devices(now)),
        ...updateQuietOverrides(),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: context.colors.page,
            body: const SettingsScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inSettings(Finder finder) =>
    find.descendant(of: find.byType(SettingsScreen), matching: finder);

final Finder _rule = _inSettings(
  find.byWidgetPredicate(
    (Widget widget) => widget is DashedDivider && widget.axis == Axis.vertical,
    description: 'the dashed rule beside the section list',
  ),
);

Map<String, Rect> _frame(WidgetTester tester) {
  final Offset origin = tester.getTopLeft(find.byType(SettingsScreen));
  Rect relative(Finder finder) => tester.getRect(finder).shift(-origin);
  return <String, Rect>{
    'column': relative(find.byKey(settingsSidebarColumnKey)),
    'kicker': relative(_inSettings(find.text('settings'))),
    'rail': relative(find.byKey(settingsTabRailKey)),
    for (final SettingsTab tab in SettingsTab.values) ...<String, Rect>{
      'entry ${tab.name}': relative(find.byKey(settingsTabFaceKey(tab))),
      'icon ${tab.name}': relative(
        find.descendant(
          of: find.byKey(settingsTabKey(tab)),
          matching: find.byType(SettingsIcon),
        ),
      ),
      'label ${tab.name}': relative(
        find.descendant(
          of: find.byKey(settingsTabKey(tab)),
          matching: find.text(tab.label),
        ),
      ),
    },
    'separator': relative(find.byKey(settingsTabSeparatorKey)),
    'rule': relative(_rule),
    'title': relative(find.byKey(settingsContentTitleKey)),
    'content': relative(find.byKey(settingsContentColumnKey)),
  };
}

BoxDecoration _face(WidgetTester tester, SettingsTab tab) =>
    tester.widget<Container>(find.byKey(settingsTabFaceKey(tab))).decoration!
        as BoxDecoration;

Color _iconColour(WidgetTester tester, SettingsTab tab) => tester
    .widget<SettingsIcon>(
      find.descendant(
        of: find.byKey(settingsTabKey(tab)),
        matching: find.byType(SettingsIcon),
      ),
    )
    .color;

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

ScrollableState _contentScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .ancestor(
            of: find.byKey(settingsTabContentKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(settingsContentTitleKey)).data!;

void main() {
  testWidgets('Windows uses the same settings frame as macOS', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester, platform: TargetPlatform.macOS);
    final Map<String, Rect> mac = _frame(tester);
    final TextStyle? macTitle = tester
        .widget<Text>(find.byKey(settingsContentTitleKey))
        .style;

    await _pumpShell(tester, platform: TargetPlatform.windows);
    expect(_inSettings(find.text('preferences')), findsNothing);
    expect(_inSettings(find.text('Settings')), findsNothing);
    expect(find.byKey(settingsTabRailKey), findsOneWidget);
    final Map<String, Rect> windows = _frame(tester);
    expect(windows.keys, mac.keys);
    for (final String part in mac.keys) {
      final Rect a = mac[part]!;
      final Rect b = windows[part]!;
      expect(b.left, closeTo(a.left, _tolerance), reason: part);
      expect(b.top, closeTo(a.top, _tolerance), reason: part);
      expect(b.width, closeTo(a.width, _tolerance), reason: part);
      if (part != 'column' && part != 'rule') {
        expect(b.height, closeTo(a.height, _tolerance), reason: part);
      }
    }
    final TextStyle? windowsTitle = tester
        .widget<Text>(find.byKey(settingsContentTitleKey))
        .style;
    expect(windowsTitle?.fontFamily, macTitle?.fontFamily);
    expect(windowsTitle?.fontSize, 34);
    expect(windowsTitle?.fontWeight, FontWeight.w500);
    expect(_title(tester), 'Journal');
    final DashedDivider rule = tester.widget<DashedDivider>(_rule);
    expect(rule.thickness, 1);
    expect(rule.color?.toARGB32(), FieldNotesColors.light.ink22.toARGB32());
    expect(mac['content']!.width, closeTo(_contentMaxWidth, _tolerance));
  });

  testWidgets(
    'the section list marks the open section and follows the keyboard',
    (WidgetTester tester) async {
      final FieldNotesColors colors = FieldNotesColors.light;
      final FocusHighlightStrategy strategy =
          FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpScreen(tester);

      expect(
        _face(tester, SettingsTab.journal).color?.toARGB32(),
        Palette.coral.withValues(alpha: 0.11).toARGB32(),
      );
      expect(
        _iconColour(tester, SettingsTab.journal).toARGB32(),
        colors.accentInk.toARGB32(),
      );
      for (final SettingsTab tab in SettingsTab.values) {
        expect(
          tester.getSemantics(find.byKey(settingsTabKey(tab))),
          isSemantics(
            label: tab.label,
            isButton: true,
            hasSelectedState: true,
            isSelected: tab == SettingsTab.journal,
            hasTapAction: true,
          ),
          reason: tab.name,
        );
        if (tab == SettingsTab.journal) {
          continue;
        }
        expect(_face(tester, tab).color, isNull, reason: tab.name);
        expect(
          _iconColour(tester, tab).toARGB32(),
          colors.ink.toARGB32(),
          reason: tab.name,
        );
      }

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(find.byKey(settingsTabFaceKey(SettingsTab.data))),
      );
      await tester.pump();
      expect(
        _face(tester, SettingsTab.data).color?.toARGB32(),
        colors.ink.withValues(alpha: 0.06).toARGB32(),
      );
      expect(
        _face(tester, SettingsTab.journal).color?.toARGB32(),
        Palette.coral.withValues(alpha: 0.11).toARGB32(),
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(_face(tester, SettingsTab.data).color, isNull);

      await _press(tester, LogicalKeyboardKey.tab);
      expect(_focusedLabel(), 'Journal');
      expect(
        find.descendant(
          of: find.byKey(settingsTabKey(SettingsTab.journal)),
          matching: find.byKey(focusRingKey),
        ),
        findsOneWidget,
      );
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'Sync & storage');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_title(tester), 'Sync & storage');
      expect(
        tester.getSemantics(
          find.byKey(settingsTabKey(SettingsTab.syncStorage)),
        ),
        isSemantics(
          label: 'Sync & storage',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          isFocusable: true,
          isFocused: true,
        ),
      );
      expect(
        _face(tester, SettingsTab.syncStorage).color?.toARGB32(),
        Palette.coral.withValues(alpha: 0.11).toARGB32(),
      );
      expect(_face(tester, SettingsTab.journal).color, isNull);

      final ScrollableState scroll = _contentScroll(tester);
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(scroll.position.pixels, greaterThan(0));

      await _press(tester, LogicalKeyboardKey.tab);
      expect(_focusedLabel(), 'Reminders & sound');
      await _press(tester, LogicalKeyboardKey.space);
      expect(_title(tester), 'Reminders & sound');
      expect(_contentScroll(tester).position.pixels, 0);

      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focusedLabel(), 'About');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_title(tester), 'About');
      expect(
        _iconColour(tester, SettingsTab.about).toARGB32(),
        colors.accentInk.toARGB32(),
      );
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focusedLabel(), 'Data');
      semantics.dispose();
    },
  );

  testWidgets('the settings frame fits the smallest window', (
    WidgetTester tester,
  ) async {
    await _pumpShell(
      tester,
      platform: TargetPlatform.macOS,
      window: _smallestWindow,
    );
    expect(tester.takeException(), isNull);
    for (final SettingsTab tab in SettingsTab.values) {
      await tester.tap(find.byKey(settingsTabKey(tab)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab.label);
      expect(_title(tester), tab.label);
      final Rect content = tester.getRect(find.byKey(settingsContentColumnKey));
      expect(content.width, lessThan(_contentMaxWidth), reason: tab.label);
      expect(
        content.right,
        lessThanOrEqualTo(
          tester.getRect(find.byType(SettingsScreen)).right - 34 + _tolerance,
        ),
        reason: tab.label,
      );
      final ScrollableState scroll = _contentScroll(tester);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: tab.label);
    }
  });
}
