import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show
        LogActionsPill,
        MediaResolver,
        ResolvedMedia,
        logActionsDeleteKey,
        logActionsEditKey;
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerExit;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerBackKey, logViewerEarlierKey, logViewerLaterKey;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/note_panel_view.dart';
import 'package:field_notes/features/log_viewer/note_reading.dart';
import 'package:field_notes/features/log_viewer/photo_viewer.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart'
    show PhotoRect;
import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

import '../../support/note_generators.dart' show noteGeneratorSeed;
import '../../support/photo_line_fixture.dart';
import '../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, prefixOf;

const Size _wide = Size(1440, 900);
const Size _narrow = Size(1280, 800);
const double _panelShare = 0.62;
const double _readingChars = 68;
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

void _useMac(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
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
  required String text,
  int index = 0,
  int count = 1,
  Entry? earlier,
  Entry? later,
}) {
  return LogViewerScene(
    entry: _entry(id: 'morning', hour: 8, text: text),
    date: _date,
    dayTitle: _dayTitle,
    mood: null,
    index: index,
    count: count,
    earlier: earlier,
    later: later,
    exit: LogViewerExit.close,
    onBack: () => calls.add('back'),
    onEarlier: earlier == null ? null : () => calls.add('earlier'),
    onLater: later == null ? null : () => calls.add('later'),
    onDelete: () => calls.add('delete'),
    onEdit: () => calls.add('edit'),
  );
}

LogViewerScene _sceneAmongFour(List<String> calls, String text) => _scene(
  calls,
  text: text,
  index: 1,
  count: 4,
  earlier: _entry(id: 'dawn', hour: 6, type: EntryType.voice),
  later: _entry(id: 'afternoon', hour: 14, text: 'Tea under the elm.'),
);

Future<void> _openPanel(
  WidgetTester tester,
  LogViewerScene scene, {
  required String name,
  MediaResolver? resolver,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<String>(name),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showGeneralDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  barrierLabel: 'Dismiss log viewer',
                  barrierColor: Colors.transparent,
                  pageBuilder:
                      (
                        BuildContext dialogContext,
                        Animation<double> animation,
                        Animation<double> secondaryAnimation,
                      ) {
                        return DialogHost(
                          child: NotePanelView(
                            scene: scene,
                            resolver: resolver ?? FakeNoteMediaResolver(),
                          ),
                        );
                      },
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

class _TallEditor extends StatefulWidget {
  const _TallEditor();

  @override
  State<_TallEditor> createState() => _TallEditorState();
}

class _TallEditorState extends State<_TallEditor> {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 600);
}

Future<void> _openSwitchingPanel(
  WidgetTester tester,
  LogViewerScene scene,
  ValueNotifier<Widget?> editor,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showGeneralDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  barrierLabel: 'Dismiss log viewer',
                  barrierColor: Colors.transparent,
                  pageBuilder:
                      (
                        BuildContext dialogContext,
                        Animation<double> animation,
                        Animation<double> secondaryAnimation,
                      ) {
                        return DialogHost(
                          child: ValueListenableBuilder<Widget?>(
                            valueListenable: editor,
                            builder:
                                (
                                  BuildContext context,
                                  Widget? shown,
                                  Widget? child,
                                ) {
                                  return NotePanelView(
                                    scene: scene,
                                    resolver: FakeNoteMediaResolver(),
                                    editor: shown,
                                  );
                                },
                          ),
                        );
                      },
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

Rect _panel(WidgetTester tester) =>
    tester.getRect(find.byKey(composerPanelKey));

double _charactersWide(WidgetTester tester, double count) {
  final BuildContext context = tester.element(find.byType(NoteReadingBody));
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: '0' * count.toInt(),
      style: context.textStyles.noteBody,
    ),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

void _expectReadingColumn(WidgetTester tester) {
  final Rect panel = _panel(tester);
  final Rect column = tester.getRect(find.byType(NoteReadingBody));
  expect(
    column.width,
    lessThanOrEqualTo(_charactersWide(tester, _readingChars)),
  );
  expect(column.center.dx, moreOrLessEquals(panel.center.dx));
  final Rect reader = tester.getRect(find.byType(NoteReaderView));
  expect(reader.width, lessThanOrEqualTo(column.width));
}

RenderNoteView _reader(WidgetTester tester) =>
    tester.renderObject<RenderNoteView>(
      find.descendant(
        of: find.byType(NoteReaderView),
        matching: find.byType(NoteViewBody),
      ),
    );

void main() {
  testWidgets(
    'the Mac note panel sizes to the note and reads at 68 characters',
    (WidgetTester tester) async {
      expect(notePanelWidthFor(800), 640);
      expect(notePanelWidthFor(2000), 1000);
      expect(notePanelWidthFor(1440), moreOrLessEquals(1440 * _panelShare));
      final String longNote = _longNote();
      expect(longNote.split(RegExp(r'\s+')), hasLength(_longNoteWords));
      final List<String> calls = <String>[];

      _useMac(tester, _wide);
      await _openPanel(
        tester,
        _sceneAmongFour(calls, _shortNote),
        name: 'short',
      );

      Rect panel = _panel(tester);
      expect(panel.width, moreOrLessEquals(_wide.width * _panelShare));
      expect(panel.width.round(), 893);
      expect(panel.center, const Offset(720, 450));
      expect(panel.height, lessThan(400));
      _expectReadingColumn(tester);
      expect(find.text('Close'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(logViewerBackKey)).top,
        lessThan(panel.top + 80),
      );
      expect(find.text(_dayTitle), findsOneWidget);
      expect(find.text('Morning note'), findsOneWidget);
      expect(find.byType(LogActionsPill), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LogActionsPill),
          matching: find.byKey(logActionsEditKey),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(LogActionsPill),
          matching: find.byKey(logActionsDeleteKey),
        ),
        findsOneWidget,
      );
      expect(find.text('2 of 4'), findsOneWidget);
      for (final Key key in <Key>[logViewerEarlierKey, logViewerLaterKey]) {
        expect(
          tester.getSize(find.byKey(key)).height,
          greaterThanOrEqualTo(48),
        );
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(calls, <String>['earlier', 'later', 'back']);

      await _openPanel(tester, _sceneAmongFour(calls, longNote), name: 'long');

      panel = _panel(tester);
      expect(panel.width, moreOrLessEquals(_wide.width * _panelShare));
      expect(panel.height, _wide.height - 2 * composerPanelMargin);
      expect(panel.height, 900 - 56);
      _expectReadingColumn(tester);
      final ScrollableState body = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(composerPanelKey),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(body.position.maxScrollExtent, greaterThan(0));
      expect(
        tester.getRect(find.text('2 of 4')).bottom,
        lessThanOrEqualTo(panel.bottom),
      );

      _useMac(tester, _narrow);
      await _openPanel(
        tester,
        _sceneAmongFour(calls, _shortNote),
        name: 'narrow',
      );

      panel = _panel(tester);
      expect(panel.width, moreOrLessEquals(_narrow.width * _panelShare));
      expect(panel.width.round(), 794);
      expect(panel.height, lessThan(400));
      _expectReadingColumn(tester);
      expect(calls, <String>['earlier', 'later', 'back']);
    },
  );

  testWidgets('Esc closes the photo, then the note', (
    WidgetTester tester,
  ) async {
    _useMac(tester, _wide);
    final List<String> calls = <String>[];
    final String note = <String>[
      'Low tide walk',
      mdPhotoLine(photoIdA, caption: 'The harbour wall'),
      'Home before the rain.',
    ].join('\n\n');
    final MediaResolver resolver = FakeNoteMediaResolver(
      <String, ResolvedMedia>{
        prefixOf(photoIdA): availablePhoto(photoIdA, width: 1600, height: 600),
      },
    )..memoizeAll();
    await _openPanel(
      tester,
      _scene(calls, text: note),
      name: 'photo',
      resolver: resolver,
    );
    await tester.pump();

    final RenderNoteView render = _reader(tester);
    final Rect image = render.noteLayout.photoRects
        .singleWhere((PhotoRect photo) => photo.reference == prefixOf(photoIdA))
        .imageRect;
    final Rect onScreen = render.contentToGlobal(image.topLeft) & image.size;
    expect((Offset.zero & _wide).contains(onScreen.center), isTrue);

    await tester.tapAt(onScreen.center);
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsOneWidget);
    final PhotoViewer viewer = tester.widget<PhotoViewer>(
      find.byType(PhotoViewer),
    );
    expect(viewer.initialIndex, 0);
    expect(viewer.dayTitle, _dayTitle);
    expect(viewer.photos.single.caption, 'The harbour wall');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsNothing);
    expect(find.byType(NotePanelView), findsOneWidget);
    expect(calls, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(calls, <String>['back']);
  });

  testWidgets('with reduce motion the note panel resizes without animating', (
    WidgetTester tester,
  ) async {
    _useMac(tester, _wide);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final ValueNotifier<Widget?> editor = ValueNotifier<Widget?>(null);
    addTearDown(editor.dispose);
    await _openSwitchingPanel(
      tester,
      _scene(<String>[], text: _shortNote),
      editor,
    );
    final double reading = _panel(tester).height;

    editor.value = const _TallEditor();
    await tester.pump();
    final double shown = _panel(tester).height;
    await tester.pumpAndSettle();

    expect(_panel(tester).height, greaterThan(reading + 100));
    expect(shown, _panel(tester).height);

    final State<_TallEditor> editing = tester.state(find.byType(_TallEditor));
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(_TallEditor)), same(editing));
  });
}
