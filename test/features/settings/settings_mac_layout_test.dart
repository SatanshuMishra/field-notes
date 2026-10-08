import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../../support/sync_overrides.dart';
import 'support/settings_harness.dart';

const Size _window = Size(1440, 900);
const double _railWidth = 196;
const double _rightPadding = 28;
const double _labelControlGap = 24;
const double _groupGap = 28;
const double _headingSize = 19;
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

List<Override> _overrides(DateTime now) {
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

Future<void> _pumpMacSettings(WidgetTester tester) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(DateTime.now().toUtc()),
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

double _twoLines(RenderParagraph paragraph) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: 'A\nA', style: paragraph.text.style),
    textScaler: paragraph.textScaler,
    textDirection: TextDirection.ltr,
  )..layout();
  final double height = painter.height;
  painter.dispose();
  return height;
}

void _expectPlainGroups(WidgetTester tester, Finder content, String page) {
  final List<Element> groups = find
      .descendant(of: content, matching: find.byType(SettingsSection))
      .evaluate()
      .toList();
  expect(groups, isNotEmpty, reason: page);
  Rect? previous;
  for (final Element group in groups) {
    final SettingsSection section = group.widget as SettingsSection;
    final Finder heading = find
        .descendant(of: _element(group), matching: find.text(section.title))
        .first;
    final Text headingText = tester.widget<Text>(heading);
    expect(headingText.style?.fontSize, _headingSize, reason: section.title);
    expect(
      headingText.style?.fontFamily,
      TypographyTokens.accent,
      reason: section.title,
    );
    expect(
      find.ancestor(of: heading, matching: find.byType(StickerCard)),
      findsNothing,
      reason: '${section.title} heading sits in a card',
    );
    expect(
      find.descendant(
        of: _element(group),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is DashedDivider && widget.axis == Axis.horizontal,
        ),
      ),
      findsNWidgets(section.children.length),
      reason: '${section.title} rows are separated by dashed rules',
    );
    final Rect rect = tester.getRect(_element(group));
    if (previous != null) {
      expect(
        rect.top - previous.bottom,
        moreOrLessEquals(_groupGap, epsilon: _tolerance),
        reason: '${section.title} on $page',
      );
    }
    previous = rect;
  }
}

void _expectRowsReachTheRightEdge(
  WidgetTester tester,
  Finder content,
  Rect area,
  String page,
) {
  final List<Element> rows = find
      .descendant(of: content, matching: find.byType(SettingsFieldRow))
      .evaluate()
      .toList();
  expect(rows, isNotEmpty, reason: page);
  for (final Element element in rows) {
    final SettingsFieldRow row = element.widget as SettingsFieldRow;
    final String name = '${row.label} on $page';
    final Rect bounds = tester.getRect(_element(element));
    final Rect control = tester.getRect(find.byWidget(row.control));
    final Rect label = tester.getRect(
      find
          .descendant(of: _element(element), matching: find.text(row.label))
          .first,
    );
    expect(
      area.right - control.right,
      moreOrLessEquals(_rightPadding, epsilon: _tolerance),
      reason: name,
    );
    expect(
      label.left,
      moreOrLessEquals(bounds.left, epsilon: _tolerance),
      reason: name,
    );
    expect(
      control.left - _labelControlGap,
      greaterThanOrEqualTo(label.right - _tolerance),
      reason: name,
    );
    final String? description = row.description;
    if (description == null) {
      continue;
    }
    final Finder text = find
        .descendant(of: _element(element), matching: find.text(description))
        .first;
    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      text,
    );
    expect(
      tester.getRect(text).top,
      greaterThanOrEqualTo(label.bottom - _tolerance),
      reason: name,
    );
    expect(
      tester.getRect(text).left,
      moreOrLessEquals(bounds.left, epsilon: _tolerance),
      reason: name,
    );
    expect(
      paragraph.size.height,
      lessThanOrEqualTo(_twoLines(paragraph) + _tolerance),
      reason: '$name wraps past two lines',
    );
  }
}

void main() {
  testWidgets('Mac settings rows reach the right edge at 1440', (
    WidgetTester tester,
  ) async {
    await _pumpMacSettings(tester);

    final Finder settings = find.byType(SettingsScreen);
    final Rect area = tester.getRect(settings);
    final Finder rail = find.byKey(settingsTabRailKey);
    final Finder content = find.byKey(settingsTabContentKey);
    final Finder rule = find.descendant(
      of: settings,
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is DashedDivider && widget.axis == Axis.vertical,
        description: 'the dashed rule beside the section list',
      ),
    );

    expect(tester.getSize(rail).width, _railWidth);
    expect(rule, findsOneWidget);
    expect(tester.getRect(rule).left, greaterThan(tester.getRect(rail).right));

    for (final SettingsTab tab in SettingsTab.values) {
      await tester.tap(find.byKey(settingsTabKey(tab)));
      await tester.pumpAndSettle();
      final String page = tab.label;

      expect(tester.getSize(rail).width, _railWidth, reason: page);
      expect(
        tester.getRect(content).left,
        greaterThan(tester.getRect(rule).right),
        reason: page,
      );
      expect(
        tester.getRect(content).right,
        moreOrLessEquals(area.right - _rightPadding, epsilon: _tolerance),
        reason: page,
      );
      expect(
        find.descendant(of: content, matching: find.byType(StickerCard)),
        findsNothing,
        reason: page,
      );
      _expectPlainGroups(tester, content, page);
      _expectRowsReachTheRightEdge(tester, content, area, page);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
