import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show
        NoteBody,
        logActionsDeleteKey,
        logActionsDeleteLabel,
        logActionsEditKey,
        logActionsEditLabel;
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerExit;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show
        logViewerBackKey,
        logViewerEarlierKey,
        logViewerEarlierLabel,
        logViewerLaterKey,
        logViewerLaterLabel;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/note_reading.dart';
import 'package:field_notes/features/log_viewer/note_sheet_view.dart';

import '../../support/note_generators.dart' show noteGeneratorSeed;
import '../notes/support/notes_harness.dart' show FakeNoteMediaResolver;

const Size _phone = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _fullSheet = 832 - 34 - 8;
const String _date = '2026-07-19';
const String _dayTitle = 'Sunday, July 19';
const String _shortNote =
    'Watered the roses.\nTea under the elm.\nRain by evening.';
const int _longNoteWords = 2000;
const int _wordsPerParagraph = 50;

const List<String> _proseWords = <String>[
  'fog',
  'harbour',
  'tide',
  'walk',
  'gulls',
  'rain',
  'pier',
  'ferry',
  'lantern',
  'stone',
  'the',
  'a',
];

void _usePhone(WidgetTester tester) {
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
}

String _longNote() {
  final Random random = Random(noteGeneratorSeed);
  return <String>[
    for (
      int paragraph = 0;
      paragraph < _longNoteWords ~/ _wordsPerParagraph;
      paragraph++
    )
      <String>[
        for (int word = 0; word < _wordsPerParagraph; word++)
          _proseWords[random.nextInt(_proseWords.length)],
      ].join(' '),
  ].join('\n\n');
}

Entry _entry({
  required String id,
  required int hour,
  EntryType type = EntryType.text,
  String? text,
}) {
  return Entry(
    id: id,
    dayId: 'day-1',
    type: type,
    textContent: text,
    mediaId: type == EntryType.text ? null : 'voice-blob',
    durationMs: type == EntryType.text ? null : 65000,
    createdAt: DateTime(2026, 7, 19, hour, 12).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

LogViewerScene _scene(
  List<String> calls, {
  required Entry entry,
  int index = 0,
  int count = 1,
  Entry? earlier,
  Entry? later,
  LogViewerExit exit = LogViewerExit.back,
  bool editable = true,
}) {
  return LogViewerScene(
    entry: entry,
    date: _date,
    dayTitle: _dayTitle,
    mood: null,
    index: index,
    count: count,
    earlier: earlier,
    later: later,
    exit: exit,
    onBack: () => calls.add('back'),
    onEarlier: earlier == null ? null : () => calls.add('earlier'),
    onLater: later == null ? null : () => calls.add('later'),
    onDelete: () => calls.add('delete'),
    onEdit: editable ? () => calls.add('edit') : null,
  );
}

Future<void> _openSheet(
  WidgetTester tester,
  LogViewerScene scene, {
  required String name,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<String>(name),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(
        platform: TargetPlatform.android,
        brightness: brightness,
      ),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showPhoneSheet<void>(
                  context,
                  builder: (BuildContext sheetContext) => NoteSheetView(
                    scene: scene,
                    resolver: FakeNoteMediaResolver(),
                  ),
                ),
                child: const Text('open note'),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open note'));
  await tester.pumpAndSettle();
}

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(PhoneSheet), matching: finder);

Finder _faceOf(Key key) => find
    .descendant(of: find.byKey(key), matching: find.byType(Container))
    .first;

double _sheetHeight(WidgetTester tester) =>
    tester.getSize(find.byType(PhoneSheet)).height;

bool _expanded(WidgetTester tester) =>
    tester.widget<PhoneSheet>(find.byType(PhoneSheet)).expanded;

void main() {
  testWidgets(
    'a short note gives a short sheet and a long note grows to near full',
    (WidgetTester tester) async {
      _usePhone(tester);
      final List<String> calls = <String>[];
      final String longNote = _longNote();
      expect(longNote.split(RegExp(r'\s+')), hasLength(_longNoteWords));

      await _openSheet(
        tester,
        _scene(
          calls,
          entry: _entry(id: 'short', hour: 8, text: _shortNote),
        ),
        name: 'short',
      );

      expect(find.byType(NoteSheetView), findsOneWidget);
      expect(
        _inSheet(
          find.byWidgetPredicate(
            (Widget widget) => widget is NoteBody && widget.text == _shortNote,
          ),
        ),
        findsOneWidget,
      );
      expect(_sheetHeight(tester), lessThan(_phone.height / 2));
      expect(_expanded(tester), isFalse);

      await _openSheet(
        tester,
        _scene(
          calls,
          entry: _entry(id: 'long', hour: 8, text: longNote),
        ),
        name: 'long',
      );

      expect(_sheetHeight(tester), _fullSheet);
      expect(_expanded(tester), isFalse);
      expect(tester.getRect(find.byType(PhoneSheet)).bottom, _phone.height);
      final ScrollableState body = tester.state<ScrollableState>(
        _inSheet(find.byType(Scrollable)).first,
      );
      expect(body.position.maxScrollExtent, greaterThan(0));
      expect(calls, isEmpty);
    },
  );

  testWidgets('the note sheet header, footer and action row', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final SemanticsHandle semantics = tester.ensureSemantics();
    final List<String> calls = <String>[];
    final Entry morning = _entry(
      id: 'morning',
      hour: 8,
      text: 'Watered the roses.',
    );
    final Entry dawn = _entry(id: 'dawn', hour: 6, type: EntryType.voice);
    final Entry afternoon = _entry(
      id: 'afternoon',
      hour: 14,
      text: 'Tea under the elm.',
    );

    await _openSheet(
      tester,
      _scene(
        calls,
        entry: morning,
        index: 1,
        count: 4,
        earlier: dawn,
        later: afternoon,
        exit: LogViewerExit.close,
      ),
      name: 'several',
    );

    final Text day = tester.widget<Text>(_inSheet(find.text(_dayTitle)));
    expect(
      day.style!.color!.toARGB32(),
      FieldNotesColors.light.accentInk.toARGB32(),
    );
    expect(day.style!.fontFamily, TypographyTokens.stampAccent.fontFamily);
    final Text heading = tester.widget<Text>(
      _inSheet(find.text('Morning note')),
    );
    expect(heading.style!.fontSize, 21);
    expect(
      heading.style!.fontFamily,
      TypographyTokens.headlineSerif.fontFamily,
    );
    final Rect grabber = tester.getRect(find.byKey(phoneSheetGrabberKey));
    final Rect dayRect = tester.getRect(_inSheet(find.text(_dayTitle)));
    final Rect headingRect = tester.getRect(
      _inSheet(find.text('Morning note')),
    );
    expect(grabber.bottom, lessThanOrEqualTo(dayRect.top));
    expect(dayRect.bottom, lessThanOrEqualTo(headingRect.top));

    final BuildContext context = tester.element(find.byType(NoteSheetView));
    final String meta = logMetaFor(context, morning);
    expect(meta, startsWith('8:12 AM'));
    final Rect metaRect = tester.getRect(_inSheet(find.text(meta)));
    final Rect bodyRect = tester.getRect(_inSheet(find.byType(NoteBody)));
    expect(metaRect.top, greaterThan(headingRect.bottom));
    expect(metaRect.bottom, lessThanOrEqualTo(bodyRect.top));

    final Rect footer = tester.getRect(find.byKey(phoneSheetFooterKey));
    expect(_inSheet(find.text('2 of 4')), findsOneWidget);
    expect(_inSheet(find.text('6:12 AM · voice')), findsOneWidget);
    expect(_inSheet(find.text('2:12 PM · note')), findsOneWidget);
    for (final Key key in <Key>[logViewerEarlierKey, logViewerLaterKey]) {
      final Rect step = tester.getRect(_inSheet(find.byKey(key)));
      expect(step.height, greaterThanOrEqualTo(44), reason: '$key');
      expect(step.width, greaterThanOrEqualTo(44), reason: '$key');
      expect(step.bottom, lessThanOrEqualTo(footer.top), reason: '$key');
    }
    expect(find.bySemanticsLabel(logViewerEarlierLabel), findsOneWidget);
    expect(find.bySemanticsLabel(logViewerLaterLabel), findsOneWidget);

    final Rect back = tester.getRect(find.byKey(logViewerBackKey));
    final Rect edit = tester.getRect(find.byKey(logActionsEditKey));
    final Rect delete = tester.getRect(find.byKey(logActionsDeleteKey));
    expect(
      find.descendant(
        of: find.byKey(logViewerBackKey),
        matching: find.text('Close'),
      ),
      findsOneWidget,
    );
    expect(back.height, 48);
    expect(edit.size, const Size(48, 48));
    expect(delete.size, const Size(48, 48));
    expect(back.width, greaterThan(edit.width + delete.width));
    expect(edit.left, greaterThan(back.right));
    expect(delete.left, greaterThan(edit.right));
    for (final Rect action in <Rect>[back, edit, delete]) {
      expect(footer.contains(action.center), isTrue, reason: '$action');
    }
    for (final Key key in <Key>[logActionsEditKey, logActionsDeleteKey]) {
      final BoxDecoration face =
          tester.widget<Container>(_faceOf(key)).decoration! as BoxDecoration;
      expect(
        face.color!.toARGB32(),
        Palette.toolbarInk.toARGB32(),
        reason: '$key',
      );
    }
    expect(find.bySemanticsLabel(logActionsEditLabel), findsOneWidget);
    expect(find.bySemanticsLabel(logActionsDeleteLabel), findsOneWidget);

    await tester.tap(find.byKey(logViewerEarlierKey));
    await tester.tap(find.byKey(logViewerLaterKey));
    await tester.tap(find.byKey(logViewerBackKey));
    await tester.tap(find.byKey(logActionsEditKey));
    await tester.tap(find.byKey(logActionsDeleteKey));
    await tester.pump();
    expect(calls, <String>['earlier', 'later', 'back', 'edit', 'delete']);

    final double resting = _sheetHeight(tester);
    expect(resting, lessThan(_fullSheet));
    await tester.drag(
      _inSheet(find.text('Morning note')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(_expanded(tester), isTrue);
    expect(_sheetHeight(tester), _fullSheet);

    await tester.tap(find.byKey(phoneSheetGrabberToggleKey));
    await tester.pumpAndSettle();
    expect(_expanded(tester), isFalse);
    expect(_sheetHeight(tester), resting);

    await tester.drag(
      _inSheet(find.text('Morning note')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      _inSheet(find.text('Morning note')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    expect(_expanded(tester), isFalse);
    expect(find.byType(NoteSheetView), findsOneWidget);
    await tester.drag(
      _inSheet(find.text('Morning note')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NoteSheetView), findsNothing);

    await _openSheet(
      tester,
      _scene(calls, entry: morning, editable: false),
      name: 'single',
      brightness: Brightness.dark,
    );
    expect(find.byType(NoteSheetView), findsOneWidget);
    expect(find.byKey(logViewerEarlierKey), findsNothing);
    expect(find.byKey(logViewerLaterKey), findsNothing);
    expect(_inSheet(find.textContaining(' of ')), findsNothing);
    expect(find.byKey(logActionsEditKey), findsNothing);
    expect(find.byKey(logActionsDeleteKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(logViewerBackKey),
        matching: find.text('Back'),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<PhoneSheet>(find.byType(PhoneSheet)).color!.toARGB32(),
      FieldNotesColors.dark.composerPaper.toARGB32(),
    );
    expect(
      tester
          .widget<Text>(_inSheet(find.text(_dayTitle)))
          .style!
          .color!
          .toARGB32(),
      FieldNotesColors.dark.accentInk.toARGB32(),
    );
    semantics.dispose();
  });
}
