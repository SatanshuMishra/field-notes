import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/icons/settings_icons.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../../support/sync_overrides.dart';
import 'support/settings_harness.dart';

const Size _window = Size(1440, 900);
const Size _laptopWindow = Size(1280, 800);
const Size _smallestWindow = Size(872, 600);
const double _railWidth = 190;
const double _columnLeft = 24;
const double _columnTop = 26;
const double _columnRight = 14;
const double _kickerInset = 10;
const double _kickerGap = 6;
const double _entryGap = 6;
const double _separatorGap = 16;
const double _separatorInset = 12;
const double _contentLeft = 28;
const double _contentTop = 26;
const double _titleAbove = 17;
const double _titleBelow = 26;
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

List<Override> _overrides(DateTime now, SyncStatus status) {
  final List<Override> sync = syncOnOverrides(
    status: status,
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

Future<void> _pumpMacSettings(
  WidgetTester tester, {
  Size window = _window,
  SyncStatus? status,
}) async {
  final DateTime now = DateTime.now().toUtc();
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(now, status ?? SyncedStatus(now)),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_settingsButton));
  await tester.pumpAndSettle();
}

Finder _element(Element element) =>
    find.byElementPredicate((Element candidate) => candidate == element);

Finder _inSettings(Finder finder) =>
    find.descendant(of: find.byType(SettingsScreen), matching: finder);

void _expectStyle(
  TextStyle? style, {
  required String family,
  required double size,
  required FontWeight weight,
  required Color color,
  required String reason,
}) {
  expect(style?.fontFamily, family, reason: reason);
  expect(style?.fontSize, size, reason: reason);
  expect(style?.fontWeight, weight, reason: reason);
  expect(style?.color?.toARGB32(), color.toARGB32(), reason: reason);
}

void main() {
  testWidgets('the desktop settings frame matches the design', (
    WidgetTester tester,
  ) async {
    final FieldNotesColors colors = FieldNotesColors.light;
    await _pumpMacSettings(tester);

    final Rect area = tester.getRect(find.byType(SettingsScreen));
    expect(_inSettings(find.text('preferences')), findsNothing);
    expect(_inSettings(find.text('Settings')), findsNothing);

    final Rect column = tester.getRect(find.byKey(settingsSidebarColumnKey));
    expect(column.left, closeTo(area.left, _tolerance));
    expect(column.top, closeTo(area.top, _tolerance));
    expect(
      column.width,
      closeTo(_columnLeft + _railWidth + _columnRight, _tolerance),
    );

    final Finder kicker = _inSettings(find.text('settings'));
    expect(kicker, findsOneWidget);
    _expectStyle(
      tester.widget<Text>(kicker).style,
      family: TypographyTokens.accent,
      size: 16,
      weight: FontWeight.w600,
      color: colors.accentInk,
      reason: 'the settings kicker',
    );
    final Rect kickerRect = tester.getRect(kicker);
    expect(
      kickerRect.left,
      closeTo(column.left + _columnLeft + _kickerInset, _tolerance),
    );
    expect(kickerRect.top, closeTo(column.top + _columnTop, _tolerance));

    final Rect rail = tester.getRect(find.byKey(settingsTabRailKey));
    expect(rail.width, closeTo(_railWidth, _tolerance));
    expect(rail.left, closeTo(column.left + _columnLeft, _tolerance));
    expect(rail.top - kickerRect.bottom, closeTo(_kickerGap, _tolerance));

    expect(SettingsTab.values, <SettingsTab>[
      SettingsTab.journal,
      SettingsTab.syncStorage,
      SettingsTab.remindersSound,
      SettingsTab.data,
      SettingsTab.about,
    ]);
    const Map<SettingsTab, SettingsGlyph> glyphs = <SettingsTab, SettingsGlyph>{
      SettingsTab.journal: SettingsGlyph.book,
      SettingsTab.syncStorage: SettingsGlyph.flip,
      SettingsTab.remindersSound: SettingsGlyph.bell,
      SettingsTab.data: SettingsGlyph.archive,
      SettingsTab.about: SettingsGlyph.info,
    };
    const Map<SettingsTab, String> labels = <SettingsTab, String>{
      SettingsTab.journal: 'Journal',
      SettingsTab.syncStorage: 'Sync & storage',
      SettingsTab.remindersSound: 'Reminders & sound',
      SettingsTab.data: 'Data',
      SettingsTab.about: 'About',
    };
    final Rect separator = tester.getRect(find.byKey(settingsTabSeparatorKey));
    Rect? previous;
    for (final SettingsTab tab in SettingsTab.values) {
      final String name = labels[tab]!;
      final Finder entry = find.byKey(settingsTabKey(tab));
      expect(entry, findsOneWidget, reason: name);
      final Rect face = tester.getRect(find.byKey(settingsTabFaceKey(tab)));
      expect(face.width, closeTo(_railWidth, _tolerance), reason: name);
      expect(face.height, greaterThanOrEqualTo(44 - _tolerance), reason: name);
      final Finder label = find.descendant(
        of: entry,
        matching: find.text(name),
      );
      expect(label, findsOneWidget, reason: name);
      _expectStyle(
        tester.widget<Text>(label).style,
        family: TypographyTokens.sans,
        size: 14,
        weight: FontWeight.w600,
        color: colors.ink,
        reason: name,
      );
      expect(
        find.descendant(of: entry, matching: find.text(tab.sublabel)),
        findsNothing,
        reason: name,
      );
      final Finder icon = find.descendant(
        of: entry,
        matching: find.byType(SettingsIcon),
      );
      expect(icon, findsOneWidget, reason: name);
      final SettingsIcon glyph = tester.widget<SettingsIcon>(icon);
      expect(glyph.glyph, glyphs[tab], reason: name);
      expect(glyph.size, 18, reason: name);
      expect(glyph.strokeWidth, closeTo(1.8, 1e-6), reason: name);
      expect(tester.getSize(icon), const Size(18, 18), reason: name);
      expect(
        tester.getTopLeft(label).dx - tester.getTopRight(icon).dx,
        closeTo(10, _tolerance),
        reason: name,
      );
      if (previous != null) {
        if (tab == SettingsTab.about) {
          expect(
            separator.top - previous.bottom,
            closeTo(_separatorGap, _tolerance),
          );
          expect(
            face.top - separator.bottom,
            closeTo(_separatorGap, _tolerance),
          );
        } else {
          expect(
            face.top - previous.bottom,
            closeTo(_entryGap, _tolerance),
            reason: name,
          );
          expect(face.top, lessThan(separator.top), reason: name);
        }
      }
      previous = face;
    }
    expect(separator.height, closeTo(1, _tolerance));
    expect(separator.left, closeTo(rail.left + _separatorInset, _tolerance));
    expect(separator.right, closeTo(rail.right - _separatorInset, _tolerance));
    final ColoredBox line = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(settingsTabSeparatorKey),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(
      line.color.toARGB32(),
      colors.ink.withValues(alpha: 0.14).toARGB32(),
    );

    final Finder rule = _inSettings(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is DashedDivider && widget.axis == Axis.vertical,
        description: 'the dashed rule beside the section list',
      ),
    );
    expect(rule, findsOneWidget);
    final DashedDivider divider = tester.widget<DashedDivider>(rule);
    expect(divider.thickness, 1);
    expect(divider.color?.toARGB32(), colors.ink22.toARGB32());
    final Rect ruleRect = tester.getRect(rule);
    expect(ruleRect.left, closeTo(column.right, _tolerance));
    expect(ruleRect.width, closeTo(1, _tolerance));
    expect(ruleRect.top, closeTo(area.top, _tolerance));
    expect(ruleRect.bottom, closeTo(area.bottom, _tolerance));

    final Finder title = find.byKey(settingsContentTitleKey);
    expect(tester.widget<Text>(title).data, 'Journal');
    final TextStyle? titleStyle = tester.widget<Text>(title).style;
    _expectStyle(
      titleStyle,
      family: TypographyTokens.serif,
      size: 34,
      weight: FontWeight.w500,
      color: colors.ink,
      reason: 'the content title',
    );
    expect(titleStyle?.height, 1);
    expect(tester.getSemantics(title), isNotNull);
    final Rect titleRect = tester.getRect(title);
    final Rect content = tester.getRect(find.byKey(settingsContentColumnKey));
    expect(content.left, closeTo(ruleRect.right + _contentLeft, _tolerance));
    expect(content.width, lessThanOrEqualTo(_contentMaxWidth + _tolerance));
    expect(content.width, closeTo(_contentMaxWidth, _tolerance));
    expect(titleRect.left, closeTo(content.left, _tolerance));
    expect(
      titleRect.top,
      closeTo(area.top + _contentTop + _titleAbove, _tolerance),
    );
    expect(
      tester.getRect(find.byKey(settingsTabContentKey)).top - titleRect.bottom,
      closeTo(_titleBelow, _tolerance),
    );

    await tester.tap(find.byKey(settingsTabKey(SettingsTab.about)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(settingsContentTitleKey)).data,
      'About',
    );
  });

  testWidgets(
    'every desktop section keeps its rows inside the content column',
    (WidgetTester tester) async {
      for (final Size window in <Size>[_window, _laptopWindow]) {
        await _pumpMacSettings(tester, window: window);
        final Rect area = tester.getRect(find.byType(SettingsScreen));
        for (final SettingsTab tab in SettingsTab.values) {
          final String page = '${tab.label} at ${window.width.round()}';
          await tester.tap(find.byKey(settingsTabKey(tab)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: page);
          expect(
            tester.widget<Text>(find.byKey(settingsContentTitleKey)).data,
            tab.label,
            reason: page,
          );
          final Rect column = tester.getRect(
            find.byKey(settingsContentColumnKey),
          );
          expect(
            column.width,
            lessThanOrEqualTo(_contentMaxWidth + _tolerance),
          );
          expect(column.right, lessThanOrEqualTo(area.right - 34 + _tolerance));
          final List<Element> rows = find
              .descendant(
                of: find.byKey(settingsTabContentKey),
                matching: find.byType(SettingsFieldRow),
              )
              .evaluate()
              .toList();
          expect(rows, isNotEmpty, reason: page);
          for (final Element row in rows) {
            final Rect rect = tester.getRect(_element(row));
            final String name =
                '${(row.widget as SettingsFieldRow).label} on $page';
            expect(
              rect.left,
              greaterThanOrEqualTo(column.left - _tolerance),
              reason: name,
            );
            expect(
              rect.right,
              lessThanOrEqualTo(column.right + _tolerance),
              reason: name,
            );
          }
          expect(
            find.descendant(
              of: find.byKey(settingsTabContentKey),
              matching: find.byType(SettingsSection),
            ),
            findsWidgets,
            reason: page,
          );
        }
      }
    },
  );

  testWidgets('the Mac sync status row fits the smallest window', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now().toUtc();
    final List<SyncStatus> statuses = <SyncStatus>[
      const OfflineStatus(),
      for (final AttentionReason reason in AttentionReason.values)
        AttentionStatus(reason),
    ];
    for (final Size window in <Size>[_smallestWindow, _laptopWindow, _window]) {
      for (final SyncStatus status in statuses) {
        final String label = status.label(now);
        final String name = '$label at ${window.width.round()}';
        await _pumpMacSettings(tester, window: window, status: status);
        await tester.tap(find.byKey(settingsTabKey(SettingsTab.syncStorage)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: name);
        final Finder row = find.ancestor(
          of: find.text(label),
          matching: find.byType(SettingsFieldRow),
        );
        expect(row, findsOneWidget, reason: name);
        final Rect rowRect = tester.getRect(row);
        final Finder syncNow = find.descendant(
          of: row,
          matching: find.widgetWithText(SettingsActionButton, syncNowLabel),
        );
        expect(syncNow, findsOneWidget, reason: name);
        final Rect button = tester.getRect(syncNow);
        expect(button.left, greaterThanOrEqualTo(rowRect.left), reason: name);
        expect(
          button.right,
          lessThanOrEqualTo(rowRect.right + _tolerance),
          reason: name,
        );
        expect(
          rowRect.right,
          lessThanOrEqualTo(
            tester.getRect(find.byKey(settingsContentColumnKey)).right +
                _tolerance,
          ),
          reason: name,
        );
      }
    }
  });

  testWidgets('Unchanged: the desktop rail keeps Sync & storage', (
    WidgetTester tester,
  ) async {
    await _pumpMacSettings(tester);

    const List<(SettingsTab, String)> entries = <(SettingsTab, String)>[
      (SettingsTab.journal, 'Journal'),
      (SettingsTab.syncStorage, 'Sync & storage'),
      (SettingsTab.remindersSound, 'Reminders & sound'),
      (SettingsTab.data, 'Data'),
      (SettingsTab.about, 'About'),
    ];
    final Finder rail = find.byKey(settingsTabRailKey);
    expect(rail, findsOneWidget);
    expect(
      find.descendant(of: rail, matching: find.byType(SettingsIcon)),
      findsNWidgets(entries.length),
    );
    double previousBottom = double.negativeInfinity;
    for (final (SettingsTab tab, String name) in entries) {
      final Finder entry = find.descendant(
        of: rail,
        matching: find.byKey(settingsTabKey(tab)),
      );
      expect(entry, findsOneWidget, reason: name);
      expect(
        find.descendant(of: entry, matching: find.text(name)),
        findsOneWidget,
        reason: name,
      );
      final Rect rect = tester.getRect(entry);
      expect(
        rect.top,
        greaterThanOrEqualTo(previousBottom - _tolerance),
        reason: name,
      );
      previousBottom = rect.bottom;
    }

    await tester.tap(find.byKey(settingsTabKey(SettingsTab.syncStorage)));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(settingsContentTitleKey)).data,
      'Sync & storage',
    );
    expect(
      find.descendant(
        of: find.byKey(settingsTabContentKey),
        matching: find.byType(SyncStorageSection),
      ),
      findsOneWidget,
    );
  });
}
