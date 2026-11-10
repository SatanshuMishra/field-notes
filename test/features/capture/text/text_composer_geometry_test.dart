import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/notes/photos/photo_import.dart';

import '../../../support/note_editor_driver.dart';

const Size _desktopSurface = Size(1280, 900);
const Size _landscapePhoneSurface = Size(844, 390);
const Size _portraitPhoneSurface = Size(360, 640);

double get _lineHeight =>
    TypographyTokens.noteBody.fontSize! * TypographyTokens.noteBody.height!;

Future<List<String>> _noPhotos() async => const <String>[];

double _runWidth(String text, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

Rect _viewport(WidgetTester tester) => tester.getRect(
  find
      .descendant(
        of: find.byType(RawScrollbar),
        matching: find.byType(Scrollable),
      )
      .first,
);

ScrollableState _editorScroll(WidgetTester tester) => tester.state(
  find
      .descendant(
        of: find.byType(RawScrollbar),
        matching: find.byType(Scrollable),
      )
      .first,
);

String get _longNote =>
    List<String>.filled(80, 'a long line of note').join('\n');

Future<void> _pumpComposer(
  WidgetTester tester, {
  required Size surface,
  double keyboardInset = 0,
  String initialText = '',
  PhotoImporter? onAddPhoto,
  TargetPlatform platform = TargetPlatform.macOS,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(platform: platform),
      home: DialogHost(
        child: ComposerShell(
          responsive: true,
          child: TextComposerSheet(
            onSave: (String _) {},
            onCancel: () {},
            initialText: initialText,
            onAddPhoto: onAddPhoto,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('TextComposerSheet geometry', () {
    for (final double window in <double>[900, 1280, 1920]) {
      testWidgets('the page is a centred 720 column in a $window window', (
        WidgetTester tester,
      ) async {
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await _pumpComposer(tester, surface: Size(window, 900));

        expect(tester.takeException(), isNull);
        final Rect surface = tester.getRect(
          find.byKey(composerWritingSurfaceKey),
        );
        expect(surface.width, 720);
        expect(surface.center.dx, window / 2);
        expect(driver.contentRect.width, 688);
        expect(
          find.descendant(
            of: find.byType(TextComposerSheet),
            matching: find.byType(NoteColumn),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('the title sits above the page, centred, at most 560 wide', (
      WidgetTester tester,
    ) async {
      await _pumpComposer(tester, surface: _desktopSurface);

      final Rect title = tester.getRect(find.byKey(composerTitleFieldKey));
      expect(title.width, 560);
      expect(title.height, 44);
      expect(title.center.dx, 640);
      expect(
        title.bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(composerWritingSurfaceKey)).top,
        ),
      );
    });

    testWidgets('the editor writes in the note body style the reader reads', (
      WidgetTester tester,
    ) async {
      const String sample = 'a quiet morning';
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _pumpComposer(tester, surface: _desktopSurface);

      expect(
        driver.paintedHint?.longestLine,
        closeTo(
          _runWidth('Start writing…', TypographyTokens.noteBodyPlaceholder),
          0.01,
        ),
      );

      await driver.enterText(sample);
      final Size line = driver.firstLineSize;
      expect(
        line.width,
        closeTo(_runWidth(sample, TypographyTokens.noteBody), 0.01),
      );
      expect(line.height, closeTo(_lineHeight, 0.01));
    });

    testWidgets(
      'a landscape phone with the keyboard up keeps a usable editor',
      (WidgetTester tester) async {
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await _pumpComposer(
          tester,
          surface: _landscapePhoneSurface,
          keyboardInset: 200,
          platform: TargetPlatform.android,
        );

        expect(tester.takeException(), isNull);
        final Size editor = driver.contentRect.size;
        expect(editor.height, greaterThanOrEqualTo(3 * _lineHeight));
        expect(editor.width, greaterThanOrEqualTo(560));
      },
    );

    testWidgets('a portrait phone with the keyboard up is not a porthole', (
      WidgetTester tester,
    ) async {
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _pumpComposer(
        tester,
        surface: _portraitPhoneSurface,
        keyboardInset: 300,
        platform: TargetPlatform.android,
      );

      expect(tester.takeException(), isNull);
      final Size editor = driver.contentRect.size;
      expect(editor.height, greaterThanOrEqualTo(3 * _lineHeight));
      expect(editor.width, 360 - 2 * 24 - 2 * 8);
    });

    testWidgets('the room lays out cleanly from a small phone up', (
      WidgetTester tester,
    ) async {
      for (final Size surface in <Size>[
        const Size(320, 568),
        const Size(360, 640),
        const Size(411, 869),
        const Size(844, 200),
        const Size(600, 500),
      ]) {
        await _pumpComposer(
          tester,
          surface: surface,
          platform: TargetPlatform.android,
          onAddPhoto: _noPhotos,
        );
        expect(tester.takeException(), isNull, reason: '$surface');
      }
    });

    testWidgets('the writing surface takes the height the window gives it', (
      WidgetTester tester,
    ) async {
      double? previous;
      for (final double window in <double>[800, 1200, 1600]) {
        await _pumpComposer(
          tester,
          surface: Size(1280, window),
          onAddPhoto: _noPhotos,
        );

        expect(tester.takeException(), isNull);
        final double height = tester
            .getSize(find.byKey(composerWritingSurfaceKey))
            .height;
        if (previous != null) {
          expect(height, closeTo(previous + 400, 0.5));
        }
        previous = height;
      }
    });

    testWidgets('the footer ends the room under the writing surface', (
      WidgetTester tester,
    ) async {
      await _pumpComposer(
        tester,
        surface: _desktopSurface,
        initialText: _longNote,
        onAddPhoto: _noPhotos,
      );

      expect(tester.takeException(), isNull);
      final Rect surface = tester.getRect(
        find.byKey(composerWritingSurfaceKey),
      );
      final Rect footer = tester.getRect(find.byType(ComposerFooter));
      expect(footer.top, greaterThanOrEqualTo(surface.bottom));
      expect(footer.bottom, closeTo(_desktopSurface.height, 0.5));
    });

    testWidgets('the note flows to the bottom of the writing surface', (
      WidgetTester tester,
    ) async {
      await _pumpComposer(
        tester,
        surface: _desktopSurface,
        initialText: _longNote,
        onAddPhoto: _noPhotos,
      );

      expect(tester.takeException(), isNull);
      expect(
        _viewport(tester).bottom,
        closeTo(
          tester.getRect(find.byKey(composerWritingSurfaceKey)).bottom,
          0.5,
        ),
      );
    });

    testWidgets('an empty note does not scroll', (WidgetTester tester) async {
      await _pumpComposer(
        tester,
        surface: _desktopSurface,
        onAddPhoto: _noPhotos,
      );

      expect(tester.takeException(), isNull);
      expect(_editorScroll(tester).position.maxScrollExtent, 0);
    });

    testWidgets('the end of a long note stays above the actions', (
      WidgetTester tester,
    ) async {
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _pumpComposer(
        tester,
        surface: _desktopSurface,
        initialText: _longNote,
        onAddPhoto: _noPhotos,
      );
      final ScrollableState scroll = _editorScroll(tester);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        driver.contentRect.bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byType(ComposerFooter)).top + 0.5,
        ),
      );
    });
  });
}
