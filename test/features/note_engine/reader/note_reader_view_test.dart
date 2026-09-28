import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/note_column.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../notes/support/notes_harness.dart';

const String _photoNote =
    'First.\n\n![Low tide](photo/a1b2c3d4e5f6 "left medium")\n\nLast.';

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpReader(
  WidgetTester tester,
  Widget child, {
  MediaResolver? resolver,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: NoteMediaScope(
          resolver: resolver ?? (FakeNoteMediaResolver()..memoizeAll()),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _bodyFinder => find.descendant(
  of: find.byType(NoteReaderView),
  matching: find.byType(NoteViewBody),
);

Rect _body(WidgetTester tester) => tester.getRect(_bodyFinder);

RenderNoteView _render(WidgetTester tester) =>
    tester.renderObject<RenderNoteView>(_bodyFinder);

Offset _globalAt(WidgetTester tester, int sourceOffset) {
  final RenderNoteView render = _render(tester);
  final Rect caret = render.noteLayout.caretRect(
    sourceOffset,
    TextAffinity.downstream,
  );
  return render.contentToGlobal(caret.center);
}

List<String> _captureClipboard(WidgetTester tester) {
  final List<String> copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        final Map<Object?, Object?> arguments =
            call.arguments as Map<Object?, Object?>;
        copied.add(arguments['text']! as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

Future<void> _heldPress(
  WidgetTester tester,
  Offset position, {
  PointerDeviceKind kind = PointerDeviceKind.mouse,
  Duration hold = const Duration(milliseconds: 110),
}) async {
  final TestGesture gesture = await tester.startGesture(position, kind: kind);
  await tester.pump(hold);
  await gesture.up();
  await tester.pump();
}

Future<void> _metaChord(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

Future<void> _doubleClick(WidgetTester tester, Offset position) async {
  await _heldPress(tester, position, hold: const Duration(milliseconds: 40));
  await tester.pump(const Duration(milliseconds: 40));
  await _heldPress(tester, position, hold: const Duration(milliseconds: 40));
}

void main() {
  testWidgets(
    'the reader draws with no active line and no caret',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final List<String> copied = _captureClipboard(tester);
      await _pumpReader(
        tester,
        const NoteReaderView(source: '# Harbour day\nThe **fog** lifted'),
      );
      final Rect body = _body(tester);
      await _heldPress(tester, body.topLeft + const Offset(20, 10));

      expect(tester.testTextInput.hasAnyClients, isFalse);
      final RenderNoteView render = _render(tester);
      expect(render.activeLine, isNull);
      expect(render.caretRect, isNull);

      await _metaChord(tester, LogicalKeyboardKey.keyA);
      await _metaChord(tester, LogicalKeyboardKey.keyC);
      expect(copied, <String>['Harbour day\nThe fog lifted']);
      expect(tester.testTextInput.hasAnyClients, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'the note viewer copies formatting free text',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final List<String> copied = _captureClipboard(tester);
      await _pumpReader(
        tester,
        const NoteReaderView(
          source: 'First **paragraph**.\n\nSecond paragraph.',
        ),
      );
      final Rect body = _body(tester);
      final TestGesture gesture = await tester.startGesture(
        Offset(body.left + 1, body.top + 12.8),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 110));
      await gesture.moveTo(Offset(body.right - 1, body.top + 64));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      await _metaChord(tester, LogicalKeyboardKey.keyC);
      expect(copied, <String>['First paragraph.\n\nSecond paragraph.']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('card bodies are not interactive', (WidgetTester tester) async {
    _pinSurface(tester);
    int taps = 0;
    await _pumpReader(
      tester,
      GestureDetector(
        onTap: () => taps++,
        child: const NoteReaderView(
          source: 'First paragraph.',
          selectable: false,
        ),
      ),
    );
    final FocusNode? focusBefore = FocusManager.instance.primaryFocus;
    final Offset onText = _body(tester).topLeft + const Offset(20, 12.8);
    await _heldPress(tester, onText);
    expect(taps, 1);

    await _heldPress(
      tester,
      onText,
      kind: PointerDeviceKind.touch,
      hold: const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    expect(FocusManager.instance.primaryFocus, focusBefore);
    expect(tester.testTextInput.hasAnyClients, isFalse);

    int cardTaps = 0;
    await _pumpReader(
      tester,
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => cardTaps++,
        child: const IgnorePointer(
          child: NoteReaderView(source: 'First paragraph.', selectable: false),
        ),
      ),
    );
    final FocusNode? cardFocusBefore = FocusManager.instance.primaryFocus;
    final Offset cardText = _body(tester).topLeft + const Offset(20, 12.8);
    await _heldPress(tester, cardText);
    expect(cardTaps, 1);
    await _heldPress(
      tester,
      cardText,
      kind: PointerDeviceKind.touch,
      hold: const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    expect(FocusManager.instance.primaryFocus, cardFocusBefore);
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  group('selection and copy', () {
    testWidgets(
      'a double click then copy gives the word',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final List<String> copied = _captureClipboard(tester);
        const String source = 'First **paragraph**.\n\nSecond paragraph.';
        await _pumpReader(tester, const NoteReaderView(source: source));
        await _doubleClick(tester, _globalAt(tester, source.indexOf('agr')));
        await _metaChord(tester, LogicalKeyboardKey.keyC);
        expect(copied, <String>['paragraph']);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'a triple click selects the source line without its break',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final List<String> copied = _captureClipboard(tester);
        const String source = 'First **paragraph**.\nSecond paragraph.';
        await _pumpReader(tester, const NoteReaderView(source: source));
        final Offset at = _globalAt(tester, source.indexOf('agr'));
        await _doubleClick(tester, at);
        await tester.pump(const Duration(milliseconds: 40));
        await _heldPress(tester, at, hold: const Duration(milliseconds: 40));
        await _metaChord(tester, LogicalKeyboardKey.keyC);
        expect(copied, <String>['First paragraph.']);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'a shift click extends the selection',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final List<String> copied = _captureClipboard(tester);
        const String source = 'Harbour fog lifted';
        await _pumpReader(tester, const NoteReaderView(source: source));
        await _heldPress(tester, _globalAt(tester, 0));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await _heldPress(tester, _globalAt(tester, source.indexOf(' lifted')));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await _metaChord(tester, LogicalKeyboardKey.keyC);
        expect(copied.single, startsWith('Harbour f'));
        expect(copied.single, isNot(contains('lifted')));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'select all then copy gives the whole visible text',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final List<String> copied = _captureClipboard(tester);
        await _pumpReader(
          tester,
          const NoteReaderView(
            source: '## Tides\n\n1. *Low* water\n2. ~~High~~ water',
          ),
        );
        await _heldPress(tester, _body(tester).topLeft + const Offset(20, 10));
        await _metaChord(tester, LogicalKeyboardKey.keyA);
        await _metaChord(tester, LogicalKeyboardKey.keyC);
        expect(copied, <String>['Tides\n\n1. Low water\n2. High water']);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'list glyphs are kept in the copy',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final List<String> copied = _captureClipboard(tester);
        await _pumpReader(tester, const NoteReaderView(source: '- a\n- b'));
        await _heldPress(tester, _body(tester).topLeft + const Offset(40, 10));
        await _metaChord(tester, LogicalKeyboardKey.keyA);
        await _metaChord(tester, LogicalKeyboardKey.keyC);
        expect(copied, <String>['• a\n• b']);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'a photo copies as an empty line with no placeholder',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final List<String> copied = _captureClipboard(tester);
        await _pumpReader(
          tester,
          const NoteReaderView(source: _photoNote),
          resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
            'a1b2c3d4e5f6': availablePhoto(photoIdA),
          })..memoizeAll(),
        );
        await _heldPress(tester, _globalAt(tester, 2));
        await _metaChord(tester, LogicalKeyboardKey.keyA);
        await _metaChord(tester, LogicalKeyboardKey.keyC);
        expect(copied, <String>['First.\n\n\n\nLast.']);
        expect(copied.single, isNot(contains('￼')));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'a tap outside clears the selection',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final List<String> copied = _captureClipboard(tester);
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: NoteMediaScope(
                resolver: FakeNoteMediaResolver()..memoizeAll(),
                child: const Column(
                  children: <Widget>[
                    NoteReaderView(source: 'Harbour fog'),
                    SizedBox(height: 400),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await _heldPress(tester, _body(tester).topLeft + const Offset(20, 10));
        await _metaChord(tester, LogicalKeyboardKey.keyA);
        expect(_render(tester).selection, isNotNull);
        await _heldPress(
          tester,
          _body(tester).bottomLeft + const Offset(20, 200),
        );
        expect(_render(tester).selection, isNull);
        await _metaChord(tester, LogicalKeyboardKey.keyC);
        expect(copied, isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'a press on a checkbox changes nothing',
      (WidgetTester tester) async {
        _pinSurface(tester);
        const String source = '- [ ] pack\n- [x] tide chart';
        await _pumpReader(tester, const NoteReaderView(source: source));
        final RenderNoteView render = _render(tester);
        final String visibleBefore = render.visibleText.text;
        await _heldPress(tester, _globalAt(tester, 3));
        expect(render.source, source);
        expect(render.visibleText.text, visibleBefore);
        expect(render.visibleText.text, startsWith('☐ pack'));
        expect(render.activeLine, isNull);
        expect(tester.testTextInput.hasAnyClients, isFalse);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'a long press selects a word and offers only copy and select all',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final List<String> copied = _captureClipboard(tester);
        const String source = 'Tidepools everywhere';
        await _pumpReader(tester, const NoteReaderView(source: source));
        await _heldPress(
          tester,
          _globalAt(tester, 3),
          kind: PointerDeviceKind.touch,
          hold: const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Select all'), findsOneWidget);
        expect(find.text('Cut'), findsNothing);
        expect(find.text('Paste'), findsNothing);
        expect(tester.testTextInput.hasAnyClients, isFalse);

        await _heldPress(
          tester,
          tester.getCenter(find.text('Copy')),
          kind: PointerDeviceKind.touch,
          hold: const Duration(milliseconds: 60),
        );
        await tester.pumpAndSettle();
        expect(copied, <String>['Tidepools']);
        expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'a second long press on the selected word opens the menu at once',
      (WidgetTester tester) async {
        _pinSurface(tester);
        _captureClipboard(tester);
        const String source = 'Tidepools everywhere';
        await _pumpReader(tester, const NoteReaderView(source: source));
        final Offset word = _globalAt(tester, 3);
        await _heldPress(
          tester,
          word,
          kind: PointerDeviceKind.touch,
          hold: const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        await _heldPress(
          tester,
          tester.getCenter(find.text('Copy')),
          kind: PointerDeviceKind.touch,
          hold: const Duration(milliseconds: 60),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);

        final TestGesture press = await tester.startGesture(
          word,
          kind: PointerDeviceKind.touch,
        );
        await tester.binding.delayed(const Duration(milliseconds: 600));
        await press.up();

        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pump();
        expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('column', () {
    testWidgets('fills the available width inside a filling measure scope', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await _pumpReader(
        tester,
        const NoteMeasureScope(
          fillsWidth: true,
          child: NoteReaderView(source: 'First paragraph.'),
        ),
      );
      expect(_body(tester).width, 1200);
    });

    testWidgets('caps the column at 45 em and centres it in its own box', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await _pumpReader(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: NoteReaderView(source: 'First paragraph.'),
        ),
      );
      expect(tester.getSize(find.byType(NoteReaderView)).width, 1200);
      final Rect body = _body(tester);
      expect(body.width, 720);
      expect(body.left, 240);
      expect(tester.getSize(find.byType(NoteReaderView)).height, body.height);

      await _pumpReader(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            child: NoteReaderView(source: 'First paragraph.'),
          ),
        ),
      );
      expect(_body(tester).width, 500);
    });

    testWidgets('a blank source lays out as empty lines', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await _pumpReader(tester, const NoteReaderView(source: '\n'));
      expect(_body(tester).height, closeTo(51.2, 0.01));
      expect(tester.takeException(), isNull);
    });
  });

  group('semantics', () {
    testWidgets('headings are marked and no text field is exposed', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpReader(
        tester,
        const NoteReaderView(source: '# Harbour day\nThe fog lifted.'),
      );
      expect(find.semantics.byLabel('Harbour day'), findsOne);
      expect(
        find.semantics.byLabel('Harbour day').evaluate().single,
        isSemantics(isHeader: true),
      );
      expect(find.semantics.byLabel('The fog lifted.'), findsOne);
      expect(find.semantics.byFlag(SemanticsFlag.isTextField), findsNothing);
      handle.dispose();
    });

    testWidgets('photos are met once each in source order', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpReader(
        tester,
        const NoteReaderView(source: _photoNote),
        resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
          'a1b2c3d4e5f6': availablePhoto(photoIdA),
        })..memoizeAll(),
      );
      const List<String> expected = <String>[
        'First.',
        'Photo, Low tide',
        'Last.',
      ];
      final List<String> met = <String>[
        for (final SemanticsNode node
            in tester.semantics.simulatedAccessibilityTraversal())
          if (expected.contains(node.label)) node.label,
      ];
      expect(met, expected);
      for (final String label in expected) {
        expect(find.semantics.byLabel(label), findsOne);
      }
      expect(find.semantics.byFlag(SemanticsFlag.isTextField), findsNothing);
      handle.dispose();
    });
  });

  group('bare harness', () {
    Widget bare(Widget child) => MediaQuery(
      data: const MediaQueryData(size: Size(1200, 2000)),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

    testWidgets('an inert reader builds with only directionality and media', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await tester.pumpWidget(
        bare(
          const NoteReaderView(source: '# Harbour day\n- a', selectable: false),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_bodyFinder, findsOneWidget);
    });

    testWidgets('a selectable reader builds and takes a press bare', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await tester.pumpWidget(
        bare(const NoteReaderView(source: 'The fog lifted.')),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _heldPress(tester, _body(tester).topLeft + const Offset(20, 10));
      expect(tester.takeException(), isNull);
      expect(_render(tester).caretRect, isNull);
    });
  });
}
