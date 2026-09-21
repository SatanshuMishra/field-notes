import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/notes/notes.dart';

import '../support/notes_harness.dart';

const double _phoneRail = 324;

Finder _inSheet(Finder finder) => find.descendant(
      of: find.byKey(photoOptionsSheetKey),
      matching: finder,
    );

bool _segmentSelected(WidgetTester tester, Key key) {
  final Semantics semantics = tester.widget<Semantics>(
    find
        .ancestor(of: find.byKey(key), matching: find.byType(Semantics))
        .first,
  );
  return semantics.properties.selected ?? false;
}

Future<TextEditingController> _openSheet(
  WidgetTester tester, {
  required String text,
  int thumb = 0,
  double measure = 284,
  FakePhotoImporter? importer,
}) async {
  final TextEditingController controller = await pumpPhotoRail(
    tester,
    text: text,
    selection: caretAt(0),
    width: _phoneRail,
    measure: measure,
    importer: importer,
    surface: const Size(360, 780),
  );
  await tester.tap(find.byKey(photoRailThumbKey(thumb)));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  final String a = photoLine(photoIdA);
  final String b = photoLine(photoIdB);
  final String source = 'one\n$a\ntwo\n$b';

  testWidgets(
      'a thumbnail tap at compact width opens the options sheet with all '
      'seven controls at 48dp or more', (WidgetTester tester) async {
    final TextEditingController controller =
        await _openSheet(tester, text: source, measure: 480);

    expect(canFloatAt(measure: 480, em: 16), isTrue);
    expect(find.byKey(photoOptionsSheetKey), findsOneWidget);
    expect(find.text('Photo 1 of 2'), findsOneWidget);
    expect(photoLineIndexAtCaret(controller.text, controller.selection), 0);

    final List<Finder> controls = <Finder>[
      _inSheet(find.byKey(photoSideControlKey)),
      _inSheet(find.byKey(photoSizeControlKey)),
      _inSheet(find.byKey(photoMoveUpKey)),
      _inSheet(find.byKey(photoMoveDownKey)),
      _inSheet(find.byKey(photoReplaceKey)),
      _inSheet(find.byKey(photoRemoveKey)),
      _inSheet(find.byKey(photoCaptionKey)),
    ];
    for (final Finder control in controls) {
      expect(control, findsOneWidget);
      expectTargetAtLeast48(tester, control);
    }
    for (final PhotoSize size in PhotoSize.values) {
      expectTargetAtLeast48(tester, _inSheet(find.byKey(photoSizeKey(size))));
    }
    for (final PhotoSide side in PhotoSide.values) {
      expectTargetAtLeast48(tester, _inSheet(find.byKey(photoSideKey(side))));
    }
    expect(_inSheet(find.byType(PhotoPlacementDiagram)), findsOneWidget);
  });

  testWidgets('the Side control is absent when the measure cannot float',
      (WidgetTester tester) async {
    await _openSheet(tester, text: source);

    expect(canFloatAt(measure: 284, em: 16), isFalse);
    expect(find.byKey(photoOptionsSheetKey), findsOneWidget);
    expect(_inSheet(find.byKey(photoSideControlKey)), findsNothing);
    for (final PhotoSide side in PhotoSide.values) {
      expect(find.byKey(photoSideKey(side)), findsNothing);
    }
    expect(_inSheet(find.byKey(photoSizeControlKey)), findsOneWidget);
    expect(_inSheet(find.byKey(photoRemoveKey)), findsOneWidget);
    expect(
      find.text('Medium — on this screen, text sits above and below'),
      findsOneWidget,
    );
  });

  testWidgets('Size in the sheet rewrites the line and the sheet follows it',
      (WidgetTester tester) async {
    final TextEditingController controller =
        await _openSheet(tester, text: source, thumb: 1);

    await tester.tap(_inSheet(find.byKey(photoSizeKey(PhotoSize.large))));
    await tester.pumpAndSettle();

    expect(
      controller.text,
      source.replaceFirst(b, photoLine(photoIdB, size: PhotoSize.large)),
    );
    expect(find.byKey(photoOptionsSheetKey), findsOneWidget);
    expect(_segmentSelected(tester, photoSizeKey(PhotoSize.large)), isTrue);
    expect(_segmentSelected(tester, photoSizeKey(PhotoSize.medium)), isFalse);
  });

  testWidgets('Move up in the sheet keeps the sheet on the same photo',
      (WidgetTester tester) async {
    final TextEditingController controller =
        await _openSheet(tester, text: '$a\n$b', thumb: 1);

    expect(find.text('Photo 2 of 2'), findsOneWidget);
    await tester.tap(_inSheet(find.byKey(photoMoveUpKey)));
    await tester.pumpAndSettle();

    expect(controller.text, '$b\n$a');
    expect(find.text('Photo 1 of 2'), findsOneWidget);
    expect(
      notePhotoLines(controller.text)[
              photoLineIndexAtCaret(controller.text, controller.selection)!]
          .reference,
      prefixOf(photoIdB),
    );
  });

  testWidgets('Remove closes the sheet and the rail offers Undo',
      (WidgetTester tester) async {
    final TextEditingController controller =
        await _openSheet(tester, text: source);

    await tester.tap(_inSheet(find.byKey(photoRemoveKey)));
    await tester.pumpAndSettle();

    expect(find.byKey(photoOptionsSheetKey), findsNothing);
    expect(controller.text, 'one\ntwo\n$b');
    expect(find.text(photoRemovedMessage), findsOneWidget);

    await tester.tap(find.text(photoRemovedUndoLabel));
    await tester.pump();

    expect(controller.text, source);
  });

  testWidgets('Caption closes the sheet, opens the caption editor and writes '
      'the alt slot', (WidgetTester tester) async {
    final TextEditingController controller =
        await _openSheet(tester, text: source);

    await tester.tap(_inSheet(find.byKey(photoCaptionKey)));
    await tester.pumpAndSettle();

    expect(find.byKey(photoOptionsSheetKey), findsNothing);
    expect(find.text(photoCaptionHelp), findsOneWidget);

    await tester.enterText(find.byKey(photoCaptionFieldKey), 'a]b');
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(photoCaptionFieldKey))
          .controller!
          .text,
      'ab',
    );
    await tester.enterText(find.byKey(photoCaptionFieldKey), 'dusk on the porch');
    await tester.tap(find.byKey(photoCaptionSaveKey));
    await tester.pumpAndSettle();

    expect(notePhotoLines(controller.text)[0].caption, 'dusk on the porch');
    expect(notePhotoLines(controller.text), hasLength(2));
  });

  testWidgets('cancelling the caption editor changes nothing',
      (WidgetTester tester) async {
    final TextEditingController controller =
        await _openSheet(tester, text: source);

    await tester.tap(_inSheet(find.byKey(photoCaptionKey)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(photoCaptionFieldKey), 'not kept');
    await tester.tap(find.byKey(photoCaptionCancelKey));
    await tester.pumpAndSettle();

    expect(controller.text, source);
  });

  testWidgets('Replace closes the sheet and swaps the reference',
      (WidgetTester tester) async {
    final TextEditingController controller = await _openSheet(
      tester,
      text: source,
      importer: FakePhotoImporter(
        results: <List<String>>[
          <String>[prefixOf(photoIdC)],
        ],
      ),
    );

    await tester.tap(_inSheet(find.byKey(photoReplaceKey)));
    await tester.pumpAndSettle();

    expect(find.byKey(photoOptionsSheetKey), findsNothing);
    expect(controller.text, source.replaceFirst(a, photoLine(photoIdC)));
  });
}
