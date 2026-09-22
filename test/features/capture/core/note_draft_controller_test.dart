import 'package:field_notes/domain/services/draft_store.dart';
import 'package:field_notes/features/capture/core/note_draft_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test_support.dart';

const String _key = '01arz3ndektsv4rrffq69g5fav';

Future<void> _sendLifecycle(WidgetTester tester, AppLifecycleState state) {
  return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state.toString()),
    (ByteData? _) {},
  );
}

void main() {
  late FakeDraftStore store;
  late TextEditingController text;
  late NoteDraftController controller;

  setUp(() {
    store = FakeDraftStore();
    text = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
    text.dispose();
  });

  NoteDraftController attach({String initialSource = ''}) {
    controller = NoteDraftController(
      key: _key,
      store: store,
      initialSource: initialSource,
    )..attach(text);
    return controller;
  }

  testWidgets('does not write before 400ms of idle and writes once after',
      (WidgetTester tester) async {
    attach();

    text.text = 'a';
    await tester.pump(const Duration(milliseconds: 200));
    text.text = 'ab';
    await tester.pump(const Duration(milliseconds: 399));
    expect(store.writes, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(store.writes, <({String key, String source})>[
      (key: _key, source: 'ab'),
    ]);

    await tester.pump(const Duration(milliseconds: 400));
    expect(store.writes, hasLength(1));
  });

  testWidgets('flushes on inactive and paused without waiting for the idle gap',
      (WidgetTester tester) async {
    attach();

    text.text = 'going away';
    await _sendLifecycle(tester, AppLifecycleState.inactive);
    await tester.pump();
    expect(store.drafts[_key], 'going away');

    text.text = 'going away for longer';
    await _sendLifecycle(tester, AppLifecycleState.paused);
    await tester.pump();
    expect(store.drafts[_key], 'going away for longer');
    expect(store.writes, hasLength(2));

    await _sendLifecycle(tester, AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.writes, hasLength(2));
  });

  testWidgets('text back at the initial source deletes the draft instead',
      (WidgetTester tester) async {
    attach(initialSource: 'saved');
    text.text = 'saved!';
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.drafts[_key], 'saved!');

    text.text = 'saved';
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.drafts, isEmpty);
    expect(controller.isDirty, isFalse);
  });

  testWidgets('restore applies a differing stored source behind the chip flag',
      (WidgetTester tester) async {
    store.drafts[_key] = 'half typed';
    attach(initialSource: 'saved');
    text.text = 'saved';
    int notifications = 0;
    controller.addListener(() => notifications++);

    final String? restored = await controller.restore();
    await tester.pump(const Duration(milliseconds: 400));

    expect(restored, 'half typed');
    expect(text.text, 'half typed');
    expect(controller.restoredDraft, isTrue);
    expect(controller.isDirty, isTrue);
    expect(notifications, 1);
    expect(store.writes, isEmpty);
  });

  testWidgets('restore of a draft equal to the initial source deletes it',
      (WidgetTester tester) async {
    store.drafts[_key] = 'saved';
    attach(initialSource: 'saved');
    text.text = 'saved';

    expect(await controller.restore(), isNull);
    expect(controller.restoredDraft, isFalse);
    expect(store.drafts, isEmpty);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('editing after a restore clears the chip flag',
      (WidgetTester tester) async {
    store.drafts[_key] = 'half typed';
    attach(initialSource: 'saved');
    await controller.restore();

    text.text = 'half typed more';
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.restoredDraft, isFalse);
    expect(store.drafts[_key], 'half typed more');
  });

  testWidgets('discardRestored reverts the text and deletes the file',
      (WidgetTester tester) async {
    store.drafts[_key] = 'half typed';
    attach(initialSource: 'saved');
    await controller.restore();

    await controller.discardRestored();
    await tester.pump(const Duration(milliseconds: 400));

    expect(text.text, 'saved');
    expect(controller.restoredDraft, isFalse);
    expect(controller.isDirty, isFalse);
    expect(store.drafts, isEmpty);
  });

  testWidgets('discard cancels a pending write and deletes the file',
      (WidgetTester tester) async {
    attach();
    text.text = 'typed';
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.drafts[_key], 'typed');

    text.text = 'typed more';
    await controller.discard();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.drafts, isEmpty);
    expect(store.writes, hasLength(1));
  });

  testWidgets('settle cancels the pending write and waits for in-flight work',
      (WidgetTester tester) async {
    attach();
    text.text = 'typed';
    await controller.settle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.writes, isEmpty);
  });

  testWidgets('a store that fails to resolve disables drafting quietly',
      (WidgetTester tester) async {
    text.text = 'x';
    controller = NoteDraftController(
      key: _key,
      store: Future<DraftStore>.error(StateError('no documents dir')),
    )..attach(text);

    expect(await controller.restore(), isNull);
    text.text = 'typed';
    await tester.pump(const Duration(milliseconds: 400));
    await controller.discard();

    expect(controller.isDirty, isTrue);
  });

  testWidgets('a write failure is swallowed and later writes still run',
      (WidgetTester tester) async {
    attach();
    store.writeError = DraftWriteException('disk full');
    text.text = 'first';
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.drafts, isEmpty);

    store.writeError = null;
    text.text = 'second';
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.drafts[_key], 'second');
  });

  testWidgets('a discarded draft is not written back when the app goes inactive',
      (WidgetTester tester) async {
    attach();
    text.text = 'throw this away';
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.drafts[_key], 'throw this away');

    await controller.discard();
    await _sendLifecycle(tester, AppLifecycleState.inactive);
    await tester.pump();
    text.text = 'throw this away too';
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.drafts, isEmpty);
    expect(store.writes, hasLength(1));
  });

  testWidgets('a sealed draft leaves no file and is not written back',
      (WidgetTester tester) async {
    attach();
    text.text = 'saved once';
    await tester.pump(const Duration(milliseconds: 400));
    text.text = 'saved once more';

    await controller.seal();
    await _sendLifecycle(tester, AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.drafts, isEmpty);
    expect(store.writes, hasLength(1));
  });

  testWidgets('discarding a restored draft keeps drafting what comes next',
      (WidgetTester tester) async {
    store.drafts[_key] = 'half typed';
    attach(initialSource: 'saved');
    await controller.restore();
    await controller.discardRestored();

    text.text = 'saved, then edited again';
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.drafts[_key], 'saved, then edited again');
  });
}
