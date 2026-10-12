import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'settings_harness.dart';

const Size _desktopWindow = Size(1140, 726);
const Size _phoneView = Size(384, 832);
const double _sectionWidth = 640;

const Key _untitledKey = ValueKey<String>('untitled-section');
const Key _titledKey = ValueKey<String>('titled-section');

Future<void> _pumpDesktop(WidgetTester tester, Widget section) async {
  tester.view.physicalSize = _desktopWindow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: _sectionWidth, child: section),
        ),
      ),
    ),
  );
}

Future<void> _pumpPhone(WidgetTester tester, List<Widget> sections) async {
  tester.view.physicalSize = _phoneView;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: TargetPlatform.android),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: sections,
          ),
        ),
      ),
    ),
  );
}

Rect _rectOf(WidgetTester tester, String text) =>
    tester.getRect(find.text(text));

Rect _textColumn(WidgetTester tester, String label) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(MergeSemantics)),
);

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

List<Rect> _rects(Finder finder) => finder.evaluate().map((Element element) {
  final RenderBox box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}).toList();

Finder _hairlines() => find.descendant(
  of: find.byType(SettingsSection),
  matching: find.byType(ColoredBox),
);

void main() {
  group('SettingsSection', () {
    testWidgets('renders its title, subtitle, and child rows inside a card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        settingsHarness(
          const SizedBox(
            width: 360,
            child: SettingsSection(
              title: 'Reminders & sound',
              subtitle: 'Nudges and audio cues',
              children: <Widget>[Text('row-a'), Text('row-b')],
            ),
          ),
        ),
      );

      expect(find.byType(StickerCard), findsOneWidget);
      expect(find.text('Reminders & sound'), findsOneWidget);
      expect(find.text('Nudges and audio cues'), findsOneWidget);
      expect(find.text('row-a'), findsOneWidget);
      expect(find.text('row-b'), findsOneWidget);
    });

    testWidgets('separates rows with one dashed divider per row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        settingsHarness(
          const SizedBox(
            width: 360,
            child: SettingsSection(
              title: 'Journal',
              children: <Widget>[Text('row-a'), Text('row-b')],
            ),
          ),
        ),
      );

      expect(find.byType(DashedDivider), findsNWidgets(2));
    });
  });

  testWidgets('desktop groups draw labels and hairlines without a card', (
    WidgetTester tester,
  ) async {
    await _pumpDesktop(
      tester,
      const SettingsSection.grouped(
        title: 'Journal',
        subtitle: 'How your journal looks',
        groups: <SettingsGroup>[
          SettingsGroup(
            label: 'look',
            rows: <Widget>[
              SettingsFieldRow(
                label: 'Appearance',
                description: 'Light, dark or the system setting',
                control: SizedBox(
                  key: ValueKey<String>('appearance-control'),
                  width: 120,
                  height: 24,
                ),
              ),
              SettingsFieldRow(
                label: 'Text size',
                control: SizedBox(width: 40, height: 10),
              ),
            ],
          ),
          SettingsGroup(
            label: 'erase',
            danger: true,
            rows: <Widget>[
              SettingsFieldRow(
                label: 'Delete all',
                description: 'Erase every entry, photo and mood',
                control: SizedBox(width: 40, height: 10),
              ),
            ],
          ),
        ],
      ),
    );
    final FieldNotesColors colors = FieldNotesColors.light;

    expect(find.byType(StickerCard), findsNothing);
    expect(find.byType(DashedDivider), findsNothing);
    expect(find.text('Journal'), findsNothing);

    for (final (String label, Color colour) in <(String, Color)>[
      ('look', colors.sage),
      ('erase', colors.dangerInk),
    ]) {
      final TextStyle style = _styleOf(tester, label);
      expect(style.fontFamily, TypographyTokens.accent, reason: label);
      expect(style.fontSize, 17, reason: label);
      expect(style.color!.toARGB32(), colour.toARGB32(), reason: label);
    }

    final TextStyle subtitle = _styleOf(tester, 'How your journal looks');
    expect(subtitle.fontFamily, TypographyTokens.sans);
    expect(subtitle.fontSize, 12);
    expect(subtitle.fontWeight, FontWeight.w400);
    expect(subtitle.color!.toARGB32(), colors.muted.toARGB32());
    final Rect look = _rectOf(tester, 'look');
    final Rect subtitleRect = _rectOf(tester, 'How your journal looks');
    expect(subtitleRect.top, greaterThanOrEqualTo(look.bottom));

    final TextStyle label = _styleOf(tester, 'Appearance');
    expect(label.fontFamily, TypographyTokens.sans);
    expect(label.fontSize, 14);
    expect(label.fontWeight, FontWeight.w600);
    expect(label.color!.toARGB32(), colors.ink.toARGB32());
    final TextStyle description = _styleOf(
      tester,
      'Light, dark or the system setting',
    );
    expect(description.fontFamily, TypographyTokens.sans);
    expect(description.fontSize, 12);
    expect(description.fontWeight, FontWeight.w400);
    expect(description.color!.toARGB32(), colors.muted.toARGB32());
    expect(
      _rectOf(tester, 'Light, dark or the system setting').top -
          _rectOf(tester, 'Appearance').bottom,
      moreOrLessEquals(1),
    );

    final List<ColoredBox> hairlines = tester
        .widgetList<ColoredBox>(_hairlines())
        .toList();
    expect(hairlines, hasLength(1));
    expect(
      hairlines.single.color.toARGB32(),
      colors.ink.withValues(alpha: 0.13).toARGB32(),
    );
    final Rect hairline = _rects(_hairlines()).single;
    expect(hairline.height, 1);
    expect(hairline.width, _sectionWidth);

    final Rect appearanceRow = tester.getRect(
      find.widgetWithText(SettingsFieldRow, 'Appearance'),
    );
    expect(appearanceRow.left, 2);
    expect(appearanceRow.right, _sectionWidth - 2);
    expect(appearanceRow.top, moreOrLessEquals(subtitleRect.bottom + 6 + 15));
    expect(hairline.top, moreOrLessEquals(appearanceRow.bottom + 15));
    expect(hairline.top - (subtitleRect.bottom + 6), greaterThanOrEqualTo(56));

    final Rect textSizeRow = tester.getRect(
      find.widgetWithText(SettingsFieldRow, 'Text size'),
    );
    expect(textSizeRow.height, lessThan(56 - 30));
    expect(textSizeRow.center.dy, moreOrLessEquals(hairline.bottom + 28));
    final Rect erase = _rectOf(tester, 'erase');
    expect(erase.top - hairline.bottom, moreOrLessEquals(56 + 15));

    final Rect deleteRow = tester.getRect(
      find.widgetWithText(SettingsFieldRow, 'Delete all'),
    );
    expect(deleteRow.top, moreOrLessEquals(erase.bottom + 6 + 15));

    final Rect control = tester.getRect(
      find.byKey(const ValueKey<String>('appearance-control')),
    );
    expect(control.right, appearanceRow.right);
    expect(control.width, 120);
    expect(
      control.left - _textColumn(tester, 'Appearance').right,
      moreOrLessEquals(20),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone groups share one card without labels', (
    WidgetTester tester,
  ) async {
    await _pumpPhone(tester, const <Widget>[
      SettingsSection.grouped(
        key: _untitledKey,
        groups: <SettingsGroup>[
          SettingsGroup(
            label: 'look',
            rows: <Widget>[
              SettingsFieldRow(
                label: 'Appearance',
                control: SizedBox(width: 40, height: 20),
              ),
              SettingsFieldRow(
                label: 'Text size',
                control: SizedBox(width: 40, height: 20),
              ),
            ],
          ),
          SettingsGroup(
            label: 'erase',
            danger: true,
            rows: <Widget>[
              SettingsFieldRow(
                label: 'Delete all',
                control: SizedBox(width: 40, height: 20),
              ),
            ],
          ),
        ],
      ),
      SizedBox(height: 16),
      SettingsSection.grouped(
        key: _titledKey,
        title: 'Performance',
        subtitle: 'Motion and battery',
        groups: <SettingsGroup>[
          SettingsGroup(
            label: 'performance',
            rows: <Widget>[
              SettingsFieldRow(
                label: 'Pause the Meadow',
                control: SizedBox(width: 40, height: 20),
              ),
            ],
          ),
        ],
      ),
    ]);
    final FieldNotesColors colors = FieldNotesColors.light;

    for (final Key key in <Key>[_untitledKey, _titledKey]) {
      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(StickerCard),
        ),
        findsOneWidget,
      );
    }
    for (final String groupLabel in <String>['look', 'erase', 'performance']) {
      expect(find.text(groupLabel), findsNothing, reason: groupLabel);
    }

    final List<Rect> untitledDividers = _rects(
      find.descendant(
        of: find.byKey(_untitledKey),
        matching: find.byType(DashedDivider),
      ),
    );
    expect(untitledDividers, hasLength(2));
    final List<Rect> rows = <String>['Appearance', 'Text size', 'Delete all']
        .map(
          (String label) =>
              tester.getRect(find.widgetWithText(SettingsFieldRow, label)),
        )
        .toList();
    for (int index = 0; index < untitledDividers.length; index++) {
      expect(
        untitledDividers[index].top - rows[index].bottom,
        moreOrLessEquals(12),
      );
      expect(
        rows[index + 1].top - untitledDividers[index].bottom,
        moreOrLessEquals(12),
      );
    }
    final Rect untitledCard = tester.getRect(
      find.descendant(
        of: find.byKey(_untitledKey),
        matching: find.byType(StickerCard),
      ),
    );
    expect(rows.first.top, greaterThan(untitledCard.top));
    expect(untitledDividers.first.top, greaterThan(rows.first.bottom));

    final TextStyle title = _styleOf(tester, 'Performance');
    expect(title.fontFamily, TypographyTokens.accent);
    expect(title.color!.toARGB32(), colors.sage.toARGB32());
    final TextStyle subtitle = _styleOf(tester, 'Motion and battery');
    expect(subtitle.fontSize, 12);
    expect(subtitle.color!.toARGB32(), colors.muted.toARGB32());
    final List<Rect> titledDividers = _rects(
      find.descendant(
        of: find.byKey(_titledKey),
        matching: find.byType(DashedDivider),
      ),
    );
    expect(titledDividers, hasLength(1));
    final Rect pauseRow = tester.getRect(
      find.widgetWithText(SettingsFieldRow, 'Pause the Meadow'),
    );
    expect(
      titledDividers.single.top,
      greaterThan(_rectOf(tester, 'Motion and battery').bottom),
    );
    expect(pauseRow.top - titledDividers.single.bottom, moreOrLessEquals(12));
    expect(tester.takeException(), isNull);
  });
}
