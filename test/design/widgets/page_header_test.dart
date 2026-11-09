import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/theme_harness.dart';

const String _eyebrow = 'looking back';
const String _title = 'Search';
const Key _firstAction = ValueKey<String>('first');
const Key _secondAction = ValueKey<String>('second');

const List<(String, Brightness, FieldNotesColors)> _themes =
    <(String, Brightness, FieldNotesColors)>[
      ('light', Brightness.light, FieldNotesColors.light),
      ('dark', Brightness.dark, FieldNotesColors.dark),
    ];

Future<void> _pump(
  WidgetTester tester,
  Widget header, {
  Brightness brightness = Brightness.light,
  Size size = const Size(600, 400),
}) => pumpThemed(
  tester,
  Align(alignment: Alignment.topCenter, child: header),
  brightness: brightness,
  platform: TargetPlatform.macOS,
  size: size,
);

void main() {
  for (final (String name, Brightness brightness, FieldNotesColors colors)
      in _themes) {
    testWidgets('it matches the Today header styles in $name', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const PageHeader(eyebrow: _eyebrow, title: _title),
        brightness: brightness,
      );
      final FieldNotesTextStyles styles = FieldNotesTextStyles(colors);

      expect(
        tester.widget<Text>(find.text(_eyebrow)).style,
        styles.pageEyebrowAccent,
      );
      expect(
        tester.widget<Text>(find.text(_title)).style,
        styles.displaySerifToday,
      );
    });
  }

  testWidgets('the eyebrow sits above the title and is optional', (
    WidgetTester tester,
  ) async {
    await _pump(tester, const PageHeader(eyebrow: _eyebrow, title: _title));
    expect(
      tester.getBottomLeft(find.text(_eyebrow)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text(_title)).dy),
    );

    await _pump(tester, const PageHeader(title: _title));
    expect(find.text(_eyebrow), findsNothing);
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('actions sit at the far end, eight apart, on the title baseline '
      'edge', (WidgetTester tester) async {
    await _pump(
      tester,
      const PageHeader(
        eyebrow: _eyebrow,
        title: _title,
        actions: <Widget>[
          SizedBox.square(key: _firstAction, dimension: 36),
          SizedBox.square(key: _secondAction, dimension: 36),
        ],
      ),
    );

    final Rect first = tester.getRect(find.byKey(_firstAction));
    final Rect second = tester.getRect(find.byKey(_secondAction));
    final Rect header = tester.getRect(find.byType(PageHeader));
    expect(second.right, header.right);
    expect(second.left - first.right, 8);
    expect(first.bottom, header.bottom);
  });

  testWidgets('a long title wraps beside its actions in a narrow window', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const PageHeader(
        eyebrow: _eyebrow,
        title: 'A very long page title that has to wrap on a phone',
        actions: <Widget>[SizedBox.square(key: _firstAction, dimension: 48)],
      ),
      size: const Size(280, 500),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(_firstAction), findsOneWidget);
  });

  testWidgets('the title is announced as a heading', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(tester, const PageHeader(eyebrow: _eyebrow, title: _title));

    expect(
      tester.getSemantics(find.text(_title)),
      matchesSemantics(label: _title, isHeader: true),
    );
    semantics.dispose();
  });
}
