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
import 'package:field_notes/features/notes/notes.dart';
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
const int _raisedStyleLimit = 1 << 30;
const Duration _imageWarmLimit = Duration(seconds: 30);
const double _canonicalMeasure = 560;
final DateTime _pinnedNow = DateTime(2026, 9, 20, 9, 30);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1 keystroke cost in a 20k-character live-styled buffer',
      (WidgetTester tester) async {
    _prepare(tester);
    final MarkdownStyleController controller = MarkdownStyleController(
      text: benchNoteOfChars(_liveStyledChars),
      styleLimit: _raisedStyleLimit,
    );
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
        'liveStyling': 'on, the shipping MarkdownStyleController with its '
            'styleLimit raised above the buffer',
        'styleLimit': _raisedStyleLimit,
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
    final IntegrationSandbox sandbox =
        await IntegrationSandbox.create('note-perf-wrap');
    addTearDown(sandbox.dispose);
    final MediaStore store = FilesystemMediaStore(
      database: sandbox.database,
      root: sandbox.mediaRoot,
    );

    final List<MediaBlob> blobs = await _async(
      tester,
      () => seedBenchPhotos(store: store, count: 1),
    );
    final String reference = benchPhotoReferences(blobs).single;
    final MediaResolver resolver =
        await _warmResolver(tester, store, <String>[reference]);
    final String photoLine = photoLineFor(reference: reference);
    final String paragraph = benchWrappedParagraphSource();
    final BenchStageState stage = await _mountStage(tester);
    Widget pinnedNote(String text) => NoteMediaScope(
          resolver: resolver,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: _canonicalMeasure,
              maxWidth: _canonicalMeasure,
              child: NoteBody(text: text),
            ),
          ),
        );
    await _warmImages(tester, stage, pinnedNote('$photoLine\n$paragraph'), 1);
    int variant = 0;

    await benchMeasure(
      id: 'firstLayoutWrappedParagraph',
      what: 'build, layout and paint of a freshly mounted NoteBody at the '
          '560 pt canonical measure holding one photo line and one paragraph, '
          'which PhotoWrapBlock splits around the floated photo',
      extra: <String, Object?>{
        'chars': '$photoLine\n$paragraph'.length,
        'paragraphChars': paragraph.length,
        'measurePt': _canonicalMeasure,
        'placement': const PhotoPlacement().format(),
        'photoPixels': '${benchPhotoWidth}x$benchPhotoHeight',
        'photoBlockRenderer': 'PhotoWrapBlock through a warm '
            'MediaStoreResolver, the float asserted after the first sample; '
            'the decoded photo comes from an ImageCache warmed before timing, '
            'so decode is not in the number',
        'parserMemo': 'missed, every sample uses a distinct source',
      },
      sample: () async {
        final int index = variant++;
        final Duration elapsed = await _mountAndTime(
          tester,
          stage,
          pinnedNote('$photoLine\n${benchVariant(paragraph, index)}'),
        );
        if (index == 0) {
          expect(find.byKey(photoWrapFloatKey), findsOneWidget);
          expect(_decodedImages(tester), 1);
        }
        return elapsed;
      },
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
    final MediaResolver resolver =
        await _warmResolver(tester, store, references);
    final List<File> files = <File>[
      for (final MediaBlob blob in blobs) File(store.absolutePath(blob)),
    ];

    final String document = benchNoteOfWords(
      _documentWords,
      photoReferences: references,
    );
    final BenchStageState stage = await _mountStage(tester);
    Widget scrollingNote(String text) => SingleChildScrollView(
          child: NoteMediaScope(
            resolver: resolver,
            child: NoteBody(text: text),
          ),
        );
    await _warmImages(
      tester,
      stage,
      scrollingNote(document),
      references.length,
    );
    int variant = 0;

    await benchMeasure(
      id: 'firstLayoutTenThousandWordDocument',
      what: 'build, layout and paint of a freshly mounted NoteBody holding a '
          '10 000-word note carrying eight photo lines, rendered as photos '
          'through a warm media resolver',
      samples: 12,
      warmup: 2,
      extra: <String, Object?>{
        'chars': document.length,
        'photoLines': references.length,
        'photoBlockRenderer': 'StackedPhoto or PhotoWrapBlock through a warm '
            'MediaStoreResolver; every decoded photo comes from an ImageCache '
            'warmed before timing, so decode is not in the number',
        'parserMemo': 'missed, every sample uses a distinct source',
      },
      sample: () async {
        final int index = variant++;
        final Duration elapsed = await _mountAndTime(
          tester,
          stage,
          scrollingNote(benchVariant(document, index)),
        );
        if (index == 0) {
          expect(_decodedImages(tester), references.length);
        }
        return elapsed;
      },
    );

    useLiveFrames(tester);
    final int cacheWidth = benchQuantisedCacheWidth(
      _noteMeasureOf(tester),
      tester.view.devicePixelRatio,
    );
    await benchMeasure(
      id: 'decodeEightPhotos',
      what: 'cold decode of the same eight photos at one quantised cacheWidth '
          'taken from the editor measure, an approximation of the per-photo '
          'widths number 4 requests; number 4 paints from a warm ImageCache',
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

Future<MediaResolver> _warmResolver(
  WidgetTester tester,
  MediaStore store,
  List<String> references,
) async {
  final MediaStoreResolver resolver = MediaStoreResolver(store);
  final List<ResolvedMedia> resolved = await _async(
    tester,
    () => Future.wait<ResolvedMedia>(references.map(resolver.resolve)),
  );
  expect(
    resolved.where((ResolvedMedia media) => media.isAvailable),
    hasLength(references.length),
  );
  return resolver;
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

Future<void> _warmImages(
  WidgetTester tester,
  BenchStageState stage,
  Widget content,
  int images,
) async {
  stage.show(KeyedSubtree(key: UniqueKey(), child: content));
  await benchFrame(tester);
  final Stopwatch watch = Stopwatch()..start();
  while (_decodedImages(tester) < images) {
    if (watch.elapsed > _imageWarmLimit) {
      throw StateError('bench photos did not decode within $_imageWarmLimit');
    }
    await tester.runAsync<void>(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await benchFrame(tester);
  }
  stage.clear();
  await benchFrame(tester);
}

int _decodedImages(WidgetTester tester) => tester
    .widgetList<RawImage>(find.byType(RawImage))
    .where((RawImage image) => image.image != null)
    .length;

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
