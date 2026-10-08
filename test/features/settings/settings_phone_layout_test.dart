import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_phone_pages.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';

const Size _phone = Size(384, 832);
const Size _note = Size(412, 869);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _headerBottom = _statusBar + 44;
const double _headerGap = 6;
const double _titleGap = 12;
const double _sideInset = 14;
const double _eyebrowSize = 15;
const double _titleSize = 30;
const double _rowMinHeight = 68;
const double _pillLift = 86;
const double _pillHeight = 48;
const double _pillClearance = 12;
const double _tolerance = 0.01;

const String _lastSyncCaption = 'Use your 12 words.';

const List<String> _syncOffRows = <String>[
  'Start syncing',
  'Join my journal',
  'Restore with recovery phrase',
];

const List<String> _mockUpRows = <String>[
  'Storage mode',
  'Server URL',
  'Access token',
  'Sync frequency',
  'Recovery passphrase',
  'Pair a device',
  'Connection',
  'Test connection',
];

final Finder _content = find.byKey(settingsTabContentKey);
final Finder _list = find.byType(SettingsSectionList);
final Finder _heading = find.byType(SettingsPageHeading);
final Finder _pill = find.byType(SettingsBackPill);
final Finder _pillGlass = find.descendant(
  of: _pill,
  matching: find.byType(GlassSurface),
);

Finder _row(SettingsTab tab) => find.byKey(settingsTabKey(tab));

List<Override> _overrides() => <Override>[
  ...shellOverrides(),
  appSettingsProvider.overrideWith(
    (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
  ),
];

Future<void> _pumpPhone(
  WidgetTester tester, {
  Size surface = _phone,
  double textScale = 1,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('gear-button')));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, SettingsTab tab) async {
  await tester.tap(_row(tab));
  await tester.pumpAndSettle();
}

ScrollableState _scroll(WidgetTester tester) => tester.state<ScrollableState>(
  find.ancestor(of: _content, matching: find.byType(Scrollable)).first,
);

void _expectHeading(WidgetTester tester, SettingsTab tab, String page) {
  final Text eyebrow = tester.widget<Text>(
    find.descendant(of: _heading, matching: find.text(settingsPageEyebrow)),
  );
  expect(eyebrow.style?.fontSize, _eyebrowSize, reason: page);
  expect(eyebrow.style?.fontFamily, TypographyTokens.accent, reason: page);
  expect(eyebrow.style?.fontWeight, FontWeight.w600, reason: page);
  final Text title = tester.widget<Text>(
    find.descendant(of: _heading, matching: find.text(tab.label)),
  );
  expect(title.style?.fontSize, _titleSize, reason: page);
  expect(title.style?.fontFamily, TypographyTokens.serif, reason: page);
  expect(title.style?.fontWeight, FontWeight.w500, reason: page);
}

void main() {
  testWidgets(
    'phone settings pages start under the header and end clear of the Back pill',
    (WidgetTester tester) async {
      for (final Size surface in <Size>[_phone, _note]) {
        await _pumpPhone(tester, surface: surface);

        expect(find.byKey(settingsTabRailKey), findsNothing);
        expect(_pill, findsNothing);
        final Rect tabBar = tester.getRect(find.byType(PhoneBottomBar));
        final Rect list = tester.getRect(_list);
        expect(
          list.top,
          moreOrLessEquals(_headerBottom + _headerGap, epsilon: _tolerance),
        );
        expect(list.left, moreOrLessEquals(_sideInset, epsilon: _tolerance));
        expect(
          list.right,
          moreOrLessEquals(surface.width - _sideInset, epsilon: _tolerance),
        );
        expect(
          tester.getRect(_row(SettingsTab.values.last)).bottom,
          lessThan(tabBar.top),
        );

        for (final SettingsTab tab in SettingsTab.values) {
          final String page = '${tab.label} on $surface';
          await _open(tester, tab);

          expect(_list, findsNothing, reason: page);
          _expectHeading(tester, tab, page);
          final Rect heading = tester.getRect(_heading);
          final Rect content = tester.getRect(_content);
          expect(
            heading.top,
            moreOrLessEquals(_headerBottom + _headerGap, epsilon: _tolerance),
            reason: page,
          );
          expect(
            content.top - heading.bottom,
            moreOrLessEquals(_titleGap, epsilon: _tolerance),
            reason: page,
          );
          expect(
            content.left,
            moreOrLessEquals(_sideInset, epsilon: _tolerance),
            reason: page,
          );
          expect(
            content.right,
            moreOrLessEquals(surface.width - _sideInset, epsilon: _tolerance),
            reason: page,
          );

          final Rect pill = tester.getRect(_pillGlass);
          expect(
            pill.bottom,
            moreOrLessEquals(
              surface.height - _gestureBar - _pillLift,
              epsilon: _tolerance,
            ),
            reason: page,
          );
          expect(
            pill.height,
            moreOrLessEquals(_pillHeight, epsilon: _tolerance),
          );
          expect(pill.bottom, lessThan(tabBar.top), reason: page);
          expect(tester.getRect(find.byType(PhoneBottomBar)), tabBar);

          final ScrollableState scroll = _scroll(tester);
          expect(scroll.position.pixels, 0, reason: page);
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pump();
          final double end = tester.getRect(_content).bottom;
          if (scroll.position.maxScrollExtent > 0) {
            expect(
              pill.top - end,
              moreOrLessEquals(_pillClearance, epsilon: _tolerance),
              reason: page,
            );
          } else {
            expect(
              end,
              lessThanOrEqualTo(pill.top - _pillClearance + _tolerance),
              reason: page,
            );
          }

          await tester.tap(_pill);
          await tester.pumpAndSettle();
          expect(_list, findsOneWidget, reason: page);
        }
      }
    },
  );

  testWidgets(
    'sync settings offer start, join and restore and none of the mock-up rows',
    (WidgetTester tester) async {
      await _pumpPhone(tester);
      expect(find.byType(SyncStorageSection), findsNothing);
      await _open(tester, SettingsTab.syncStorage);

      expect(find.byType(SyncStorageSection), findsOneWidget);
      for (final String row in _mockUpRows) {
        expect(find.text(row, skipOffstage: false), findsNothing, reason: row);
      }
      for (final String row in _syncOffRows) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(
        find.text(
          'Your journal is only on this phone. Sync keeps it on your other '
          'devices, encrypted.',
        ),
        findsOneWidget,
      );
      expect(find.text(_lastSyncCaption), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SyncStorageSection),
          matching: find.byType(DashedDivider),
        ),
        findsNWidgets(4),
      );

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      await pumpShell(
        tester,
        const AppShell(),
        overrides: <Override>[
          appSettingsProvider.overrideWith(
            (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
          ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey<String>('settings-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(settingsTabRailKey), findsOneWidget);
      await tester.tap(_row(SettingsTab.syncStorage));
      await tester.pumpAndSettle();

      expect(find.byType(SyncStorageSection), findsOneWidget);
      for (final String row in _mockUpRows) {
        expect(find.text(row), findsNothing, reason: row);
      }
      for (final String row in _syncOffRows) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(
        find.text('You lost every device. Use your 12 words.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('with large text the section list and pages stay on the screen', (
    WidgetTester tester,
  ) async {
    await _pumpPhone(tester, textScale: 1.6);

    expect(tester.takeException(), isNull);
    for (final SettingsTab tab in SettingsTab.values) {
      final Rect row = tester.getRect(_row(tab));
      expect(row.left, greaterThanOrEqualTo(0), reason: tab.label);
      expect(row.right, lessThanOrEqualTo(_phone.width), reason: tab.label);
      expect(
        row.height,
        greaterThanOrEqualTo(_rowMinHeight),
        reason: tab.label,
      );
    }

    await _open(tester, SettingsTab.data);

    expect(tester.takeException(), isNull);
    _expectHeading(tester, SettingsTab.data, 'Data in large text');
    final Rect pill = tester.getRect(_pillGlass);
    expect(pill.left, moreOrLessEquals(12, epsilon: _tolerance));
    expect(pill.right, lessThanOrEqualTo(_phone.width));
    expect(pill.height, moreOrLessEquals(_pillHeight, epsilon: _tolerance));
    expect(
      find.descendant(of: _pill, matching: find.text(settingsListTitle)),
      findsOneWidget,
    );
  });
}
