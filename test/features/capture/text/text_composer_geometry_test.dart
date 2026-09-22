import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/editor/editor.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';

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

Future<void> _pumpComposer(
  WidgetTester tester, {
  required Size surface,
  double keyboardInset = 0,
  bool responsive = false,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DialogHost(
        child: ComposerShell(
          responsive: responsive,
          child: TextComposerSheet(onSave: (String _) {}, onCancel: () {}),
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
      await _pumpComposer(tester, surface: _desktopSurface);

      expect(composerPanelWidth, 640);
      expect(tester.getSize(_panel()).width, 640);
      expect(tester.getSize(find.byType(EditableText)).width, 560);
      expect(tester.getSize(find.text('Start writing…')).width, 560);
      expect(tester.getRect(find.byType(EditableText)).left, 360);
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
      await _pumpComposer(tester, surface: _desktopSurface);

      final EditableText editor = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(
        editor.style,
        unmergedFromTheMaterialTextTheme(TypographyTokens.noteBody),
      );
      final Text hint = tester.widget<Text>(find.text('Start writing…'));
      expect(hint.style, TypographyTokens.noteBodyPlaceholder);
    });

    testWidgets(
      'a landscape phone with the keyboard up keeps a usable editor',
      (WidgetTester tester) async {
        await _pumpComposer(
          tester,
          surface: _landscapePhoneSurface,
          keyboardInset: 200,
        );

        expect(tester.takeException(), isNull);
        final Size editor = tester.getSize(find.byType(EditableText));
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
        await _pumpComposer(
          tester,
          surface: _landscapePhoneSurface,
          keyboardInset: 200,
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(formatUndoKey), findsOneWidget);
        expect(
          tester.getSize(find.byType(EditableText)).height,
          greaterThanOrEqualTo(3 * _lineHeight),
        );
      },
    );

    testWidgets('a portrait phone with the keyboard up is not a porthole', (
      WidgetTester tester,
    ) async {
      await _pumpComposer(
        tester,
        surface: _portraitPhoneSurface,
        keyboardInset: 300,
      );

      expect(tester.takeException(), isNull);
      final Size editor = tester.getSize(find.byType(EditableText));
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
        await _pumpComposer(
          tester,
          surface: Size(size.window, 900),
          responsive: true,
        );

        expect(tester.takeException(), isNull);
        final Rect editor = tester.getRect(find.byType(EditableText));
        expect(editor.width, size.column);
        expect(editor.center.dx, size.centre);
      });
    }

    for (final ({double panel, double surface}) size
        in <({double panel, double surface})>[
      (panel: 800, surface: 440),
      (panel: 1200, surface: 660),
      (panel: 1600, surface: 760),
    ]) {
      testWidgets(
          'the writing surface is ${size.surface} tall with ${size.panel} of '
          'height inside the panel', (WidgetTester tester) async {
        await _pumpComposer(
          tester,
          surface: Size(1280, size.panel + 2 * composerPanelBorderWidth),
          responsive: true,
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byKey(composerWritingSurfaceKey)).height,
          closeTo(size.surface, 0.01),
        );
      });
    }

    testWidgets(
      'the page margins shrink with the surface instead of the editor',
      (WidgetTester tester) async {
        await _pumpComposer(tester, surface: _desktopSurface);
        final Size desktopEditor = tester.getSize(find.byType(EditableText));
        final Size desktopSurface = tester.getSize(find.byType(RawScrollbar));
        final double desktopChrome =
            desktopSurface.height - desktopEditor.height;

        await _pumpComposer(
          tester,
          surface: _landscapePhoneSurface,
          keyboardInset: 200,
        );
        final Size phoneEditor = tester.getSize(find.byType(EditableText));
        final Size phoneSurface = tester.getSize(find.byType(RawScrollbar));
        final double phoneChrome = phoneSurface.height - phoneEditor.height;

        expect(desktopChrome, greaterThan(phoneChrome));
        expect(phoneChrome, lessThan(phoneSurface.height / 2));
        expect(desktopEditor.height, greaterThan(phoneEditor.height));
      },
    );
  });
}
