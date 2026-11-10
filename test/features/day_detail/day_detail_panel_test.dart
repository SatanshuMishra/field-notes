import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Scaffold, MaterialApp;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart' show DashedDivider;
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/features/day_detail/day_detail_header.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/day_detail/day_note_pane.dart'
    show DayPaneFrame, dayNotePaneKey;
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/note_reading.dart'
    show LogStepFooter, NoteReadingBody;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../../support/ax_update_checker.dart';
import '../../support/composer_room.dart';
import '../../support/note_editor_driver.dart';
import '../entry_cards/support/reading_path.dart';
import 'support/day_detail_harness.dart';

Finder _panelCard() => find.byKey(dayDetailPanelKey);

Future<void> _revealPillOn(WidgetTester tester, Finder card) async {
  await tester.longPress(card);
  await tester.pumpAndSettle();
}

Future<void> _confirmDelete(WidgetTester tester) async {
  await tester.tap(find.byKey(logActionsDeleteKey).hitTestable());
  await tester.pumpAndSettle();
  expect(find.text('Delete this log?'), findsOneWidget);
  await tester.tap(find.byKey(confirmDialogConfirmKey));
  await tester.pumpAndSettle();
}

Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(kToastLifetime);
  await tester.pumpAndSettle();
}

List<Override> _overrides(
  FakeJournalRepository repository, {
  Override? mediaResolver,
}) {
  return <Override>[
    journalRepositoryProvider.overrideWithValue(repository),
    draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
    mediaResolver ??
        dayDetailMediaResolverProvider.overrideWith(
          (Ref ref) => FakeMediaResolver(),
        ),
    todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
  ];
}

Widget _panelApp(
  FakeJournalRepository repository, {
  Override? mediaResolver,
  String? focusEntryId,
}) {
  return ProviderScope(
    overrides: _overrides(repository, mediaResolver: mediaResolver),
    child: dayDetailHarness(
      DayDetailPanel(date: '2026-07-19', focusEntryId: focusEntryId),
    ),
  );
}

const Key _windowCaptureKey = ValueKey<String>('day-window-capture');

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

Widget _windowApp(
  FakeJournalRepository repository, {
  Brightness brightness = Brightness.light,
}) {
  return ProviderScope(
    overrides: _overrides(repository),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(
        platform: TargetPlatform.macOS,
        brightness: brightness,
      ),
      home: const Scaffold(
        body: RepaintBoundary(
          key: _windowCaptureKey,
          child: DayDetailPanel(date: '2026-07-19'),
        ),
      ),
    ),
  );
}

void _useDesktopWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _selectFirstCard(WidgetTester tester) async {
  await tester.tapAt(
    tester.getTopLeft(find.byType(CompactLogCard).first) + const Offset(24, 18),
  );
  await tester.pumpAndSettle();
}

Future<List<Color>> _windowPixels(
  WidgetTester tester,
  List<Offset> points,
) async {
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(_windowCaptureKey),
  ) as RenderRepaintBoundary;
  final Offset origin = tester.getTopLeft(find.byKey(_windowCaptureKey));
  final List<Color>? pixels = await tester.runAsync<List<Color>>(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData data = (await image.toByteData())!;
    final List<Color> sampled = <Color>[
      for (final Offset point in points)
        _pixelAt(data, image.width, point - origin),
    ];
    image.dispose();
    return sampled;
  });
  return pixels!;
}

Color _pixelAt(ByteData data, int width, Offset point) {
  final int offset = (point.dy.floor() * width + point.dx.floor()) * 4;
  return Color.fromARGB(
    data.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );
}

bool _near(Color actual, Color expected, int tolerance) {
  int channel(double value) => (value * 255).round();
  return (channel(actual.r) - channel(expected.r)).abs() <= tolerance &&
      (channel(actual.g) - channel(expected.g)).abs() <= tolerance &&
      (channel(actual.b) - channel(expected.b)).abs() <= tolerance;
}

List<Rect> _horizontalRulesIn(WidgetTester tester, Finder scope) {
  final Finder rules = find.descendant(
    of: scope,
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is DashedDivider && widget.axis == Axis.horizontal,
    ),
  );
  return <Rect>[
    for (int index = 0; index < rules.evaluate().length; index++)
      tester.getRect(rules.at(index)),
  ];
}

String _longNote(int index) {
  final StringBuffer buffer = StringBuffer('journal note number $index');
  int word = 0;
  while (buffer.length < 600) {
    buffer.write(' word${word++}');
  }
  return buffer.toString();
}

FakeJournalRepository _twoNotes() => FakeJournalRepository(
  entries: <Entry>[
    entryOf(id: 'entry-1', type: EntryType.text, textContent: 'a good day'),
    entryOf(id: 'entry-2', type: EntryType.text, textContent: 'and a walk'),
  ],
);

void main() {
  testWidgets('both header rules meet in one straight line', (
    WidgetTester tester,
  ) async {
    _useDesktopWindow(tester);
    await tester.pumpWidget(_windowApp(_twoNotes()));
    await tester.pumpAndSettle();
    await _selectFirstCard(tester);

    final Rect panel = tester.getRect(_panelCard());
    final Rect left = tester.getRect(
      find.descendant(
        of: find.byType(DayDetailHeader),
        matching: find.byType(DashedDivider),
      ),
    );
    final Rect right = tester.getRect(
      find
          .descendant(
            of: find.byType(DayPaneFrame),
            matching: find.byType(DashedDivider),
          )
          .first,
    );
    expect(right.bottom, left.bottom);
    expect(right.left, greaterThan(left.right));
    expect(
      left.bottom,
      panel.top + 2 + dayDetailHeaderHeight + dayDetailHeaderRuleThickness,
    );
  }, variant: _mac);

  testWidgets('choosing a card at the foot of the list keeps it in view', (
    WidgetTester tester,
  ) async {
    _useDesktopWindow(tester);
    await tester.pumpWidget(
      _windowApp(
        FakeJournalRepository(
          entries: <Entry>[
            for (int i = 0; i < 10; i++)
              entryOf(
                id: 'entry-$i',
                type: EntryType.text,
                textContent: 'journal note number $i for the day',
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    const double shownSlice = 36;
    final Finder list = find
        .descendant(
          of: find.byKey(dayDetailListPaneKey),
          matching: find.byType(Scrollable),
        )
        .first;
    final Finder card = find.descendant(
      of: find.byKey(const ValueKey<String>('entry-6'), skipOffstage: false),
      matching: find.byType(CompactLogCard, skipOffstage: false),
    );
    final ScrollPosition position = tester
        .state<ScrollableState>(list)
        .position;
    position.jumpTo(
      position.pixels +
          tester.getRect(card).top -
          (tester.getRect(list).bottom - shownSlice),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(list).bottom - tester.getRect(card).top,
      closeTo(shownSlice, 0.5),
    );

    await tester.tapAt(tester.getTopLeft(card) + const Offset(24, 18));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<NoteReadingBody>(
            find.descendant(
              of: find.byKey(dayNotePaneKey),
              matching: find.byType(NoteReadingBody),
            ),
          )
          .entry
          .id,
      'entry-6',
    );
    expect(
      tester.getRect(list).bottom - tester.getRect(card).top,
      greaterThanOrEqualTo(shownSlice - 0.5),
    );
  }, variant: _mac);

  testWidgets('one footer rule runs under both panes', (
    WidgetTester tester,
  ) async {
    _useDesktopWindow(tester);
    await tester.pumpWidget(_windowApp(_twoNotes()));
    await tester.pumpAndSettle();
    await _selectFirstCard(tester);

    final Rect panel = tester.getRect(_panelCard());
    final Rect list = tester.getRect(find.byKey(dayDetailListPaneKey));
    final Rect pane = tester.getRect(find.byKey(dayNotePaneKey));
    final Rect stepper = tester.getRect(find.byType(LogStepFooter));
    final double headerBottom =
        panel.top + 2 + dayDetailHeaderHeight + dayDetailHeaderRuleThickness;
    final List<Rect> footerRules = <Rect>[
      for (final Rect rule in _horizontalRulesIn(tester, _panelCard()))
        if (rule.top > headerBottom && rule.width > list.width) rule,
    ];

    expect(footerRules, hasLength(1));
    final Rect rule = footerRules.single;
    expect(rule.left, closeTo(panel.left + 2, 0.5));
    expect(rule.right, closeTo(panel.right - 2, 0.5));
    expect(list.bottom, lessThanOrEqualTo(rule.top + 0.5));
    expect(pane.bottom, lessThanOrEqualTo(rule.top + 0.5));
    expect(stepper.top, greaterThanOrEqualTo(rule.bottom - 0.5));
    expect(stepper.left, greaterThan(list.right));
  }, variant: _mac);

  for (final Brightness brightness in Brightness.values) {
    testWidgets('the day window is the ${brightness.name} page colour in both '
        'halves', (WidgetTester tester) async {
      _useDesktopWindow(tester);
      await tester.pumpWidget(
        _windowApp(FakeJournalRepository(), brightness: brightness),
      );
      await tester.pumpAndSettle();

      final FieldNotesColors colors = switch (brightness) {
        Brightness.light => FieldNotesColors.light,
        Brightness.dark => FieldNotesColors.dark,
      };
      final Rect list = tester.getRect(find.byKey(dayDetailListPaneKey));
      final Rect pane = tester.getRect(find.byKey(dayNotePaneKey));
      final List<Color> pixels = await _windowPixels(tester, <Offset>[
        list.bottomLeft + const Offset(24, -24),
        pane.topRight + const Offset(-24, 24),
        pane.bottomRight + const Offset(-24, -24),
      ]);

      for (final Color pixel in pixels) {
        expect(_near(pixel, colors.panelTop, 1), isTrue, reason: '$pixel');
      }
    }, variant: _mac);
  }

  testWidgets('the window outline keeps its top-right corner arc', (
    WidgetTester tester,
  ) async {
    _useDesktopWindow(tester);
    await tester.pumpWidget(
      _windowApp(_twoNotes(), brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();
    await _selectFirstCard(tester);

    final Rect panel = tester.getRect(_panelCard());
    const double radius = Shapes.radiusXl;
    const double centreline = radius - 2 / 2;
    const double angle = math.pi / 4;
    final Offset arc = Offset(
      panel.right - radius + centreline * math.cos(angle),
      panel.top + radius - centreline * math.sin(angle),
    );
    final List<Color> pixels = await _windowPixels(tester, <Offset>[arc]);

    expect(
      _near(pixels.single, FieldNotesColors.dark.line, 24),
      isTrue,
      reason: '${pixels.single}',
    );
  }, variant: _mac);

  testWidgets('the day card actions lie inside every reading-order frame', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(_panelApp(_twoNotes()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(logActionsOpenLabel), findsNothing);
    expectInsideEveryReadingFrame(tester, logActionsMoreLabel);
    for (int card = 0; card < 2; card += 1) {
      await _revealPillOn(tester, find.byType(CompactLogCard).at(card));
      expectInsideEveryReadingFrame(tester, logActionsEditLabel);
      expectInsideEveryReadingFrame(tester, logMenuDeleteLabel);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }
    semantics.dispose();
  });

  testWidgets('day cards keep their list positions for screen readers', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(_panelApp(_twoNotes()));
    await tester.pumpAndSettle();

    expect(scrolledChildIndexes(tester), <int?>[0, 1, 2]);
    semantics.dispose();
  });

  testWidgets('renders the day heading, mood prompt, count and entries', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(id: 'entry-1', type: EntryType.text, textContent: 'a good day'),
        entryOf(id: 'entry-2', type: EntryType.text, textContent: 'and a walk'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(find.text('a day in the garden'), findsOneWidget);
    expect(find.text('2026'), findsNothing);
    expect(find.text(dayDetailMoodPrompt), findsOneWidget);
    expect(find.text('2 logs that day'), findsOneWidget);
    expect(find.byType(CompactLogCard), findsNWidgets(2));
    for (final String note in <String>['a good day', 'and a walk']) {
      expect(
        find.descendant(
          of: find.byType(CompactLogCard),
          matching: find.text(note),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('shows the dashed empty state when the day has no entries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_panelApp(FakeJournalRepository()));
    await tester.pumpAndSettle();

    expect(find.text('0 logs that day'), findsOneWidget);
    expect(find.byType(EmptyStatePlaceholder), findsOneWidget);
    expect(find.text(dayDetailEmptyMessage), findsOneWidget);
  });

  testWidgets('tapping add a note opens the note composer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_panelApp(FakeJournalRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a note'));
    await tester.pumpAndSettle();

    expect(composerTitled(newNoteTitle), findsOneWidget);
    expect(find.byKey(composerCloseKey), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsWidgets);
  });

  testWidgets('tapping edit opens the note editor prefilled', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    await _revealPillOn(tester, find.byType(CompactLogCard));
    await tester.tap(find.byKey(logActionsEditKey).hitTestable());
    await tester.pumpAndSettle();

    expect(
      composerTitled(
        editNoteTitleFor(
          entryOf(type: EntryType.text, textContent: 'a good day'),
        ),
      ),
      findsOneWidget,
    );
    expect(NoteEditorDriver(tester).source, 'a good day');
  });

  testWidgets('deleting an entry soft-deletes it and updates the list', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();
    expect(find.text('1 log that day'), findsOneWidget);

    await _revealPillOn(tester, find.byType(CompactLogCard));
    await _confirmDelete(tester);

    expect(repository.deletedEntryIds, <String>['entry-1']);
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is NoteBody && w.text == 'a good day',
      ),
      findsNothing,
    );
    expect(find.text('0 logs that day'), findsOneWidget);
    await _drainToast(tester);
  });

  testWidgets('a delete rebuilds the surviving tiles by id, not by position', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(id: 'entry-1', type: EntryType.text, textContent: 'a good day'),
        entryOf(
          id: 'entry-2',
          type: EntryType.voice,
          mediaId: 'blob-1',
          durationMs: 4000,
        ),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final Finder survivor = find.byKey(const ValueKey<String>('entry-2'));
    expect(survivor, findsOneWidget);
    final Element survivorElement = tester.element(survivor);

    await _revealPillOn(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey<String>('entry-1')),
        matching: find.byType(CompactLogCard),
      ),
    );
    await _confirmDelete(tester);

    expect(repository.deletedEntryIds, <String>['entry-1']);
    expect(find.byKey(const ValueKey<String>('entry-1')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is NoteBody && w.text == 'a good day',
      ),
      findsNothing,
    );
    expect(survivor, findsOneWidget);
    expect(identical(tester.element(survivor), survivorElement), isTrue);
    await _drainToast(tester);
  });

  testWidgets('surfaces a non-destructive message when the delete fails', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    )..deleteError = Exception('locked');

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    await _revealPillOn(tester, find.byType(CompactLogCard));
    await _confirmDelete(tester);

    expect(repository.deletedEntryIds, isEmpty);
    expect(find.text(dayDetailDeleteErrorMessage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CompactLogCard),
        matching: find.text('a good day'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('surfaces a load error and never claims the day is empty', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entriesError: Exception('database unavailable'),
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    expect(find.text(dayDetailEntriesErrorMessage), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(find.byType(EmptyStatePlaceholder), findsNothing);
    expect(find.text(dayDetailEmptyMessage), findsNothing);
    expect(find.text('0 logs that day'), findsNothing);
  });

  testWidgets('surfaces a media error instead of mounting unplayable tiles', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(
      _panelApp(
        repository,
        mediaResolver: dayDetailMediaResolverProvider.overrideWith(
          (Ref ref) async => throw Exception('no media directory'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(dayDetailMediaErrorMessage), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is NoteBody && w.text == 'a good day',
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('entry-1')), findsNothing);
    expect(find.text('1 log that day'), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsOneWidget);
  });

  testWidgets('builds only a bounded subset of tiles for a large day', (
    WidgetTester tester,
  ) async {
    const int entryCount = 40;
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        for (int i = 0; i < entryCount; i++)
          entryOf(
            id: 'entry-$i',
            type: EntryType.text,
            textContent: 'journal note number $i for the day',
          ),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final int builtTiles = find
        .byType(CompactLogCard, skipOffstage: false)
        .evaluate()
        .length;
    expect(builtTiles, greaterThan(0));
    expect(builtTiles, lessThan(entryCount));
  });

  testWidgets(
    'the panel is the window less a 24 gutter, capped at 1060 by 660',
    (WidgetTester tester) async {
      await tester.pumpWidget(_panelApp(FakeJournalRepository()));
      await tester.pumpAndSettle();

      expect(dayDetailPanelMaxWidth, 1060);
      expect(dayDetailPanelMaxHeight, 660);
      expect(tester.getSize(_panelCard()), const Size(800 - 48, 600 - 48));

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      expect(tester.getSize(_panelCard()), const Size(1060, 660));
    },
  );

  testWidgets('a narrow window leaves a 24 gutter either side of the panel', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_panelApp(FakeJournalRepository()));
    await tester.pumpAndSettle();

    expect(tester.getSize(_panelCard()).width, 400 - 48);
  });

  testWidgets('a long day keeps the panel at its full height', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        for (int i = 0; i < 40; i++)
          entryOf(
            id: 'entry-$i',
            type: EntryType.text,
            textContent: 'journal note number $i for the day',
          ),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final Size panel = tester.getSize(_panelCard());
    expect(panel.height, dayDetailPanelMaxHeight);
    expect(panel.width, 800 - 48);
  });

  testWidgets('a day-detail card reads in the padded column of the list pane', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final Rect panel = tester.getRect(_panelCard());
    final Rect list = tester.getRect(find.byKey(dayDetailListPaneKey));
    final Rect card = tester.getRect(find.byType(CompactLogCard));
    expect(list.width, dayDetailListMinWidth);
    expect(list.left, panel.left + 2);
    expect(card.width, dayDetailListMinWidth - 2 * 18);
    expect(card.left, panel.left + 2 + 18);
    expect(
      tester.widget<CompactLogCard>(find.byType(CompactLogCard)).density,
      CompactLogDensity.row,
    );
  });

  testWidgets('a one-entry day lists its card at the top of the list pane', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(id: 'entry-1', type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final double listBottom = tester
        .getBottomLeft(find.byKey(dayDetailListPaneKey))
        .dy;
    final double cardBottom = tester
        .getBottomLeft(find.byKey(const ValueKey<String>('entry-1')))
        .dy;
    expect(cardBottom + 20, lessThan(listBottom));
    expect(tester.getSize(_panelCard()).height, 600 - 48);
  });

  testWidgets('a long note reads as a one-line snippet with no Read link', (
    WidgetTester tester,
  ) async {
    final String note = _longNote(0);
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entryOf(type: EntryType.text, textContent: note)],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    expect(find.byType(CompactLogCard), findsOneWidget);
    expect(find.byKey(compactLogOpenLabelKey), findsNothing);
    final Text snippet = tester.widget<Text>(
      find.textContaining('journal note number 0 word0'),
    );
    expect(snippet.maxLines, 1);
    expect(snippet.overflow, TextOverflow.ellipsis);
    expect(find.byType(NoteBody), findsNothing);
    expect(find.textContaining('word60'), findsNothing);
  });

  testWidgets('the header stays fixed while the body scrolls', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        for (int i = 0; i < 40; i++)
          entryOf(
            id: 'entry-$i',
            type: EntryType.text,
            textContent: 'journal note number $i for the day',
          ),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final double headerTop = tester.getTopLeft(find.byType(DayDetailHeader)).dy;
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(DayDetailHeader)).dy, headerTop);
    expect(find.byKey(const ValueKey<String>('entry-0')), findsNothing);
  });

  testWidgets('opening with focusEntryId scrolls that entry into view', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const String focused = 'entry-30';
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        for (int i = 0; i < 40; i++)
          entryOf(
            id: 'entry-$i',
            type: EntryType.text,
            textContent: 'journal note number $i for the day',
          ),
      ],
    );

    await tester.pumpWidget(_panelApp(repository, focusEntryId: focused));
    await tester.pumpAndSettle();

    final Finder tile = find.byKey(const ValueKey<String>(focused));
    expect(tile, findsOneWidget);
    final Rect tileRect = tester.getRect(tile);
    final Rect listRect = tester.getRect(find.byType(ListView));
    expect(tileRect.top, greaterThanOrEqualTo(listRect.top - 1));
    expect(tileRect.bottom, lessThanOrEqualTo(listRect.bottom + 1));
  });

  testWidgets('opening without focusEntryId stays at the top of the day', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        for (int i = 0; i < 40; i++)
          entryOf(
            id: 'entry-$i',
            type: EntryType.text,
            textContent: 'journal note number $i for the day',
          ),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('entry-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('entry-30')), findsNothing);
  });

  testWidgets(
    'scrolling a day of 40 notes sends no accessibility update macOS rejects',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final FakeJournalRepository repository = FakeJournalRepository(
        entries: <Entry>[
          for (int i = 0; i < 40; i++)
            entryOf(
              id: 'entry-$i',
              type: EntryType.text,
              textContent: 'journal note number $i for the day',
            ),
        ],
      );
      AxUpdateChecker.instance.reset();
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(_panelApp(repository));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(AxUpdateChecker.instance.updates, greaterThan(0));
      expect(AxUpdateChecker.instance.rejections, isEmpty);
      semantics.dispose();
    },
  );
}
