import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/notes/photos/photo_import.dart';

import '../../../support/note_editor_driver.dart';

const Size _desktopSurface = Size(1280, 900);
const Size _landscapePhoneSurface = Size(844, 390);
const Size _portraitPhoneSurface = Size(360, 640);

double get _lineHeight =>
    TypographyTokens.noteBody.fontSize! * TypographyTokens.noteBody.height!;

Finder _panel() => find
    .descendant(
      of: find.byType(ComposerShell),
      matching: find.byType(Container),
    )
    .first;

Future<List<String>> _noPhotos() async => const <String>[];

Rect _viewport(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(RawScrollbar),
        matching: find.byType(Scrollable),
      ).first,
    );

ScrollableState _editorScroll(WidgetTester tester) => tester.state(
      find
          .descendant(
            of: find.byType(RawScrollbar),
            matching: find.byType(Scrollable),
          )
          .first,
    );

Future<void> _pumpComposer(
  WidgetTester tester, {
  required Size surface,
  double keyboardInset = 0,
  bool responsive = false,
  String initialText = '',
  PhotoImporter? onAddPhoto,
  TargetPlatform? platform,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: platform == null ? null : ThemeData(platform: platform),
      home: DialogHost(
        child: ComposerShell(
          responsive: responsive,
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
    testWidgets('the editor column measures exactly 560 inside the 640 panel', (
      WidgetTester tester,
    ) async {
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _pumpComposer(tester, surface: _desktopSurface);

      expect(composerPanelWidth, 640);
      expect(tester.getSize(_panel()).width, 640);
      expect(driver.contentRect.size.width, 560);
      expect(driver.visibleHintStyle, isNotNull);
      expect(driver.contentRect.left, 360);
      expect(
        find.descendant(
          of: find.byType(TextComposerSheet),
          matching: find.byType(NoteColumn),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the editor writes in the note body style the reader reads', (
      WidgetTester tester,
    ) async {
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _pumpComposer(tester, surface: _desktopSurface);

      final TextStyle style = driver.style;
      expect(style.fontFamily, TypographyTokens.noteBody.fontFamily);
      expect(style.fontSize, TypographyTokens.noteBody.fontSize);
      expect(style.fontWeight, TypographyTokens.noteBody.fontWeight);
      expect(style.height, TypographyTokens.noteBody.height);
      expect(driver.visibleHintStyle, TypographyTokens.noteBodyPlaceholder);
    });

    testWidgets(
      'a landscape phone with the keyboard up keeps a usable editor',
      (WidgetTester tester) async {
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await _pumpComposer(
          tester,
          surface: _landscapePhoneSurface,
          keyboardInset: 200,
        );

        expect(tester.takeException(), isNull);
        final Size editor = driver.contentRect.size;
        expect(editor.height, greaterThan(0));
        expect(editor.height, greaterThanOrEqualTo(3 * _lineHeight));
        expect(editor.width, 560);
        expect(tester.getRect(_panel()).bottom, lessThanOrEqualTo(390 - 200));
        expect(
          MediaQuery.viewInsetsOf(
            tester.element(find.byType(ComposerShell)),
          ).bottom,
          200,
        );
        expect(
          MediaQuery.viewInsetsOf(
            tester.element(find.byType(TextComposerSheet)),
          ).bottom,
          0,
          reason: 'the shell consumes the keyboard inset once, for the panel',
        );
      },
    );

    testWidgets(
      'a landscape phone with the keyboard up keeps Undo and three lines',
      (WidgetTester tester) async {
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await _pumpComposer(
          tester,
          surface: _landscapePhoneSurface,
          keyboardInset: 200,
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(formatUndoKey), findsOneWidget);
        expect(
          driver.contentRect.size.height,
          greaterThanOrEqualTo(3 * _lineHeight),
        );
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
      );

      expect(tester.takeException(), isNull);
      final Size editor = driver.contentRect.size;
      expect(editor.height, greaterThanOrEqualTo(6 * _lineHeight));
      expect(editor.width, 360 - 4 - 2 * 38);
      expect(tester.getRect(_panel()).bottom, lessThanOrEqualTo(640 - 300));
    });

    for (final ({double window, double column, double centre}) size
        in <({double window, double column, double centre})>[
      (window: 900, column: 560, centre: 450),
      (window: 1280, column: 688, centre: 640),
      (window: 1920, column: 720, centre: 960),
    ]) {
      testWidgets(
          'a responsive composer writes in a ${size.column} column in a '
          '${size.window} window', (WidgetTester tester) async {
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await _pumpComposer(
          tester,
          surface: Size(size.window, 900),
          responsive: true,
        );

        expect(tester.takeException(), isNull);
        final Rect editor = driver.contentRect;
        expect(editor.width, size.column);
        expect(editor.center.dx, size.centre);
      });
    }

    testWidgets('the writing surface takes the height the window gives it',
        (WidgetTester tester) async {
      for (final double window in <double>[800, 1200, 1600]) {
        await _pumpComposer(
          tester,
          surface: Size(1280, window),
          responsive: true,
          onAddPhoto: _noPhotos,
        );

        expect(tester.takeException(), isNull);
        final Rect panel = tester.getRect(_panel());
        final Rect surface =
            tester.getRect(find.byKey(composerWritingSurfaceKey));
        expect(
          panel.height,
          closeTo(window - 2 * composerPanelMarginFor(window), 0.01),
          reason: 'a window ${window}pt tall',
        );
        expect(
          panel.bottom - surface.bottom,
          lessThanOrEqualTo(formatBarHeight + _lineHeight),
          reason: 'a window ${window}pt tall',
        );
      }
    });

    testWidgets('the footer floats over the writing surface, blurred',
        (WidgetTester tester) async {
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _pumpComposer(
        tester,
        surface: _desktopSurface,
        responsive: true,
        initialText: List<String>.filled(80, 'a long line of note').join('\n'),
        onAddPhoto: _noPhotos,
      );

      expect(tester.takeException(), isNull);
      final Rect surface =
          tester.getRect(find.byKey(composerWritingSurfaceKey));
      final Rect footer = tester.getRect(find.byType(ComposerFooter));
      expect(footer.top, greaterThan(surface.top));
      expect(footer.bottom, closeTo(surface.bottom, 0.5));
      expect(
        find.descendant(
          of: find.byType(ComposerFooterVeil),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(
        driver.contentRect.size.height,
        greaterThan(surface.height),
        reason: 'the note keeps scrolling under the footer',
      );
    });

    testWidgets('the composer leaves no dead band under its footer',
        (WidgetTester tester) async {
      await _pumpComposer(
        tester,
        surface: _desktopSurface,
        responsive: true,
        initialText: List<String>.filled(80, 'a long line of note').join('\n'),
        onAddPhoto: _noPhotos,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(composerWritingSurfaceKey)).bottom -
            tester.getRect(find.byType(ComposerFooter)).bottom,
        lessThanOrEqualTo(_lineHeight),
      );
    });

    testWidgets('the note flows to the bottom of the writing surface',
        (WidgetTester tester) async {
      await _pumpComposer(
        tester,
        surface: _desktopSurface,
        responsive: true,
        initialText: List<String>.filled(80, 'a long line of note').join('\n'),
        onAddPhoto: _noPhotos,
      );

      expect(tester.takeException(), isNull);
      expect(
        _viewport(tester).bottom,
        closeTo(
          tester.getRect(find.byKey(composerWritingSurfaceKey)).bottom,
          0.5,
        ),
        reason: 'the note stops short of the footer',
      );
    });

    testWidgets('the footer reaches the bottom edge of the panel',
        (WidgetTester tester) async {
      await _pumpComposer(
        tester,
        surface: _desktopSurface,
        responsive: true,
        platform: TargetPlatform.macOS,
        initialText: List<String>.filled(80, 'a long line of note').join('\n'),
        onAddPhoto: _noPhotos,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(ComposerFooterVeil)).bottom,
        closeTo(
          tester.getRect(_panel()).bottom - composerPanelBorderWidth,
          0.5,
        ),
      );
    });

    testWidgets('an empty note does not scroll', (WidgetTester tester) async {
      await _pumpComposer(
        tester,
        surface: _desktopSurface,
        responsive: true,
        onAddPhoto: _noPhotos,
      );

      expect(tester.takeException(), isNull);
      expect(_editorScroll(tester).position.maxScrollExtent, 0);
    });

    testWidgets('the end of a long note clears the footer',
        (WidgetTester tester) async {
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _pumpComposer(
        tester,
        surface: _desktopSurface,
        responsive: true,
        initialText: List<String>.filled(80, 'a long line of note').join('\n'),
        onAddPhoto: _noPhotos,
      );
      final ScrollableState scroll = _editorScroll(tester);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        driver.contentRect.bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byType(ComposerFooterVeil)).top + 0.5,
        ),
      );
    });

    testWidgets(
      'the page margins shrink with the surface instead of the editor',
      (WidgetTester tester) async {
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await _pumpComposer(tester, surface: _desktopSurface);
        final Size desktopEditor = driver.contentRect.size;
        final Size desktopSurface = tester.getSize(find.byType(RawScrollbar));
        final double desktopChrome =
            desktopSurface.height - desktopEditor.height;

        await _pumpComposer(
          tester,
          surface: _landscapePhoneSurface,
          keyboardInset: 200,
        );
        final Size phoneEditor = driver.contentRect.size;
        final Size phoneSurface = tester.getSize(find.byType(RawScrollbar));
        final double phoneChrome = phoneSurface.height - phoneEditor.height;

        expect(desktopChrome, greaterThan(phoneChrome));
        expect(phoneChrome, lessThan(phoneSurface.height / 2));
        expect(desktopEditor.height, greaterThan(phoneEditor.height));
      },
    );
  });
}
