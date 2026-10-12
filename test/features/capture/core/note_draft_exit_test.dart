import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:field_notes/domain/services/draft_store.dart';
import 'package:field_notes/features/capture/core/note_draft_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const String _key = '01arz3ndektsv4rrffq69g5fav';

class _GatedStore implements DraftStore {
  _GatedStore({this.fail = false});

  final bool fail;
  final Completer<void> gate = Completer<void>();
  final Map<String, String> drafts = <String, String>{};

  @override
  Future<String?> read(String key) async => drafts[key];

  @override
  Future<void> write(String key, String source) async {
    await gate.future;
    if (fail) {
      throw DraftWriteException('disk full');
    }
    drafts[key] = source;
  }

  @override
  Future<void> delete(String key) async {
    drafts.remove(key);
  }
}

void main() {
  late TextEditingController text;
  late NoteDraftController controller;

  setUp(() {
    text = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
    text.dispose();
  });

  NoteDraftController attach(DraftStore store) {
    controller = NoteDraftController(key: _key, store: store)..attach(text);
    return controller;
  }

  testWidgets('an exit request saves the open draft first', (
    WidgetTester tester,
  ) async {
    final _GatedStore store = _GatedStore();
    attach(store);
    text.text = 'typed before the update';

    bool completed = false;
    AppExitResponse? response;
    final Future<void> pending = controller.didRequestAppExit().then((
      AppExitResponse value,
    ) {
      completed = true;
      response = value;
    });

    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(completed, isFalse);
    expect(store.drafts, isEmpty);

    store.gate.complete();
    await tester.runAsync(() => pending);

    expect(store.drafts[_key], 'typed before the update');
    expect(response, AppExitResponse.exit);
  });

  testWidgets('an exit request still exits when the write fails', (
    WidgetTester tester,
  ) async {
    final _GatedStore store = _GatedStore(fail: true);
    store.gate.complete();
    attach(store);
    text.text = 'lost to a full disk';

    final AppExitResponse response = (await tester.runAsync(
      controller.didRequestAppExit,
    ))!;

    expect(response, AppExitResponse.exit);
    expect(store.drafts, isEmpty);
  });

  testWidgets('a sealed controller exits at once without writing', (
    WidgetTester tester,
  ) async {
    final _GatedStore store = _GatedStore();
    attach(store);
    text.text = 'about to be discarded';
    await tester.runAsync(controller.seal);

    final AppExitResponse response = (await tester.runAsync(
      controller.didRequestAppExit,
    ))!;

    expect(response, AppExitResponse.exit);
    expect(store.drafts, isEmpty);
  });
}
