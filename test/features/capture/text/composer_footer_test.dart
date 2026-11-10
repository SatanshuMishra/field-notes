import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/sticker_button.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';

import '../../../support/composer_photo_bar.dart';
import '../../../support/note_editor_driver.dart';
import '../../../support/photo_line_fixture.dart';
import '../../notes/support/notes_harness.dart';

const Size _landscapePhoneSurface = Size(844, 390);
const double _keyboardInset = 200;
const Duration _hold = Duration(milliseconds: 110);

Widget _footer({
  int words = 0,
  VoidCallback? onLeave,
  VoidCallback? onKeep,
  ComposerFooterRoom room = ComposerFooterRoom.desktop,
}) {
  return notesHarness(
    ComposerFooter(
      leaveLabel: 'Let it go',
      keepLabel: 'Keep this',
      words: words,
      onLeave: onLeave,
      onKeep: onKeep,
      room: room,
    ),
    width: composerPhotoBarRoom,
  );
}

void main() {
  testWidgets(
    'Add a photo picks, stores and inserts the photo line at the caret',
    (WidgetTester tester) async {
      final FakePhotoImporter importer = FakePhotoImporter(
        results: <List<String>>[
          <String>[prefixOf(photoIdA)],
        ],
      );
      final TextEditingController controller = TextEditingController(
        text: 'one\ntwo',
      )..selection = caretAt(3);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        notesHarness(
          ComposerPhotoBar(controller: controller, importer: importer.call),
          width: composerPhotoBarRoom,
        ),
      );

      await NoteEditorDriver(tester)
          .press(find.byKey(composerAddPhotoKey), _hold);
      await tester.pump();

      expect(importer.calls, 1);
      expect(controller.text, 'one\n${mdPhotoLine(photoIdA)}\ntwo');
    },
  );

  testWidgets('a refused pick is reported and leaves the note alone', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: 'kept',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      notesHarness(
        ComposerPhotoBar(
          controller: controller,
          importer: FakePhotoImporter(error: denialError).call,
        ),
        width: composerPhotoBarRoom,
      ),
    );

    await NoteEditorDriver(tester)
        .press(find.byKey(composerAddPhotoKey), _hold);
    await tester.pump();

    expect(find.text(photoLibraryErrorMessage), findsOneWidget);
    expect(controller.text, 'kept');

    await tester.pump(kToastLifetime);
    await tester.pump();

    expect(find.text(photoLibraryErrorMessage), findsNothing);
  });

  testWidgets('Add a photo stays reachable through More on a short screen', (
    WidgetTester tester,
  ) async {
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

    await NoteEditorDriver(tester).press(find.byKey(formatMoreKey), _hold);
    await tester.pump();

    expect(find.byKey(composerAddPhotoKey).hitTestable(), findsOneWidget);
    expect(find.text(composerAddPhotoLabel), findsOneWidget);
  });

  testWidgets('the word count is singular at one and tabular', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_footer(words: 1));
    expect(find.text('1 word'), findsOneWidget);

    await tester.pumpWidget(_footer(words: 12));
    final Text count = tester.widget<Text>(find.byKey(composerWordCountKey));
    expect(count.data, '12 words');
    expect(
      count.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('Leave is soft, Keep is the kept press, and each fires once', (
    WidgetTester tester,
  ) async {
    int left = 0;
    int kept = 0;
    await tester.pumpWidget(
      _footer(onLeave: () => left++, onKeep: () => kept++),
    );

    expect(
      tester.widget<StickerButton>(find.byKey(composerLetGoKey)).variant,
      StickerButtonVariant.stageSoft,
    );
    expect(
      tester.widget<StickerButton>(find.byKey(composerSaveKey)).variant,
      StickerButtonVariant.keep,
    );

    await tester.tap(find.byKey(composerLetGoKey));
    await tester.tap(find.byKey(composerSaveKey));
    await tester.pump();

    expect(left, 1);
    expect(kept, 1);
  });

  testWidgets('the row is centred on the word count in every room', (
    WidgetTester tester,
  ) async {
    for (final ComposerFooterRoom room in ComposerFooterRoom.values) {
      await tester.pumpWidget(_footer(words: 3, room: room));

      expect(
        tester.getCenter(find.byKey(composerWordCountKey)).dx,
        closeTo(composerPhotoBarRoom / 2, 0.5),
        reason: '$room',
      );
      expect(
        tester.getRect(find.byKey(composerLetGoKey)).right,
        lessThan(tester.getRect(find.byKey(composerWordCountKey)).left),
        reason: '$room',
      );
      expect(
        tester.getRect(find.byKey(composerSaveKey)).left,
        greaterThan(tester.getRect(find.byKey(composerWordCountKey)).right),
        reason: '$room',
      );
    }
  });
}
