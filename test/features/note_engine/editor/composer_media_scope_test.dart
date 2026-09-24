import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/editor/composer_media_scope.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../notes/support/notes_harness.dart';

class _RecordingDependant extends StatefulWidget {
  const _RecordingDependant({required this.onDependency});

  final VoidCallback onDependency;

  @override
  State<_RecordingDependant> createState() => _RecordingDependantState();
}

class _RecordingDependantState extends State<_RecordingDependant> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ComposerMediaScope.maybeResolverOf(context);
    widget.onDependency();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('the scope resolver wins over the note media scope',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final FakeNoteMediaResolver outer = FakeNoteMediaResolver()
      ..memoizeAll();
    final FakeNoteMediaResolver inner = FakeNoteMediaResolver()
      ..memoizeAll();

    MediaResolver? recorded;
    final Widget builder = Builder(
      builder: (BuildContext context) {
        recorded = ComposerMediaScope.maybeResolverOf(context);
        return const SizedBox.shrink();
      },
    );

    await tester.pumpWidget(
      notesHarness(
        NoteMediaScope(
          resolver: outer,
          child: ComposerMediaScope(resolver: inner, child: builder),
        ),
      ),
    );
    expect(recorded, same(inner));

    await tester.pumpWidget(
      notesHarness(
        NoteMediaScope(
          resolver: outer,
          child: ComposerMediaScope(resolver: null, child: builder),
        ),
      ),
    );
    expect(recorded, isNull);

    await tester.pumpWidget(
      notesHarness(
        NoteMediaScope(resolver: outer, child: builder),
      ),
    );
    expect(recorded, same(outer));

    await tester.pumpWidget(notesHarness(builder));
    expect(recorded, isNull);
  });

  test('updateShouldNotify differs only by resolver identity', () {
    final FakeNoteMediaResolver resolver = FakeNoteMediaResolver();
    final FakeNoteMediaResolver otherResolver = FakeNoteMediaResolver();
    final ComposerMediaScope original = ComposerMediaScope(
      resolver: resolver,
      child: const SizedBox.shrink(),
    );
    final ComposerMediaScope sameResolver = ComposerMediaScope(
      resolver: resolver,
      child: const SizedBox.shrink(),
    );
    final ComposerMediaScope differentResolver = ComposerMediaScope(
      resolver: otherResolver,
      child: const SizedBox.shrink(),
    );

    expect(original.updateShouldNotify(sameResolver), isFalse);
    expect(original.updateShouldNotify(differentResolver), isTrue);
  });

  testWidgets(
      'dependants are notified only when the resolver instance changes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final FakeNoteMediaResolver first = FakeNoteMediaResolver()
      ..memoizeAll();
    final FakeNoteMediaResolver second = FakeNoteMediaResolver()
      ..memoizeAll();

    int dependencyCalls = 0;
    final Widget dependant = _RecordingDependant(
      onDependency: () => dependencyCalls++,
    );

    await tester.pumpWidget(
      notesHarness(ComposerMediaScope(resolver: first, child: dependant)),
    );
    expect(dependencyCalls, 1);

    await tester.pumpWidget(
      notesHarness(ComposerMediaScope(resolver: first, child: dependant)),
    );
    expect(dependencyCalls, 1);

    await tester.pumpWidget(
      notesHarness(ComposerMediaScope(resolver: second, child: dependant)),
    );
    expect(dependencyCalls, 2);
  });
}
