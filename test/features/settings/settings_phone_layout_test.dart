import 'dart:math' as math;

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/sync/sync_shell_options.dart';
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
const double _barLift = 82;
const double _barToTabBar = 10;
const double _rowsToBar = 8;
const double _titleGap = 12;
const double _segmentHeight = 40;
const double _minHitHeight = 44;

const String _onDeviceNote =
    'Entries are stored only on this device. Nothing is uploaded '
    'and there is no syncing across devices.';

const List<String> _serverRows = <String>[
  'Server URL',
  'Access token',
  'Sync frequency',
  'Recovery passphrase',
  'Pair a device',
  'Connection',
];

const Map<SettingsTab, String> _segmentLabels = <SettingsTab, String>{
  SettingsTab.syncStorage: 'Sync',
  SettingsTab.remindersSound: 'Reminders',
  SettingsTab.journal: 'Journal',
  SettingsTab.data: 'Data',
};

final Finder _chips = find.byKey(settingsTabChipsKey);

final Finder _glass = find.descendant(
  of: _chips,
  matching: find.byType(GlassSurface),
);

final Finder _content = find.byKey(settingsTabContentKey);

Finder _segment(SettingsTab tab) => find.byKey(settingsTabKey(tab));

Finder _face(SettingsTab tab) => find.descendant(
  of: _segment(tab),
  matching: find.byType(AnimatedContainer),
);

Finder _title(String label) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is Text && widget.data == label && widget.style?.fontSize == 30,
);

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

BoxDecoration _fill(WidgetTester tester, SettingsTab tab) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: _face(tab),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

double _lastRowBottom() {
  double lowest = double.negativeInfinity;
  for (final Element element
      in find
          .descendant(of: _content, matching: find.byType(Text))
          .evaluate()) {
    final RenderBox box = element.renderObject! as RenderBox;
    lowest = math.max(lowest, box.localToGlobal(Offset(0, box.size.height)).dy);
  }
  return lowest;
}

Color _ink(WidgetTester tester, SettingsTab tab) => tester
    .widget<Text>(
      find.descendant(
        of: _segment(tab),
        matching: find.text(_segmentLabels[tab]!),
      ),
    )
    .style!
    .color!;

void _expectSelected(WidgetTester tester, SettingsTab selected) {
  final FieldNotesColors colors = FieldNotesColors.light;
  for (final SettingsTab tab in SettingsTab.values) {
    final BoxDecoration fill = _fill(tester, tab);
    final Border border = fill.border! as Border;
    if (tab == selected) {
      expect(fill.color!.toARGB32(), Palette.coral.toARGB32(), reason: '$tab');
      expect(border.top.width, 1.5, reason: '$tab');
      expect(border.top.color.toARGB32(), colors.line.toARGB32());
      expect(_ink(tester, tab).toARGB32(), Palette.onAccent.toARGB32());
    } else {
      expect(fill.color!.a, 0, reason: '$tab');
      expect(border.top.color.a, 0, reason: '$tab');
      expect(_ink(tester, tab).toARGB32(), colors.ink.toARGB32());
    }
  }
}

void _expectBarAboveTabBar(WidgetTester tester, Size surface) {
  final GlassSurface glass = tester.widget<GlassSurface>(_glass);
  expect(glass.tone, GlassTone.paper);
  expect(glass.borderRadius, const BorderRadius.all(Radius.circular(22)));
  final Rect segmented = tester.getRect(_glass);
  final Rect tabBar = tester.getRect(find.byType(PhoneBottomBar));
  expect(
    segmented.bottom,
    moreOrLessEquals(surface.height - _gestureBar - _barLift, epsilon: 0.01),
  );
  expect(tabBar.top - segmented.bottom, moreOrLessEquals(_barToTabBar));
  expect(segmented.center.dx, moreOrLessEquals(surface.width / 2));
  expect(segmented.height, moreOrLessEquals(_segmentHeight + 6));
  double previousRight = segmented.left;
  for (final SettingsTab tab in SettingsTab.values) {
    final Rect face = tester.getRect(_face(tab));
    final Rect hit = tester.getRect(_segment(tab));
    expect(
      find.descendant(
        of: _segment(tab),
        matching: find.text(_segmentLabels[tab]!),
      ),
      findsOneWidget,
    );
    expect(face.height, moreOrLessEquals(_segmentHeight), reason: '$tab');
    expect(face.top - segmented.top, moreOrLessEquals(3), reason: '$tab');
    expect(face.left - previousRight, greaterThanOrEqualTo(2), reason: '$tab');
    expect(hit.height, greaterThanOrEqualTo(_minHitHeight), reason: '$tab');
    expect(hit.width, greaterThanOrEqualTo(_minHitHeight), reason: '$tab');
    expect(hit.top, lessThanOrEqualTo(face.top), reason: '$tab');
    expect(hit.bottom, greaterThanOrEqualTo(face.bottom), reason: '$tab');
    previousRight = face.right;
  }
  expect(segmented.right - previousRight, moreOrLessEquals(3));
}

void main() {
  testWidgets(
    'phone settings tabs float above the tab bar and rows anchor to the bottom',
    (WidgetTester tester) async {
      for (final Size surface in <Size>[_phone, _note]) {
        await _pumpPhone(tester, surface: surface);

        expect(find.byKey(settingsTabRailKey), findsNothing);
        _expectBarAboveTabBar(tester, surface);
        _expectSelected(tester, SettingsTab.syncStorage);

        final Rect segmented = tester.getRect(_glass);
        final Text eyebrow = tester.widget<Text>(find.text('preferences'));
        expect(eyebrow.style?.fontSize, 15);
        expect(eyebrow.style?.fontFamily, TypographyTokens.accent);
        expect(eyebrow.style?.fontWeight, FontWeight.w600);
        expect(_title('Sync & storage'), findsOneWidget);
        final Text title = tester.widget<Text>(_title('Sync & storage'));
        expect(title.style?.fontFamily, TypographyTokens.serif);
        expect(title.style?.fontWeight, FontWeight.w500);
        expect(find.text('Settings'), findsNothing);

        final Rect syncContent = tester.getRect(_content);
        final Rect syncTitle = tester.getRect(_title('Sync & storage'));
        expect(
          segmented.top - syncContent.bottom,
          moreOrLessEquals(_rowsToBar),
        );
        expect(syncContent.top - syncTitle.bottom, moreOrLessEquals(_titleGap));
        expect(
          syncTitle.top,
          moreOrLessEquals(tester.getRect(find.text('preferences')).bottom),
        );
        expect(
          tester.getRect(find.text('preferences')).top,
          greaterThan(_headerBottom + 6 + 100),
        );
        final double syncLastRow = _lastRowBottom();
        expect(
          syncLastRow,
          moreOrLessEquals(tester.getRect(find.text(_onDeviceNote)).bottom),
        );
        expect(syncLastRow, lessThan(segmented.top - _rowsToBar));
        expect(segmented.top - syncLastRow, lessThan(48));

        final Rect dataFace = tester.getRect(_face(SettingsTab.data));
        await tester.tapAt(Offset(dataFace.center.dx, dataFace.top - 1.5));
        await tester.pumpAndSettle();

        _expectSelected(tester, SettingsTab.data);
        expect(_title('Data'), findsOneWidget);
        expect(_title('Sync & storage'), findsNothing);
        final Rect dataContent = tester.getRect(_content);
        expect(dataContent.bottom, moreOrLessEquals(syncContent.bottom));
        expect(dataContent.top, isNot(moreOrLessEquals(syncContent.top)));
        expect(
          dataContent.top - tester.getRect(_title('Data')).bottom,
          moreOrLessEquals(_titleGap),
        );
        final double dataLastRow = _lastRowBottom();
        expect(
          dataLastRow,
          moreOrLessEquals(
            tester
                .getRect(
                  find.text(
                    'Erase every entry, photo, and mood on this device.',
                  ),
                )
                .bottom,
          ),
        );
        expect(dataLastRow, lessThan(segmented.top - _rowsToBar));
        expect(segmented.top - dataLastRow, lessThan(48));

        await tester.tap(_segment(SettingsTab.journal));
        await tester.pumpAndSettle();
        expect(_title('Journal'), findsOneWidget);
        final ScrollableState scroll = tester.state<ScrollableState>(
          find.ancestor(of: _content, matching: find.byType(Scrollable)).first,
        );
        expect(scroll.position.axis, Axis.vertical);
        expect(
          tester.getRect(find.text('preferences')).top,
          greaterThanOrEqualTo(_headerBottom + 6 - 0.01),
        );
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        expect(
          segmented.top - tester.getRect(_content).bottom,
          moreOrLessEquals(_rowsToBar),
        );
      }
    },
  );

  testWidgets(
    'phone sync settings hide the server rows while storage is on this device',
    (WidgetTester tester) async {
      await _pumpPhone(tester);

      expect(find.byType(SyncStorageSection), findsOneWidget);
      for (final String row in _serverRows) {
        expect(find.text(row, skipOffstage: false), findsNothing, reason: row);
      }
      expect(find.text('Storage mode'), findsOneWidget);
      expect(find.text(_onDeviceNote), findsOneWidget);
      expect(find.text('Sync to server'), findsOneWidget);
      final SettingsSegmented<SyncStorageChoice> storage = tester
          .widget<SettingsSegmented<SyncStorageChoice>>(
            find.byType(SettingsSegmented<SyncStorageChoice>),
          );
      expect(storage.value, SyncStorageChoice.onDevice);
      expect(storage.enabled, isFalse);
      expect(storage.onChanged, isNull);
      expect(
        find.descendant(
          of: find.byType(SyncStorageSection),
          matching: find.byType(DashedDivider),
        ),
        findsNWidgets(2),
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
      expect(find.byType(SyncStorageSection), findsOneWidget);
      for (final String row in _serverRows) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(find.text('Storage mode'), findsOneWidget);
      expect(find.text(_onDeviceNote), findsOneWidget);
    },
  );

  testWidgets(
    'the picked phone segment fills over 200 ms, at once with reduce motion',
    (WidgetTester tester) async {
      await _pumpPhone(tester);

      await tester.tap(_segment(SettingsTab.data));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double halfway = _fill(tester, SettingsTab.data).color!.a;
      expect(halfway, greaterThan(0.2));
      expect(halfway, lessThan(0.8));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      _expectSelected(tester, SettingsTab.data);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.tap(_segment(SettingsTab.journal));
      await tester.pump();
      await tester.pump();
      _expectSelected(tester, SettingsTab.journal);
    },
  );

  testWidgets('with large text the segmented bar scrolls within the screen', (
    WidgetTester tester,
  ) async {
    await _pumpPhone(tester, textScale: 1.6);

    expect(tester.takeException(), isNull);
    final Rect segmented = tester.getRect(_glass);
    expect(segmented.left, moreOrLessEquals(12));
    expect(segmented.right, moreOrLessEquals(_phone.width - 12));
    final ScrollableState row = tester.state<ScrollableState>(
      find.descendant(of: _chips, matching: find.byType(Scrollable)),
    );
    expect(row.position.axis, Axis.horizontal);
    expect(row.position.maxScrollExtent, greaterThan(0));

    await tester.ensureVisible(_segment(SettingsTab.data));
    await tester.pumpAndSettle();
    await tester.tap(_segment(SettingsTab.data));
    await tester.pumpAndSettle();

    expect(_title('Data'), findsOneWidget);
    expect(
      tester.getRect(_face(SettingsTab.data)).right,
      lessThanOrEqualTo(segmented.right),
    );
  });
}
