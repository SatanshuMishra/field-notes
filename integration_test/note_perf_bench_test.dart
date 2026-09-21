import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/capture/text/editor/editor.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/today/today_layout.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'fixtures/long_note_fixtures.dart';
import 'support/bench_recorder.dart';
import 'support/integration_sandbox.dart';

const int _liveStyledChars = 20000;
const int _plainChars = 60000;
const int _documentWords = 10000;
const double _editorSurfaceHeight = 420;
const double _pageInset = 18;
const Offset _scrollStep = Offset(0, -60);
final DateTime _pinnedNow = DateTime(2026, 9, 20, 9, 30);

class ForcedLiveStyleController extends MarkdownStyleController {
  ForcedLiveStyleController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final TextEditingValue current = value;
    final String text = current.text;
    if (text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final TextStyle base = style ?? TypographyTokens.noteBody;
    final bool composing = withComposing && current.isComposingRangeValid;
    final List<int> codes = markdownStyleCodes(
      text,
      composing: composing ? current.composing : null,
    );
    final Map<int, TextStyle?> styles = <int, TextStyle?>{};
    final List<InlineSpan> children = <InlineSpan>[];
    int runStart = 0;
    for (int i = 1; i <= codes.length; i++) {
      if (i < codes.length && codes[i] == codes[runStart]) {
        continue;
      }
      final int code = codes[runStart];
      children.add(
        TextSpan(
          text: text.substring(runStart, i),
          style: styles.putIfAbsent(code, () => markdownRunStyle(code, base)),
        ),
      );
      runStart = i;
    }
    return TextSpan(style: style, children: children);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1 keystroke cost in a 20k-character live-styled buffer',
      (WidgetTester tester) async {
    _prepare(tester);
    final ForcedLiveStyleController controller =
        ForcedLiveStyleController(text: benchNoteOfChars(_liveStyledChars));
    final int startingChars = controller.text.length;
    await _mountEditor(tester, controller);
    controller.selection =
        TextSelection.collapsed(offset: startingChars ~/ 2);
    await benchFrames(tester);

    await benchMeasure(
      id: 'keystrokeLiveStyled20k',
      what: 'frame cost after one inserted character in a '
          '20 000-character buffer with live Markdown styling forced on',
      extra: <String, Object?>{
        'startingChars': startingChars,
        'liveStyling': 'forced on above MarkdownStyleController.liveStyleLimit',
        'liveStyleLimit': MarkdownStyleController.liveStyleLimit,
        'caret': 'mid-document, unfocused',
      },
      sample: () => _typeOneCharacter(tester, controller),
    );
  });

  testWidgets('2 keystroke cost in a 60k-character buffer, live styling off',
      (WidgetTester tester) async {
    _prepare(tester);
    final MarkdownStyleController controller =
        MarkdownStyleController(text: benchNoteOfChars(_plainChars));
    final int startingChars = controller.text.length;
    await _mountEditor(tester, controller);
    controller.selection =
        TextSelection.collapsed(offset: startingChars ~/ 2);
    await benchFrames(tester);

    await benchMeasure(
      id: 'keystrokePlain60k',
      what: 'frame cost after one inserted character in a '
          '60 000-character buffer past liveStyleLimit, so the shipping '
          'controller returns one plain span',
      extra: <String, Object?>{
        'startingChars': startingChars,
        'liveStyling': 'off, by the shipping liveStyleLimit short circuit',
        'liveStyleLimit': MarkdownStyleController.liveStyleLimit,
        'caret': 'mid-document, unfocused',
      },
      sample: () => _typeOneCharacter(tester, controller),
    );
  });

  testWidgets('3 first-layout cost for one wrapped paragraph',
      (WidgetTester tester) async {
    _prepare(tester);
    final BenchStageState stage = await _mountStage(tester);
    final String paragraph = benchWrappedParagraphSource();
    int variant = 0;

    await benchMeasure(
      id: 'firstLayoutWrappedParagraph',
      what: 'build, layout and paint of a freshly mounted NoteBody holding '
          'one paragraph that wraps at the note measure',
      extra: <String, Object?>{
        'chars': paragraph.length,
        'parserMemo': 'missed, every sample uses a distinct source',
      },
      sample: () => _mountAndTime(
        tester,
        stage,
        NoteBody(text: benchVariant(paragraph, variant++)),
      ),
    );
  });

  testWidgets('4 first-layout cost for a 10 000-word note with eight photos',
      (WidgetTester tester) async {
    _prepare(tester);
    final IntegrationSandbox sandbox =
        await IntegrationSandbox.create('note-perf-doc');
    addTearDown(sandbox.dispose);
    final MediaStore store = FilesystemMediaStore(
      database: sandbox.database,
      root: sandbox.mediaRoot,
    );

    final List<MediaBlob> blobs = await _async(
      tester,
      () => seedBenchPhotos(store: store, count: benchPhotoCount),
    );
    final List<String> references = benchPhotoReferences(blobs);
    final List<File> files = <File>[
      for (final MediaBlob blob in blobs) File(store.absolutePath(blob)),
    ];

    final String document = benchNoteOfWords(
      _documentWords,
      photoReferences: references,
    );
    final BenchStageState stage = await _mountStage(tester);
    int variant = 0;

    await benchMeasure(
      id: 'firstLayoutTenThousandWordDocument',
      what: 'build, layout and paint of a freshly mounted NoteBody holding a '
          '10 000-word note carrying eight photo lines',
      samples: 12,
      warmup: 2,
      extra: <String, Object?>{
        'chars': document.length,
        'photoLines': references.length,
        'photoBlockRenderer': 'NotePhotoStub, the shipping placeholder; no '
            'photo bytes are decoded by this measurement',
        'parserMemo': 'missed, every sample uses a distinct source',
      },
      sample: () => _mountAndTime(
        tester,
        stage,
        SingleChildScrollView(
          child: NoteBody(text: benchVariant(document, variant++)),
        ),
      ),
    );

    useLiveFrames(tester);
    final int cacheWidth = benchQuantisedCacheWidth(
      _noteMeasureOf(tester),
      tester.view.devicePixelRatio,
    );
    await benchMeasure(
      id: 'decodeEightPhotos',
      what: 'cold decode of the same eight photos at the quantised cacheWidth '
          'a note image will request, the cost NotePhotoStub does not yet pay',
      samples: 8,
      warmup: 1,
      extra: <String, Object?>{
        'photos': files.length,
        'sourcePixels': '${benchPhotoWidth}x$benchPhotoHeight',
        'cacheWidth': cacheWidth,
        'bytesEach': blobs.first.bytes,
      },
      sample: () => _decodeAll(tester, files, cacheWidth),
    );
  });

  testWidgets('5 scroll frame over a feed of preview cards',
      (WidgetTester tester) async {
    _prepare(tester);
    final IntegrationSandbox sandbox =
        await IntegrationSandbox.create('note-perf-feed');
    addTearDown(sandbox.dispose);
    final String date = captureDateKey(_pinnedNow);

    await tester.runAsync<void>(() async {
      final ProviderContainer container = sandbox.createContainer();
      await seedBenchFeed(
        repository: container.read(journalRepositoryProvider),
        date: date,
        count: benchFeedEntryCount,
      );
      container.dispose();
    });

    await _mountLive(
      tester,
      ProviderScope(
        overrides: <Override>[
          ...sandbox.overrides,
          todayClockProvider.overrideWithValue(() => _pinnedNow),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: TodayScreen(layout: TodayLayout.stacked),
        ),
      ),
    );
    expect(find.byType(EntryCard), findsWidgets);

    final Finder scrollable = find.byType(Scrollable).first;
    final Offset origin = tester.getCenter(scrollable);
    useBenchmarkFrames(tester);
    final TestGesture gesture = await tester.startGesture(origin);

    await benchMeasure(
      id: 'feedScrollFrame',
      what: 'build, layout and paint of one dragged scroll frame over the '
          'seeded today feed of truncated preview cards',
      samples: 34,
      extra: <String, Object?>{
        'entries': benchFeedEntryCount,
        'stepPt': _scrollStep.dy.abs(),
        'previewCharLimit': notePreviewCharLimit,
      },
      sample: () async {
        await gesture.moveBy(_scrollStep);
        return benchFrame(tester);
      },
    );

    await gesture.up();
    await benchFrames(tester);

    if (benchOnDevice) {
      useLiveFrames(tester);
      await benchBinding(tester).watchPerformance(
        () async {
          await tester.fling(scrollable, const Offset(0, -1200), 3000);
          await tester.pumpAndSettle();
          await tester.fling(scrollable, const Offset(0, 1200), 3000);
          await tester.pumpAndSettle();
        },
        reportKey: benchScrollFrameKey,
      );
      await BenchRecorder.instance.publish();
    }
  });
}

void _prepare(WidgetTester tester) {
  useLiveFrames(tester);
  adoptBenchSurface(tester);
  final double dpr = tester.view.devicePixelRatio;
  final Size logical = tester.view.physicalSize / dpr;
  BenchRecorder.instance.describeSurface(<String, Object?>{
    'logicalWidth': logical.width,
    'logicalHeight': logical.height,
    'devicePixelRatio': dpr,
    'noteMeasurePt': _noteMeasureOf(tester),
    'noteBodyFontSize': TypographyTokens.noteBody.fontSize,
    'liveStyleLimit': MarkdownStyleController.liveStyleLimit,
  });
}

double _noteMeasureOf(WidgetTester tester) {
  final double logicalWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  return math.min(
    logicalWidth - 2 * _pageInset,
    NoteColumn.measureEm * TypographyTokens.noteBody.fontSize!,
  );
}

Future<T> _async<T extends Object>(
  WidgetTester tester,
  Future<T> Function() body,
) async {
  final T? result = await tester.runAsync<T>(body);
  if (result == null) {
    throw StateError('bench setup failed; the reported error is above');
  }
  return result;
}

Future<void> _mountLive(WidgetTester tester, Widget app) async {
  useLiveFrames(tester);
  await tester.pumpWidget(app);
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _mountEditor(
  WidgetTester tester,
  MarkdownStyleController controller,
) async {
  final FocusNode focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  final UndoHistoryController undoController = UndoHistoryController();
  addTearDown(controller.dispose);
  addTearDown(focusNode.dispose);
  addTearDown(scrollController.dispose);
  addTearDown(undoController.dispose);

  await _mountLive(
    tester,
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: Palette.composerPaper,
        child: Padding(
          padding: const EdgeInsets.all(_pageInset),
          child: SizedBox(
            height: _editorSurfaceHeight,
            child: NoteColumn(
              child: noteEditorFor(
                NoteEditorConfig(
                  controller: controller,
                  focusNode: focusNode,
                  undoController: undoController,
                  scrollController: scrollController,
                  hintText: 'Start writing…',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  useBenchmarkFrames(tester);
}

Future<BenchStageState> _mountStage(WidgetTester tester) async {
  await _mountLive(
    tester,
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: Palette.page,
        child: BenchStage(key: benchStageKey),
      ),
    ),
  );
  useBenchmarkFrames(tester);
  final BenchStageState? stage = benchStageKey.currentState;
  if (stage == null) {
    throw StateError('bench stage did not mount');
  }
  return stage;
}

Future<Duration> _typeOneCharacter(
  WidgetTester tester,
  TextEditingController controller,
) {
  final int offset = controller.selection.baseOffset;
  final String text = controller.text;
  controller.value = TextEditingValue(
    text: text.replaceRange(offset, offset, 'e'),
    selection: TextSelection.collapsed(offset: offset + 1),
  );
  return benchFrame(tester);
}

Future<Duration> _mountAndTime(
  WidgetTester tester,
  BenchStageState stage,
  Widget content,
) async {
  stage.clear();
  await benchFrame(tester);
  stage.show(KeyedSubtree(key: UniqueKey(), child: content));
  return benchFrame(tester);
}

Future<Duration> _decodeAll(
  WidgetTester tester,
  List<File> files,
  int cacheWidth,
) {
  return _async(tester, () async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    final Stopwatch watch = Stopwatch()..start();
    await Future.wait<void>(
      files.map((File file) => _decodeOne(file, cacheWidth)),
    );
    watch.stop();
    return watch.elapsed;
  });
}

Future<void> _decodeOne(File file, int cacheWidth) {
  final Completer<void> done = Completer<void>();
  final ImageStream stream =
      ResizeImage(FileImage(file), width: cacheWidth).resolve(
    ImageConfiguration.empty,
  );
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool synchronous) {
      info.dispose();
      stream.removeListener(listener);
      if (!done.isCompleted) {
        done.complete();
      }
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      if (!done.isCompleted) {
        done.completeError(error, stackTrace);
      }
    },
  );
  stream.addListener(listener);
  return done.future;
}
