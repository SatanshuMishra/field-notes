import 'dart:async';

import 'package:field_notes/app/capture/app_capture_routes.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/calendar_chevron_button.dart';
import 'package:field_notes/features/calendar/widgets/calendar_month_picker.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser.dart';
import 'package:field_notes/features/capture/chooser/capture_chooser_sheet.dart';
import 'package:field_notes/features/capture/chooser/capture_routes_provider.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/search/search_screen.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/streak/streak_providers.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/support/app_shell_harness.dart' show pumpShell;
import '../features/capture/core/capture_test_support.dart'
    show FakeDraftStore, FakeNoteWriter;
import '../features/capture/photo/photo_test_support.dart' show FakePhotoPicker;
import '../features/garden/support/garden_harness.dart' show dayOf;
import '../features/notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, FakeNoteMediaStore;
import '../features/settings/support/settings_harness.dart'
    show FakeSettingsDataController;
import '../features/sound/support/fake_sound_player.dart';
import '../features/today/support/today_harness.dart' show todayTestEntry;

typedef _Layout = ({
  String name,
  TargetPlatform platform,
  Size surface,
  String navigation,
  Key settings,
});

const List<_Layout> _layouts = <_Layout>[
  (
    name: 'sidebar',
    platform: TargetPlatform.macOS,
    surface: Size(1200, 900),
    navigation: 'rail',
    settings: ValueKey<String>('settings-button'),
  ),
  (
    name: 'bottom bar',
    platform: TargetPlatform.android,
    surface: Size(412, 915),
    navigation: 'tab',
    settings: ValueKey<String>('gear-button'),
  ),
];

const Set<int> _lightOnlyTextInks = <int>{
  0x4A3B2E,
  0x6A5C4A,
  0xA08A70,
  0x8A7358,
  0xB3A58C,
  0x7D8450,
  0xB45C44,
  0x9A4832,
  0xA3866A,
  0x7D6A52,
  0x6F6254,
};

const Set<int> _lightOnlySurfaces = <int>{
  0xD9CBB2,
  0xE6D8BF,
  0xCDBD9F,
  0xEFE2CE,
  0xE9DCC4,
  0xF8EFE0,
  0xFFF5EA,
  0xFFFAF1,
  0xF6EFE0,
  0xFBF3E4,
  0xF3E7D4,
  0xE4D6BF,
  0xECDFC8,
  0xE2D3BA,
  0xD9C9AE,
  0xFBECEA,
};

final Set<int> _darkBacks = <int>{
  FieldNotesColors.dark.pill.toARGB32(),
  Palette.toolbarInk.toARGB32(),
};

const String _moodQuestion = 'How are you feeling today?';
const String _writeNote = 'Write a note';

final DateTime _now = DateTime(2026, 9, 25, 9, 30);

DateTime _clock() => _now;

final List<Entry> _entries = <Entry>[
  todayTestEntry(
    id: 'entry-1',
    textContent: 'The fog lifted over the harbour before the ferry came in.',
  ),
  todayTestEntry(
    id: 'entry-2',
    textContent: '- [ ] water the peonies\n- [x] buy seed packets',
  ),
];

List<Day> _daysIn(({int year, int month}) args) {
  final MonthRef month = MonthRef(args.year, args.month);
  return <Day>[
    dayOf(month.dateKey(7), mood: Mood.calm),
    dayOf(month.dateKey(14), mood: Mood.happy),
    dayOf(month.dateKey(15), mood: Mood.grateful),
  ];
}

List<Override> _walkthroughOverrides() => <Override>[
  todayClockProvider.overrideWithValue(_clock),
  streakClockProvider.overrideWithValue(_clock),
  captureRoutesProvider.overrideWithValue(appCaptureRoutes),
  appSettingsProvider.overrideWith(
    (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
  ),
  settingsDataControllerProvider.overrideWith(
    (Ref ref) async => FakeSettingsDataController(),
  ),
  entriesForDateProvider.overrideWith(
    (Ref ref, String date) => Stream<List<Entry>>.value(_entries),
  ),
  photosForEntryProvider.overrideWith(
    (Ref ref, String entryId) =>
        Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
  ),
  daysInMonthProvider.overrideWith(
    (Ref ref, ({int year, int month}) args) =>
        Stream<List<Day>>.value(_daysIn(args)),
  ),
  allDaysProvider.overrideWith(
    (Ref ref) => Stream<List<Day>>.value(<Day>[
      dayOf('2026-09-23'),
      dayOf('2026-09-24', mood: Mood.grateful),
    ]),
  ),
  todayMediaResolverProvider.overrideWith(
    (Ref ref) async => FakeNoteMediaResolver(),
  ),
  notesMediaResolverProvider.overrideWith(
    (Ref ref) async => FakeNoteMediaResolver(),
  ),
  dayDetailMediaResolverProvider.overrideWith(
    (Ref ref) async => FakeNoteMediaResolver(),
  ),
  noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
  draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
  mediaStoreProvider.overrideWith((Ref ref) async => FakeNoteMediaStore()),
  notePhotoPickerProvider.overrideWithValue(FakePhotoPicker()),
  soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
];

Future<void> _pumpDarkShell(WidgetTester tester, _Layout layout) async {
  await pumpShell(
    tester,
    const AppShell(),
    platform: layout.platform,
    surface: layout.surface,
    overrides: _walkthroughOverrides(),
    brightness: Brightness.dark,
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _navigate(
  WidgetTester tester,
  _Layout layout,
  String destination,
) => _tap(
  tester,
  find.byKey(ValueKey<String>('${layout.navigation}-$destination')),
);

Future<void> _openCaptureChooser(WidgetTester tester, _Layout layout) async {
  if (layout.platform == TargetPlatform.android) {
    await _tap(tester, find.byKey(const ValueKey<String>('capture-button')));
    return;
  }
  unawaited(
    showCaptureChooser(
      tester.element(find.byType(TodayScreen)),
      availableTypes: <EntryType>{
        for (final CaptureRoute route in appCaptureRoutes.routes) route.type,
      },
    ),
  );
  await _settle(tester);
}

Future<void> _openComposer(WidgetTester tester, _Layout layout) async {
  if (layout.platform == TargetPlatform.android) {
    await _openCaptureChooser(tester, layout);
    await _tap(
      tester,
      find.descendant(
        of: find.byType(CaptureChooserSheet),
        matching: find.text(_writeNote),
      ),
    );
    return;
  }
  await _tap(tester, find.widgetWithText(StickerButton, _writeNote));
}

bool _hidden(RenderObject object) => switch (object) {
  RenderOffstage(:final bool offstage) => offstage,
  RenderOpacity(:final double opacity) => opacity == 0,
  RenderAnimatedOpacity(:final Animation<double> opacity) => opacity.value == 0,
  _ => false,
};

Iterable<Color> _fillsOf(RenderObject object) sync* {
  switch (object) {
    case RenderDecoratedBox(
      decoration: BoxDecoration(:final Color? color, :final Gradient? gradient),
    ):
    case RenderDecoratedBox(
      decoration: ShapeDecoration(
        :final Color? color,
        :final Gradient? gradient,
      ),
    ):
      if (color != null) {
        yield color;
      }
      if (gradient != null) {
        yield* gradient.colors;
      }
    case RenderPhysicalModel(:final Color color):
    case RenderPhysicalShape(:final Color color):
      yield color;
  }
  if (object.debugCreator case DebugCreator(
    element: Element(widget: ColoredBox(:final Color color)),
  )) {
    yield color;
  }
}

Iterable<Color> _inksOf(InlineSpan span, Color? inherited) sync* {
  final Color? ink =
      span.style?.foreground?.color ?? span.style?.color ?? inherited;
  if (span is! TextSpan) {
    return;
  }
  if (ink != null && (span.text?.isNotEmpty ?? false)) {
    yield ink;
  }
  for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
    yield* _inksOf(child, ink);
  }
}

int _rgb(Color color) => color.toARGB32() & 0x00FFFFFF;

String _hex(Color color) =>
    '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

String _widgetPath(RenderObject object) => switch (object.debugCreator) {
  DebugCreator(:final Element element) => element.debugGetCreatorChain(24),
  _ => object.toStringShort(),
};

List<String> _lightOnlyPaint(WidgetTester tester) {
  final List<String> found = <String>[];
  void visit(RenderObject object, {required bool onDarkBack}) {
    if (_hidden(object)) {
      return;
    }
    final List<Color> fills = _fillsOf(object).toList();
    for (final Color fill in fills) {
      if (fill.a > 0 && _lightOnlySurfaces.contains(_rgb(fill))) {
        found.add('fills with ${_hex(fill)}: ${_widgetPath(object)}');
      }
    }
    final bool darkBack =
        onDarkBack ||
        fills.any((Color fill) => _darkBacks.contains(fill.toARGB32()));
    if (object is RenderParagraph && !darkBack) {
      for (final Color ink in _inksOf(object.text, null)) {
        if (_lightOnlyTextInks.contains(_rgb(ink))) {
          found.add(
            'paints "${object.text.toPlainText()}" in ${_hex(ink)}: '
            '${_widgetPath(object)}',
          );
        }
      }
    }
    object.visitChildren(
      (RenderObject child) => visit(child, onDarkBack: darkBack),
    );
  }

  for (final RenderView view in tester.binding.renderViews) {
    visit(view, onDarkBack: false);
  }
  return found;
}

void _expectDark(WidgetTester tester, Finder proof, String screen) {
  expect(proof, findsWidgets, reason: '$screen is not open');
  expect(
    _lightOnlyPaint(tester),
    isEmpty,
    reason: '$screen paints a light-only colour under the dark theme',
  );
}

void main() {
  for (final _Layout layout in _layouts) {
    group('the ${layout.name} layout under the dark theme', () {
      testWidgets('Today, Calendar and its month picker, Garden and Search '
          'draw dark', (WidgetTester tester) async {
        await _pumpDarkShell(tester, layout);
        _expectDark(tester, find.byType(TodayScreen), 'Today');

        await _navigate(tester, layout, 'calendar');
        _expectDark(tester, find.byType(CalendarScreen), 'Calendar');

        await _tap(tester, find.byKey(calendarTitleKey));
        _expectDark(
          tester,
          find.byType(CalendarMonthPicker),
          'the calendar month picker',
        );
        Navigator.of(tester.element(find.byType(CalendarMonthPicker))).pop();
        await _settle(tester);

        await _navigate(tester, layout, 'garden');
        _expectDark(tester, find.byType(GardenScreen), 'Garden');

        await _navigate(tester, layout, 'search');
        _expectDark(tester, find.byType(SearchScreen), 'Search');

        await tester.enterText(find.byType(TextField), 'harbour');
        await _settle(tester);
        _expectDark(tester, find.byType(SearchScreen), 'Search with a query');
      }, variant: TargetPlatformVariant.only(layout.platform));

      testWidgets(
        'each Settings tab draws dark',
        (WidgetTester tester) async {
          await _pumpDarkShell(tester, layout);
          await _tap(tester, find.byKey(layout.settings));

          for (final SettingsTab tab in SettingsTab.values) {
            await _tap(tester, find.byKey(settingsTabKey(tab)));
            _expectDark(
              tester,
              find.byType(SettingsScreen),
              'the ${tab.label} Settings tab',
            );
          }
        },
        variant: TargetPlatformVariant.only(layout.platform),
      );

      testWidgets(
        'a day view draws dark',
        (WidgetTester tester) async {
          await _pumpDarkShell(tester, layout);
          await _navigate(tester, layout, 'calendar');
          await _tap(
            tester,
            find.byWidgetPredicate(
              (Widget widget) =>
                  widget is CalendarChevronButton &&
                  widget.semanticLabel == 'Previous month',
            ),
          );
          final MonthRef previous = MonthRef.forDate(DateTime.now()).previous;
          await _tap(
            tester,
            find.byKey(ValueKey<String>('day-${previous.dateKey(15)}')),
          );

          _expectDark(tester, find.byType(DayDetailPanel), 'a day view');
        },
        variant: TargetPlatformVariant.only(layout.platform),
      );

      testWidgets(
        'a log view and its delete confirm dialog draw dark',
        (WidgetTester tester) async {
          await _pumpDarkShell(tester, layout);
          await _tap(tester, find.byType(CompactLogCard).first);
          _expectDark(tester, find.byType(LogViewerPanel), 'a log view');

          await _tap(
            tester,
            find.descendant(
              of: find.byType(LogViewerPanel),
              matching: find.byKey(logActionsDeleteKey),
            ),
          );
          _expectDark(
            tester,
            find.byKey(confirmDialogConfirmKey),
            'the delete confirm dialog',
          );
        },
        variant: TargetPlatformVariant.only(layout.platform),
      );

      testWidgets(
        'the mood picker draws dark',
        (WidgetTester tester) async {
          await _pumpDarkShell(tester, layout);
          await _tap(tester, find.text(_moodQuestion));

          _expectDark(tester, find.text('Grateful'), 'the mood picker');
        },
        variant: TargetPlatformVariant.only(layout.platform),
      );

      testWidgets(
        'the capture chooser draws dark',
        (WidgetTester tester) async {
          await _pumpDarkShell(tester, layout);
          await _openCaptureChooser(tester, layout);

          _expectDark(
            tester,
            find.byType(CaptureChooserSheet),
            'the capture chooser',
          );
        },
        variant: TargetPlatformVariant.only(layout.platform),
      );

      testWidgets('the text composer, its More formats menu and a toast '
          'draw dark', (WidgetTester tester) async {
        await _pumpDarkShell(tester, layout);
        await _openComposer(tester, layout);
        _expectDark(
          tester,
          find.byType(TextComposerSheet),
          'the text composer',
        );

        await _tap(tester, find.byKey(formatMoreKey));
        _expectDark(
          tester,
          find.byKey(formatHighlightKey),
          'the More formats menu',
        );
        await _tap(tester, find.byKey(formatMoreKey));

        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        _expectDark(tester, find.text(emptySaveGuardMessage), 'a toast');
        await tester.pump(kToastLifetime);
        await tester.pump();
      }, variant: TargetPlatformVariant.only(layout.platform));
    });
  }
}
