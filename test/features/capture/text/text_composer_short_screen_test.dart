import 'dart:async';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/editor.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';

import '../../notes/support/notes_harness.dart'
    show FakeNoteMediaStore, photoIdA, prefixOf;
import '../core/capture_test_support.dart';
import '../photo/photo_test_support.dart' show FakePhotoPicker;

const Size _landscapePhoneSurface = Size(844, 390);
const double _keyboardInset = 200;

class _ComposerTrigger extends StatelessWidget {
  const _ComposerTrigger({required this.date, required this.onResult});

  final String date;
  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => onResult(await showTextComposer(context, date)),
      child: const Text('open'),
    );
  }
}

Widget _composerApp({
  required NoteWriter writer,
  required ValueChanged<String?> onResult,
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      noteWriterProvider.overrideWith((Ref ref) => writer),
      draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
      ...overrides,
    ],
    child: captureHarness(
      _ComposerTrigger(date: '2026-07-19', onResult: onResult),
    ),
  );
}

List<Override> _mediaOverrides(FakeNoteMediaStore store) {
  return <Override>[
    mediaStoreProvider.overrideWith((Ref ref) async => store),
    notePhotoPickerProvider.overrideWithValue(FakePhotoPicker()),
  ];
}

double get _lineHeight =>
    TypographyTokens.noteBody.fontSize! * TypographyTokens.noteBody.height!;

void _expectInside(Rect inner, Rect outer) {
  expect(inner.left, greaterThanOrEqualTo(outer.left));
  expect(inner.top, greaterThanOrEqualTo(outer.top));
  expect(inner.right, lessThanOrEqualTo(outer.right));
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom));
}

void _useLandscapePhone(WidgetTester tester) {
  tester.view.physicalSize = _landscapePhoneSurface;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardInset);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
      'the new-note composer keeps Add memory on a landscape phone with the keyboard up',
      (WidgetTester tester) async {
    _useLandscapePhone(tester);
    await tester.pumpWidget(
      _composerApp(
        writer: FakeNoteWriter(),
        onResult: (String? _) {},
        overrides: _mediaOverrides(FakeNoteMediaStore()),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(composerAddPhotoKey).hitTestable(), findsOneWidget);
    expect(find.byKey(formatUndoKey), findsOneWidget);
    expect(find.byKey(composerHintsKey), findsNothing);
    _expectInside(
      tester.getRect(find.byKey(composerAddPhotoKey)),
      tester.getRect(find.byType(ComposerFooter)),
    );
    expect(
      tester.getRect(find.byType(ComposerFooter)).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(composerWritingSurfaceKey)).bottom,
      ),
    );
    expect(
      tester.getSize(find.byType(EditableText)).height,
      greaterThanOrEqualTo(_lineHeight),
    );
    expect(
      tester.getRect(find.byKey(composerPanelKey)).bottom -
          tester.getRect(find.byType(ComposerFooter)).bottom,
      lessThanOrEqualTo(_lineHeight),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pick started from the footer lands after the keyboard closes',
      (WidgetTester tester) async {
    _useLandscapePhone(tester);
    final Completer<List<String>> pick = Completer<List<String>>();
    final String reference = prefixOf(photoIdA);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DialogHost(
          child: ComposerShell(
            child: TextComposerSheet(
              onSave: (String _) {},
              onCancel: () {},
              onAddPhoto: () => pick.future,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    _expectInside(
      tester.getRect(find.byKey(composerAddPhotoKey)),
      tester.getRect(find.byType(ComposerFooter)),
    );
    await tester.tap(find.byKey(composerAddPhotoKey));
    await tester.pump();

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    pick.complete(<String>[reference]);
    await tester.pump();

    final EditableText editor =
        tester.widget<EditableText>(find.byType(EditableText));
    expect(editor.controller.text, contains(photoLineFor(reference: reference)));
    expect(
      tester.getRect(find.byType(ComposerFooter)).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(composerWritingSurfaceKey)).bottom,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('the footer and the bar agree on the shared heights', () {
    expect(composerFooterHeight, greaterThanOrEqualTo(formatBarHeight));
    expect(photoRailSlimHeight, formatBarHeight);
  });
}
