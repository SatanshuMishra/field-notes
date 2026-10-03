import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/search/search.dart';
import 'package:field_notes/features/search/search_day_tile.dart';
import 'package:field_notes/features/search/search_field.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import 'support/search_harness.dart';

const Size _phone = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _headerBottom = _statusBar + 44;
const double _keyboard = 300;

final Finder _field = find.byType(SearchField);
final Finder _tiles = find.byType(SearchDayTile);
final Finder _title = find.text('Find a day');
final Finder _eyebrow = find.text('search');

List<Day> _days(int count) => <Day>[
  for (int index = 0; index < count; index++)
    dayOf(
      DateTime(2026, 7, 28 - index).toIso8601String().substring(0, 10),
      id: 'd$index',
      mood: Mood.values[index % Mood.values.length],
    ),
];

Future<void> _pumpPhone(WidgetTester tester, {required List<Day> days}) async {
  tester.view.physicalSize = _phone;
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
      overrides: <Override>[
        ...shellOverrides(),
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(days),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('tab-search')));
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void _expectTitleAtTop(WidgetTester tester) {
  final Rect eyebrow = tester.getRect(_eyebrow);
  final Rect title = tester.getRect(_title);
  expect(eyebrow.top, moreOrLessEquals(_headerBottom + 6, epsilon: 0.01));
  expect(title.top, moreOrLessEquals(eyebrow.bottom, epsilon: 0.01));
}

void main() {
  testWidgets(
    'the phone search field sits at the bottom with results above it',
    (WidgetTester tester) async {
      await _pumpPhone(tester, days: _days(2));

      final Rect field = tester.getRect(_field);
      final Rect bar = tester.getRect(find.byType(PhoneBottomBar));
      expect(field.height, 52);
      expect(bar.top - field.bottom, moreOrLessEquals(22, epsilon: 0.01));
      expect(field.left, 14);
      expect(field.right, _phone.width - 14);

      _expectTitleAtTop(tester);

      expect(_tiles, findsNWidgets(2));
      expect(
        tester.widget<SearchDayTile>(_tiles.first).view.date,
        '2026-07-28',
      );
      expect(tester.widget<SearchDayTile>(_tiles.last).view.date, '2026-07-27');
      final Rect upper = tester.getRect(_tiles.first);
      final Rect lower = tester.getRect(_tiles.last);
      expect(lower.top - upper.bottom, moreOrLessEquals(10, epsilon: 0.01));
      expect(field.top - lower.bottom, moreOrLessEquals(16, epsilon: 0.01));
      expect(upper.top - tester.getRect(_title).bottom, greaterThan(200));
      expect(upper.left, 14);
      expect(upper.right, _phone.width - 14);
    },
  );

  testWidgets('many results fill the space up to the title and scroll', (
    WidgetTester tester,
  ) async {
    await _pumpPhone(tester, days: _days(24));

    _expectTitleAtTop(tester);
    final Rect title = tester.getRect(_title);
    final Rect first = tester.getRect(_tiles.first);
    expect(first.top - title.bottom, moreOrLessEquals(12, epsilon: 0.01));
    expect(tester.widget<SearchDayTile>(_tiles.first).view.date, '2026-07-28');

    final ScrollableState scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    for (int jump = 0; jump < 4; jump++) {
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
    }

    final Rect field = tester.getRect(_field);
    final Rect last = tester.getRect(_tiles.last);
    expect(tester.widget<SearchDayTile>(_tiles.last).view.date, '2026-07-05');
    expect(field.top - last.bottom, moreOrLessEquals(16, epsilon: 0.01));
  });

  testWidgets('the no-match message sits just above the field', (
    WidgetTester tester,
  ) async {
    await _pumpPhone(tester, days: _days(2));

    await tester.enterText(find.byType(TextField), 'zzz');
    await _settle(tester);

    expect(_tiles, findsNothing);
    expect(find.text('No days match "zzz".'), findsOneWidget);
    _expectTitleAtTop(tester);
    final Rect message = tester.getRect(find.byType(EmptyStatePlaceholder));
    final Rect field = tester.getRect(_field);
    expect(field.top - message.bottom, moreOrLessEquals(16, epsilon: 0.01));
    expect(message.left, 14);
    expect(message.right, _phone.width - 14);
  });

  testWidgets('the phone clear button is a 44-point face inside the field', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpPhone(tester, days: _days(2));

    expect(find.bySemanticsLabel('Clear search'), findsNothing);
    await tester.enterText(find.byType(TextField), 'rain');
    await _settle(tester);

    final Rect field = tester.getRect(_field);
    final Rect face = tester.getRect(find.byKey(searchClearFaceKey));
    final Rect hit = tester.getRect(find.bySemanticsLabel('Clear search'));
    expect(face.size, const Size.square(44));
    expect(face.right, moreOrLessEquals(field.right - 7.5, epsilon: 0.01));
    expect(face.center.dy, moreOrLessEquals(field.center.dy, epsilon: 0.01));
    expect(hit.width, greaterThanOrEqualTo(44));
    expect(hit.height, greaterThanOrEqualTo(44));
    expect(field.contains(hit.topLeft), isTrue);
    expect(field.contains(hit.bottomRight), isTrue);
    expect(
      tester.getRect(find.byType(TextField)).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.bySemanticsLabel('Clear search'));
    await _settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.bySemanticsLabel('Clear search'), findsNothing);
    semantics.dispose();
  });

  testWidgets('with the keyboard open the field rides above the keyboard', (
    WidgetTester tester,
  ) async {
    await _pumpPhone(tester, days: _days(2));

    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
    await _settle(tester);

    final Rect field = tester.getRect(_field);
    expect(field.height, 52);
    expect(
      field.bottom,
      moreOrLessEquals(_phone.height - _keyboard - 14, epsilon: 0.01),
    );
  });

  testWidgets('macOS keeps the search field above the results', (
    WidgetTester tester,
  ) async {
    await pumpShell(
      tester,
      const AppShell(),
      overrides: <Override>[
        allDaysProvider.overrideWith(
          (Ref ref) => Stream<List<Day>>.value(_days(2)),
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey<String>('rail-search')));
    await _settle(tester);

    expect(
      tester.widget<SearchField>(_field).variant,
      SearchFieldVariant.standard,
    );
    expect(_title, findsNothing);
    expect(_tiles, findsNWidgets(2));
    final Rect field = tester.getRect(_field);
    final Rect screen = tester.getRect(find.byType(SearchScreen));
    expect(field.top - screen.top, 16);
    expect(tester.getRect(_tiles.first).top - field.bottom, 16);
  });
}
