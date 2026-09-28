import 'dart:async';

import 'package:field_notes/design/feedback/toast.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/capture/photo/photo_intrinsics.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/photos/photo_commands.dart';
import 'package:field_notes/features/note_engine/photos/photo_import_flow.dart';
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String canonicalOf(String reference) => '![](photo/$reference "right medium")';

final class _Harness {
  _Harness(String source, int caret)
    : state = EditorState.create(
        source,
        parse: parseNoteTree,
        selection: NoteSelection.collapsed(caret),
      ) {
    flow = PhotoImportFlow(
      readState: () => state,
      onOutcome: (PhotoImportOutcome outcome) {
        outcomes.add(outcome);
        if (outcome is PhotoImportInserted) {
          apply(outcome.result.transaction);
        }
      },
    );
    flow.addListener(() => notifications += 1);
  }

  EditorState state;
  late final PhotoImportFlow flow;
  final List<PhotoImportOutcome> outcomes = <PhotoImportOutcome>[];
  int notifications = 0;

  void apply(Transaction transaction) {
    state = state.apply(transaction);
    flow.mapThrough(transaction.changes);
  }

  void insert(int at, String text) => apply(
    Transaction(
      changes: ChangeSet.single(state.source.length, at, at, text),
      selection: NoteSelection.collapsed(at + text.length),
      event: TransactionEvent.inputType,
    ),
  );
}

void main() {
  test('the import placeholder is a decoration, not source', () async {
    final _Harness harness = _Harness('A\n\nB', 0);
    final Completer<List<String>> load = Completer<List<String>>();
    PhotoImportOutcome? result;
    bool completed = false;
    unawaited(
      harness.flow.importAtCaret(() => load.future).then((
        PhotoImportOutcome? outcome,
      ) {
        result = outcome;
        completed = true;
      }),
    );
    expect(harness.flow.placeholders, <PhotoImportPlaceholder>[
      const PhotoImportPlaceholder(id: 0, target: PhotoBoundaryTarget(1)),
    ]);
    expect(harness.flow.placeholders.single.offset, 1);
    expect(harness.notifications, 1);
    expect(harness.outcomes, isEmpty);
    expect(harness.state.source, 'A\n\nB');

    load.complete(<String>[]);
    await pumpEventQueue();
    expect(harness.flow.placeholders, isEmpty);
    expect(harness.outcomes, isEmpty);
    expect(completed, isTrue);
    expect(result, isNull);
    expect(harness.state.source, 'A\n\nB');
  });

  test(
    'the finished import inserts at the boundary mapped through later edits',
    () async {
      final _Harness harness = _Harness('A\n\nB', 0);
      final Completer<List<String>> load = Completer<List<String>>();
      unawaited(harness.flow.importAtCaret(() => load.future));
      harness.insert(0, 'xyz');
      harness.insert(4, '!');
      expect(harness.state.source, 'xyzA!\n\nB');
      expect(
        harness.flow.placeholders.single.target,
        const PhotoBoundaryTarget(4),
      );
      expect(
        resolvePhotoTarget(
          harness.state.source,
          harness.state.tree,
          const PhotoBoundaryTarget(4),
        ),
        const PhotoBoundaryTarget(5),
      );
      load.complete(<String>['abc123abc123']);
      await pumpEventQueue();
      expect(
        harness.state.source,
        'xyzA!\n${canonicalOf('abc123abc123')}\n\nB',
      );

      final _Harness second = _Harness('A\n\nB', 0);
      final Completer<List<String>> secondLoad = Completer<List<String>>();
      unawaited(second.flow.importAtCaret(() => secondLoad.future));
      second.insert(1, '\n\nNew');
      secondLoad.complete(<String>['abc123abc123']);
      await pumpEventQueue();
      expect(
        second.state.source,
        'A\n${canonicalOf('abc123abc123')}\n\nNew\n\nB',
      );
    },
  );

  test('a failed import makes no transaction', () async {
    final _Harness harness = _Harness('A\n\nB', 0);
    final PhotoImportOutcome? outcome = await harness.flow.importAtCaret(
      () async => throw Exception('disk'),
    );
    expect(harness.outcomes, <PhotoImportOutcome>[
      const PhotoImportFailed('Could not add that photo. Please try again.'),
    ]);
    expect(outcome, harness.outcomes.single);
    expect(harness.flow.placeholders, isEmpty);

    final _Harness picked = _Harness('A\n\nB', 0);
    await picked.flow.importAtCaret(
      () async => throw const PhotoPickException(undecodablePhotoMessage),
    );
    expect(picked.outcomes, <PhotoImportOutcome>[
      const PhotoImportFailed(undecodablePhotoMessage),
    ]);
    expect(picked.flow.placeholders, isEmpty);
    for (final PhotoImportOutcome reported in <PhotoImportOutcome>[
      ...harness.outcomes,
      ...picked.outcomes,
    ]) {
      expect(reported, isNot(isA<PhotoImportInserted>()));
    }
    expect(harness.state.source, 'A\n\nB');
    expect(picked.state.source, 'A\n\nB');
  });

  testWidgets('the new photo arrives selected with its toast', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final EditorState state = EditorState.create(
      'A',
      parse: parseNoteTree,
      selection: const NoteSelection.collapsed(1),
    );
    final List<PhotoImportOutcome> outcomes = <PhotoImportOutcome>[];
    final PhotoImportFlow flow = PhotoImportFlow(
      readState: () => state,
      onOutcome: outcomes.add,
    );
    addTearDown(flow.dispose);
    final Completer<List<String>> load = Completer<List<String>>();
    PhotoImportOutcome? returned;
    unawaited(
      flow
          .importAtCaret(() => load.future)
          .then((PhotoImportOutcome? outcome) => returned = outcome),
    );
    load.complete(<String>['abc123abc123']);
    await tester.pump();

    expect(outcomes, hasLength(1));
    final PhotoImportInserted inserted = outcomes.single as PhotoImportInserted;
    expect(returned, same(inserted));
    final Transaction transaction = inserted.result.transaction;
    expect(
      state.apply(transaction).source,
      'A\n${canonicalOf('abc123abc123')}\n',
    );
    expect(transaction.selection, const NoteSelection(anchor: 2, head: 40));
    expect(transaction.event, TransactionEvent.photo);
    expect(transaction.addToHistory, isTrue);
    expect(inserted.result.toast, PhotoToast.added);

    expect(photoAddedToastMessage, 'Photo added — tap it to size & place it');
    expect(photoAddedToastMessage.contains('—'), isTrue);
    expect(photoAddedToastLifetime, const Duration(seconds: 4));

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext builderContext) {
            context = builderContext;
            return const SizedBox();
          },
        ),
      ),
    );
    showTransientToast(
      context,
      photoAddedToastMessage,
      lifetime: photoAddedToastLifetime,
    );
    await tester.pump();
    expect(find.text(photoAddedToastMessage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.text(photoAddedToastMessage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text(photoAddedToastMessage), findsNothing);
  });

  test('a late result after dispose is dropped', () async {
    for (final bool fails in <bool>[false, true]) {
      final _Harness harness = _Harness('A\n\nB', 0);
      final Completer<List<String>> load = Completer<List<String>>();
      PhotoImportOutcome? result;
      bool completed = false;
      unawaited(
        harness.flow.importAtCaret(() => load.future).then((
          PhotoImportOutcome? outcome,
        ) {
          result = outcome;
          completed = true;
        }),
      );
      harness.flow.dispose();
      if (fails) {
        load.completeError(Exception('late'));
      } else {
        load.complete(<String>['abc123abc123']);
      }
      await pumpEventQueue();
      expect(completed, isTrue);
      expect(result, isNull);
      expect(harness.outcomes, isEmpty);
      expect(harness.state.source, 'A\n\nB');
      harness.flow.mapThrough(ChangeSet.single(5, 0, 0, 'x'));
    }
  });

  test('a failure left to the caller is only returned', () async {
    final _Harness harness = _Harness('A', 1);
    final Exception thrown = Exception('disk');
    final PhotoImportOutcome? outcome = await harness.flow.importAtCaret(
      () async => throw thrown,
      reportFailure: false,
    );
    expect(harness.outcomes, isEmpty);
    expect(outcome, isA<PhotoImportFailed>());
    final PhotoImportFailed failed = outcome! as PhotoImportFailed;
    expect(failed.error, same(thrown));
    expect(failed.stackTrace, isNotNull);
    expect(harness.flow.placeholders, isEmpty);
  });

  test('two imports pending at once each keep their place', () async {
    final _Harness harness = _Harness('A\n\nB', 0);
    final Completer<List<String>> x = Completer<List<String>>();
    final Completer<List<String>> y = Completer<List<String>>();
    unawaited(harness.flow.importAtCaret(() => x.future));
    unawaited(harness.flow.importAtBoundary(4, () => y.future));
    expect(harness.flow.placeholders, <PhotoImportPlaceholder>[
      const PhotoImportPlaceholder(id: 0, target: PhotoBoundaryTarget(1)),
      const PhotoImportPlaceholder(id: 1, target: PhotoBoundaryTarget(4)),
    ]);
    x.complete(<String>['aaa111aaa111']);
    await pumpEventQueue();
    expect(harness.state.source, 'A\n${canonicalOf('aaa111aaa111')}\n\nB');
    y.complete(<String>['bbb222bbb222']);
    await pumpEventQueue();
    expect(
      harness.state.source,
      'A\n${canonicalOf('aaa111aaa111')}\n\nB\n'
      '${canonicalOf('bbb222bbb222')}\n',
    );
    expect(harness.flow.placeholders, isEmpty);
  });

  test('an empty line target follows typing on that line', () async {
    final _Harness plain = _Harness('A\n\n\nB', 2);
    final Completer<List<String>> load = Completer<List<String>>();
    unawaited(plain.flow.importAtCaret(() => load.future));
    expect(
      plain.flow.placeholders.single.target,
      const PhotoEmptyLineTarget(2, 2),
    );
    load.complete(<String>['abc123abc123']);
    await pumpEventQueue();
    expect(plain.state.source, 'A\n${canonicalOf('abc123abc123')}\n\nB');

    final _Harness typed = _Harness('A\n\n\nB', 2);
    final Completer<List<String>> typedLoad = Completer<List<String>>();
    unawaited(typed.flow.importAtCaret(() => typedLoad.future));
    typed.insert(2, 'hi');
    typedLoad.complete(<String>['abc123abc123']);
    await pumpEventQueue();
    expect(typed.state.source, 'A\nhi\n${canonicalOf('abc123abc123')}\n\nB');
  });

  test(
    'an import at the start writes the line break after the photo',
    () async {
      final _Harness harness = _Harness('A', 1);
      await harness.flow.importAtBoundary(
        0,
        () async => <String>['abc123abc123'],
      );
      expect(harness.state.source, '${canonicalOf('abc123abc123')}\nA');
    },
  );

  test('two references in one load go in order', () async {
    final _Harness harness = _Harness('A', 1);
    final PhotoImportOutcome? outcome = await harness.flow.importAtCaret(
      () async => <String>['aaa111aaa111', 'bbb222bbb222'],
    );
    final String first = canonicalOf('aaa111aaa111');
    final String second = canonicalOf('bbb222bbb222');
    expect(harness.state.source, 'A\n$first\n$second\n');
    final int start = 2 + first.length + 1;
    expect(
      (outcome! as PhotoImportInserted).result.transaction.selection,
      NoteSelection(anchor: start, head: start + second.length),
    );
  });

  test('targets map through edits and resolve to boundaries', () {
    final ChangeSet insertion = ChangeSet.single(5, 1, 1, 'xy');
    expect(
      mapPhotoTarget(const PhotoBoundaryTarget(1), insertion),
      const PhotoBoundaryTarget(1),
    );
    expect(
      mapPhotoTarget(const PhotoBoundaryTarget(3), insertion),
      const PhotoBoundaryTarget(5),
    );
    expect(
      mapPhotoTarget(const PhotoEmptyLineTarget(1, 1), insertion),
      const PhotoEmptyLineTarget(1, 3),
    );

    const String source = 'A\n\nB';
    final MdTree tree = parseNoteTree(source);
    expect(
      resolvePhotoTarget(source, tree, const PhotoBoundaryTarget(1)),
      const PhotoBoundaryTarget(1),
    );
    expect(
      resolvePhotoTarget(source, tree, const PhotoEmptyLineTarget(2, 2)),
      const PhotoEmptyLineTarget(2, 2),
    );
    expect(
      resolvePhotoTarget(source, tree, const PhotoBoundaryTarget(99)),
      const PhotoBoundaryTarget(4),
    );

    const String before = 'one\n\ntwo';
    final ChangeSet deletion = ChangeSet.single(before.length, 3, 5, ' ');
    final PhotoTarget mapped = mapPhotoTarget(
      const PhotoBoundaryTarget(3),
      deletion,
    );
    expect(mapped, const PhotoBoundaryTarget(3));
    final String after = deletion.apply(before);
    expect(after, 'one two');
    expect(
      resolvePhotoTarget(after, parseNoteTree(after), mapped),
      const PhotoBoundaryTarget(7),
    );
  });

  test('the placeholder is half a desktop column and a whole phone column', () {
    final Size desktop = photoImportPlaceholderSize(columnWidth: 688, em: 16);
    expect(desktop.width, 344);
    expect(desktop.height, closeTo(229.33, 0.01));
    final Size phone = photoImportPlaceholderSize(columnWidth: 350, em: 16);
    expect(phone.width, 350);
    expect(phone.height, closeTo(233.33, 0.01));
    expect(
      photoImportPlaceholderSize(columnWidth: 480, em: 16),
      const Size(240, 160),
    );
  });

  testWidgets('the placeholder box draws the hatched placeholder at its size', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: PhotoImportPlaceholderBox(size: Size(344, 229.33)),
        ),
      ),
    );
    expect(find.byType(NeutralMediaPlaceholder), findsOneWidget);
    final Size size = tester.getSize(find.byType(NeutralMediaPlaceholder));
    expect(size.width, 344);
    expect(size.height, closeTo(229.33, 0.001));
  });

  testWidgets('a toast with no lifetime keeps the default lifetime', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext builderContext) {
            context = builderContext;
            return const SizedBox();
          },
        ),
      ),
    );
    showTransientToast(context, 'Saved');
    await tester.pump();
    await tester.pump(kToastLifetime - const Duration(milliseconds: 100));
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Saved'), findsNothing);
  });
}
