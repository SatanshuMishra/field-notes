import 'package:field_notes/domain/models/models.dart';
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

class _SlowCountingNoteWriter implements NoteWriter {
  _SlowCountingNoteWriter({required this.delay});

  final Duration delay;
  int saveCalls = 0;

  @override
  Future<NoteSaveResult> save({
    String? entryId,
    required String date,
    required String source,
    List<String> photoMediaIds = const <String>[],
    String? draftKey,
  }) async {
    saveCalls++;
    await Future<void>.delayed(delay);
    return NoteSaveResult(
      entry: Entry(
        id: 'entry-1',
        dayId: 'day-1',
        type: EntryType.text,
        textContent: source,
        createdAt: 0,
        updatedAt: 0,
      ),
    );
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger({required this.timeout, required this.onResult});

  final Duration timeout;
  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => onResult(
        await showGeneralDialog<String>(
          context: context,
          barrierDismissible: false,
          barrierLabel: 'Dismiss note composer',
          pageBuilder: (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return TextComposerConnector(
              date: '2026-07-19',
              saveTimeout: timeout,
            );
          },
        ),
      ),
      child: const Text('open'),
    );
  }
}

void main() {
  testWidgets(
      'a save that completes within the timeout invokes save() exactly once '
      'and pops with the real entry id', (WidgetTester tester) async {
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    final _SlowCountingNoteWriter writer = _SlowCountingNoteWriter(
      delay: const Duration(milliseconds: 200),
    );
    String? result = 'unset';

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          noteWriterProvider.overrideWith((Ref ref) => writer),
          draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        ],
        child: captureHarness(
          _Trigger(
            timeout: const Duration(milliseconds: 500),
            onResult: (String? id) => result = id,
          ),
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
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(writer.saveCalls, 1);
    expect(result, 'entry-1');
    expect(find.byType(TextComposerSheet), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
