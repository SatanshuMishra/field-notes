import 'dart:async';

import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/note_editor_driver.dart';
import '../core/capture_test_support.dart';

class _HangingNoteWriter implements NoteWriter {
  final Completer<NoteSaveResult> _never = Completer<NoteSaveResult>();
  int saveCalls = 0;

  @override
  Future<NoteSaveResult> save({
    String? entryId,
    required String date,
    required String source,
    List<String> photoMediaIds = const <String>[],
    String? draftKey,
  }) {
    saveCalls++;
    return _never.future;
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger({required this.timeout});

  final Duration timeout;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => showGeneralDialog<String>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Dismiss note composer',
        pageBuilder: (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return TextComposerConnector(
            date: '2026-07-21',
            saveTimeout: timeout,
          );
        },
      ),
      child: const Text('open'),
    );
  }
}

void main() {
  testWidgets(
      'when save() never completes, the save is bounded: the "Saving…" '
      'state clears and a timeout error is surfaced instead of hanging',
      (WidgetTester tester) async {
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    final _HangingNoteWriter writer = _HangingNoteWriter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          noteWriterProvider.overrideWith((Ref ref) => writer),
          draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        ],
        child: captureHarness(
          const _Trigger(timeout: Duration(milliseconds: 100)),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await driver.enterText('a slow day');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));

    expect(writer.saveCalls, 1);
    expect(find.text(textSaveTimeoutMessage), findsOneWidget);
    expect(find.text('Saving…'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(TextComposerSheet), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
