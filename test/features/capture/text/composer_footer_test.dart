import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';

import '../../notes/support/notes_harness.dart';

const Size _landscapePhoneSurface = Size(844, 390);
const double _keyboardInset = 200;

void main() {
  testWidgets('Add memory picks, stores and inserts the photo line at the caret',
      (WidgetTester tester) async {
    final FakePhotoImporter importer = FakePhotoImporter(
      results: <List<String>>[
        <String>[prefixOf(photoIdA)],
      ],
    );
    final TextEditingController controller =
        TextEditingController(text: 'one\ntwo')..selection = caretAt(3);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      notesHarness(
        ComposerFooter(controller: controller, onAddPhoto: importer.call),
      ),
    );

    await tester.tap(find.byKey(composerAddPhotoKey));
    await tester.pump();

    expect(importer.calls, 1);
    expect(controller.text, 'one\n${photoLine(photoIdA)}\ntwo');
  });

  testWidgets('a refused pick is reported and leaves the note alone',
      (WidgetTester tester) async {
    final TextEditingController controller =
        TextEditingController(text: 'kept');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      notesHarness(
        ComposerFooter(
          controller: controller,
          onAddPhoto: FakePhotoImporter(error: denialError).call,
        ),
      ),
    );

    await tester.tap(find.byKey(composerAddPhotoKey));
    await tester.pump();

    expect(find.text(photoLibraryErrorMessage), findsOneWidget);
    expect(controller.text, 'kept');

    await tester.pump(kToastLifetime);
    await tester.pump();

    expect(find.text(photoLibraryErrorMessage), findsNothing);
  });

  testWidgets('Add memory keeps its place on a short screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = _landscapePhoneSurface;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardInset);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DialogHost(
          child: ComposerShell(
            responsive: true,
            child: TextComposerSheet(
              onSave: (String _) {},
              onCancel: () {},
              onAddPhoto: FakePhotoImporter().call,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(composerAddPhotoKey).hitTestable(), findsOneWidget);
    expect(find.byKey(composerHintsKey), findsNothing);
  });
}
